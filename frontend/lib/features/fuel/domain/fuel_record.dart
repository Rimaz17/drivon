import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/utils/fixed_decimal.dart';

part 'fuel_record.freezed.dart';

/// A fill-up as the server stores it.
@freezed
abstract class FuelRecord with _$FuelRecord {
  const factory FuelRecord({
    required String id,
    required String vehicleId,
    required DateTime date,
    required FixedDecimal litres,
    required FixedDecimal amount,
    required FixedDecimal pricePerLitre,
    required int odometerKm,
    required bool fullTank,
    String? station,

    /// Efficiency of the full-to-full stretch this fill closes, calculated
    /// by the server; null for partial fills and the first full fill.
    FixedDecimal? kmPerLitre,
  }) = _FuelRecord;

  const FuelRecord._();

  FuelDraft toDraft() => FuelDraft(
    date: date,
    litres: litres,
    amount: amount,
    pricePerLitre: pricePerLitre,
    odometerKm: odometerKm,
    fullTank: fullTank,
    station: station,
  );
}

/// The details of a fill-up the user enters, for logging or editing one.
@freezed
abstract class FuelDraft with _$FuelDraft {
  const factory FuelDraft({
    required DateTime date,
    required FixedDecimal litres,
    required FixedDecimal amount,
    required FixedDecimal pricePerLitre,
    required int odometerKm,
    required bool fullTank,
    String? station,
  }) = _FuelDraft;
}

/// All-time fuel figures for a vehicle, calculated by the server.
@freezed
abstract class FuelStats with _$FuelStats {
  const factory FuelStats({
    required FixedDecimal totalSpend,
    required FixedDecimal totalLitres,
    required int fillUps,
    required int trackedDistanceKm,
    FixedDecimal? averageKmPerLitre,
    FixedDecimal? bestKmPerLitre,
    FixedDecimal? latestKmPerLitre,
    FixedDecimal? costPerKm,
  }) = _FuelStats;

  const FuelStats._();

  /// km/L needs two full fills; until then the efficiency figures are null.
  bool get hasEfficiency => latestKmPerLitre != null;
}
