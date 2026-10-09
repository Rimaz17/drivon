import 'package:flutter/material.dart';

import '../tokens/drivon_colors.dart';
import '../tokens/drivon_motion.dart';
import '../tokens/drivon_radii.dart';
import '../tokens/drivon_spacing.dart';

/// One option of a [PillSegmentedControl]: a bold [label] with an optional
/// lighter [detail] beside it, e.g. "Aqua  CAB-1234".
class PillSegment<T> {
  const PillSegment({
    required this.value,
    required this.label,
    this.detail,
    this.tooltip,
  });

  final T value;
  final String label;
  final String? detail;
  final String? tooltip;
}

/// Picks one of a few options. A dark pill track holds the options, and a
/// light pill slides behind the selected one. For two or three short options
/// on the dark canvas; use chips for longer lists.
class PillSegmentedControl<T> extends StatelessWidget {
  const PillSegmentedControl({
    required this.segments,
    required this.selected,
    required this.onSelected,
    this.semanticsLabel,
    super.key,
  }) : assert(segments.length > 1, 'Needs at least two options.');

  final List<PillSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onSelected;

  /// Names the group for screen readers, e.g. "Choose a vehicle".
  final String? semanticsLabel;

  static const double _trackPadding = DrivonSpacing.xs;

  @override
  Widget build(BuildContext context) {
    final colors = context.drivonColors;
    final count = segments.length;
    final index = segments.indexWhere((segment) => segment.value == selected);
    final animate = !MediaQuery.disableAnimationsOf(context);

    return Semantics(
      label: semanticsLabel,
      container: true,
      explicitChildNodes: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: DrivonRadii.pill,
        ),
        child: Padding(
          padding: const EdgeInsets.all(_trackPadding),
          child: Stack(
            children: [
              if (index >= 0)
                Positioned.fill(
                  child: AnimatedAlign(
                    alignment: AlignmentDirectional(
                      -1 + 2 * index / (count - 1),
                      0,
                    ),
                    duration: animate ? DrivonMotion.medium : Duration.zero,
                    curve: DrivonMotion.standard,
                    child: FractionallySizedBox(
                      widthFactor: 1 / count,
                      heightFactor: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.selectedFill,
                          borderRadius: DrivonRadii.pill,
                        ),
                      ),
                    ),
                  ),
                ),
              Material(
                type: MaterialType.transparency,
                child: Row(
                  children: [
                    for (final segment in segments)
                      Expanded(
                        child: _Segment(
                          segment: segment,
                          selected: segment.value == selected,
                          animate: animate,
                          onTap: () {
                            if (segment.value != selected) {
                              onSelected(segment.value);
                            }
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Segment<T> extends StatelessWidget {
  const _Segment({
    required this.segment,
    required this.selected,
    required this.animate,
    required this.onTap,
  });

  final PillSegment<T> segment;
  final bool selected;
  final bool animate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = context.drivonColors;
    final detail = segment.detail;

    Widget option = Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: DrivonSpacing.minTouchTarget,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DrivonSpacing.md,
              vertical: DrivonSpacing.sm,
            ),
            child: Center(
              child: AnimatedDefaultTextStyle(
                duration: animate ? DrivonMotion.fast : Duration.zero,
                curve: DrivonMotion.standard,
                style: textTheme.labelLarge!.copyWith(
                  color: selected
                      ? colors.onSelectedFill
                      : colors.textSecondary,
                ),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: segment.label),
                      if (detail != null)
                        TextSpan(
                          text: '  $detail',
                          style: TextStyle(
                            fontSize: textTheme.labelMedium?.fontSize,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final tooltip = segment.tooltip;
    if (tooltip != null) option = Tooltip(message: tooltip, child: option);
    return option;
  }
}
