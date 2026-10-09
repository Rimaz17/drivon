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
    required this.accentText,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.highlight,
    required this.onHighlight,
    required this.accentSoft,
    required this.onAccentSoft,
    required this.gaugeTrack,
    required this.selectedFill,
    required this.onSelectedFill,
    required this.sheet,
    required this.sheetHandle,
    required this.signatureGradient,
    required this.heroGradient,
    required this.chartSeries,
    required this.costSeries,
  });

  /// The dark theme, Drivon's primary theme.
  static const DrivonColors dark = DrivonColors(
    textPrimary: DrivonPalette.ink50,
    textSecondary: DrivonPalette.ink300,
    textTertiary: DrivonPalette.ink400,
    accentText: DrivonPalette.violetLight,
    success: DrivonPalette.mint,
    warning: DrivonPalette.amber,
    danger: DrivonPalette.coral,
    info: DrivonPalette.skyText,
    highlight: DrivonPalette.lavender,
    onHighlight: DrivonPalette.onLight,
    accentSoft: DrivonPalette.sky,
    onAccentSoft: DrivonPalette.onLight,
    gaugeTrack: DrivonPalette.ink750,
    selectedFill: DrivonPalette.lilac,
    onSelectedFill: DrivonPalette.onLight,
    sheet: DrivonPalette.paper,
    sheetHandle: DrivonPalette.paper400,
    signatureGradient: [
      DrivonPalette.violet,
      DrivonPalette.orchid,
      DrivonPalette.lavender,
      DrivonPalette.mint,
    ],
    heroGradient: [DrivonPalette.lavender, DrivonPalette.violetMist],
    chartSeries: [
      DrivonPalette.violetLight,
      DrivonPalette.mint,
      DrivonPalette.lavender,
      DrivonPalette.amber,
      DrivonPalette.skyText,
      DrivonPalette.coral,
    ],
    costSeries: [
      DrivonPalette.seriesViolet,
      DrivonPalette.seriesTeal,
      DrivonPalette.seriesOchre,
    ],
  );

  /// Colors for content placed directly on the light paper sheet (see
  /// `DrivonSheet`); dark cards on the sheet switch back to [dark].
  static const DrivonColors paper = DrivonColors(
    textPrimary: DrivonPalette.onLight,
    textSecondary: DrivonPalette.paperText2,
    textTertiary: DrivonPalette.paperText3,
    accentText: DrivonPalette.violetInk,
    success: DrivonPalette.mintInk,
    warning: DrivonPalette.amberInk,
    danger: DrivonPalette.coralInk,
    info: DrivonPalette.skyInk,
    highlight: DrivonPalette.lavender,
    onHighlight: DrivonPalette.onLight,
    accentSoft: DrivonPalette.sky,
    onAccentSoft: DrivonPalette.onLight,
    gaugeTrack: DrivonPalette.paper300,
    selectedFill: DrivonPalette.ink850,
    onSelectedFill: DrivonPalette.ink50,
    sheet: DrivonPalette.paper,
    sheetHandle: DrivonPalette.paper400,
    signatureGradient: [
      DrivonPalette.violet,
      DrivonPalette.orchid,
      DrivonPalette.lavender,
      DrivonPalette.mint,
    ],
    heroGradient: [DrivonPalette.lavender, DrivonPalette.violetMist],
    chartSeries: [
      DrivonPalette.violet,
      DrivonPalette.mintInk,
      DrivonPalette.violetInk,
      DrivonPalette.amberInk,
      DrivonPalette.skyInk,
      DrivonPalette.coralInk,
    ],
    costSeries: [
      DrivonPalette.seriesViolet,
      DrivonPalette.seriesTeal,
      DrivonPalette.seriesOchre,
    ],
  );

  final Color textPrimary;
  final Color textSecondary;

  /// Lowest-emphasis text that still meets WCAG AA on cards (captions, units).
  final Color textTertiary;

  /// Violet for text: links, text buttons, focused input borders.
  final Color accentText;
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

  /// Fill of the selected option in a segmented control.
  final Color selectedFill;
  final Color onSelectedFill;

  /// Light paper sheet that holds a screen's details below its headline
  /// content, and the small handle at its top edge.
  final Color sheet;
  final Color sheetHandle;

  /// Violet-to-mint sweep for gauges and hero cards only, never for text.
  final List<Color> signatureGradient;

  /// Light fill for the one hero card on a screen; text on it uses
  /// [onHighlight].
  final List<Color> heroGradient;

  /// Ordered chart series colors; each is legible on dark surfaces.
  final List<Color> chartSeries;

  /// Fuel, maintenance and other, in that fixed order, for charts that split
  /// a running cost. Charts sit on dark cards, so both themes use the same
  /// validated mid-tones.
  final List<Color> costSeries;

  @override
  DrivonColors copyWith({
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? accentText,
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
    Color? highlight,
    Color? onHighlight,
    Color? accentSoft,
    Color? onAccentSoft,
    Color? gaugeTrack,
    Color? selectedFill,
    Color? onSelectedFill,
    Color? sheet,
    Color? sheetHandle,
    List<Color>? signatureGradient,
    List<Color>? heroGradient,
    List<Color>? chartSeries,
    List<Color>? costSeries,
  }) {
    return DrivonColors(
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      accentText: accentText ?? this.accentText,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
      highlight: highlight ?? this.highlight,
      onHighlight: onHighlight ?? this.onHighlight,
      accentSoft: accentSoft ?? this.accentSoft,
      onAccentSoft: onAccentSoft ?? this.onAccentSoft,
      gaugeTrack: gaugeTrack ?? this.gaugeTrack,
      selectedFill: selectedFill ?? this.selectedFill,
      onSelectedFill: onSelectedFill ?? this.onSelectedFill,
      sheet: sheet ?? this.sheet,
      sheetHandle: sheetHandle ?? this.sheetHandle,
      signatureGradient: signatureGradient ?? this.signatureGradient,
      heroGradient: heroGradient ?? this.heroGradient,
      chartSeries: chartSeries ?? this.chartSeries,
      costSeries: costSeries ?? this.costSeries,
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
      accentText: c(accentText, other.accentText),
      success: c(success, other.success),
      warning: c(warning, other.warning),
      danger: c(danger, other.danger),
      info: c(info, other.info),
      highlight: c(highlight, other.highlight),
      onHighlight: c(onHighlight, other.onHighlight),
      accentSoft: c(accentSoft, other.accentSoft),
      onAccentSoft: c(onAccentSoft, other.onAccentSoft),
      gaugeTrack: c(gaugeTrack, other.gaugeTrack),
      selectedFill: c(selectedFill, other.selectedFill),
      onSelectedFill: c(onSelectedFill, other.onSelectedFill),
      sheet: c(sheet, other.sheet),
      sheetHandle: c(sheetHandle, other.sheetHandle),
      signatureGradient: list(signatureGradient, other.signatureGradient),
      heroGradient: list(heroGradient, other.heroGradient),
      chartSeries: list(chartSeries, other.chartSeries),
      costSeries: list(costSeries, other.costSeries),
    );
  }
}

extension DrivonColorsContext on BuildContext {
  /// Drivon's semantic colors for the current theme.
  DrivonColors get drivonColors => Theme.of(this).extension<DrivonColors>()!;
}
