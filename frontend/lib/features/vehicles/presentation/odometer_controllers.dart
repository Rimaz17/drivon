import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/paged.dart';
import '../../../core/ui/paged_list_controller.dart';
import '../data/odometer_repository.dart';
import '../domain/odometer_reading.dart';
import 'vehicles_controller.dart';

/// A vehicle's odometer readings, newest first, a page at a time.
class OdometerHistoryController extends PagedListController<OdometerReading> {
  OdometerHistoryController(this.vehicleId);

  final String vehicleId;

  @override
  Future<Paged<OdometerReading>> fetchPage(int page) =>
      ref.read(odometerRepositoryProvider).list(vehicleId, page: page);
}

final odometerHistoryProvider = AsyncNotifierProvider.autoDispose
    .family<OdometerHistoryController, PagedList<OdometerReading>, String>(
      OdometerHistoryController.new,
      // Failures are shown with a retry button instead of retried silently.
      retry: (_, _) => null,
    );

/// A reading to correct, from the loaded history; null if it isn't there
/// (for example after it was deleted elsewhere).
final odometerReadingProvider = Provider.autoDispose
    .family<OdometerReading?, ({String vehicleId, String readingId})>((
      ref,
      key,
    ) {
      final loaded = ref.watch(odometerHistoryProvider(key.vehicleId)).value;
      for (final reading in loaded?.items ?? const <OdometerReading>[]) {
        if (reading.id == key.readingId) return reading;
      }
      return null;
    });

/// Adds, corrects and deletes readings, then refreshes the history and the
/// vehicle, whose odometer is the highest reading. Throws AppExceptions.
class OdometerMutations {
  OdometerMutations(this._ref);

  final Ref _ref;

  OdometerRepository get _repository => _ref.read(odometerRepositoryProvider);

  Future<void> add(String vehicleId, int readingKm, DateTime date) async {
    await _repository.add(vehicleId, readingKm, date);
    _refresh(vehicleId);
  }

  Future<void> correct(
    String vehicleId,
    String id,
    int readingKm,
    DateTime date,
  ) async {
    await _repository.correct(vehicleId, id, readingKm, date);
    _refresh(vehicleId);
  }

  Future<void> remove(String vehicleId, String id) async {
    await _repository.delete(vehicleId, id);
    _refresh(vehicleId);
  }

  void _refresh(String vehicleId) {
    _ref.invalidate(odometerHistoryProvider(vehicleId));
    unawaited(_ref.read(vehiclesControllerProvider.notifier).reload());
  }
}

final odometerMutationsProvider = Provider<OdometerMutations>(
  OdometerMutations.new,
);
