import 'package:drivon/app/launch_intro.dart';
import 'package:drivon/design_system/design_system.dart';
import 'package:drivon/features/auth/presentation/session_controller.dart';
import 'package:drivon/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A session whose restore finishes only when the test says so.
class _ManualSession extends SessionController {
  _ManualSession(this._initial);

  final SessionState _initial;

  @override
  SessionState build() => _initial;

  void finishRestore() => state = const SignedOut();
}

void main() {
  late ProviderContainer container;
  late int taps;

  Future<void> launch(
    WidgetTester tester, {
    SessionState session = const SessionRestoring(),
  }) async {
    taps = 0;
    container = ProviderContainer(
      overrides: [
        sessionControllerProvider.overrideWith(() => _ManualSession(session)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: DrivonTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => LaunchIntro(child: child!),
          home: Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => taps++,
                child: const Text('Behind'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void finishRestore() =>
      (container.read(sessionControllerProvider.notifier) as _ManualSession)
          .finishRestore();

  testWidgets('starts on the empty canvas', (tester) async {
    await launch(tester);

    expect(find.byType(DrivonLogo), findsOneWidget);
    expect(find.byType(DrivonLogo), paintsNothing);
  });

  testWidgets('covers the app until the session is restored', (tester) async {
    await launch(tester);
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));

    expect(find.byType(DrivonLogo), findsOneWidget);

    finishRestore();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.byType(DrivonLogo), findsNothing);
    expect(find.text('Behind'), findsOneWidget);
  });

  testWidgets('plays the whole intro even when the session is ready early', (
    tester,
  ) async {
    await launch(tester, session: const SignedOut());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1600));

    expect(find.byType(DrivonLogo), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(DrivonLogo), findsNothing);
  });

  testWidgets('blocks touches to the app until it has finished', (
    tester,
  ) async {
    await launch(tester, session: const SignedOut());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('Behind'), warnIfMissed: false);
    expect(taps, 0);

    await tester.pumpAndSettle();
    await tester.tap(find.text('Behind'));
    expect(taps, 1);
  });

  testWidgets('hides the app from screen readers until it has finished', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await launch(tester, session: const SignedOut());
    await tester.pump();

    expect(find.bySemanticsLabel('Opening Drivon'), findsOneWidget);
    expect(find.bySemanticsLabel('Behind'), findsNothing);

    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Opening Drivon'), findsNothing);
    expect(find.bySemanticsLabel('Behind'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('keeps the app underneath mounted when it finishes', (
    tester,
  ) async {
    await launch(tester, session: const SignedOut());
    final before = tester.element(find.text('Behind'));

    await tester.pumpAndSettle();

    expect(tester.element(find.text('Behind')), same(before));
  });

  testWidgets('with reduced motion, only fades the logo in and out', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await launch(tester, session: const SignedOut());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    // The finished logo, already in place: nothing is drawn in.
    final logo = tester.widget<DrivonLogo>(find.byType(DrivonLogo));
    expect(logo.frame, DrivonLogoFrame.complete);

    await tester.pump(const Duration(milliseconds: 900));

    expect(find.byType(DrivonLogo), findsNothing);
  });
}
