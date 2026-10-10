import 'package:dio/dio.dart';
import 'package:drivon/core/network/offline_cache_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import '../../support/offline_fakes.dart';

void main() {
  late InMemoryLocalStore store;
  late Dio dio;
  late List<String> events;
  String? userId;
  var online = true;

  setUp(() {
    store = InMemoryLocalStore();
    events = [];
    userId = 'user-1';
    online = true;
    dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
      ..httpClientAdapter = FakeHttpAdapter((request) async {
        if (!online) {
          throw DioException.connectionError(
            requestOptions: request,
            reason: 'offline',
          );
        }
        if (request.uri.path.endsWith('/missing')) {
          return jsonBody(404, {'code': 'NOT_FOUND'});
        }
        return jsonBody(200, {
          'path': request.uri.path,
          'query': request.uri.query,
        });
      })
      ..interceptors.add(
        OfflineCacheInterceptor(
          store: store,
          userId: () => userId,
          onReachable: () => events.add('reachable'),
          onUnreachable: () => events.add('unreachable'),
        ),
      );
  });

  test('answers a read from the saved copy when offline', () async {
    await dio.get<Map<String, dynamic>>(
      '/api/v1/vehicles',
      queryParameters: {'size': 20, 'page': 0},
    );
    online = false;

    final response = await dio.get<Map<String, dynamic>>(
      '/api/v1/vehicles',
      queryParameters: {'page': 0, 'size': 20},
    );

    expect(response.data, {
      'path': '/api/v1/vehicles',
      'query': 'size=20&page=0',
    });
    expect(response.extra[OfflineCacheInterceptor.fromCacheKey], isTrue);
    expect(events, ['reachable', 'unreachable']);
  });

  test('without a saved copy the connection error comes through', () async {
    online = false;

    await expectLater(
      dio.get<Map<String, dynamic>>('/api/v1/vehicles'),
      throwsA(
        isA<DioException>().having(
          (e) => e.type,
          'type',
          DioExceptionType.connectionError,
        ),
      ),
    );
  });

  test('keeps copies per user', () async {
    await dio.get<Map<String, dynamic>>('/api/v1/vehicles');
    userId = 'user-2';
    online = false;

    await expectLater(
      dio.get<Map<String, dynamic>>('/api/v1/vehicles'),
      throwsA(isA<DioException>()),
    );
  });

  test(
    'never keeps writes, download links or reads while signed out',
    () async {
      await dio.post<Map<String, dynamic>>('/api/v1/vehicles', data: {});
      await dio.get<Map<String, dynamic>>(
        '/api/v1/vehicles/v1/documents/d1/download-url',
      );
      userId = null;
      await dio.get<Map<String, dynamic>>('/api/v1/users/me');

      expect(store.cache, isEmpty);
    },
  );

  test('an error answer means the server is reachable', () async {
    await expectLater(
      dio.get<Map<String, dynamic>>('/api/v1/missing'),
      throwsA(isA<DioException>()),
    );

    expect(events, ['reachable']);
    expect(store.cache, isEmpty);
  });

  test('a failed write while offline is reported as unreachable', () async {
    online = false;

    await expectLater(
      dio.post<Map<String, dynamic>>('/api/v1/vehicles', data: {}),
      throwsA(isA<DioException>()),
    );
    expect(events, ['unreachable']);
  });

  test('cache keys ignore the order of query parameters', () {
    String key(String url) =>
        OfflineCacheInterceptor.cacheKey(RequestOptions(path: url));

    expect(
      key('http://api.test/api/v1/x?b=2&a=1'),
      key('http://api.test/api/v1/x?a=1&b=2'),
    );
    expect(key('http://api.test/api/v1/x'), '/api/v1/x');
  });
}
