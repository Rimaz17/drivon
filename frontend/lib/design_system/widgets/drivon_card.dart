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

  /// Light gradient for the screen's main subject (for example the selected
  /// vehicle). Use at most once per screen.
  hero,
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
    final isLight = tone != DrivonCardTone.surface;
    final foreground = isLight ? colors.onHighlight : colors.textPrimary;
    final decoration = BoxDecoration(
      borderRadius: DrivonRadii.lgAll,
      color: switch (tone) {
        DrivonCardTone.surface => theme.colorScheme.surfaceContainer,
        DrivonCardTone.highlight => colors.highlight,
        DrivonCardTone.hero => null,
      },
      gradient: tone == DrivonCardTone.hero
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors.heroGradient,
            )
          : null,
    );

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
    // Theme text and icon-button styles carry explicit light colors, so on a
    // light fill the subtree gets a re-colored theme. Descendants must read
    // Theme.of(context) below the card (e.g. via a Builder) to pick it up.
    if (isLight) {
      content = Theme(
        data: theme.copyWith(
          textTheme: theme.textTheme.apply(
            bodyColor: foreground,
            displayColor: foreground,
          ),
          iconButtonTheme: IconButtonThemeData(
            style: IconButton.styleFrom(
              foregroundColor: foreground,
              minimumSize: const Size.square(DrivonSpacing.minTouchTarget),
            ),
          ),
        ),
        child: content,
      );
    }

    return Material(
      type: MaterialType.transparency,
      child: Ink(
        decoration: decoration,
        child: onTap == null
            ? content
            : InkWell(
                onTap: onTap,
                borderRadius: DrivonRadii.lgAll,
                child: content,
              ),
      ),
    );
  }
}
