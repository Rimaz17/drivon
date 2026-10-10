import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the app can reach the API right now, as last seen by a request.
@immutable
sealed class ConnectionStatus {
  const ConnectionStatus();
}

final class Online extends ConnectionStatus {
  const Online();
}

/// Requests fail; screens show the copies saved while the app was online.
final class Offline extends ConnectionStatus {
  const Offline();
}

class ConnectionStatusController extends Notifier<ConnectionStatus> {
  @override
  ConnectionStatus build() => const Online();

  void reachedServer() {
    if (state is! Online) state = const Online();
  }

  void lostServer() {
    if (state is! Offline) state = const Offline();
  }
}

final connectionStatusProvider =
    NotifierProvider<ConnectionStatusController, ConnectionStatus>(
      ConnectionStatusController.new,
    );

/// Tells when the phone gets a network again, so waiting drafts can be
/// sent. Wraps connectivity_plus, which works on Android and iOS.
abstract interface class NetworkMonitor {
  /// Emits true when the phone has a network (Wi-Fi, mobile data, ...)
  /// and false when it has none.
  Stream<bool> get changes;
}

class ConnectivityNetworkMonitor implements NetworkMonitor {
  ConnectivityNetworkMonitor([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Stream<bool> get changes => _connectivity.onConnectivityChanged.map(
    (results) => results.any((result) => result != ConnectivityResult.none),
  );
}

final networkMonitorProvider = Provider<NetworkMonitor>(
  (ref) => ConnectivityNetworkMonitor(),
);
