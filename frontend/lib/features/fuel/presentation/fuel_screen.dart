import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/errors/error_text.dart';
import '../../../core/utils/number_format.dart';
import '../../../design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../../vehicles/domain/vehicle.dart';
import '../../vehicles/presentation/vehicles_controller.dart';
import '../../vehicles/presentation/widgets/selected_vehicle_view.dart';
import '../data/fuel_repository.dart';
import 'fuel_controllers.dart';
import 'widgets/fuel_efficiency_card.dart';
import 'widgets/fuel_record_tile.dart';
import 'widgets/monthly_spend_card.dart';

/// Fuel tab: efficiency, spend and the fill-up history of the selected
/// vehicle.
class FuelScreen extends ConsumerWidget {
  const FuelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final vehicle = ref.watch(selectedVehicleProvider);
    final hasRecords =
        vehicle != null &&
        (ref.watch(fuelHistoryProvider(vehicle.id)).value?.records.isNotEmpty ??
            false);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.fuelTitle)),
      body: SafeArea(
        child: SelectedVehicleView(
          builder: (context, vehicle, switcher) =>
              _FuelBody(vehicle: vehicle, switcher: switcher),
        ),
      ),
      floatingActionButton: hasRecords
          ? FloatingActionButton.extended(
              onPressed: () =>
                  context.push(AppRoutes.addFuelRecordPath(vehicle.id)),
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.logFillUpTitle),
            )
          : null,
    );
  }
}

class _FuelBody extends ConsumerWidget {
  const _FuelBody({required this.vehicle, required this.switcher});

  final Vehicle vehicle;
  final Widget? switcher;

  /// Space below the list so the last row clears the floating button.
  static const double _fabClearance = 96;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final history = ref.watch(fuelHistoryProvider(vehicle.id));
    final switcherHeader = switcher == null
        ? null
        : Padding(
            padding: const EdgeInsets.fromLTRB(
              DrivonSpacing.screenGutter,
              DrivonSpacing.sm,
              DrivonSpacing.screenGutter,
              0,
            ),
            child: switcher,
          );

    void retry() {
      ref
        ..invalidate(fuelHistoryProvider(vehicle.id))
        ..invalidate(fuelSummaryProvider(vehicle.id));
    }

    final content = history.when(
      loading: () => LoadingState(semanticsLabel: l10n.loadingFuel),
      error: (error, _) => ErrorState(
        title: l10n.fuelLoadErrorTitle,
        message: errorText(l10n, error),
        retryLabel: l10n.retryAction,
        onRetry: retry,
      ),
      data: (data) => data.records.isEmpty
          ? EmptyState(
              icon: Icons.local_gas_station_outlined,
              title: l10n.fuelEmptyTitle,
              message: l10n.fuelEmptyMessage,
              actionLabel: l10n.logFillUpTitle,
              onAction: () =>
                  context.push(AppRoutes.addFuelRecordPath(vehicle.id)),
            )
          : null,
    );
    if (content != null) {
      return Column(
        children: [
          ?switcherHeader,
          Expanded(child: content),
        ],
      );
    }

    final data = history.value!;
    final summary = ref.watch(fuelSummaryProvider(vehicle.id));
    final textTheme = Theme.of(context).textTheme;

    return RefreshIndicator.adaptive(
      onRefresh: () async {
        retry();
        await ref.read(fuelHistoryProvider(vehicle.id).future);
      },
      child: ContentWidth(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            DrivonSpacing.screenGutter,
            DrivonSpacing.sm,
            DrivonSpacing.screenGutter,
            _fabClearance,
          ),
          children: [
            if (switcher != null) ...[
              switcher!,
              const SizedBox(height: DrivonSpacing.lg),
            ],
            ...summary.when(
              loading: () => [
                const SizedBox(
                  height: FuelEfficiencyCard.gaugeSize,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
              error: (error, _) => [
                InlineNotice(message: errorText(l10n, error)),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () =>
                        ref.invalidate(fuelSummaryProvider(vehicle.id)),
                    child: Text(l10n.retryAction),
                  ),
                ),
              ],
              data: (summary) => _summary(context, summary),
            ),
            const SizedBox(height: DrivonSpacing.xxl),
            Semantics(
              header: true,
              child: Text(l10n.fillUpsTitle, style: textTheme.titleLarge),
            ),
            const SizedBox(height: DrivonSpacing.xs),
            for (final (index, record) in data.records.indexed) ...[
              if (index > 0) const Divider(),
              FuelRecordTile(
                record: record,
                onTap: () => context.push(
                  AppRoutes.editFuelRecordPath(vehicle.id, record.id),
                ),
              ),
            ],
            if (data.hasMore) ...[
              const SizedBox(height: DrivonSpacing.md),
              if (data.loadingMore)
                Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: l10n.loadingMore,
                  ),
                )
              else ...[
                if (data.loadMoreFailed) ...[
                  InlineNotice(message: l10n.loadMoreFailed),
                  const SizedBox(height: DrivonSpacing.sm),
                ],
                OutlinedButton(
                  onPressed: () => ref
                      .read(fuelHistoryProvider(vehicle.id).notifier)
                      .loadMore(),
                  child: Text(
                    data.loadMoreFailed
                        ? l10n.retryAction
                        : l10n.showMoreAction,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _summary(BuildContext context, FuelSummary summary) {
    final l10n = AppLocalizations.of(context);
    final stats = summary.stats;
    final thisMonth = summary.monthlySpend.isEmpty
        ? null
        : summary.monthlySpend.last.total;
    final costPerKm = stats.costPerKm;
    return [
      FuelEfficiencyCard(stats: stats),
      const SizedBox(height: DrivonSpacing.md),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: StatTile(
              label: l10n.thisMonthLabel,
              value: thisMonth == null
                  ? l10n.notYetValue
                  : formatRupees(context, thisMonth),
              tagTone: TagTone.violet,
            ),
          ),
          const SizedBox(width: DrivonSpacing.md),
          Expanded(
            child: StatTile(
              label: l10n.fuelCostLabel,
              value: costPerKm == null
                  ? l10n.notYetValue
                  : formatRupees(context, costPerKm, showCents: true),
              unit: costPerKm == null ? null : l10n.perKmUnit,
              caption: costPerKm == null ? l10n.costPerKmPendingCaption : null,
              tagTone: TagTone.mint,
            ),
          ),
        ],
      ),
      const SizedBox(height: DrivonSpacing.md),
      MonthlySpendCard(
        title: l10n.monthlyFuelSpendTitle,
        months: summary.monthlySpend,
        footnote: l10n.allTimeFuelSummary(
          formatRupees(context, stats.totalSpend),
          stats.fillUps,
          formatDecimal(context, stats.totalLitres),
        ),
      ),
    ];
  }
}
