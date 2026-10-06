import 'package:flutter/painting.dart';

/// Raw brand colors sampled from the Drivon inspiration boards.
///
/// Feature code must not use these directly: read semantic roles from
/// `Theme.of(context).colorScheme` or `context.drivonColors` instead, so a
/// light theme can be added later without touching screens.
abstract final class DrivonPalette {
  // Neutrals: cool near-blacks, never pure black.
  static const Color ink950 = Color(0xFF0F1011);
  static const Color ink900 = Color(0xFF151718); // canvas
  static const Color ink850 = Color(0xFF1C1D1F);
  static const Color ink800 = Color(0xFF242427); // cards / tiles
  static const Color ink750 = Color(0xFF2E2F32);
  static const Color ink700 = Color(0xFF393A3E);
  static const Color ink450 = Color(0xFF7C7E85); // input borders (3:1)
  static const Color ink400 = Color(0xFF9A9CA2);
  static const Color ink300 = Color(0xFFA8AAAE);
  static const Color ink50 = Color(0xFFF4F4F6);

  // Brand.
  static const Color violet = Color(0xFF7D56EE); // primary
  static const Color violetDeep = Color(0xFF3B2A78);
  static const Color violetLight = Color(0xFFB9A3FF); // violet text on dark
  static const Color violetPale = Color(0xFFE6DDFF);
  static const Color orchid = Color(0xFFD7ABD8); // gauge gradient
  static const Color lavender = Color(0xFFF3C7F8); // highlight cards
  static const Color mint = Color(0xFF99E7D8);
  static const Color mintDeep = Color(0xFF1F3B36);
  static const Color mintPale = Color(0xFFC9F4EB);
  static const Color sky = Color(0xFFD7EFFF);

  // Status. Lightened variants keep text legible on dark surfaces.
  static const Color coral = Color(0xFFFF6E96); // danger, from brand magenta
  static const Color coralDeep = Color(0xFF4A1426);
  static const Color amber = Color(0xFFF6C177);
  static const Color skyText = Color(0xFF9CCFF0);

  // Dark text for use on the light brand fills above.
  static const Color onLight = Color(0xFF17151C);
}
