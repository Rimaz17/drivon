/// 4-point spacing scale. Use these instead of literal paddings and gaps.
abstract final class DrivonSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 48;

  /// Horizontal padding between the screen edges and content.
  static const double screenGutter = xl;

  /// Widest a form or message column grows, so lines stay readable on tablets.
  static const double formMaxWidth = 440;

  /// Widest a screen's main content grows on tablets and in landscape.
  static const double contentMaxWidth = 600;

  /// Minimum touch target on both platforms (Material 48dp > iOS 44pt).
  static const double minTouchTarget = 48;
}
