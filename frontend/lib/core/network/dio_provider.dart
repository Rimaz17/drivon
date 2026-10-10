import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/local_store.dart';
import '../storage/token_store.dart';
import 'api_client.dart';
import 'auth_interceptor.dart';
import 'connection_status.dart';
import 'offline_cache_interceptor.dart';
import 'session_events.dart';

/// The app's HTTP client for the Drivon API, with automatic token handling
/// and offline copies of what it reads.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(apiBaseOptions());
  // Refresh calls bypass the interceptor so they never recurse.
  final refreshClient = Dio(apiBaseOptions());
  AuthInterceptor(
    tokenStore: ref.watch(tokenStoreProvider),
    refreshClient: refreshClient,
    onSessionExpired: ref.watch(sessionEventsProvider).notifyExpired,
  ).attachTo(dio);
  final status = ref.read(connectionStatusProvider.notifier);
  dio.interceptors.add(
    OfflineCacheInterceptor(
      store: ref.watch(localStoreProvider),
      userId: () => ref.read(activeUserIdProvider),
      onReachable: status.reachedServer,
      onUnreachable: status.lostServer,
    ),
  );
  ref.onDispose(() {
    dio.close();
    refreshClient.close();
  });
  return dio;
});
