import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../storage/local_store.dart';

/// Keeps a copy of every API read for the signed-in user and answers from it
/// when the server can't be reached, so the app keeps showing data offline.
/// Reports whether the server is reachable through [onReachable] and
/// [onUnreachable].
///
/// Only `GET`s are cached, and not short-lived links (document downloads),
/// so stale data is never written anywhere. The server stays the source of
/// truth: the next successful read replaces the copy.
class OfflineCacheInterceptor extends Interceptor {
  OfflineCacheInterceptor({
    required this._store,
    required this._userId,
    required this._onReachable,
    required this._onUnreachable,
  });

  /// Set on responses that came from the saved copy.
  static const String fromCacheKey = 'drivon.fromCache';

  final LocalStore _store;
  final String? Function() _userId;
  final VoidCallback _onReachable;
  final VoidCallback _onUnreachable;

  /// Reads whose answers are worth keeping. Download links expire after
  /// minutes and the assistant's answers are not reads.
  static bool cacheable(RequestOptions request) {
    if (request.method.toUpperCase() != 'GET') return false;
    final path = request.uri.path;
    return path.startsWith('/api/v1/') && !path.endsWith('/download-url');
  }

  /// The path and query, with query parameters in a stable order.
  static String cacheKey(RequestOptions request) {
    final uri = request.uri;
    final query = uri.queryParametersAll.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final queryText = [
      for (final entry in query)
        for (final value in entry.value) '${entry.key}=$value',
    ].join('&');
    return queryText.isEmpty ? uri.path : '${uri.path}?$queryText';
  }

  /// Network trouble, as opposed to an answer from the server.
  static bool unreachable(DioException error) => switch (error.type) {
    DioExceptionType.connectionError ||
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => true,
    DioExceptionType.unknown => error.error is SocketException,
    _ => false,
  };

  @override
  Future<void> onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) async {
    _onReachable();
    final request = response.requestOptions;
    final userId = _userId();
    if (userId != null && cacheable(request) && response.statusCode == 200) {
      try {
        await _store.writeCache(
          userId,
          cacheKey(request),
          jsonEncode(response.data),
        );
      } on Object catch (error) {
        // A full disk must not break the app; the copy is only a fallback.
        debugPrint('Could not keep an offline copy: $error');
      }
    }
    handler.next(response);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (!unreachable(err)) {
      if (err.response != null) _onReachable();
      handler.next(err);
      return;
    }
    _onUnreachable();
    final request = err.requestOptions;
    final userId = _userId();
    if (userId != null && cacheable(request)) {
      String? saved;
      try {
        saved = await _store.readCache(userId, cacheKey(request));
      } on Object catch (error) {
        debugPrint('Could not read the offline copy: $error');
      }
      if (saved != null) {
        handler.resolve(
          Response<dynamic>(
            requestOptions: request,
            data: jsonDecode(saved),
            statusCode: 200,
            extra: {fromCacheKey: true},
          ),
        );
        return;
      }
    }
    handler.next(err);
  }
}
