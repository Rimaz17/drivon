import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/connection_status.dart';
import '../../auth/presentation/session_controller.dart';
import '../data/fuel_repository.dart';
import '../data/pending_fill_ups.dart';
import '../domain/fuel_record.dart';
import 'fuel_controllers.dart';

/// Fill-ups saved offline and whether they are being sent.
@immutable
class FuelSyncState {
  const FuelSyncState({this.pending = const [], this.syncing = false});

  /// Oldest first.
  final List<PendingFillUp> pending;
  final bool syncing;

  List<PendingFillUp> forVehicle(String vehicleId) => [
    for (final fillUp in pending)
      if (fillUp.vehicleId == vehicleId) fillUp,
  ];
}

/// Sends fill-ups saved offline once the server can be reached: when the
/// phone gets a network, when a request succeeds again, at sign-in, and on
/// request. The server has the last word: a fill-up it refuses stays on the
/// phone with the reason until the user retries or discards it.
class FuelSyncController extends Notifier<FuelSyncState> {
  @override
  FuelSyncState build() {
    final userId = ref.watch(currentUserProvider.select((user) => user?.id));
    if (userId == null) return const FuelSyncState();
    final network = ref
        .read(networkMonitorProvider)
        .changes
        .where((connected) => connected)
        .listen((_) => unawaited(syncNow()));
    ref
      ..onDispose(network.cancel)
      ..listen(connectionStatusProvider, (previous, next) {
        if (previous is Offline && next is Online) unawaited(syncNow());
      });
    unawaited(Future.microtask(() => _loadAndSync(userId)));
    return const FuelSyncState();
  }

  PendingFillUpStore get _store => ref.read(pendingFillUpStoreProvider);

  String? get _userId => ref.read(currentUserProvider)?.id;

  /// Keeps a fill-up that couldn't reach the server, to send later.
  Future<void> keep(String vehicleId, String id, FuelDraft draft) async {
    final userId = _userId;
    if (userId == null) return;
    final fillUp = PendingFillUp(
      id: id,
      vehicleId: vehicleId,
      draft: draft,
      savedAt: DateTime.now(),
    );
    await _store.save(userId, fillUp);
    if (ref.mounted) {
      state = FuelSyncState(
        pending: [...state.pending, fillUp],
        syncing: state.syncing,
      );
    }
  }

  /// Sends every waiting fill-up, oldest first, until one can't reach the
  /// server.
  Future<void> syncNow() async {
    final userId = _userId;
    if (userId == null || state.syncing) return;
    final waiting = [
      for (final fillUp in state.pending)
        if (!fillUp.rejected) fillUp,
    ];
    if (waiting.isEmpty) return;
    state = FuelSyncState(pending: state.pending, syncing: true);
    final repository = ref.read(fuelRepositoryProvider);
    try {
      for (final fillUp in waiting) {
        try {
          await repository.create(
            fillUp.vehicleId,
            fillUp.draft,
            id: fillUp.id,
          );
          await _store.remove(fillUp.id);
          if (!ref.mounted) return;
          refreshAfterFuelChange(ref, fillUp.vehicleId);
        } on ApiProblemException catch (error) {
          if (error.statusCode >= 500) break;
          await _store.save(
            userId,
            PendingFillUp(
              id: fillUp.id,
              vehicleId: fillUp.vehicleId,
              draft: fillUp.draft,
              savedAt: fillUp.savedAt,
              rejection: SyncRejection(code: error.code, detail: error.detail),
            ),
          );
        } on AppException {
          // Offline or the server is still waking up: try again later.
          break;
        }
      }
    } finally {
      if (ref.mounted) await _reload(userId);
    }
  }

  /// Sends a refused fill-up again, e.g. after fixing an odometer reading
  /// that was out of order.
  Future<void> retry(String id) async {
    final userId = _userId;
    if (userId == null) return;
    for (final fillUp in state.pending) {
      if (fillUp.id == id && fillUp.rejected) {
        await _store.save(
          userId,
          PendingFillUp(
            id: fillUp.id,
            vehicleId: fillUp.vehicleId,
            draft: fillUp.draft,
            savedAt: fillUp.savedAt,
          ),
        );
      }
    }
    if (!ref.mounted) return;
    await _reload(userId);
    await syncNow();
  }

  /// Deletes a fill-up that was never saved to the account.
  Future<void> discard(String id) async {
    final userId = _userId;
    await _store.remove(id);
    if (userId != null && ref.mounted) await _reload(userId);
  }

  Future<void> _loadAndSync(String userId) async {
    await _reload(userId);
    await syncNow();
  }

  Future<void> _reload(String userId) async {
    final pending = await _store.all(userId);
    if (ref.mounted && _userId == userId) {
      state = FuelSyncState(pending: pending);
    }
  }
}

final fuelSyncProvider = NotifierProvider<FuelSyncController, FuelSyncState>(
  FuelSyncController.new,
);
