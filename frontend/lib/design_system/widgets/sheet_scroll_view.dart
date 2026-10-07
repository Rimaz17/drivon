import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/drivon_theme.dart';
import '../tokens/drivon_colors.dart';
import '../tokens/drivon_radii.dart';
import '../tokens/drivon_spacing.dart';

/// A screen's scrolling body in two layers: [header] on the dark canvas
/// (greeting, vehicle switcher, the one headline card) and [sheet] on a
/// light paper sheet with rounded top corners that runs to the bottom of the
/// screen, even when its content is short.
///
/// Content placed directly on the sheet gets [DrivonTheme.paper], so text,
/// rows, chips and buttons turn dark. [DrivonCard]s on the sheet switch back
/// to the app theme, giving dark cards on light paper. Sheet widgets must
/// read the theme in their own build (or under a [Builder]); a style taken
/// from the screen's context would carry the canvas colors onto the paper.
class SheetScrollView extends StatelessWidget {
  const SheetScrollView({
    required this.header,
    required this.sheet,
    this.bottomPadding = DrivonSpacing.xxxl,
    super.key,
  });

  final List<Widget> header;
  final List<Widget> sheet;

  /// Space below the last sheet item, e.g. to clear a floating button.
  final double bottomPadding;

  /// Gap between the screen edge and the sheet. With the sheet's own
  /// padding, sheet content lines up with the header's screen gutter.
  static const double inset = DrivonSpacing.sm;
  static const double _padding = DrivonSpacing.screenGutter - inset;

  /// The app theme when [context] is on a sheet, otherwise null. Cards use
  /// it to keep their dark look on the paper.
  static ThemeData? appThemeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SheetScope>()?.appTheme;

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context);
    final paper = DrivonTheme.paper();

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            DrivonSpacing.screenGutter,
            DrivonSpacing.sm,
            DrivonSpacing.screenGutter,
            DrivonSpacing.xl,
          ),
          sliver: SliverList.list(children: header),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: inset),
          sliver: _SheetScope(
            appTheme: appTheme,
            child: Theme(
              data: paper,
              child: DefaultTextStyle(
                style: paper.textTheme.bodyMedium!,
                child: DecoratedSliver(
                  decoration: BoxDecoration(
                    color: context.drivonColors.sheet,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(DrivonRadii.xl),
                    ),
                  ),
                  sliver: SliverMainAxisGroup(
                    slivers: [
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          _padding,
                          DrivonSpacing.md,
                          _padding,
                          bottomPadding,
                        ),
                        sliver: SliverList.list(
                          children: [
                            const _Handle(),
                            const SizedBox(height: DrivonSpacing.lg),
                            // The paper hides the scaffold's own ink layer,
                            // so rows on the sheet need one for ripples.
                            for (final child in sheet)
                              Material(
                                type: MaterialType.transparency,
                                child: child,
                              ),
                          ],
                        ),
                      ),
                      // Carries the paper down to the bottom edge when the
                      // content is short. (SliverFillRemaining fails inside a
                      // group once the content outgrows the screen.)
                      SliverLayoutBuilder(
                        builder: (context, constraints) => SliverToBoxAdapter(
                          child: SizedBox(
                            height: math.max(
                              0,
                              constraints.viewportMainAxisExtent -
                                  constraints.precedingScrollExtent,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SheetScope extends InheritedWidget {
  const _SheetScope({required this.appTheme, required super.child});

  final ThemeData appTheme;

  @override
  bool updateShouldNotify(_SheetScope oldWidget) =>
      appTheme != oldWidget.appTheme;
}

/// The small bar at the sheet's top edge, as on a bottom sheet. Decorative.
class _Handle extends StatelessWidget {
  const _Handle();

  static const Size _size = Size(36, 4);

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Center(
        child: SizedBox.fromSize(
          size: _size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.drivonColors.sheetHandle,
              borderRadius: DrivonRadii.pill,
            ),
          ),
        ),
      ),
    );
  }
}
