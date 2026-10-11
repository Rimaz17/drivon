import 'package:drivon/design_system/design_system.dart';
import 'package:drivon/design_system/tokens/drivon_palette.dart';
import 'package:drivon/design_system/widgets/drivon_logo.dart'
    show parseOutline;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(DrivonLogoFrame frame) => Directionality(
  textDirection: TextDirection.ltr,
  child: DrivonLogo(frame: frame),
);

void main() {
  group('DrivonLogo', () {
    testWidgets('paints the spokes, then the hub, rim and wordmark on top', (
      tester,
    ) async {
      await tester.pumpWidget(_host(DrivonLogoFrame.complete));

      expect(
        find.byType(DrivonLogo),
        paints
          ..line(color: DrivonPalette.ink50, strokeWidth: 5)
          ..line(color: DrivonPalette.ink50, strokeWidth: 5)
          ..line(color: DrivonPalette.ink50, strokeWidth: 5)
          ..circle(x: 0, y: 0, radius: 7, color: DrivonPalette.violetLight)
          ..path()
          ..path(color: DrivonPalette.ink50),
      );
    });

    testWidgets('paints nothing on an empty frame', (tester) async {
      await tester.pumpWidget(_host(DrivonLogoFrame.empty));

      expect(find.byType(DrivonLogo), paintsNothing);
    });

    testWidgets('clips the rim while it is being revealed', (tester) async {
      await tester.pumpWidget(
        _host(
          const DrivonLogoFrame(
            rimReveal: 0.5,
            hubOpacity: 0,
            spokesReveal: 0,
            stemReveal: 0,
            wordmarkOpacity: 0,
          ),
        ),
      );

      expect(
        find.byType(DrivonLogo),
        paints
          ..clipPath()
          ..path(),
      );
    });

    testWidgets('scales the hub about its centre', (tester) async {
      await tester.pumpWidget(_host(const DrivonLogoFrame(hubScale: 0.6)));

      expect(
        find.byType(DrivonLogo),
        paints..circle(x: 0, y: 0, radius: 7 * 0.6),
      );
    });

    testWidgets('draws the idle highlight inside the rim', (tester) async {
      await tester.pumpWidget(
        _host(
          const DrivonLogoFrame(highlightPosition: 0.5, highlightOpacity: 1),
        ),
      );

      // Three soft layers, clipped to the rim outline.
      expect(
        find.byType(DrivonLogo),
        paints
          ..clipPath()
          ..arc(strokeWidth: 10)
          ..arc(strokeWidth: 10)
          ..arc(strokeWidth: 10),
      );
    });

    testWidgets('leaves out highlight layers that are off the rim', (
      tester,
    ) async {
      // At -0.5 every layer ends before the rim starts.
      await tester.pumpWidget(
        _host(
          const DrivonLogoFrame(highlightPosition: -0.5, highlightOpacity: 1),
        ),
      );

      expect(find.byType(DrivonLogo), isNot(paints..arc()));
    });
  });

  group('DrivonLogoFrame', () {
    test('compares by value', () {
      expect(
        const DrivonLogoFrame(rimReveal: 0.5),
        const DrivonLogoFrame(rimReveal: 0.5),
      );
      expect(
        const DrivonLogoFrame(rimReveal: 0.5).hashCode,
        const DrivonLogoFrame(rimReveal: 0.5).hashCode,
      );
      expect(
        const DrivonLogoFrame(rimReveal: 0.5),
        isNot(const DrivonLogoFrame(rimReveal: 0.6)),
      );
    });

    test('is invisible when empty or fully faded', () {
      expect(DrivonLogoFrame.complete.isVisible, isTrue);
      expect(DrivonLogoFrame.empty.isVisible, isFalse);
      expect(const DrivonLogoFrame(opacity: 0).isVisible, isFalse);
    });
  });

  test('the painter repaints only when the frame changes', () {
    const painter = DrivonLogoPainter(frame: DrivonLogoFrame.complete);

    expect(
      painter.shouldRepaint(
        const DrivonLogoPainter(frame: DrivonLogoFrame.complete),
      ),
      isFalse,
    );
    expect(
      painter.shouldRepaint(
        const DrivonLogoPainter(frame: DrivonLogoFrame.empty),
      ),
      isTrue,
    );
  });

  group('parseOutline', () {
    test('reads absolute move, line, quadratic and close commands', () {
      final path = parseOutline('M0 0L10 0Q10 10 0 10ZM20 20L30 30Z');

      expect(path.getBounds(), const Rect.fromLTRB(0, 0, 30, 30));
      expect(path.computeMetrics().length, 2);
    });

    test('rejects commands the wordmark does not use', () {
      expect(() => parseOutline('M0 0C1 1 2 2 3 3'), throwsFormatException);
    });
  });
}
