import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/session_controller.dart';
import '../../vehicles/presentation/vehicles_controller.dart';
import '../data/fuel_repository.dart';
import '../domain/fuel_record.dart';

/// The fill-ups loaded so far for one vehicle, newest first.
@immutable
class FuelHistory {
  const FuelHistory({
    required this.records,
    required this.hasMore,
    this.loadingMore = false,
    this.loadMoreFailed = false,
  });

  final List<FuelRecord> records;
  final bool hasMore;
  final bool loadingMore;

  /// The last attempt to load the next page failed; offer a retry.
  final bool loadMoreFailed;

  FuelHistory copyWith({
    List<FuelRecord>? records,
    bool? hasMore,
    bool? loadingMore,
    bool? loadMoreFailed,
  }) => FuelHistory(
    records: records ?? this.records,
    hasMore: hasMore ?? this.hasMore,
    loadingMore: loadingMore ?? this.loadingMore,
    loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
  );
}

/// A vehicle's fill-ups, a page at a time.
class FuelHistoryController extends AsyncNotifier<FuelHistory> {
  FuelHistoryController(this.vehicleId);

  final String vehicleId;
  int _nextPage = 0;

  FuelRepository get _repository => ref.read(fuelRepositoryProvider);

  @override
  Future<FuelHistory> build() async {
    ref.watch(currentUserProvider);
    final page = await _repository.list(vehicleId, page: 0);
    _nextPage = 1;
    return FuelHistory(records: page.items, hasMore: page.hasMore);
  }

  /// Appends the next page; a failure keeps what is shown and flags it.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(
      current.copyWith(loadingMore: true, loadMoreFailed: false),
    );
    try {
      final page = await _repository.list(vehicleId, page: _nextPage);
      _nextPage++;
      if (!ref.mounted) return;
      state = AsyncData(
        FuelHistory(
          records: [...current.records, ...page.items],
          hasMore: page.hasMore,
        ),
      );
    } on Object {
      if (ref.mounted) {
        state = AsyncData(current.copyWith(loadMoreFailed: true));
      }
    }
  }
}

final fuelHistoryProvider = AsyncNotifierProvider.autoDispose
    .family<FuelHistoryController, FuelHistory, String>(
      FuelHistoryController.new,
      // Failures are shown with a retry button instead of retried silently.
      retry: (_, _) => null,
    );

/// All-time fuel figures and recent monthly spend for a vehicle.
final fuelSummaryProvider = FutureProvider.autoDispose
    .family<FuelSummary, String>((ref, vehicleId) {
      ref.watch(currentUserProvider);
      return ref.read(fuelRepositoryProvider).summary(vehicleId);
    }, retry: (_, _) => null);

/// A fill-up to edit: taken from the loaded history when possible, so the
/// form opens instantly, otherwise fetched.
final fuelRecordProvider = FutureProvider.autoDispose
    .family<FuelRecord, ({String vehicleId, String recordId})>((ref, key) {
      final loaded = ref.read(fuelHistoryProvider(key.vehicleId)).value;
      for (final record in loaded?.records ?? const <FuelRecord>[]) {
        if (record.id == key.recordId) return record;
      }
      return ref.read(fuelRepositoryProvider).get(key.vehicleId, key.recordId);
    }, retry: (_, _) => null);

/// Logs, edits and deletes fill-ups, then refreshes everything they affect:
/// the history (km/L of neighbouring fill-ups can change), the figures and
/// the vehicle's odometer. Throws AppExceptions for forms to explain.
class FuelMutations {
  FuelMutations(this._ref);

  final Ref _ref;

  FuelRepository get _repository => _ref.read(fuelRepositoryProvider);

  Future<FuelRecord> add(String vehicleId, FuelDraft draft) async {
    final record = await _repository.create(vehicleId, draft);
    _refresh(vehicleId);
    return record;
  }

  Future<FuelRecord> edit(String vehicleId, String id, FuelDraft draft) async {
    final record = await _repository.update(vehicleId, id, draft);
    _refresh(vehicleId);
    return record;
  }

  Future<void> remove(String vehicleId, String id) async {
    await _repository.delete(vehicleId, id);
    _refresh(vehicleId);
  }

  void _refresh(String vehicleId) {
    _ref
      ..invalidate(fuelHistoryProvider(vehicleId))
      ..invalidate(fuelSummaryProvider(vehicleId));
    unawaited(_ref.read(vehiclesControllerProvider.notifier).reload());
  }
}

final fuelMutationsProvider = Provider<FuelMutations>(FuelMutations.new);
