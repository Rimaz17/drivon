import 'package:dio/dio.dart';

import '../../app/environment.dart';
import '../errors/app_exception.dart';
import 'error_mapper.dart';

/// Shared HTTP settings. The receive timeout is generous because the free
/// Render instance can take close to a minute to wake from sleep.
BaseOptions apiBaseOptions({String? baseUrl}) => BaseOptions(
  baseUrl: baseUrl ?? Environment.apiBaseUrl,
  connectTimeout: const Duration(seconds: 20),
  sendTimeout: const Duration(seconds: 20),
  receiveTimeout: const Duration(seconds: 70),
  contentType: Headers.jsonContentType,
);

/// Request option that skips the access token (sign-in, sign-up, refresh).
final Options publicRequest = Options(
  extra: {RequestFlags.authenticated: false},
);

abstract final class RequestFlags {
  /// `false` for endpoints that must not carry or refresh an access token.
  static const String authenticated = 'drivon.authenticated';

  /// Set on a request that was already retried after a token refresh.
  static const String retried = 'drivon.retried';
}

/// Runs an API call and converts transport errors into [AppException]s.
Future<T> guardApi<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on DioException catch (error) {
    throw mapDioException(error);
  }
}
