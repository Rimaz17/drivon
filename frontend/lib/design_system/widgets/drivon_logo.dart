import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../tokens/drivon_palette.dart';

/// The Drivon logo: a steering-wheel mark (an open gauge arc as the rim, a
/// T of spokes and a hub) with the "drivon" wordmark beneath it.
///
/// It is drawn from the vector geometry in `docs/brand`, so it stays sharp at
/// any size, and each part can be animated through a [DrivonLogoFrame]. The
/// hub sits at the centre of the widget.
class DrivonLogo extends StatelessWidget {
  const DrivonLogo({
    this.frame = DrivonLogoFrame.complete,
    this.markWidth = DrivonLogoPainter.defaultMarkWidth,
    super.key,
  });

  final DrivonLogoFrame frame;

  /// Outer width of the rim, in logical pixels.
  final double markWidth;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: DrivonLogoPainter(frame: frame, markWidth: markWidth),
    child: const SizedBox.expand(),
  );
}

/// How far each part of the logo has been drawn in, for animating it.
///
/// Reveals and opacities run from 0 to 1. [complete] is the finished logo;
/// [empty] draws nothing.
@immutable
class DrivonLogoFrame {
  const DrivonLogoFrame({
    this.rimReveal = 1,
    this.hubOpacity = 1,
    this.hubScale = 1,
    this.spokesReveal = 1,
    this.stemReveal = 1,
    this.wordmarkOpacity = 1,
    this.wordmarkDrop = 0,
    this.highlightPosition = 0,
    this.highlightOpacity = 0,
    this.opacity = 1,
    this.scale = 1,
  });

  static const DrivonLogoFrame complete = DrivonLogoFrame();
  static const DrivonLogoFrame empty = DrivonLogoFrame(
    rimReveal: 0,
    hubOpacity: 0,
    spokesReveal: 0,
    stemReveal: 0,
    wordmarkOpacity: 0,
  );

  /// Share of the rim drawn, sweeping from its left end over the top.
  final double rimReveal;
  final double hubOpacity;

  /// Hub size relative to its final size, scaled about its centre.
  final double hubScale;

  /// Share of the horizontal spokes drawn, growing out from the hub.
  final double spokesReveal;

  /// Share of the downward spoke drawn, growing out from the hub.
  final double stemReveal;
  final double wordmarkOpacity;

  /// How far below its final position the wordmark is, in logical pixels.
  final double wordmarkDrop;

  /// Centre of the soft highlight travelling along the rim, as a share of
  /// the rim's length (it may start before the rim, below 0).
  final double highlightPosition;
  final double highlightOpacity;

  /// Opacity of the whole logo.
  final double opacity;

  /// Scale of the whole logo about the hub.
  final double scale;

  /// Whether any part of the logo shows.
  bool get isVisible =>
      opacity > 0 &&
      (rimReveal > 0 ||
          hubOpacity > 0 ||
          spokesReveal > 0 ||
          stemReveal > 0 ||
          wordmarkOpacity > 0 ||
          highlightOpacity > 0);

  @override
  bool operator ==(Object other) =>
      other is DrivonLogoFrame &&
      other.rimReveal == rimReveal &&
      other.hubOpacity == hubOpacity &&
      other.hubScale == hubScale &&
      other.spokesReveal == spokesReveal &&
      other.stemReveal == stemReveal &&
      other.wordmarkOpacity == wordmarkOpacity &&
      other.wordmarkDrop == wordmarkDrop &&
      other.highlightPosition == highlightPosition &&
      other.highlightOpacity == highlightOpacity &&
      other.opacity == opacity &&
      other.scale == scale;

  @override
  int get hashCode => Object.hash(
    rimReveal,
    hubOpacity,
    hubScale,
    spokesReveal,
    stemReveal,
    wordmarkOpacity,
    wordmarkDrop,
    highlightPosition,
    highlightOpacity,
    opacity,
    scale,
  );
}

/// Paints [DrivonLogo]. Geometry is in design units with the hub at the
/// origin and y pointing down; the rim is 65 units wide.
class DrivonLogoPainter extends CustomPainter {
  const DrivonLogoPainter({
    required this.frame,
    this.markWidth = defaultMarkWidth,
  });

  static const double defaultMarkWidth = 160;

