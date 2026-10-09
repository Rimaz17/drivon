import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_text.dart';
import '../../../design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../../expenses/data/expense_repository.dart';
import '../../expenses/presentation/expense_controllers.dart';
import '../../fuel/presentation/fuel_controllers.dart';
import '../../vehicles/domain/vehicle.dart';
import '../../vehicles/presentation/vehicles_controller.dart';
import '../../vehicles/presentation/widgets/selected_vehicle_view.dart';
import 'analytics_controllers.dart';
import 'widgets/cost_charts.dart';
import 'widgets/insight_card.dart';
import 'widgets/running_cost_card.dart';
import 'widgets/split_and_comparison.dart';

/// Insights tab: what the selected vehicle costs per km and why, how its
/// costs and efficiency move month to month, and how two vehicles compare.
/// Every figure comes from the server.
class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.insightsTitle)),
      body: SafeArea(
        child: SelectedVehicleView(
          builder: (context, vehicle, switcher) =>
              _InsightsBody(vehicle: vehicle, switcher: switcher),
        ),
      ),
    );
  }
}

class _InsightsBody extends ConsumerWidget {
  const _InsightsBody({required this.vehicle, required this.switcher});

  final Vehicle vehicle;
  final Widget? switcher;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final period = ref.watch(insightsPeriodProvider);
    final key = (vehicleId: vehicle.id, period: period);
    final cost = ref.watch(costPerKmProvider(key));
    final monthly = ref.watch(monthlyCostsProvider(vehicle.id));
    final trend = ref.watch(efficiencyTrendProvider(vehicle.id));
    final summary = ref.watch(spendingSummaryProvider(key));
    final fuel = ref.watch(fuelSummaryProvider(vehicle.id));
    final vehicleCount =
        ref.watch(vehiclesControllerProvider).value?.length ?? 0;
    final comparison = vehicleCount > 1
        ? ref.watch(vehicleComparisonProvider(period))
        : null;

    void retryAll() {
      refreshInsights(ref.invalidate);
      ref
        ..invalidate(spendingSummaryProvider(key))
        ..invalidate(fuelSummaryProvider(vehicle.id));
    }

    if (cost.hasError && !cost.hasValue) {
      return ErrorState(
        title: l10n.insightsLoadErrorTitle,
        message: errorText(l10n, cost.error!),
        retryLabel: l10n.retryAction,
        onRetry: retryAll,
      );
    }

    /// A chart's data, a loading space, or a failure with a retry.
    Widget section<T>(
      AsyncValue<T> value,
      Widget Function(T data) build, {
      required VoidCallback retry,
    }) => switch (value) {
      AsyncValue(:final value?) => build(value),
      AsyncError() => InsightMessage(
        message: l10n.sectionLoadFailed,
        retryLabel: l10n.retryAction,
        onRetry: retry,
      ),
      _ => const InsightLoading(),
    };

    const gap = SizedBox(height: DrivonSpacing.md);
    return RefreshIndicator.adaptive(
      onRefresh: () async {
        retryAll();
        await ref.read(costPerKmProvider(key).future);
      },
      child: ContentWidth(
        child: SheetScrollView(
          header: [
            if (switcher != null) ...[
              switcher!,
              const SizedBox(height: DrivonSpacing.md),
            ],
            _PeriodSelector(selected: period),
            const SizedBox(height: DrivonSpacing.lg),
            if (cost.value case final data?)
              RunningCostCard(cost: data)
            else
              SizedBox(
                height: RunningCostCard.placeholderHeight,
                child: LoadingState(semanticsLabel: l10n.loadingInsights),
              ),
          ],
          sheet: [
            InsightCard(
              title: l10n.monthlyCostsTitle,
              caption: l10n.lastSixMonthsCaption,
              child: section(
                monthly,
                (months) => MonthlyCostsChart(months: months),
                retry: () => ref.invalidate(monthlyCostsProvider(vehicle.id)),
              ),
            ),
            gap,
            InsightCard(
              title: l10n.costPerKmTrendTitle,
              caption: l10n.costPerKmTrendCaption,
              child: section(
                monthly,
                (months) => CostPerKmTrendChart(months: months),
                retry: () => ref.invalidate(monthlyCostsProvider(vehicle.id)),
              ),
            ),
            gap,
            InsightCard(
              title: l10n.efficiencyTrendTitle,
              caption: l10n.efficiencyTrendCaption,
              child: section(
                trend,
                (points) => EfficiencyTrendChart(
                  points: points,
                  average: fuel.value?.stats.averageKmPerLitre,
                ),
                retry: () =>
                    ref.invalidate(efficiencyTrendProvider(vehicle.id)),
              ),
            ),
            gap,
            InsightCard(
              title: l10n.categorySplitTitle,
              child: section(
                summary,
                (data) => CategorySplit(summary: data),
                retry: () => ref.invalidate(spendingSummaryProvider(key)),
              ),
            ),
            if (comparison != null) ...[
              gap,
              InsightCard(
                title: l10n.compareVehiclesTitle,
                caption: l10n.compareVehiclesCaption,
                child: section(
                  comparison,
                  (vehicles) => VehicleComparison(
                    vehicles: vehicles,
                    selectedId: vehicle.id,
                  ),
                  retry: () =>
                      ref.invalidate(vehicleComparisonProvider(period)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _periodLabel(AppLocalizations l10n, SpendingPeriod period) =>
    switch (period) {
      SpendingPeriod.thisMonth => l10n.periodThisMonth,
      SpendingPeriod.thisYear => l10n.periodThisYear,
      SpendingPeriod.allTime => l10n.periodAllTime,
    };

class _PeriodSelector extends ConsumerWidget {
  const _PeriodSelector({required this.selected});

  final SpendingPeriod selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return PillSegmentedControl<SpendingPeriod>(
      semanticsLabel: l10n.periodLabel,
      segments: [
        for (final period in SpendingPeriod.values)
          PillSegment(value: period, label: _periodLabel(l10n, period)),
      ],
      selected: selected,
      onSelected: (period) =>
          ref.read(insightsPeriodProvider.notifier).select(period),
    );
  }
}
