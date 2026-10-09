import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../tokens/drivon_colors.dart';
import '../../tokens/drivon_motion.dart';
import '../../tokens/drivon_radii.dart';
import '../../tokens/drivon_spacing.dart';

/// One column of a [StackedBarChart]: parts drawn bottom-up in series order.
@immutable
class StackedBarColumn {
  const StackedBarColumn({
    required this.label,
    required this.values,
    required this.tooltip,
  });

  /// Short axis label, e.g. "Oct".
  final String label;

  /// One non-negative value per series, in the chart's series order.
  final List<double> values;

  /// What a tap on the column shows, e.g. the month's total and parts.
  final String tooltip;
}

/// Columns split into stacked series with a 2 dp gap between parts, a
/// recessive grid and a tap tooltip. Pair it with a [ChartLegend]; screen
/// readers hear [semanticsLabel] instead of the drawing.
class StackedBarChart extends StatelessWidget {
  const StackedBarChart({
    required this.columns,
    required this.colors,
    required this.semanticsLabel,
    required this.formatAxisValue,
    this.height = 200,
    super.key,
  });

  final List<StackedBarColumn> columns;

  /// One color per series, in a fixed order.
  final List<Color> colors;
  final String semanticsLabel;

  /// Labels the value gridlines, e.g. "40k".
  final String Function(double value) formatAxisValue;
  final double height;

  static const double _barWidth = 18;
  static const double _gridSteps = 3;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final drivon = context.drivonColors;
    final surface = theme.colorScheme.surfaceContainerLow;
    final axisStyle = theme.textTheme.labelSmall?.copyWith(
      color: drivon.textSecondary,
    );
    final maxTotal = columns.fold<double>(0, (max, column) {
      final total = column.values.fold<double>(0, (sum, v) => sum + v);
      return total > max ? total : max;
    });
    // Round the scale up so the top gridline sits above the tallest bar.
    final interval = maxTotal == 0 ? 1.0 : _niceStep(maxTotal / _gridSteps);
    final maxY = interval * _gridSteps;

    return Semantics(
      // Its own node, so the summary is announced on its own.
      container: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        child: BarChart(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : DrivonMotion.slow,
          curve: DrivonMotion.standard,
          BarChartData(
            maxY: maxY,
            alignment: BarChartAlignment.spaceAround,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: interval,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: drivon.gaugeTrack, strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  interval: interval,
                  getTitlesWidget: (value, meta) => SideTitleWidget(
                    meta: meta,
                    child: Text(formatAxisValue(value), style: axisStyle),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: DrivonSpacing.xxl,
                  getTitlesWidget: (value, meta) => SideTitleWidget(
                    meta: meta,
                    child: Text(columns[value.toInt()].label, style: axisStyle),
                  ),
                ),
              ),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) =>
                    theme.colorScheme.surfaceContainerHighest,
                tooltipBorderRadius: DrivonRadii.smAll,
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                    BarTooltipItem(
                      columns[groupIndex].tooltip,
                      theme.textTheme.labelMedium!.copyWith(
                        color: drivon.textPrimary,
                      ),
                      textAlign: TextAlign.start,
                    ),
              ),
            ),
            barGroups: [
              for (final (index, column) in columns.indexed)
                BarChartGroupData(x: index, barRods: [_rod(column, surface)]),
            ],
          ),
        ),
      ),
    );
  }

  BarChartRodData _rod(StackedBarColumn column, Color surface) {
    final items = <BarChartRodStackItem>[];
    var from = 0.0;
    for (final (series, value) in column.values.indexed) {
      if (value <= 0) continue;
      items.add(
        BarChartRodStackItem(
          from,
          from + value,
          colors[series],
          // A hairline of the card color on each side reads as a 2 dp gap.
          borderSide: BorderSide(color: surface),
        ),
      );
      from += value;
    }
    return BarChartRodData(
      toY: from,
      width: _barWidth,
      color: Colors.transparent,
      rodStackItems: items,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(DrivonRadii.xs),
      ),
    );
  }
}

/// 1, 2 or 5 times a power of ten at or above [rough], for round gridlines.
double _niceStep(double rough) {
  var magnitude = 1.0;
  while (magnitude * 10 <= rough) {
    magnitude *= 10;
  }
  while (magnitude > rough) {
    magnitude /= 10;
  }
  for (final factor in [1, 2, 5, 10]) {
    if (magnitude * factor >= rough) return magnitude * factor;
  }
  return magnitude * 10;
}

/// Exposed for tests of the axis scale.
@visibleForTesting
double niceStep(double rough) => _niceStep(rough);