  // Brand colors are fixed: the logo looks the same in every theme.
  static const List<Color> _rimColors = [
    DrivonPalette.violet,
    DrivonPalette.violetLight,
    DrivonPalette.lavender,
    DrivonPalette.mint,
  ];
  static const List<double> _rimStops = [0, 0.36, 0.7, 1];
  static const Color _spokeColor = DrivonPalette.ink50;
  static const Color _hubColor = DrivonPalette.violetLight;
  static const Color _wordmarkColor = DrivonPalette.ink50;
  static const Color _highlightColor = DrivonPalette.ink50;

  static const double _markUnits = 65;
  static const double _rimOuter = 32.5;
  static const double _rimCentreline = 28.5;
  static const double _rimInner = 24.5;
  static const double _rimCapRadius = 4;
  static const double _spokeWidth = 5;
  static const double _spokeLength = 28;
  static const double _stemTop = 2.5;
  static const double _stemLength = 19;
  static const double _hubRadius = 7;

  // The rim runs clockwise from 135° (bottom left) over the top to 405°
  // (bottom right). Its reveal and highlight follow a slightly longer arc,
  // 127° to 413°, that also covers the rounded ends.
  static const double _travelStart = 127 * math.pi / 180;
  static const double _travelSweep = 286 * math.pi / 180;
  static const double _revealHalfWidth = 6;
  static const double _highlightWidth = 10;

  // The highlight is three stacked strokes, widest and faintest first, so
  // its edges are soft: (share of the arc, opacity).
  static const List<(double, double)> _highlightLayers = [
    (0.28, 0.07),
    (0.18, 0.14),
    (0.09, 0.30),
  ];

  // The wordmark outline is in font units: its baseline centre sits at
  // (1526.8, 548.53) and it is drawn at 0.06 units per font unit, with the
  // baseline 54.8 units below the hub.
  static const double _wordmarkBaseline = 54.8;
  static const double _wordmarkScale = 0.06;
  static const Offset _wordmarkOrigin = Offset(1526.8, 548.53);

  static final Path _rim = _rimOutline();
  static final Path _wordmark = parseOutline(_wordmarkOutline);

  final DrivonLogoFrame frame;
  final double markWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final f = frame;
    if (!f.isVisible) return;
    final unit = markWidth / _markUnits;

    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..scale(f.scale * unit);
    final faded = f.opacity < 1;
    if (faded) {
      canvas.saveLayer(null, Paint()..color = _alpha(f.opacity));
    }

    _paintSpokes(canvas);
    if (f.hubOpacity > 0) {
      canvas.drawCircle(
        Offset.zero,
        _hubRadius * f.hubScale,
        Paint()..color = _hubColor.withValues(alpha: f.hubOpacity),
      );
    }
    _paintRim(canvas);
    _paintHighlight(canvas);
    _paintWordmark(canvas, unit);

