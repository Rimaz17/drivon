import 'package:flutter/animation.dart';

/// Motion tokens: short and decelerating, never bouncy.
abstract final class DrivonMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 450);

  /// Default easing for elements entering or changing state.
  static const Curve standard = Curves.easeOutCubic;

  /// For larger moves, such as a gauge sweep filling in.
  static const Curve emphasized = Curves.easeOutQuart;
}
