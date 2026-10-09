import 'package:flutter/material.dart';

import '../../tokens/drivon_colors.dart';
import '../../tokens/drivon_radii.dart';
import '../../tokens/drivon_spacing.dart';

/// One legend entry: a swatch of the series color and its name, with an
/// optional value. The text keeps text colors; only the swatch is colored.
@immutable
class LegendEntry {
  const LegendEntry({required this.color, required this.label, this.value});

  final Color color;
  final String label;
  final String? value;
}

/// The legend of a chart with two or more series, so series identity never
/// relies on color alone. Wraps on narrow screens.
class ChartLegend extends StatelessWidget {
  const ChartLegend({required this.entries, super.key});

  final List<LegendEntry> entries;

  static const double _swatch = 10;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = context.drivonColors;
    return Wrap(
      spacing: DrivonSpacing.lg,
      runSpacing: DrivonSpacing.xs,
      children: [
        for (final entry in entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: _swatch,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: entry.color,
                    borderRadius: DrivonRadii.pill,
                  ),
                ),
              ),
              const SizedBox(width: DrivonSpacing.xs),
              // One wrapping text, so long values and large text sizes
              // never overflow a narrow screen.
              Flexible(
                child: Text.rich(
                  TextSpan(
                    text: entry.label,
                    children: [
                      if (entry.value case final value?)
                        TextSpan(
                          text: ' $value',
                          style: TextStyle(color: colors.textSecondary),
                        ),
                    ],
                  ),
                  style: textTheme.labelMedium,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
