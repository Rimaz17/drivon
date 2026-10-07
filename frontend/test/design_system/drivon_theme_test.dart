import 'package:drivon/design_system/theme/drivon_theme.dart';
import 'package:drivon/design_system/tokens/drivon_colors.dart';
import 'package:drivon/design_system/tokens/drivon_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG 2.x contrast ratio between two opaque colors.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  final theme = DrivonTheme.dark();
  final scheme = theme.colorScheme;
  const colors = DrivonColors.dark;

  group('dark theme', () {
    test('is dark, uses the bundled typeface and exposes Drivon colors', () {
      expect(theme.brightness, Brightness.dark);
      expect(
        theme.textTheme.bodyLarge?.fontFamily,
        DrivonTypography.fontFamily,
      );
      expect(theme.extension<DrivonColors>(), isNotNull);
    });

    final surfaces = {
      'canvas': scheme.surface,
      'card': scheme.surfaceContainer,
      'raised card': scheme.surfaceContainerHigh,
    };
    final texts = {
      'primary text': colors.textPrimary,
      'secondary text': colors.textSecondary,
      'tertiary text': colors.textTertiary,
      'danger text': colors.danger,
      'success text': colors.success,
      'warning text': colors.warning,
      'info text': colors.info,
      'accent text': colors.accentText,
    };

    for (final surface in surfaces.entries) {
      for (final text in texts.entries) {
        test('${text.key} meets WCAG AA on ${surface.key}', () {
          expect(
            contrast(text.value, surface.value),
            greaterThanOrEqualTo(4.5),
          );
        });
      }
    }

    test('text on brand fills meets WCAG AA', () {
      expect(
        contrast(scheme.onPrimary, scheme.primary),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(colors.onHighlight, colors.highlight),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(colors.onAccentSoft, colors.accentSoft),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(scheme.onSecondary, scheme.secondary),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(colors.onSelectedFill, colors.selectedFill),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('navigation labels and icons meet WCAG AA on their surfaces', () {
      // Unselected items on the bar/rail background, selected icons on the
      // indicator pill.
      expect(
        contrast(colors.textSecondary, scheme.surfaceContainerLow),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(colors.textPrimary, scheme.surfaceContainerLow),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(scheme.onPrimaryContainer, scheme.primaryContainer),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('dark text stays readable across the hero gradient', () {
      for (final color in colors.heroGradient) {
        expect(contrast(colors.onHighlight, color), greaterThanOrEqualTo(4.5));
      }
    });

    test('input borders meet the 3:1 non-text contrast minimum', () {
      expect(
        contrast(scheme.outline, scheme.surfaceContainer),
        greaterThanOrEqualTo(3),
      );
    });
  });

  group('paper theme', () {
    final paper = DrivonTheme.paper();
    final paperScheme = paper.colorScheme;
    const paperColors = DrivonColors.paper;

    test('is light and exposes the paper colors', () {
      expect(paper.brightness, Brightness.light);
      expect(paper.extension<DrivonColors>(), paperColors);
      expect(paperScheme.surface, colors.sheet);
    });

    final surfaces = {
      'paper': paperScheme.surface,
      'chip / notice fill': paperScheme.surfaceContainerHigh,
    };
    final texts = {
      'primary text': paperColors.textPrimary,
      'secondary text': paperColors.textSecondary,
      'tertiary text': paperColors.textTertiary,
      'danger text': paperColors.danger,
      'success text': paperColors.success,
      'warning text': paperColors.warning,
      'info text': paperColors.info,
      'accent text': paperColors.accentText,
    };

    for (final surface in surfaces.entries) {
      for (final text in texts.entries) {
        test('${text.key} meets WCAG AA on ${surface.key}', () {
          expect(
            contrast(text.value, surface.value),
            greaterThanOrEqualTo(4.5),
          );
        });
      }
    }

    test('selected chips and filled buttons meet WCAG AA', () {
      expect(
        contrast(paperColors.onSelectedFill, paperColors.selectedFill),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(paperScheme.onPrimary, paperScheme.primary),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('input and button borders meet the 3:1 non-text minimum', () {
      expect(
        contrast(paperScheme.outline, paperScheme.surface),
        greaterThanOrEqualTo(3),
      );
    });
  });
}
