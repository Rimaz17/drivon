import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drivon/core/storage/token_store.dart';

/// In-memory [TokenStore] for tests.
class InMemoryTokenStore implements TokenStore {
  InMemoryTokenStore([this.tokens]);

  AuthTokens? tokens;

  @override
  Future<AuthTokens?> read() async => tokens;

  @override
  Future<void> save(AuthTokens tokens) async => this.tokens = tokens;

  @override
  Future<void> clear() async => tokens = null;
}

typedef FakeRoute = Future<ResponseBody> Function(RequestOptions request);

/// Serves canned responses instead of making network calls, and records
/// every request it receives.
class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter(this.route);

  final FakeRoute route;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return route(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonBody(int status, Object body) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);
