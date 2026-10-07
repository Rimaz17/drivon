import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/monthly_amount.dart';
import '../../../core/models/paged.dart';
import '../../../core/utils/uuid.dart';
import '../domain/fuel_record.dart';
import 'fuel_api.dart';
import 'fuel_dto.dart';

/// A vehicle's fill-ups and fuel figures. The server calculates every
/// figure (km/L, cost per km, totals); the app only displays them.
class FuelRepository {
  FuelRepository(this._api, {this._newId = uuidV4});

  final FuelApi _api;
  final String Function() _newId;

  Future<Paged<FuelRecord>> list(String vehicleId, {required int page}) async =>
      (await _api.list(vehicleId, page: page)).map((dto) => dto.toDomain());

  Future<FuelRecord> get(String vehicleId, String id) async =>
      (await _api.get(vehicleId, id)).toDomain();

  Future<FuelRecord> create(String vehicleId, FuelDraft draft) async =>
      (await _api.create(vehicleId, draft, id: _newId())).toDomain();

  Future<FuelRecord> update(
    String vehicleId,
    String id,
    FuelDraft draft,
  ) async => (await _api.update(vehicleId, id, draft)).toDomain();

  Future<void> delete(String vehicleId, String id) =>
      _api.delete(vehicleId, id);

  /// All-time stats and the last [months] months of spend, fetched together.
  Future<FuelSummary> summary(String vehicleId, {int months = 6}) async {
    // Future.wait rethrows the first AppException as is, so screens can
    // explain it; the other request's failure is then ignored.
    final results = await Future.wait<Object>([
      _api.stats(vehicleId),
      _api.monthly(vehicleId, months: months),
    ]);
    return FuelSummary(
      stats: (results[0] as FuelStatsDto).toDomain(),
      monthlySpend: results[1] as List<MonthlyAmount>,
    );
  }
}

/// What the Fuel tab shows above the fill-up history.
class FuelSummary {
  const FuelSummary({required this.stats, required this.monthlySpend});

  final FuelStats stats;

  /// Oldest first; the last entry is the current month.
  final List<MonthlyAmount> monthlySpend;
}

final fuelRepositoryProvider = Provider<FuelRepository>(
  (ref) => FuelRepository(ref.watch(fuelApiProvider)),
);
