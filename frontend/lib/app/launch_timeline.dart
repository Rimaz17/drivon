import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

import '../design_system/design_system.dart';

/// One frame of the launch animation: the logo, and the canvas it is drawn
/// on (which fades at the end to reveal the app).
@immutable
class LaunchFrame {
  const LaunchFrame({required this.logo, required this.canvasOpacity});

  final DrivonLogoFrame logo;
  final double canvasOpacity;
}

/// Choreography of the launch animation, as a function of time.
///
/// The canvas starts empty (matching the native launch screen). The rim
/// sweeps in like a gauge, the hub and spokes grow from the centre, and the
/// wordmark rises into place. If the app is still loading after the intro,
/// a soft highlight travels along the rim on a loop. Once loading is done the
/// logo fades out and shrinks slightly, then the canvas fades to show the
/// app. With reduced motion the finished logo only fades in and out.
///
/// Times are milliseconds since the first frame. `readyAt` is when loading
/// finished, or null while it is still running.
class LaunchTimeline {
  const LaunchTimeline({required this.reduceMotion});

  final bool reduceMotion;

  /// Every move eases out on this curve. It is not [Curves.easeOutCubic].
  static const Curve curve = Cubic(0.33, 1, 0.68, 1);

  // Intro.
  static const double rimStart = 150;
  static const double rimDuration = 450;
  static const double hubStart = 250;
  static const double hubDuration = 250;
  static const double hubScaleFrom = 0.6;
  static const double spokesStart = 450;
  static const double spokesDuration = 250;
  static const double wordmarkStart = 750;
  static const double wordmarkDuration = 450;
  static const double wordmarkRise = 8;
  static const double introEnd = 1200;

  /// Pause on the finished logo before the exit when loading is already done.
  static const double hold = 150;

  // Idle loop, only while loading outlasts the intro.
  static const double idleCycle = 2800;
  static const double idleTravel = 2520;
  static const double idleFadeIn = 504;
  static const double idleFadeOutAt = 1386;
  static const double idleFadeOutDuration = 1134;
  static const double highlightFrom = -0.5;
  static const double highlightTo = 1;
  static const double highlightStop = 150;

  // Exit.
  static const double exitDuration = 250;
  static const double exitScale = 0.94;

  /// The empty canvas fades to reveal the app once the logo has gone.
  static const double revealDuration = 150;

  // Reduced motion.
  static const double reducedFade = 250;
  static const double reducedHold = 450;

  /// When the exit starts: after the intro and hold, and not before loading
  /// has finished. Null while loading is still running.
  double? exitStart(double? readyAt) {
    if (readyAt == null) return null;
    final earliest = reduceMotion ? reducedFade + reducedHold : introEnd + hold;
    return math.max(earliest, readyAt);
  }

  /// Whether the animation has ended and the app is fully visible.
  bool isFinished(double t, {required double? readyAt}) {
    final exit = exitStart(readyAt);
    return exit != null && t >= exit + exitDuration + revealDuration;
  }

  LaunchFrame frameAt(double t, {required double? readyAt}) {
    final exit = exitStart(readyAt);
    final exitProgress = exit == null ? 0.0 : _ease(t, exit, exitDuration);
    final reveal = exit == null
        ? 0.0
        : _ease(t, exit + exitDuration, revealDuration);
    final canvasOpacity = 1 - reveal;

    if (reduceMotion) {
      final fadeIn = _ease(t, 0, reducedFade);
      return LaunchFrame(
        logo: DrivonLogoFrame(opacity: fadeIn * (1 - exitProgress)),
        canvasOpacity: canvasOpacity,
      );
    }

    final hub = _ease(t, hubStart, hubDuration);
    final spokes = _ease(t, spokesStart, spokesDuration);
    final wordmark = _ease(t, wordmarkStart, wordmarkDuration);
    final (highlightPosition, highlightOpacity) = _highlight(t, readyAt, exit);
    return LaunchFrame(
      logo: DrivonLogoFrame(
        rimReveal: _ease(t, rimStart, rimDuration),
        hubOpacity: hub,
        hubScale: hubScaleFrom + (1 - hubScaleFrom) * hub,
        spokesReveal: spokes,
        stemReveal: spokes,
        wordmarkOpacity: wordmark,
        wordmarkDrop: wordmarkRise * (1 - wordmark),
        highlightPosition: highlightPosition,
        highlightOpacity: highlightOpacity,
        opacity: 1 - exitProgress,
        scale: 1 - (1 - exitScale) * exitProgress,
      ),
      canvasOpacity: canvasOpacity,
    );
  }

  /// The idle highlight: it travels along the rim, fading in and out, and is
  /// invisible at both ends of each cycle so the loop is seamless.
  (double, double) _highlight(double t, double? readyAt, double? exit) {
    final loadedDuringIntro = readyAt != null && readyAt <= introEnd;
    if (t < introEnd || loadedDuringIntro) return (0, 0);
    final u = (t - introEnd) % idleCycle;
    if (u >= idleTravel) return (0, 0);
    final position =
        highlightFrom +
        (highlightTo - highlightFrom) * curve.transform(u / idleTravel);
    var opacity =
        _ease(u, 0, idleFadeIn) *
        (1 - _ease(u, idleFadeOutAt, idleFadeOutDuration));
    if (exit != null) opacity *= 1 - _ease(t, exit, highlightStop);
    return (position, opacity);
  }

  /// Eased progress, 0 to 1, of a move starting at [start] lasting
  /// [duration].
  static double _ease(double t, double start, double duration) =>
      curve.transform(((t - start) / duration).clamp(0.0, 1.0));
}