    if (faded) canvas.restore();
    canvas.restore();
  }

  void _paintSpokes(Canvas canvas) {
    final paint = Paint()
      ..color = _spokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _spokeWidth
      ..strokeCap = StrokeCap.round;
    final spokes = frame.spokesReveal;
    if (spokes > 0) {
      canvas
        ..drawLine(Offset.zero, Offset(-_spokeLength * spokes, 0), paint)
        ..drawLine(Offset.zero, Offset(_spokeLength * spokes, 0), paint);
    }
    final stem = frame.stemReveal;
    if (stem > 0) {
      canvas.drawLine(
        const Offset(0, _stemTop),
        Offset(0, _stemTop + _stemLength * stem),
        paint,
      );
    }
  }

  void _paintRim(Canvas canvas) {
    final reveal = frame.rimReveal;
    if (reveal <= 0) return;
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(-_rimOuter, 0),
        const Offset(_rimOuter, 0),
        _rimColors,
        _rimStops,
      );
    if (reveal >= 1) {
      canvas.drawPath(_rim, paint);
      return;
    }
    // Reveal the rim like a gauge filling: clip it to a band along the arc
    // that grows from the left end, so the leading edge is cut square.
    final band = Path()
      ..addArc(
        Rect.fromCircle(
          center: Offset.zero,
          radius: _rimCentreline + _revealHalfWidth,
        ),
        _travelStart,
        _travelSweep * reveal,
      )
      ..arcTo(
        Rect.fromCircle(
          center: Offset.zero,
          radius: _rimCentreline - _revealHalfWidth,
        ),
        _travelStart + _travelSweep * reveal,
        -_travelSweep * reveal,
        false,
      )
      ..close();
    canvas
      ..save()
      ..clipPath(band)
      ..drawPath(_rim, paint)
      ..restore();
  }

  void _paintHighlight(Canvas canvas) {
    if (frame.highlightOpacity <= 0) return;
    final arc = Rect.fromCircle(center: Offset.zero, radius: _rimCentreline);
    canvas
      ..save()
      ..clipPath(_rim)
      ..saveLayer(null, Paint()..color = _alpha(frame.highlightOpacity));
    for (final (length, opacity) in _highlightLayers) {
      final start = math.max(0.0, frame.highlightPosition - length / 2);
      final end = math.min(1.0, frame.highlightPosition + length / 2);
      if (end <= start) continue;
      canvas.drawArc(
        arc,
        _travelStart + _travelSweep * start,
        _travelSweep * (end - start),
        false,
        Paint()
          ..color = _highlightColor.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = _highlightWidth,
      );
    }
    canvas
      ..restore()
      ..restore();
  }

  void _paintWordmark(Canvas canvas, double unit) {
    if (frame.wordmarkOpacity <= 0) return;
    canvas
      ..save()
      ..translate(0, _wordmarkBaseline + frame.wordmarkDrop / unit)
      ..scale(_wordmarkScale)
      ..translate(-_wordmarkOrigin.dx, -_wordmarkOrigin.dy)
      ..drawPath(
        _wordmark,
        Paint()
          ..color = _wordmarkColor.withValues(alpha: frame.wordmarkOpacity),
      )
      ..restore();
  }

  static Color _alpha(double opacity) =>
      const Color(0xFF000000).withValues(alpha: opacity);

  /// The rim as a filled outline: an 8-unit band with rounded ends.
  static Path _rimOutline() {
    const end = _rimOuter * math.sqrt1_2;
    const innerEnd = _rimInner * math.sqrt1_2;
    return Path()
      ..moveTo(-end, end)
      ..arcToPoint(
        const Offset(end, end),
        radius: const Radius.circular(_rimOuter),
        largeArc: true,
      )
      ..arcToPoint(
        const Offset(innerEnd, innerEnd),
        radius: const Radius.circular(_rimCapRadius),
      )
      ..arcToPoint(
        const Offset(-innerEnd, innerEnd),
        radius: const Radius.circular(_rimInner),
        largeArc: true,
        clockwise: false,
      )
      ..arcToPoint(
        const Offset(-end, end),
        radius: const Radius.circular(_rimCapRadius),
      )
      ..close();
  }

  @override
  bool shouldRepaint(DrivonLogoPainter oldDelegate) =>
      oldDelegate.frame != frame || oldDelegate.markWidth != markWidth;
}

/// Parses SVG path data that uses only absolute M, L, Q and Z commands, as
/// the outlined wordmark does.
@visibleForTesting
Path parseOutline(String data) {
  final tokens = RegExp(
    r'[A-Za-z]|-?(?:\d+\.?\d*|\.\d+)',
  ).allMatches(data).map((match) => match[0]!).toList();
  final path = Path();
  var index = 0;
  double number() => double.parse(tokens[index++]);
  String? command;
  while (index < tokens.length) {
    if (RegExp('[A-Za-z]').hasMatch(tokens[index])) {
      command = tokens[index++];
    }
    switch (command) {
      case 'M':
        path.moveTo(number(), number());
        // Coordinate pairs after a moveto are linetos.
        command = 'L';
      case 'L':
        path.lineTo(number(), number());
      case 'Q':
        path.quadraticBezierTo(number(), number(), number(), number());
      case 'Z':
        path.close();
        command = null;
      default:
        throw FormatException('Unsupported path command', data, index);
    }
  }
  return path;
}

