import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../tokens/drivon_colors.dart';
import '../../tokens/drivon_motion.dart';
import '../../tokens/drivon_radii.dart';
import '../../tokens/drivon_spacing.dart';

/// One point of a [TrendLineChart].
@immutable
class TrendPoint {
  const TrendPoint({
    required this.value,
    required this.label,
    required this.tooltip,
  });

  final double value;

  /// Axis label under the point, e.g. "Oct"; empty to leave it unlabelled.
  final String label;

  /// What a tap on the point shows.
  final String tooltip;
}

/// A single series over time: a 2 dp line with 8 dp markers ringed in the
/// card color, an optional dashed reference line (an average), a recessive
/// grid and a tap tooltip. One series, so the card title names it and no
/// legend is needed. Screen readers hear [semanticsLabel].
class TrendLineChart extends StatelessWidget {
  const TrendLineChart({
    required this.points,
    required this.color,
    required this.semanticsLabel,
    required this.formatAxisValue,
    this.reference,
    this.referenceLabel,
    this.height = 180,
    super.key,
  });

  final List<TrendPoint> points;
  final Color color;
  final String semanticsLabel;
  final String Function(double value) formatAxisValue;

  /// Value of the dashed reference line, e.g. the average.
  final double? reference;
  final String? referenceLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final drivon = context.drivonColors;
    final surface = theme.colorScheme.surfaceContainerLow;
    final axisStyle = theme.textTheme.labelSmall?.copyWith(
      color: drivon.textSecondary,
    );
    final values = [for (final point in points) point.value, ?reference];
    final low = values.reduce((a, b) => a < b ? a : b);
    final high = values.reduce((a, b) => a > b ? a : b);
    // Pad the range so the line never touches the edges, and keep a flat
    // series centered.
    final pad = high == low
        ? (high == 0 ? 1.0 : high * 0.2)
        : (high - low) * 0.2;
    final minY = (low - pad) < 0 ? 0.0 : low - pad;
    final maxY = high + pad;
    final referenceValue = reference;

    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        child: LineChart(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : DrivonMotion.slow,
          curve: DrivonMotion.standard,
          LineChartData(
            minY: minY,
            maxY: maxY,
            minX: -0.3,
            maxX: points.length - 0.7,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: (maxY - minY) / 3,
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
                  interval: (maxY - minY) / 3,
                  getTitlesWidget: (value, meta) =>
                      value == meta.min || value == meta.max
                      ? const SizedBox.shrink()
                      : SideTitleWidget(
                          meta: meta,
                          child: Text(formatAxisValue(value), style: axisStyle),
                        ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  reservedSize: DrivonSpacing.xxl,
                  getTitlesWidget: (value, meta) {
                    final index = value.round();
                    if (value != index || index < 0 || index >= points.length) {
                      return const SizedBox.shrink();
                    }
                    return SideTitleWidget(
                      meta: meta,
                      child: Text(points[index].label, style: axisStyle),
                    );
                  },
                ),
              ),
            ),
            extraLinesData: ExtraLinesData(
              horizontalLines: [
                if (referenceValue != null)
                  HorizontalLine(
                    y: referenceValue,
                    color: drivon.textTertiary,
                    strokeWidth: 1,
                    dashArray: const [4, 4],
                    label: HorizontalLineLabel(
                      show: referenceLabel != null,
                      alignment: Alignment.topRight,
                      labelResolver: (_) => referenceLabel ?? '',
                      style: axisStyle,
                    ),
                  ),
              ],
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) =>
                    theme.colorScheme.surfaceContainerHighest,
                tooltipBorderRadius: DrivonRadii.smAll,
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipItems: (spots) => [
                  for (final spot in spots)
                    LineTooltipItem(
                      points[spot.x.toInt()].tooltip,
                      theme.textTheme.labelMedium!.copyWith(
                        color: drivon.textPrimary,
                      ),
                      textAlign: TextAlign.start,
                    ),
                ],
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: [
                  for (final (index, point) in points.indexed)
                    FlSpot(index.toDouble(), point.value),
                ],
                color: color,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  getDotPainter: (spot, percent, bar, index) =>
                      FlDotCirclePainter(
                        radius: 4,
                        color: color,
                        strokeWidth: 2,
                        strokeColor: surface,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
