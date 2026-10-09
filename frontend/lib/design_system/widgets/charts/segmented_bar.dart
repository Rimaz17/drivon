import 'package:flutter/material.dart';

import '../../tokens/drivon_colors.dart';
import '../../tokens/drivon_radii.dart';

/// One part of a [SegmentedBar].
@immutable
class BarSegment {
  const BarSegment({required this.value, required this.color});

  /// Any non-negative amount; segments are drawn in proportion.
  final double value;
  final Color color;
}

/// A single horizontal bar split into parts in proportion to their values,
/// with a 2 dp gap between parts. Pair it with a [ChartLegend]. Shows an
/// empty track when every value is zero.
class SegmentedBar extends StatelessWidget {
  const SegmentedBar({
    required this.segments,
    required this.semanticsLabel,
    this.height = 12,
    super.key,
  });

  final List<BarSegment> segments;
  final String semanticsLabel;
  final double height;

  static const double _gap = 2;

  @override
  Widget build(BuildContext context) {
    final visible = [
      for (final segment in segments)
        if (segment.value > 0) segment,
    ];
    final total = visible.fold<double>(0, (sum, s) => sum + s.value);
    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: DrivonRadii.pill,
        child: SizedBox(
          height: height,
          child: total == 0
              ? ColoredBox(color: context.drivonColors.gaugeTrack)
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final gaps = _gap * (visible.length - 1);
                    final width = constraints.maxWidth - gaps;
                    return Row(
                      // Childless boxes collapse unless stretched to the
                      // bar's height.
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (index, segment) in visible.indexed) ...[
                          if (index > 0) const SizedBox(width: _gap),
                          SizedBox(
                            width: width * segment.value / total,
                            child: ColoredBox(color: segment.color),
                          ),
                        ],
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }
}
