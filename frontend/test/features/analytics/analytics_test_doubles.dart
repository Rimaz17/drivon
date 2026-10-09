import 'package:drivon/core/errors/app_exception.dart';
import 'package:drivon/core/utils/fixed_decimal.dart';
import 'package:drivon/features/analytics/data/analytics_api.dart';
import 'package:drivon/features/analytics/domain/analytics.dart';

FixedDecimal money(String text) => FixedDecimal.parse(text, scale: 2);

List<GroupCost> breakdown(String fuel, String maintenance, String other) => [
  GroupCost(group: CostGroup.fuel, total: money(fuel)),
  GroupCost(group: CostGroup.maintenance, total: money(maintenance)),
  GroupCost(group: CostGroup.other, total: money(other)),
];

/// Cost per km with each part per km over [distanceKm].
CostPerKm runningCost({
  required int distanceKm,
  String fuel = '0',
  String maintenance = '0',
  String other = '0',
}) {
  final parts = [money(fuel), money(maintenance), money(other)];
  final total = parts.fold<int>(0, (sum, part) => sum + part.units);
  FixedDecimal? perKm(int units) => distanceKm == 0
      ? null
      : FixedDecimal(FixedDecimal.divideHalfUp(units, distanceKm), 2);
  return CostPerKm(
    distanceKm: distanceKm,
    totalCost: FixedDecimal(total, 2),
    costPerKm: perKm(total),
    breakdown: [
      for (final (index, group) in CostGroup.values.indexed)
        GroupCost(
          group: group,
          total: parts[index],
          costPerKm: perKm(parts[index].units),
        ),
    ],
  );
}

MonthlyCost monthlyCost(
  int month, {
  String fuel = '0',
  String maintenance = '0',
  String other = '0',
  int distanceKm = 0,
  int year = 2026,
}) {
  final parts = [money(fuel), money(maintenance), money(other)];
  final total = parts.fold<int>(0, (sum, part) => sum + part.units);
  return MonthlyCost(
    month: DateTime(year, month),
    fuel: parts[0],
    maintenance: parts[1],
    other: parts[2],
    total: FixedDecimal(total, 2),
    distanceKm: distanceKm,
    costPerKm: distanceKm == 0
        ? null
        : FixedDecimal(FixedDecimal.divideHalfUp(total, distanceKm), 2),
  );
}

EfficiencyPoint tank(DateTime end, String kmPerLitre, {int distanceKm = 480}) =>
    EfficiencyPoint(
      startDate: end.subtract(const Duration(days: 14)),
      endDate: end,
      distanceKm: distanceKm,
      litres: FixedDecimal.parse('25', scale: 3),
      kmPerLitre: FixedDecimal.parse(kmPerLitre, scale: 2),
      costPerKm: money('18.25'),
    );

/// In-memory [AnalyticsApi] for tests; every response is scripted.
class FakeAnalyticsApi implements AnalyticsApi {
  CostPerKm costResponse = runningCost(distanceKm: 0);
  List<MonthlyCost> monthlyResponse = [
    for (var month = 5; month <= 10; month++) monthlyCost(month),
  ];
  List<EfficiencyPoint> trendResponse = [];
  List<VehicleCost> comparisonResponse = [];

  /// When set, the next call throws it once.
  AppException? nextError;
  final List<DateTime?> costStarts = [];
  final List<DateTime?> trendStarts = [];

  @override
  Future<CostPerKm> costPerKm(String vehicleId, {DateTime? from}) async {
    _throwIfScripted();
    costStarts.add(from);
    return costResponse;
  }

  @override
  Future<List<MonthlyCost>> monthlyCosts(
    String vehicleId, {
    required int months,
  }) async {
    _throwIfScripted();
    return monthlyResponse;
  }

  @override
  Future<List<EfficiencyPoint>> efficiencyTrend(
    String vehicleId, {
    DateTime? from,
  }) async {
    _throwIfScripted();
    trendStarts.add(from);
    return trendResponse;
  }

  @override
  Future<List<VehicleCost>> compareVehicles({DateTime? from}) async {
    _throwIfScripted();
    return comparisonResponse;
  }

  void _throwIfScripted() {
    final error = nextError;
    if (error != null) {
      nextError = null;
      throw error;
    }
  }
}
