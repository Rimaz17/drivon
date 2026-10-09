import 'package:flutter/material.dart';

import '../../../../core/utils/date_format.dart';
import '../../../../core/utils/fixed_decimal.dart';
import '../../../../core/utils/number_format.dart';
import '../../../../design_system/design_system.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/analytics.dart';
import 'insight_card.dart';

/// Compact axis labels for rupee amounts: 950, 12k, 1.2M.
String compactRupees(double value) {
  if (value >= 1000000) {
    final millions = value / 1000000;
    return '${millions.toStringAsFixed(millions >= 10 ? 0 : 1)}M';
  }
  if (value >= 1000) {
    final thousands = value / 1000;
    return '${thousands.toStringAsFixed(thousands >= 10 ? 0 : 1)}k';
  }
  return value.toStringAsFixed(0);
}

/// Each month's cost as a stacked bar of fuel, maintenance and other.
class MonthlyCostsChart extends StatelessWidget {
  const MonthlyCostsChart({required this.months, super.key});

  /// Oldest first, as the server sends them.
  final List<MonthlyCost> months;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (months.every((month) => month.total.isZero)) {
      return InsightMessage(message: l10n.noCostsInWindow);
    }
    String rupees(FixedDecimal amount) => formatRupees(context, amount);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StackedBarChart(
          colors: context.drivonColors.costSeries,
          formatAxisValue: compactRupees,
          semanticsLabel: l10n.monthlyCostsSemantics(
            [
              for (final month in months)
                l10n.monthCostEntry(
                  formatMonthYear(context, month.month),
                  rupees(month.total),
                ),
            ].join(', '),
          ),
          columns: [
            for (final month in months)
              StackedBarColumn(
                label: formatShortMonth(context, month.month),
                values: [
                  month.fuel.toDouble(),
                  month.maintenance.toDouble(),
                  month.other.toDouble(),
                ],
                tooltip: l10n.monthlyCostTooltip(
                  formatMonthYear(context, month.month),
                  rupees(month.total),
                  rupees(month.fuel),
                  rupees(month.maintenance),
                  rupees(month.other),
                ),
              ),
          ],
        ),
        const SizedBox(height: DrivonSpacing.md),
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

/// Cost per km month by month; months without distance are left out
/// because a cost per zero km has no meaning.
class CostPerKmTrendChart extends StatelessWidget {
  const CostPerKmTrendChart({required this.months, super.key});

  final List<MonthlyCost> months;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final measured = [
      for (final month in months)
        if (month.costPerKm != null) month,
    ];
    if (measured.length < 2) {
      return InsightMessage(message: l10n.trendNeedsTwoMonths);
    }
    String perKm(MonthlyCost month) =>
        formatRupees(context, month.costPerKm!, showCents: true);
    return TrendLineChart(
      color: context.drivonColors.costSeries.first,
      formatAxisValue: (value) => value.toStringAsFixed(0),
      semanticsLabel: l10n.costPerKmTrendSemantics(
        [
          for (final month in measured)
            l10n.monthCostEntry(
              formatMonthYear(context, month.month),
              perKm(month),
            ),
        ].join(', '),
      ),
      points: [
        for (final month in measured)
          TrendPoint(
            value: month.costPerKm!.toDouble(),
            label: formatShortMonth(context, month.month),
            tooltip: l10n.costPerKmTooltip(
              formatMonthYear(context, month.month),
              perKm(month),
              formatInteger(context, month.distanceKm),
            ),
          ),
      ],
    );
  }
}

/// km/L of each full tank, with the vehicle's all-time average as a dashed
/// reference line when it is known.
class EfficiencyTrendChart extends StatelessWidget {
  const EfficiencyTrendChart({
    required this.points,
    required this.average,
    super.key,
  });

  /// Oldest first.
  final List<EfficiencyPoint> points;
  final FixedDecimal? average;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (points.length < 2) {
      return InsightMessage(message: l10n.efficiencyNeedsTanks);
    }
    String kmPerLitre(FixedDecimal value) =>
        formatDecimal(context, value, trimZeros: false);
    final reference = average;
    // Label a month only on its first tank, so the axis stays readable.
    final labels = <String>[];
    DateTime? lastMonth;
    for (final point in points) {
      final month = DateTime(point.endDate.year, point.endDate.month);
      labels.add(month == lastMonth ? '' : formatShortMonth(context, month));
      lastMonth = month;
    }
    return TrendLineChart(
      color: context.drivonColors.costSeries[1],
      formatAxisValue: (value) => value.toStringAsFixed(0),
      reference: reference?.toDouble(),
      referenceLabel: reference == null
          ? null
          : l10n.allTimeAverageLabel(kmPerLitre(reference)),
      semanticsLabel: l10n.efficiencyTrendSemantics(
        points.length,
        [
          for (final point in points)
            l10n.kmPerLitreValue(kmPerLitre(point.kmPerLitre)),
        ].join(', '),
      ),
      points: [
        for (final (index, point) in points.indexed)
          TrendPoint(
            value: point.kmPerLitre.toDouble(),
            label: labels[index],
            tooltip: l10n.efficiencyTooltip(
              formatDate(context, point.endDate),
              kmPerLitre(point.kmPerLitre),
              formatInteger(context, point.distanceKm),
              formatDecimal(context, point.litres),
            ),
          ),
      ],
    );
  }
}
