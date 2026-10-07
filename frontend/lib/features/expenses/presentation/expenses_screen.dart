import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/errors/error_text.dart';
import '../../../core/ui/load_more_footer.dart';
import '../../../core/ui/record_tile.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/number_format.dart';
import '../../../design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../../fuel/presentation/widgets/monthly_spend_card.dart';
import '../../vehicles/domain/vehicle.dart';
import '../../vehicles/presentation/vehicles_controller.dart';
import '../../vehicles/presentation/widgets/selected_vehicle_view.dart';
import '../data/expense_repository.dart';
import '../domain/expense.dart';
import 'category_label.dart';
import 'expense_controllers.dart';

/// Expenses tab: what the selected vehicle cost over a period, by category,
/// month and (with two vehicles) vehicle, plus the expenses the user logged.
/// Fill-ups and services are included in the totals automatically.
class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final vehicle = ref.watch(selectedVehicleProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.expensesTitle)),
      body: SafeArea(
        child: SelectedVehicleView(
          builder: (context, vehicle, switcher) =>
              _ExpensesBody(vehicle: vehicle, switcher: switcher),
        ),
      ),
      floatingActionButton: vehicle == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () =>
                  context.push(AppRoutes.addExpensePath(vehicle.id)),
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.addExpenseAction),
            ),
    );
  }
}

class _ExpensesBody extends ConsumerWidget {
  const _ExpensesBody({required this.vehicle, required this.switcher});

  final Vehicle vehicle;
  final Widget? switcher;

  /// Space below the list so the last row clears the floating button.
  static const double _fabClearance = 96;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final period = ref.watch(spendingPeriodProvider);
    final summaryKey = (vehicleId: vehicle.id, period: period);
    final summary = ref.watch(spendingSummaryProvider(summaryKey));
    final monthly = ref.watch(monthlySpendingProvider(vehicle.id));
    final history = ref.watch(expenseHistoryProvider(vehicle.id));
    final vehicleCount =
        ref.watch(vehiclesControllerProvider).value?.length ?? 0;
    final vehicleTotals = vehicleCount > 1
        ? ref.watch(vehicleTotalsProvider(period)).value
        : null;

    void retry() {
      ref
        ..invalidate(spendingSummaryProvider(summaryKey))
        ..invalidate(monthlySpendingProvider(vehicle.id))
        ..invalidate(expenseHistoryProvider(vehicle.id))
        ..invalidate(vehicleTotalsProvider(period));
    }

    if (summary.hasError && !summary.hasValue) {
      return ErrorState(
        title: l10n.spendingLoadErrorTitle,
        message: errorText(l10n, summary.error!),
        retryLabel: l10n.retryAction,
        onRetry: retry,
      );
    }

