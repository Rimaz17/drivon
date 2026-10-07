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
}
