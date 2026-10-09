import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../expenses/data/expense_repository.dart';
import '../domain/analytics.dart';
import 'analytics_api.dart';

/// Running-cost figures for the Insights tab. The server calculates every
/// number; periods are turned into date ranges here.
class AnalyticsRepository {
  AnalyticsRepository(this._api);

  final AnalyticsApi _api;

  /// Months shown in the monthly cost charts.
  static const int monthlyWindow = 6;

  /// Months of tanks shown in the efficiency trend.
  static const int trendWindowMonths = 12;

  Future<CostPerKm> costPerKm(
    String vehicleId,
    SpendingPeriod period,
    DateTime today,
  ) => _api.costPerKm(vehicleId, from: period.start(today));

  Future<List<MonthlyCost>> monthlyCosts(String vehicleId) =>
      _api.monthlyCosts(vehicleId, months: monthlyWindow);

  /// Tanks of the last twelve months, counted from the first of the month
  /// so the window matches calendar months.
  Future<List<EfficiencyPoint>> efficiencyTrend(
    String vehicleId,
    DateTime today,
  ) => _api.efficiencyTrend(
    vehicleId,
    from: DateTime(today.year, today.month - (trendWindowMonths - 1)),
  );

  Future<List<VehicleCost>> compareVehicles(
    SpendingPeriod period,
    DateTime today,
  ) => _api.compareVehicles(from: period.start(today));
}

final analyticsRepositoryProvider = Provider<AnalyticsRepository>(
  (ref) => AnalyticsRepository(ref.watch(analyticsApiProvider)),
);
