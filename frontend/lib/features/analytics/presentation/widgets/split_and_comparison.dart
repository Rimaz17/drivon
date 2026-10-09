import 'package:flutter/material.dart';

import '../../../../core/utils/number_format.dart';
import '../../../../design_system/design_system.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../expenses/domain/expense.dart';
import '../../../expenses/presentation/category_label.dart';
import '../../domain/analytics.dart';
import 'insight_card.dart';

/// Spend per category as bars, largest first, each with its share of the
/// total. Eight categories read better as labelled bars than as a pie.
class CategorySplit extends StatelessWidget {
  const CategorySplit({required this.summary, super.key});

  final SpendingSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spent = [
      for (final category in summary.categories)
        if (!category.total.isZero) category,
    ];
    if (spent.isEmpty) return InsightMessage(message: l10n.noSpendingInPeriod);
    final total = summary.total.units;
    final largest = spent.first.total.units;
    return BarList(
      items: [
        for (final category in spent)
          BarListItem(
            label: category.category.label(l10n),
            value: l10n.categoryShareValue(
              formatRupees(context, category.total),
              (category.total.units * 100 / total).round(),
            ),
            fraction: category.total.units / largest,
            color: _groupOf(category.category).color(context),
          ),
      ],
    );
  }

  /// Bars take their cost group's color, matching the running-cost split.
  static CostGroup _groupOf(ExpenseCategory category) => switch (category) {
    ExpenseCategory.fuel => CostGroup.fuel,
    ExpenseCategory.maintenance ||
    ExpenseCategory.repairs => CostGroup.maintenance,
    _ => CostGroup.other,
  };
}

/// Each vehicle's cost per km as a bar split into fuel, maintenance and
/// other, scaled to the dearest vehicle, with its distance and km/L.
class VehicleComparison extends StatelessWidget {
  const VehicleComparison({
    required this.vehicles,
    required this.selectedId,
    super.key,
  });

  final List<VehicleCost> vehicles;
  final String selectedId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colors = context.drivonColors;
    final highest = vehicles.fold<double>(0, (max, vehicle) {
      final value = vehicle.costPerKm?.toDouble() ?? 0;
      return value > max ? value : max;
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, vehicle) in vehicles.indexed) ...[
          if (index > 0) const SizedBox(height: DrivonSpacing.lg),
          _VehicleRow(
            vehicle: vehicle,
            fraction: highest == 0
                ? 0
                : (vehicle.costPerKm?.toDouble() ?? 0) / highest,
            emphasized: vehicle.vehicleId == selectedId,
            textTheme: textTheme,
            colors: colors,
            l10n: l10n,
          ),
        ],
        const SizedBox(height: DrivonSpacing.lg),
        ExcludeSemantics(
          child: ChartLegend(
            entries: [
              for (final group in CostGroup.values)
                LegendEntry(
                  color: group.color(context),
                  label: group.label(l10n),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VehicleRow extends StatelessWidget {
  const _VehicleRow({
    required this.vehicle,
    required this.fraction,
    required this.emphasized,
    required this.textTheme,
    required this.colors,
    required this.l10n,
  });

  final VehicleCost vehicle;
  final double fraction;
  final bool emphasized;
  final TextTheme textTheme;
  final DrivonColors colors;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final perKm = vehicle.costPerKm;
    final value = perKm == null
        ? l10n.notYetValue
        : l10n.perKmValue(formatRupees(context, perKm, showCents: true));
    final km = formatInteger(context, vehicle.distanceKm);
    final average = vehicle.averageKmPerLitre;
    final detail = average == null
        ? l10n.vehicleCostDetailNoFuel(km)
        : l10n.vehicleCostDetail(
            km,
            l10n.kmPerLitreValue(
              formatDecimal(context, average, trimZeros: false),
            ),
          );
    final name = '${vehicle.make} ${vehicle.model}';
    final nameStyle = emphasized
        ? textTheme.titleSmall
        : textTheme.titleSmall?.copyWith(color: colors.textSecondary);
    return Semantics(
      label: '$name, ${vehicle.registrationNumber}, $value, $detail',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: nameStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: DrivonSpacing.sm),
              Text(value, style: textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: DrivonSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FractionallySizedBox(
              // A sliver even at zero, so the row never looks broken.
              widthFactor: fraction.clamp(0.02, 1),
              child: SegmentedBar(
                semanticsLabel: value,
                height: 10,
                segments: [
                  for (final group in vehicle.breakdown)
                    BarSegment(
                      value: group.total.toDouble(),
                      color: group.group.color(context),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: DrivonSpacing.xs),
          Text(
            '${vehicle.registrationNumber} · $detail',
            style: textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
