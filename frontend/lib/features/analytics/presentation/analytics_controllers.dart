import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;

import '../../../core/utils/date_format.dart';
import '../../auth/presentation/session_controller.dart';
import '../../expenses/data/expense_repository.dart';
import '../data/analytics_repository.dart';
import '../domain/analytics.dart';

/// The period the Insights tab totals over; this year by default, since a
/// single month is often too short for a steady cost per km.
class InsightsPeriodController extends Notifier<SpendingPeriod> {
  @override
  SpendingPeriod build() => SpendingPeriod.thisYear;

  void select(SpendingPeriod period) => state = period;
}

final insightsPeriodProvider =
    NotifierProvider<InsightsPeriodController, SpendingPeriod>(
      InsightsPeriodController.new,
    );

typedef PeriodKey = ({String vehicleId, SpendingPeriod period});

final costPerKmProvider = FutureProvider.autoDispose
    .family<CostPerKm, PeriodKey>((ref, key) {
      ref.watch(currentUserProvider);
      return ref
          .read(analyticsRepositoryProvider)
          .costPerKm(key.vehicleId, key.period, today());
    }, retry: (_, _) => null);

final monthlyCostsProvider = FutureProvider.autoDispose
    .family<List<MonthlyCost>, String>((ref, vehicleId) {
      ref.watch(currentUserProvider);
      return ref.read(analyticsRepositoryProvider).monthlyCosts(vehicleId);
    }, retry: (_, _) => null);

final efficiencyTrendProvider = FutureProvider.autoDispose
    .family<List<EfficiencyPoint>, String>((ref, vehicleId) {
      ref.watch(currentUserProvider);
      return ref
          .read(analyticsRepositoryProvider)
          .efficiencyTrend(vehicleId, today());
    }, retry: (_, _) => null);

final vehicleComparisonProvider = FutureProvider.autoDispose
    .family<List<VehicleCost>, SpendingPeriod>((ref, period) {
      ref.watch(currentUserProvider);
      return ref
          .read(analyticsRepositoryProvider)
          .compareVehicles(period, today());
    }, retry: (_, _) => null);

/// Reloads every Insights figure. Fill-ups, services, expenses and odometer
/// readings all feed them, so each of those features calls this after a
/// change. Accepts a `Ref` or a `WidgetRef`.
void refreshInsights(void Function(ProviderOrFamily provider) invalidate) {
  invalidate(costPerKmProvider);
  invalidate(monthlyCostsProvider);
  invalidate(efficiencyTrendProvider);
  invalidate(vehicleComparisonProvider);
}
