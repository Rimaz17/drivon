import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/models/paged.dart';
import '../../../core/ui/paged_list_controller.dart';
import '../../auth/presentation/session_controller.dart';
import '../../expenses/presentation/expense_controllers.dart';
import '../../reminders/presentation/reminder_controllers.dart';
import '../../vehicles/presentation/odometer_controllers.dart';
import '../../vehicles/presentation/vehicles_controller.dart';
import '../data/fuel_repository.dart';
import '../domain/fuel_record.dart';
import 'fuel_sync_controller.dart';

/// A vehicle's fill-ups, newest first, a page at a time.
class FuelHistoryController extends PagedListController<FuelRecord> {
  FuelHistoryController(this.vehicleId);

  final String vehicleId;

  @override
  Future<Paged<FuelRecord>> fetchPage(int page) =>
      ref.read(fuelRepositoryProvider).list(vehicleId, page: page);
}

final fuelHistoryProvider = AsyncNotifierProvider.autoDispose
    .family<FuelHistoryController, PagedList<FuelRecord>, String>(
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
      for (final record in loaded?.items ?? const <FuelRecord>[]) {
        if (record.id == key.recordId) return record;
      }
      return ref.read(fuelRepositoryProvider).get(key.vehicleId, key.recordId);
    }, retry: (_, _) => null);

/// Reloads everything a fill-up affects: the history (km/L of neighbouring
/// fill-ups can change), the figures, the vehicle's odometer and its
/// history, spending totals and mileage reminders.
void refreshAfterFuelChange(Ref ref, String vehicleId) {
  ref
    ..invalidate(fuelHistoryProvider(vehicleId))
    ..invalidate(fuelSummaryProvider(vehicleId))
    ..invalidate(odometerHistoryProvider(vehicleId));
  refreshSpending(ref);
  refreshReminders(ref.invalidate);
  unawaited(ref.read(vehiclesControllerProvider.notifier).reload());
}

/// Logs, edits and deletes fill-ups, then refreshes everything they affect.
/// Throws AppExceptions for forms to explain.
class FuelMutations {
  FuelMutations(this._ref);

  final Ref _ref;

  FuelRepository get _repository => _ref.read(fuelRepositoryProvider);

  /// Saves a fill-up. Without a connection it is kept on the phone and sent
  /// later (see [FuelSyncController]); then this returns null.
  Future<FuelRecord?> add(String vehicleId, FuelDraft draft) async {
    final id = _repository.newFillUpId();
    final FuelRecord record;
    try {
      record = await _repository.create(vehicleId, draft, id: id);
    } on NoConnectionException {
      await _keep(vehicleId, id, draft);
      return null;
    } on ServerTimeoutException {
      // It may have been saved; sending it again with the same ID is safe.
      await _keep(vehicleId, id, draft);
      return null;
    }
    _refresh(vehicleId);
    return record;
  }

  Future<void> _keep(String vehicleId, String id, FuelDraft draft) =>
      _ref.read(fuelSyncProvider.notifier).keep(vehicleId, id, draft);

  Future<FuelRecord> edit(String vehicleId, String id, FuelDraft draft) async {
    final record = await _repository.update(vehicleId, id, draft);
    _refresh(vehicleId);
    return record;
  }

  Future<void> remove(String vehicleId, String id) async {
    await _repository.delete(vehicleId, id);
    _refresh(vehicleId);
  }

  void _refresh(String vehicleId) => refreshAfterFuelChange(_ref, vehicleId);
}

final fuelMutationsProvider = Provider<FuelMutations>(FuelMutations.new);
