import 'package:flutter/material.dart';

import 'drivon_palette.dart';

/// Semantic colors that Material's [ColorScheme] has no slot for: text
/// levels, status tones, highlight fills, chart series and the signature
/// gradient. Read them with `context.drivonColors`.
@immutable
class DrivonColors extends ThemeExtension<DrivonColors> {
  const DrivonColors({
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.highlight,
    required this.onHighlight,
    required this.accentSoft,
    required this.onAccentSoft,
    required this.gaugeTrack,
    required this.signatureGradient,
    required this.chartSeries,
  });

  /// The dark theme, Drivon's primary theme.
  static const DrivonColors dark = DrivonColors(
    textPrimary: DrivonPalette.ink50,
    textSecondary: DrivonPalette.ink300,
    textTertiary: DrivonPalette.ink400,
    success: DrivonPalette.mint,
    warning: DrivonPalette.amber,
    danger: DrivonPalette.coral,
    info: DrivonPalette.skyText,
    highlight: DrivonPalette.lavender,
    onHighlight: DrivonPalette.onLight,
    accentSoft: DrivonPalette.sky,
    onAccentSoft: DrivonPalette.onLight,
    gaugeTrack: DrivonPalette.ink750,
    signatureGradient: [
      DrivonPalette.violet,
      DrivonPalette.orchid,
      DrivonPalette.lavender,
      DrivonPalette.mint,
    ],
    chartSeries: [
      DrivonPalette.violetLight,
      DrivonPalette.mint,
      DrivonPalette.lavender,
      DrivonPalette.amber,
      DrivonPalette.skyText,
      DrivonPalette.coral,
    ],
  );

  final Color textPrimary;
  final Color textSecondary;

  /// Lowest-emphasis text that still meets WCAG AA on cards (captions, units).
  final Color textTertiary;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;

  /// Light fill for the single most important card on a screen.
  final Color highlight;
  final Color onHighlight;

  /// Light fill for secondary call-to-action buttons.
  final Color accentSoft;
  final Color onAccentSoft;
  final Color gaugeTrack;

  /// Violet-to-mint sweep for gauges and hero cards only, never for text.
  final List<Color> signatureGradient;

  /// Ordered chart series colors; each is legible on dark surfaces.
  final List<Color> chartSeries;

  @override
  DrivonColors copyWith({
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
    Color? highlight,
    Color? onHighlight,
    Color? accentSoft,
    Color? onAccentSoft,
    Color? gaugeTrack,
    List<Color>? signatureGradient,
    List<Color>? chartSeries,
  }) {
    return DrivonColors(
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
      highlight: highlight ?? this.highlight,
      onHighlight: onHighlight ?? this.onHighlight,
      accentSoft: accentSoft ?? this.accentSoft,
      onAccentSoft: onAccentSoft ?? this.onAccentSoft,
      gaugeTrack: gaugeTrack ?? this.gaugeTrack,
      signatureGradient: signatureGradient ?? this.signatureGradient,
      chartSeries: chartSeries ?? this.chartSeries,
    );
  }

  @override
  DrivonColors lerp(DrivonColors? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    List<Color> list(List<Color> a, List<Color> b) {
      if (a.length != b.length) return t < 0.5 ? a : b;
      return [for (var i = 0; i < a.length; i++) c(a[i], b[i])];
    }

    return DrivonColors(
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      textTertiary: c(textTertiary, other.textTertiary),
      success: c(success, other.success),
      warning: c(warning, other.warning),
      danger: c(danger, other.danger),
      info: c(info, other.info),
      highlight: c(highlight, other.highlight),
      onHighlight: c(onHighlight, other.onHighlight),
      accentSoft: c(accentSoft, other.accentSoft),
      onAccentSoft: c(onAccentSoft, other.onAccentSoft),
      gaugeTrack: c(gaugeTrack, other.gaugeTrack),
      signatureGradient: list(signatureGradient, other.signatureGradient),
      chartSeries: list(chartSeries, other.chartSeries),
    );
  }
}

extension DrivonColorsContext on BuildContext {
  /// Drivon's semantic colors for the current theme.
  DrivonColors get drivonColors => Theme.of(this).extension<DrivonColors>()!;
}
