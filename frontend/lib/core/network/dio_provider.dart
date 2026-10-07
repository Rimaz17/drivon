import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/token_store.dart';
import 'api_client.dart';
import 'auth_interceptor.dart';
import 'session_events.dart';

/// The app's HTTP client for the Drivon API, with automatic token handling.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(apiBaseOptions());
  // Refresh calls bypass the interceptor so they never recurse.
  final refreshClient = Dio(apiBaseOptions());
  AuthInterceptor(
    tokenStore: ref.watch(tokenStoreProvider),
    refreshClient: refreshClient,
    onSessionExpired: ref.watch(sessionEventsProvider).notifyExpired,
  ).attachTo(dio);
  ref.onDispose(() {
    dio.close();
    refreshClient.close();
  });
  return dio;
});
