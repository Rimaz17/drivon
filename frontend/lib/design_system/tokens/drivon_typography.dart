import 'package:flutter/material.dart';

/// Type scale set in Hanken Grotesk (OFL), the open-licence stand-in for the
/// inspiration's Sequel Sans; see docs/adr/0002-typeface-hanken-grotesk.md.
///
/// Sizes are logical pixels and scale with the system text size setting.
/// Large figures use light weights and tight tracking, like the inspiration's
/// big readouts; numeric styles use tabular figures so values line up.
abstract final class DrivonTypography {
  static const String fontFamily = 'HankenGrotesk';

  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  static TextTheme textTheme({
    required Color primary,
    required Color secondary,
  }) {
    return TextTheme(
      displayLarge: _style(56, FontWeight.w300, -1.6, 1.05, primary, _tabular),
      displayMedium: _style(44, FontWeight.w300, -1.2, 1.08, primary, _tabular),
      displaySmall: _style(36, FontWeight.w400, -0.9, 1.1, primary, _tabular),
      headlineLarge: _style(30, FontWeight.w400, -0.6, 1.15, primary),
      headlineMedium: _style(26, FontWeight.w500, -0.4, 1.2, primary),
      headlineSmall: _style(22, FontWeight.w500, -0.2, 1.25, primary),
      titleLarge: _style(20, FontWeight.w500, -0.1, 1.3, primary),
      titleMedium: _style(16, FontWeight.w600, 0, 1.35, primary, _tabular),
      titleSmall: _style(14, FontWeight.w600, 0, 1.35, primary, _tabular),
      bodyLarge: _style(16, FontWeight.w400, 0, 1.5, primary),
      bodyMedium: _style(14, FontWeight.w400, 0, 1.45, secondary),
      bodySmall: _style(12, FontWeight.w400, 0.1, 1.4, secondary),
      labelLarge: _style(15, FontWeight.w600, 0.1, 1.2, primary),
      labelMedium: _style(13, FontWeight.w500, 0.2, 1.2, primary),
      labelSmall: _style(11, FontWeight.w500, 0.3, 1.2, secondary),
    );
  }

  static TextStyle _style(
    double size,
    FontWeight weight,
    double letterSpacing,
    double height,
    Color color, [
    List<FontFeature>? features,
  ]) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      height: height,
      color: color,
      fontFeatures: features,
    );
  }
}
