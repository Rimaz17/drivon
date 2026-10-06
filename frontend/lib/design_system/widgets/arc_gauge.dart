import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens/drivon_colors.dart';
import '../tokens/drivon_motion.dart';
import '../tokens/drivon_spacing.dart';

/// Open circular gauge with the signature gradient, for a single ratio such
/// as fuel efficiency against the vehicle's best tank.
///
/// [progress] is clamped to 0..1. [value]/[unit]/[caption] are shown in the
/// centre and are pre-formatted by the caller. The fill animates in unless the
/// platform asks for reduced motion.
class ArcGauge extends StatelessWidget {
  const ArcGauge({
    required this.progress,
    required this.value,
    required this.semanticsLabel,
    this.unit,
    this.caption,
    this.size = 240,
    super.key,
  });

  final double progress;
  final String value;
  final String? unit;
  final String? caption;

  /// Full spoken description, e.g. "Average 14.2 km per litre, 80% of best".
  final String semanticsLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.drivonColors;
    final textTheme = Theme.of(context).textTheme;
    final target = progress.clamp(0.0, 1.0);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: target),
          duration: reduceMotion ? Duration.zero : DrivonMotion.slow,
          curve: DrivonMotion.emphasized,
          builder: (context, animated, child) => CustomPaint(
            painter: ArcGaugePainter(
              progress: animated,
              trackColor: colors.gaugeTrack,
              gradient: colors.signatureGradient,
              strokeWidth: size * 0.075,
            ),
            child: child,
          ),
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(size * 0.16),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: value, style: textTheme.displayLarge),
                          if (unit != null)
                            TextSpan(
                              text: ' $unit',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (caption != null) ...[
                      const SizedBox(height: DrivonSpacing.xs),
                      Text(caption!, style: textTheme.bodyMedium),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints a 270° arc opening at the bottom: a track plus a gradient fill.
class ArcGaugePainter extends CustomPainter {
  const ArcGaugePainter({
    required this.progress,
    required this.trackColor,
    required this.gradient,
    required this.strokeWidth,
  });

  static const double sweep = 1.5 * math.pi;
  static const double start = 0.75 * math.pi;

  final double progress;
  final Color trackColor;
  final List<Color> gradient;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(strokeWidth / 2);
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arcRect, start, sweep, false, track);

    if (progress <= 0) return;
    final fill = Paint()
      ..shader = SweepGradient(
        startAngle: start,
        endAngle: start + sweep,
        colors: gradient,
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arcRect, start, sweep * progress, false, fill);
  }

  @override
  bool shouldRepaint(ArcGaugePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.strokeWidth != strokeWidth ||
      !identical(oldDelegate.gradient, gradient);
}
