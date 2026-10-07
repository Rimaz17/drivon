import 'package:flutter/material.dart';

import '../tokens/drivon_colors.dart';
import '../tokens/drivon_motion.dart';
import '../tokens/drivon_radii.dart';
import '../tokens/drivon_spacing.dart';

/// One row of a [BarList].
@immutable
class BarListItem {
  const BarListItem({
    required this.label,
    required this.value,
    required this.fraction,
    this.color,
    this.emphasized = false,
  });

  /// e.g. a month or category name.
  final String label;

  /// Pre-formatted figure, e.g. `Rs. 18,500`.
  final String value;

  /// Bar length relative to the longest bar, 0..1.
  final double fraction;

  /// Bar color; the first chart series color when null.
  final Color? color;

  /// Shows the label and value in the primary text color, e.g. this month.
  final bool emphasized;
}

/// Labelled horizontal bars for comparing a few totals, such as monthly
/// spend or spend per category. Each row reads label and value on one line
/// with the bar beneath, so it stays legible at large text sizes. Screen
/// readers hear "label, value" per row.
class BarList extends StatelessWidget {
  const BarList({required this.items, super.key});

  final List<BarListItem> items;

  /// Bar thickness; a slim bar keeps the figures in charge.
  static const double barHeight = 8;

  @override
  Widget build(BuildContext context) {
    final colors = context.drivonColors;
    final textTheme = Theme.of(context).textTheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Column(
      children: [
        for (final (index, item) in items.indexed) ...[
          if (index > 0) const SizedBox(height: DrivonSpacing.md),
          Semantics(
            label: '${item.label}, ${item.value}',
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.label,
                        style: textTheme.bodyMedium?.copyWith(
                          color: item.emphasized
                              ? colors.textPrimary
                              : colors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: DrivonSpacing.sm),
                    Text(
                      item.value,
                      style: textTheme.titleSmall?.copyWith(
                        color: item.emphasized
                            ? colors.textPrimary
                            : colors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DrivonSpacing.xs),
                ClipRRect(
                  borderRadius: DrivonRadii.pill,
                  child: SizedBox(
                    height: barHeight,
                    child: ColoredBox(
                      color: colors.gaugeTrack,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: item.fraction.clamp(0.0, 1.0)),
                        duration: reduceMotion
                            ? Duration.zero
                            : DrivonMotion.medium,
                        curve: DrivonMotion.standard,
                        builder: (context, fraction, _) => FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: fraction,
                          child: ColoredBox(
                            color: item.color ?? colors.chartSeries.first,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
