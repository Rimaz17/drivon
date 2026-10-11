import 'package:drivon/app/launch_timeline.dart';
import 'package:drivon/design_system/design_system.dart';
import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const timeline = LaunchTimeline(reduceMotion: false);
  const reduced = LaunchTimeline(reduceMotion: true);
  const curve = Cubic(0.33, 1, 0.68, 1);

  DrivonLogoFrame logoAt(double t, {double? readyAt = 0}) =>
      timeline.frameAt(t, readyAt: readyAt).logo;

  group('intro', () {
    test('starts on the empty canvas, like the native launch screen', () {
      final frame = timeline.frameAt(0, readyAt: null);

      expect(frame.logo.isVisible, isFalse);
      expect(frame.canvasOpacity, 1);
    });

    test('sweeps the rim in from 150 to 600 ms', () {
      expect(logoAt(150).rimReveal, 0);
      expect(logoAt(375).rimReveal, closeTo(curve.transform(0.5), 1e-9));
      expect(logoAt(600).rimReveal, 1);
    });

    test('grows the hub from 60% between 250 and 500 ms', () {
      expect(logoAt(250).hubOpacity, 0);
      expect(logoAt(250).hubScale, 0.6);
      expect(logoAt(500).hubOpacity, 1);
      expect(logoAt(500).hubScale, 1);
    });

    test('grows all spokes out from the hub between 450 and 700 ms', () {
      expect(logoAt(450).spokesReveal, 0);
      expect(logoAt(450).stemReveal, 0);
      expect(logoAt(575).spokesReveal, logoAt(575).stemReveal);
      expect(logoAt(700).spokesReveal, 1);
      expect(logoAt(700).stemReveal, 1);
    });

    test('raises the wordmark 8 px into place between 750 and 1200 ms', () {
      expect(logoAt(750).wordmarkOpacity, 0);
      expect(logoAt(750).wordmarkDrop, 8);
      expect(logoAt(1200).wordmarkOpacity, 1);
      expect(logoAt(1200).wordmarkDrop, 0);
    });

    test('eases out on the spec curve, not Curves.easeOutCubic', () {
      final halfway = logoAt(975).wordmarkOpacity;

      expect(halfway, closeTo(curve.transform(0.5), 1e-9));
      expect(halfway, isNot(closeTo(Curves.easeOutCubic.transform(0.5), 1e-3)));
    });

    test('ends on the complete logo', () {
      expect(logoAt(1200), DrivonLogoFrame.complete);
    });
  });

  group('when loading finishes during the intro', () {
    test('holds the logo for 150 ms, then exits by 1600 ms', () {
      expect(timeline.exitStart(300), 1350);
      expect(logoAt(1350), DrivonLogoFrame.complete);

      final exited = logoAt(1600);
      expect(exited.opacity, 0);
      expect(exited.scale, closeTo(0.94, 1e-9));
    });

    test('shows no idle highlight', () {
      expect(logoAt(1300, readyAt: 1200).highlightOpacity, 0);
    });

    test('fades the canvas to reveal the app and then finishes', () {
      expect(timeline.frameAt(1600, readyAt: 0).canvasOpacity, 1);
      expect(timeline.frameAt(1750, readyAt: 0).canvasOpacity, 0);
      expect(timeline.isFinished(1749, readyAt: 0), isFalse);
      expect(timeline.isFinished(1750, readyAt: 0), isTrue);
    });
  });

  group('when loading outlasts the intro', () {
    test('keeps the logo up while loading', () {
      expect(timeline.exitStart(null), isNull);
      expect(timeline.isFinished(60000, readyAt: null), isFalse);
      expect(logoAt(60000, readyAt: null).opacity, 1);
    });

    test('runs a highlight along the rim every 2.8 s', () {
      final early = logoAt(1200 + 600, readyAt: null);
      final nextCycle = logoAt(1200 + 2800 + 600, readyAt: null);

      expect(early.highlightOpacity, greaterThan(0));
      expect(
        nextCycle.highlightPosition,
        closeTo(early.highlightPosition, 1e-9),
      );
      expect(nextCycle.highlightOpacity, closeTo(early.highlightOpacity, 1e-9));
    });

    test(
      'hides the highlight at the ends of each cycle, so it loops cleanly',
      () {
        expect(logoAt(1200, readyAt: null).highlightOpacity, 0);
        expect(logoAt(1200 + 2520, readyAt: null).highlightOpacity, 0);
        expect(logoAt(1200 + 2700, readyAt: null).highlightOpacity, 0);
      },
    );

    test('moves the highlight from before the rim to its far end', () {
      expect(logoAt(1200, readyAt: null).highlightPosition, -0.5);
      expect(
        logoAt(1200 + 2519.9, readyAt: null).highlightPosition,
        closeTo(1, 1e-3),
      );
    });

    test('exits as soon as loading finishes, fading the highlight out', () {
      const readyAt = 2000.0;

      expect(timeline.exitStart(readyAt), readyAt);
      expect(
        logoAt(readyAt, readyAt: readyAt).highlightOpacity,
        greaterThan(0),
      );
      expect(logoAt(readyAt + 150, readyAt: readyAt).highlightOpacity, 0);
      expect(logoAt(readyAt + 250, readyAt: readyAt).opacity, 0);
      expect(timeline.isFinished(readyAt + 400, readyAt: readyAt), isTrue);
    });

    test('still holds the finished logo for 150 ms after the intro', () {
      expect(timeline.exitStart(1250), 1350);
    });
  });

  group('with reduced motion', () {
    test('only fades the finished logo in, over 250 ms', () {
      final start = reduced.frameAt(0, readyAt: null).logo;
      final shown = reduced.frameAt(250, readyAt: null).logo;

      expect(start.opacity, 0);
      expect(shown, DrivonLogoFrame.complete);
    });

    test('never moves, scales or highlights the logo', () {
      for (final t in [100.0, 900.0, 5000.0, 5100.0]) {
        final logo = reduced.frameAt(t, readyAt: 5000).logo;
        expect(logo.scale, 1);
        expect(logo.wordmarkDrop, 0);
        expect(logo.hubScale, 1);
        expect(logo.highlightOpacity, 0);
      }
    });

    test('holds for 450 ms, then fades out and finishes', () {
      expect(reduced.exitStart(0), 700);
      expect(reduced.frameAt(950, readyAt: 0).logo.opacity, 0);
      expect(reduced.isFinished(1100, readyAt: 0), isTrue);
    });

    test('waits for loading before fading out', () {
      expect(reduced.exitStart(3000), 3000);
      expect(reduced.frameAt(2999, readyAt: 3000).logo.opacity, 1);
    });
  });
}
