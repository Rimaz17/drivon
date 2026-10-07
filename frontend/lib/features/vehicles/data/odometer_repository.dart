import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/paged.dart';
import '../domain/odometer_reading.dart';
import 'odometer_api.dart';

/// A vehicle's odometer timeline. The server enforces its order and keeps
/// the vehicle's current odometer equal to the highest reading.
class OdometerRepository {
  OdometerRepository(this._api);

  final OdometerApi _api;

  Future<Paged<OdometerReading>> list(String vehicleId, {required int page}) =>
      _api.list(vehicleId, page: page);

  Future<OdometerReading> add(String vehicleId, int readingKm, DateTime date) =>
      _api.add(vehicleId, readingKm, date);

  Future<OdometerReading> correct(
    String vehicleId,
    String id,
    int readingKm,
    DateTime date,
  ) => _api.correct(vehicleId, id, readingKm, date);

  Future<void> delete(String vehicleId, String id) =>
      _api.delete(vehicleId, id);
}

final odometerRepositoryProvider = Provider<OdometerRepository>(
  (ref) => OdometerRepository(ref.watch(odometerApiProvider)),
);