    return RefreshIndicator.adaptive(
      onRefresh: () async {
        retry();
        await ref.read(spendingSummaryProvider(summaryKey).future);
      },
      child: ContentWidth(
        child: SheetScrollView(
          bottomPadding: _fabClearance,
          header: [
            if (switcher != null) ...[
              switcher!,
              const SizedBox(height: DrivonSpacing.md),
            ],
            _PeriodSelector(selected: period),
            const SizedBox(height: DrivonSpacing.lg),
            if (summary.value case final data?)
              _TotalCard(summary: data, period: period)
            else
              SizedBox(
                height: _TotalCard.placeholderHeight,
                child: LoadingState(semanticsLabel: l10n.loadingSpending),
              ),
          ],
          sheet: [
            if (summary.value case final data?) ...[
              _CategoryCard(summary: data),
              const SizedBox(height: DrivonSpacing.md),
            ],
            if (vehicleTotals != null && vehicleTotals.length > 1) ...[
              _VehicleCard(totals: vehicleTotals, selectedId: vehicle.id),
              const SizedBox(height: DrivonSpacing.md),
            ],
            if (monthly.value case final months?) ...[
              MonthlySpendCard(
                title: l10n.monthlySpendingTitle,
                months: months,
              ),
              const SizedBox(height: DrivonSpacing.md),
            ],
            const SizedBox(height: DrivonSpacing.md),
            SectionTitle(l10n.loggedExpensesTitle),
            const SizedBox(height: DrivonSpacing.xs),
            ...history.when(
              loading: () => [
                Padding(
                  padding: const EdgeInsets.all(DrivonSpacing.xl),
                  child: LoadingState(semanticsLabel: l10n.loadingSpending),
                ),
              ],
              error: (error, _) => [
                InlineNotice(message: l10n.expensesLoadErrorTitle),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    onPressed: () =>
                        ref.invalidate(expenseHistoryProvider(vehicle.id)),
                    child: Text(l10n.retryAction),
                  ),
                ),
              ],
              data: (list) => [
                if (list.items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: DrivonSpacing.md,
                    ),
                    child: Builder(
                      // Reads the sheet's paper theme, not the screen's.
                      builder: (context) => Text(
                        l10n.expensesEmptyMessage,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                for (final (index, expense) in list.items.indexed) ...[
                  if (index > 0) const Divider(),
                  _ExpenseTile(
                    expense: expense,
                    onTap: () => context.push(
                      AppRoutes.editExpensePath(vehicle.id, expense.id),
                    ),
                  ),
                ],
                LoadMoreFooter(
                  list: list,
                  failedMessage: l10n.expensesLoadMoreFailed,
                  onLoadMore: () => ref
                      .read(expenseHistoryProvider(vehicle.id).notifier)
                      .loadMore(),
                ),
              ],
            ),
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
          ref.read(spendingPeriodProvider.notifier).select(period),
    );
  }
}

/// The period's total, set large like the other headline figures.
class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.summary, required this.period});

  final SpendingSummary summary;
  final SpendingPeriod period;

  /// Height reserved while the total loads, so the screen doesn't jump.
  static const double placeholderHeight = 120;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final total = formatRupees(context, summary.total);
    return Semantics(
      label: l10n.spentInPeriodSemantics(
        _periodLabel(l10n, period).toLowerCase(),
        total,
      ),
      excludeSemantics: true,
      child: DrivonCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(total, style: textTheme.displayMedium),
            ),
            const SizedBox(height: DrivonSpacing.xs),
            Text(l10n.spendingSourcesCaption, style: textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// Spend per category as bars, largest first; empty categories are left out.
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.summary});

  final SpendingSummary summary;

  @override
  Widget build(BuildContext context) {
    // Read the theme below the card, which may re-theme its content.
    return DrivonCard(child: Builder(builder: _content));
  }

  Widget _content(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final series = context.drivonColors.chartSeries;
    final spent = [
      for (final category in summary.categories)
        if (!category.total.isZero) category,
    ];
    final largest = spent.isEmpty ? 0 : spent.first.total.units;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.byCategoryTitle, style: textTheme.titleMedium),
        ),
        const SizedBox(height: DrivonSpacing.lg),
        if (spent.isEmpty)
          Text(l10n.noSpendingInPeriod, style: textTheme.bodyMedium)
        else
          BarList(
            items: [
              for (final category in spent)
                BarListItem(
                  label: category.category.label(l10n),
                  value: formatRupees(context, category.total),
                  fraction: category.total.units / largest,
                  color: series[category.category.index % series.length],
                  emphasized: true,
                ),
            ],
          ),
      ],
    );
  }
}

/// Both vehicles' totals for the period, the selected one emphasized.
class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.totals, required this.selectedId});

  final List<VehicleTotal> totals;
  final String selectedId;

  @override
  Widget build(BuildContext context) {
    // Read the theme below the card, which may re-theme its content.
    return DrivonCard(child: Builder(builder: _content));
  }

  Widget _content(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final largest = totals.fold<int>(
      0,
      (max, vehicle) => vehicle.total.units > max ? vehicle.total.units : max,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.yourVehiclesTitle, style: textTheme.titleMedium),
        ),
        const SizedBox(height: DrivonSpacing.lg),
        BarList(
          items: [
            for (final vehicle in totals)
              BarListItem(
                label: '${vehicle.make} ${vehicle.model}',
                value: formatRupees(context, vehicle.total),
                fraction: largest == 0 ? 0 : vehicle.total.units / largest,
                emphasized: vehicle.vehicleId == selectedId,
              ),
          ],
        ),
      ],
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({required this.expense, required this.onTap});

  final Expense expense;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = expense.category.label(l10n);
    final amount = formatRupees(context, expense.amount);
    final date = formatDate(context, expense.date);
    return RecordTile(
      title: title,
      amount: amount,
      details: date,
      notes: expense.notes,
      semanticsLabel: '$title, $amount, $date',
      onTap: onTap,
    );
  }
}
