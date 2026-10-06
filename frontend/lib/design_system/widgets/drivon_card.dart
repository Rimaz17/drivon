import 'package:flutter/material.dart';

import '../tokens/drivon_colors.dart';
import '../tokens/drivon_radii.dart';
import '../tokens/drivon_spacing.dart';

/// Visual weight of a [DrivonCard].
enum DrivonCardTone {
  /// Default dark tile.
  surface,

  /// Light lavender fill reserved for the one item that needs attention
  /// (for example the next reminder). Use at most once per screen.
  highlight,
}

/// Rounded container used for every grouped block of content.
///
/// Never nest cards inside cards; group with spacing instead.
class DrivonCard extends StatelessWidget {
  const DrivonCard({
    required this.child,
    this.tone = DrivonCardTone.surface,
    this.onTap,
    this.padding = const EdgeInsets.all(DrivonSpacing.lg),
    super.key,
  });

  final Widget child;
  final DrivonCardTone tone;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.drivonColors;
    final theme = Theme.of(context);
    final isHighlight = tone == DrivonCardTone.highlight;
    final background = isHighlight
        ? colors.highlight
        : theme.colorScheme.surfaceContainer;
    final foreground = isHighlight ? colors.onHighlight : colors.textPrimary;

    // Text theme styles carry explicit colors, so on the light highlight fill
    // the subtree gets a re-colored theme. Descendants must read
    // Theme.of(context) below the card (e.g. via a Builder) to pick it up.
    Widget content = Padding(
      padding: padding,
      child: DefaultTextStyle.merge(
        style: TextStyle(color: foreground),
        child: IconTheme.merge(
          data: IconThemeData(color: foreground),
          child: child,
        ),
      ),
    );
    if (isHighlight) {
      content = Theme(
        data: theme.copyWith(
          textTheme: theme.textTheme.apply(
            bodyColor: foreground,
            displayColor: foreground,
          ),
        ),
        child: content,
      );
    }

    return Material(
      color: background,
      borderRadius: DrivonRadii.lgAll,
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}
