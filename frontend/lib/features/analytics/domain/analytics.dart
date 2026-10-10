import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/utils/fixed_decimal.dart';

part 'analytics.freezed.dart';

/// The parts of a running cost. Wire values match the backend's enum.
enum CostGroup {
  /// Fill-ups and fuel expenses.
  fuel('FUEL'),

  /// Services, maintenance and repairs.
  maintenance('MAINTENANCE'),

  /// Insurance, parking, tolls, washing and other expenses.
  other('OTHER');

  const CostGroup(this.wireValue);

  final String wireValue;

  static CostGroup fromWire(String value) => values.firstWhere(
    (group) => group.wireValue == value,
    orElse: () => throw FormatException('Unknown cost group: $value'),
  );
}

/// One part of a running cost.
@freezed
abstract class GroupCost with _$GroupCost {
  const factory GroupCost({
    required CostGroup group,
    required FixedDecimal total,

    /// Null when no distance was recorded.
    FixedDecimal? costPerKm,
  }) = _GroupCost;
}

/// What a vehicle cost per km driven in a period, calculated by the server:
/// everything spent over the distance its odometer advanced.
@freezed
abstract class CostPerKm with _$CostPerKm {
  const factory CostPerKm({
    required int distanceKm,
    required FixedDecimal totalCost,

    /// Fuel, maintenance and other, in that order.
    required List<GroupCost> breakdown,

    /// Null when no distance was recorded in the period.
    FixedDecimal? costPerKm,
  }) = _CostPerKm;
}

/// One month's running cost and distance.
@freezed
abstract class MonthlyCost with _$MonthlyCost {
  const factory MonthlyCost({
    /// The first day of the month.
    required DateTime month,
    required FixedDecimal fuel,
    required FixedDecimal maintenance,
    required FixedDecimal other,
    required FixedDecimal total,
    required int distanceKm,
    FixedDecimal? costPerKm,
  }) = _MonthlyCost;
}

/// One tank's efficiency (full-tank method), plotted at its closing fill.
@freezed
abstract class EfficiencyPoint with _$EfficiencyPoint {
  const factory EfficiencyPoint({
    required DateTime startDate,
    required DateTime endDate,
    required int distanceKm,
    required FixedDecimal litres,
    required FixedDecimal kmPerLitre,
    required FixedDecimal costPerKm,
  }) = _EfficiencyPoint;
}

/// One vehicle in a side-by-side comparison.
@freezed
abstract class VehicleCost with _$VehicleCost {
  const factory VehicleCost({
    required String vehicleId,
    required String make,
    required String model,
    required String registrationNumber,
    required int distanceKm,
    required FixedDecimal totalCost,
    required List<GroupCost> breakdown,
    FixedDecimal? costPerKm,

    /// Null until the vehicle has two full fills in the period.
    FixedDecimal? averageKmPerLitre,
  }) = _VehicleCost;
}
