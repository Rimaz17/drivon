import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../core/utils/number_format.dart';
import '../../../../design_system/design_system.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../expenses/data/expense_repository.dart';
import '../../../expenses/presentation/expense_controllers.dart';
import '../../../fuel/presentation/fuel_controllers.dart';
import '../../../maintenance/presentation/maintenance_controllers.dart';
import '../../../maintenance/presentation/widgets/upcoming_service_text.dart';
import '../../domain/vehicle.dart';

/// The selected vehicle's key figures for the Garage sheet: efficiency and
/// fuel cost per km, the next service and this month's spending. Each opens
/// the tab with the details. Figures come from the server; while they load
/// or if they fail, tiles show a dash so the layout doesn't jump.
class VehicleSnapshot extends ConsumerWidget {
  const VehicleSnapshot({required this.vehicle, super.key});

  final Vehicle vehicle;

  /// Spending key for this month, shared with [refresh].
  static ({String vehicleId, SpendingPeriod period}) _spendingKey(
    String vehicleId,
  ) => (vehicleId: vehicleId, period: SpendingPeriod.thisMonth);

  /// Reloads every figure shown for [vehicleId].
  static void refresh(WidgetRef ref, String vehicleId) {
    ref
      ..invalidate(fuelSummaryProvider(vehicleId))
      ..invalidate(upcomingServicesProvider(vehicleId))
      ..invalidate(spendingSummaryProvider(_spendingKey(vehicleId)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final fuel = ref.watch(fuelSummaryProvider(vehicle.id));
    final upcoming = ref.watch(upcomingServicesProvider(vehicle.id));
    final spending = ref.watch(
      spendingSummaryProvider(_spendingKey(vehicle.id)),
    );

    final stats = fuel.value?.stats;
    final average = stats?.averageKmPerLitre;
    final costPerKm = stats?.costPerKm;
    // A caption explains a dash: still loading says nothing, a failure or
    // too few fill-ups says why.
    final fuelCaption = fuel.hasError
        ? l10n.snapshotLoadFailed
        : (stats != null && average == null)
        ? l10n.costPerKmPendingCaption
        : null;
    final monthTotal = spending.value?.total;

    void openFuel() => context.go(AppRoutes.fuel);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: StatTile(
                  label: l10n.averageLabel,
                  value: average == null
                      ? l10n.notYetValue
                      : formatDecimal(context, average, trimZeros: false),
                  unit: average == null ? null : l10n.kmPerLitreUnit,
                  caption: fuelCaption,
                  tagTone: TagTone.violet,
                  onTap: openFuel,
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
                  caption: fuelCaption,
                  tagTone: TagTone.mint,
                  onTap: openFuel,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: DrivonSpacing.md),
        _NextServiceCard(
          headline: switch (upcoming) {
            AsyncData(:final value) when value.isNotEmpty => upcomingHeadline(
              context,
              l10n,
              value.first,
            ),
            AsyncData() => l10n.noServiceYetMessage,
            AsyncError() => l10n.snapshotLoadFailed,
            _ => l10n.notYetValue,
          },
          detail: switch (upcoming) {
            AsyncData(:final value) when value.isNotEmpty => upcomingDetail(
              context,
              l10n,
              value.first,
            ),
            _ => null,
          },
          overdue: upcoming.value?.firstOrNull?.overdue ?? false,
          onTap: upcoming.value?.isEmpty ?? false
              ? () => context.push(AppRoutes.addServicePath(vehicle.id))
              : () => context.go(AppRoutes.service),
        ),
        const SizedBox(height: DrivonSpacing.md),
        StatTile(
          label: l10n.spentThisMonthLabel,
          value: monthTotal == null
              ? l10n.notYetValue
              : formatRupees(context, monthTotal),
          caption: spending.hasError
              ? l10n.snapshotLoadFailed
              : l10n.spendingSourcesCaption,
          tagTone: TagTone.sky,
          onTap: () => context.go(AppRoutes.expenses),
        ),
      ],
    );
  }
}

/// What is due next, as a wide dark tile; tapping opens the Service tab, or
/// the service form when nothing has been logged yet.
class _NextServiceCard extends StatelessWidget {
  const _NextServiceCard({
    required this.headline,
    required this.detail,
    required this.overdue,
    required this.onTap,
  });

  final String headline;
  final String? detail;
  final bool overdue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final detailText = detail;
    return Semantics(
      container: true,
      button: true,
      label: [l10n.nextServiceLabel, headline, ?detailText].join(', '),
      excludeSemantics: true,
      child: DrivonCard(
        onTap: onTap,
        child: Builder(
          builder: (context) {
            final textTheme = Theme.of(context).textTheme;
            final colors = context.drivonColors;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    TagChip(label: l10n.nextServiceLabel),
                    const Spacer(),
                    Icon(
                      overdue
                          ? Icons.warning_amber_rounded
                          : Icons.chevron_right_rounded,
                      color: overdue ? colors.warning : colors.textTertiary,
                    ),
                  ],
                ),
                const SizedBox(height: DrivonSpacing.lg),
                // A due date reads as a headline; a prompt or status line
                // (nothing logged yet, loading, failed) stays smaller.
                Text(
                  headline,
                  style: detailText != null
                      ? textTheme.headlineSmall
                      : textTheme.titleMedium,
                ),
                if (detailText != null) ...[
                  const SizedBox(height: DrivonSpacing.xs),
                  Text(detailText, style: textTheme.bodyMedium),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