/// "drivon" in Hanken Grotesk Medium, converted to outlines (font units).
const String _wordmarkOutline =
    'M1071.30 552.31L1071.30 552.31Q1043.16 552.31 1022.58 538.24'
    'Q1002 524.17 990.45 499.60Q978.90 475.03 978.90 444.79'
    'L978.90 444.79Q978.90 411.61 991.29 387.67'
    'Q1003.68 363.73 1024.68 350.71Q1045.68 337.69 1071.30 337.69'
    'L1071.30 337.69Q1089.78 337.69 1105.11 345.25'
    'Q1120.44 352.81 1130.94 366.25L1130.94 366.25'
    'Q1133.04 369.19 1135.14 372.13L1135.14 372.13L1135.14 255.79'
    'L1175.88 255.79L1175.88 548.53L1135.14 548.53L1135.14 517.45'
    'Q1133.04 520.81 1130.94 523.33L1130.94 523.33'
    'Q1120.02 537.61 1104.69 544.96Q1089.36 552.31 1071.30 552.31Z'
    'M1079.70 514.51L1079.70 514.51Q1097.76 514.51 1110.99 505.69'
    'Q1124.22 496.87 1131.57 481.12Q1138.92 465.37 1138.92 444.79'
    'Q1138.92 424.21 1131.57 408.46Q1124.22 392.71 1110.99 384.10'
    'Q1097.76 375.49 1079.70 375.49L1079.70 375.49'
    'Q1062.06 375.49 1048.62 384.10Q1035.18 392.71 1027.83 408.46'
    'Q1020.48 424.21 1020.48 444.79Q1020.48 465.37 1027.83 481.12'
    'Q1035.18 496.87 1048.62 505.69Q1062.06 514.51 1079.70 514.51Z'
    'M1262.40 548.53L1220.82 548.53L1220.82 341.47L1262.40 341.47'
    'L1262.40 372.55Q1264.08 369.61 1266.60 366.67L1266.60 366.67'
    'Q1277.10 353.23 1291.80 345.46Q1306.50 337.69 1320.78 337.69'
    'L1320.78 337.69Q1330.86 337.69 1339.89 340'
    'Q1348.92 342.31 1358.16 347.77L1358.16 347.77L1338 384.73'
    'Q1333.38 382.21 1326.24 380.53Q1319.10 378.85 1312.80 378.85'
    'L1312.80 378.85Q1303.14 378.85 1293.90 382.21'
    'Q1284.66 385.57 1277.31 393.13Q1269.96 400.69 1266.18 412.87'
    'L1266.18 412.87Q1264.50 418.75 1263.45 428.20'
    'Q1262.40 437.65 1262.40 454.03L1262.40 454.03L1262.40 548.53Z'
    'M1422.42 548.53L1381.26 548.53L1381.26 341.47L1422.42 341.47'
    'L1422.42 548.53Z'
    'M1424.94 305.77L1378.32 305.77L1378.32 255.79L1424.94 255.79'
    'L1424.94 305.77Z'
    'M1565.64 548.53L1531.20 548.53L1446.36 341.47L1491.72 341.47'
    'L1548.00 495.19L1605.12 341.47L1649.64 341.47L1565.64 548.53Z'
    'M1760.94 552.31L1760.94 552.31Q1731.54 552.31 1708.44 538.45'
    'Q1685.34 524.59 1672.11 500.23Q1658.88 475.87 1658.88 444.79'
    'L1658.88 444.79Q1658.88 413.71 1671.90 389.56'
    'Q1684.92 365.41 1708.23 351.55Q1731.54 337.69 1760.94 337.69'
    'L1760.94 337.69Q1790.76 337.69 1813.44 351.55'
    'Q1836.12 365.41 1849.35 389.56Q1862.58 413.71 1862.58 444.79'
    'L1862.58 444.79Q1862.58 475.87 1849.35 500.02'
    'Q1836.12 524.17 1813.23 538.24Q1790.34 552.31 1760.94 552.31Z'
    'M1760.94 515.77L1760.94 515.77Q1779.42 515.77 1793.07 506.95'
    'Q1806.72 498.13 1814.07 482.17Q1821.42 466.21 1821.42 444.79'
    'L1821.42 444.79Q1821.42 422.95 1814.07 406.99'
    'Q1806.72 391.03 1793.07 382.42Q1779.42 373.81 1760.94 373.81'
    'L1760.94 373.81Q1742.04 373.81 1728.39 382.63'
    'Q1714.74 391.45 1707.39 407.20Q1700.04 422.95 1700.04 444.79'
    'L1700.04 444.79Q1700.04 466.21 1707.39 482.17'
    'Q1714.74 498.13 1728.39 506.95Q1742.04 515.77 1760.94 515.77Z'
    'M1939.02 548.53L1897.44 548.53L1897.44 341.47L1939.02 341.47'
    'L1939.02 370.45Q1942.38 364.99 1946.58 360.37L1946.58 360.37'
    'Q1956.66 349.45 1970.73 343.57Q1984.80 337.69 2001.18 337.69'
    'L2001.18 337.69Q2035.62 337.69 2055.15 357.64'
    'Q2074.68 377.59 2074.68 415.81L2074.68 415.81L2074.68 548.53'
    'L2033.52 548.53L2033.52 430.93Q2033.52 401.11 2022.81 387.25'
    'Q2012.10 373.39 1989.84 373.39L1989.84 373.39'
    'Q1973.04 373.39 1961.91 380.95Q1950.78 388.51 1944.90 404.89'
    'Q1939.02 421.27 1939.02 446.47L1939.02 446.47L1939.02 548.53Z';
