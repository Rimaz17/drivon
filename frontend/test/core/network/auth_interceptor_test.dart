import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drivon/core/errors/app_exception.dart';
import 'package:drivon/core/network/api_client.dart';
import 'package:drivon/core/network/auth_interceptor.dart';
import 'package:drivon/core/network/error_mapper.dart';
import 'package:drivon/core/storage/token_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

void main() {
  late InMemoryTokenStore store;
  late FakeHttpAdapter api;
  late FakeHttpAdapter refreshApi;
  late Dio dio;
  late int sessionExpiredCount;

  /// Valid tokens are "access-N"; the API accepts only the newest one.
  var validAccessToken = 'access-1';
  var refreshCalls = 0;

  setUp(() {
    store = InMemoryTokenStore(
      const AuthTokens(accessToken: 'access-1', refreshToken: 'refresh-1'),
    );
    validAccessToken = 'access-1';
    refreshCalls = 0;
    sessionExpiredCount = 0;
    api = FakeHttpAdapter((request) async {
      if (request.path.startsWith('/api/v1/auth/')) {
        return jsonBody(200, {'ok': true});
      }
      final auth = request.headers[HttpHeaders.authorizationHeader];
      return auth == 'Bearer $validAccessToken'
          ? jsonBody(200, {'ok': true})
          : jsonBody(401, {'code': 'UNAUTHENTICATED'});
    });
    dio = Dio(apiBaseOptions(baseUrl: 'http://api.test'))
      ..httpClientAdapter = api;
    final refreshClient = Dio(apiBaseOptions(baseUrl: 'http://api.test'));
    refreshApi = FakeHttpAdapter((request) async {
      refreshCalls++;
      // Simulate latency so concurrent callers overlap.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      validAccessToken = 'access-${refreshCalls + 1}';
      return jsonBody(200, {
        'accessToken': validAccessToken,
        'refreshToken': 'refresh-${refreshCalls + 1}',
      });
    });
    refreshClient.httpClientAdapter = refreshApi;
    AuthInterceptor(
      tokenStore: store,
      refreshClient: refreshClient,
      onSessionExpired: () => sessionExpiredCount++,
    ).attachTo(dio);
  });

  test('sends the access token on authenticated requests only', () async {
    await dio.get<dynamic>('/api/v1/vehicles');
    await dio.post<dynamic>('/api/v1/auth/login', options: publicRequest);

    expect(
      api.requests[0].headers[HttpHeaders.authorizationHeader],
      'Bearer access-1',
    );
    expect(
      api.requests[1].headers.containsKey(HttpHeaders.authorizationHeader),
      isFalse,
    );
  });

  test('refreshes an expired token once and retries the request', () async {
    validAccessToken = 'access-0-rotated-elsewhere';

    final response = await dio.get<dynamic>('/api/v1/vehicles');

    expect(response.statusCode, 200);
    expect(refreshCalls, 1);
    expect(store.tokens?.refreshToken, 'refresh-2');
    expect(refreshApi.requests.single.data, {'refreshToken': 'refresh-1'});
  });

  test('concurrent 401s share a single refresh', () async {
    validAccessToken = 'expired';

    final responses = await Future.wait([
      dio.get<dynamic>('/api/v1/vehicles'),
      dio.get<dynamic>('/api/v1/users/me'),
      dio.get<dynamic>('/api/v1/vehicles/1'),
    ]);

    expect(responses.map((r) => r.statusCode), everyElement(200));
    expect(refreshCalls, 1);
  });

  test(
    'a rejected refresh clears tokens and reports the session ended',
    () async {
      validAccessToken = 'expired';
      final refreshClient = Dio(apiBaseOptions(baseUrl: 'http://api.test'))
        ..httpClientAdapter = FakeHttpAdapter(
          (_) async => jsonBody(401, {'code': 'INVALID_REFRESH_TOKEN'}),
        );
      dio.interceptors.clear();
      AuthInterceptor(
        tokenStore: store,
        refreshClient: refreshClient,
        onSessionExpired: () => sessionExpiredCount++,
      ).attachTo(dio);

      final error = await dio
          .get<dynamic>('/api/v1/vehicles')
          .then<Object?>((_) => null, onError: (Object e) => e);

      expect(
        mapDioException(error! as DioException),
        isA<SessionExpiredException>(),
      );
      expect(store.tokens, isNull);
      expect(sessionExpiredCount, 1);
    },
  );

  test('a network failure during refresh keeps the session', () async {
    validAccessToken = 'expired';
    final refreshClient = Dio(apiBaseOptions(baseUrl: 'http://api.test'))
      ..httpClientAdapter = FakeHttpAdapter(
        (request) => Future.error(
          DioException.connectionError(
            requestOptions: request,
            reason: 'offline',
          ),
        ),
      );
    dio.interceptors.clear();
    AuthInterceptor(
      tokenStore: store,
      refreshClient: refreshClient,
      onSessionExpired: () => sessionExpiredCount++,
    ).attachTo(dio);

    await expectLater(
      dio.get<dynamic>('/api/v1/vehicles'),
      throwsA(isA<DioException>()),
    );
    expect(store.tokens, isNotNull);
    expect(sessionExpiredCount, 0);
  });

  test('does not refresh for 401s from public endpoints', () async {
    final login = Dio(apiBaseOptions(baseUrl: 'http://api.test'))
      ..httpClientAdapter = FakeHttpAdapter(
        (_) async => jsonBody(401, {'code': 'INVALID_CREDENTIALS'}),
      );
    AuthInterceptor(
      tokenStore: store,
      refreshClient: Dio()..httpClientAdapter = refreshApi,
      onSessionExpired: () => sessionExpiredCount++,
    ).attachTo(login);

    await expectLater(
      login.post<dynamic>('/api/v1/auth/login', options: publicRequest),
      throwsA(isA<DioException>()),
    );
    expect(refreshCalls, 0);
  });
}
