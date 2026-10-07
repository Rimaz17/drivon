import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../errors/app_exception.dart';
import '../storage/token_store.dart';
import 'api_client.dart';

/// Adds the access token to API requests and recovers from expired ones.
///
/// On a 401 it refreshes the token pair once and retries the request.
/// Concurrent 401s share a single refresh: the server rotates refresh tokens
/// and treats reuse as theft, so parallel refreshes would end the session.
/// A rejected refresh clears the tokens and reports the session as expired;
/// a network failure during refresh keeps the session for a later retry.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this._tokenStore,
    required this._refreshClient,
    required this._onSessionExpired,
  });

  static const String refreshPath = '/api/v1/auth/refresh';

  final TokenStore _tokenStore;
  final Dio _refreshClient;
  final void Function() _onSessionExpired;
  late final Dio _client;
  Future<String?>? _refreshing;

  /// Installs the interceptor on [dio], which is also used for retries.
  void attachTo(Dio dio) {
    _client = dio;
    dio.interceptors.add(this);
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_isAuthenticated(options)) {
      final tokens = await _tokenStore.read();
      if (tokens != null) {
        options.headers[HttpHeaders.authorizationHeader] = _bearer(
          tokens.accessToken,
        );
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final shouldRecover =
        err.response?.statusCode == HttpStatus.unauthorized &&
        _isAuthenticated(options) &&
        options.extra[RequestFlags.retried] != true;
    if (!shouldRecover) {
      handler.next(err);
      return;
    }

    final String? accessToken;
    try {
      accessToken = await _freshAccessToken(options);
    } on DioException {
      // Could not reach the server to refresh; keep the session.
      handler.next(err);
      return;
    }
    if (accessToken == null) {
      _onSessionExpired();
      handler.next(err.copyWith(error: const SessionExpiredException()));
      return;
    }

    options.extra[RequestFlags.retried] = true;
    options.headers[HttpHeaders.authorizationHeader] = _bearer(accessToken);
    try {
      handler.resolve(await _client.fetch<dynamic>(options));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  /// A token newer than the one [failed] used, refreshing only if needed.
  Future<String?> _freshAccessToken(RequestOptions failed) async {
    final current = await _tokenStore.read();
    if (current == null) return null;
    final sent = failed.headers[HttpHeaders.authorizationHeader];
    if (sent != _bearer(current.accessToken)) {
      return current.accessToken; // Another request already refreshed.
    }
    return _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
  }

  Future<String?> _refresh() async {
    final current = await _tokenStore.read();
    if (current == null) return null;
    try {
      final response = await _refreshClient.post<Map<String, dynamic>>(
        refreshPath,
        data: {'refreshToken': current.refreshToken},
      );
      final tokens = AuthTokens.fromJson(response.data!);
      await _tokenStore.save(tokens);
      return tokens.accessToken;
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == HttpStatus.unauthorized ||
          status == HttpStatus.badRequest) {
        await _tokenStore.clear();
        return null;
      }
      rethrow;
    }
  }

  static bool _isAuthenticated(RequestOptions options) =>
      options.extra[RequestFlags.authenticated] != false;

  static String _bearer(String token) => 'Bearer $token';
}
