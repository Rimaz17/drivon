import 'package:drivon/core/errors/app_exception.dart';
import 'package:drivon/design_system/design_system.dart';
import 'package:drivon/features/auth/presentation/session_controller.dart';
import 'package:drivon/features/auth/presentation/sign_in_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_app.dart';
import 'auth_test_doubles.dart';

void main() {
  late FakeAuthApi api;
  late ProviderContainer container;

  Future<void> pumpSignIn(WidgetTester tester) async {
    container = ProviderContainer(overrides: testOverrides(authApi: api));
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedApp(const SignInScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  setUp(() => api = FakeAuthApi());

  testWidgets('shows the logo instead of the app name in text', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpSignIn(tester);

    expect(find.byType(DrivonLogo), findsOneWidget);
    expect(find.text('Drivon'), findsNothing);
    expect(find.bySemanticsLabel('Drivon'), findsOneWidget);
    handle.dispose();
  });

  /// How far the screen scrolls (the first scrollable is the screen's own;
  /// text fields have their own inside it).
  double maxScroll(WidgetTester tester) => tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position
      .maxScrollExtent;

  testWidgets('fits a phone screen without scrolling', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.8125;
    addTearDown(tester.view.reset);
    await pumpSignIn(tester);

    expect(maxScroll(tester), 0);
    // The logo sits above the heading, the form below it.
    expect(
      tester.getBottomLeft(find.byType(DrivonLogo)).dy,
      lessThan(tester.getTopLeft(find.text('Welcome back')).dy),
    );
  });

  testWidgets('scrolls rather than overflowing on a short screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await pumpSignIn(tester);

    expect(tester.takeException(), isNull);
    expect(maxScroll(tester), greaterThan(0));
  });

  testWidgets('validates the form before calling the server', (tester) async {
    await pumpSignIn(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();

    expect(find.text('Enter your email.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
    expect(api.lastLogin, isNull);
  });

  testWidgets('signs in with the entered credentials', (tester) async {
    await pumpSignIn(tester);

    await tester.enterText(field('Email'), 'rimaz@example.com');
    await tester.enterText(field('Password'), 'secret-pass');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(api.lastLogin, {
      'email': 'rimaz@example.com',
      'password': 'secret-pass',
    });
    expect(container.read(sessionControllerProvider), isA<SignedIn>());
  });

  testWidgets('explains wrong credentials without clearing the form', (
    tester,
  ) async {
    api.loginResult = const ApiProblemException(
      statusCode: 401,
      code: ApiErrorCodes.invalidCredentials,
    );
    await pumpSignIn(tester);

    await tester.enterText(field('Email'), 'rimaz@example.com');
    await tester.enterText(field('Password'), 'wrong-pass');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.textContaining("don't match"), findsOneWidget);
    expect(find.text('rimaz@example.com'), findsOneWidget);
  });

  testWidgets('toggles password visibility', (tester) async {
    await pumpSignIn(tester);

    expect(find.byTooltip('Show password'), findsOneWidget);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(find.byTooltip('Hide password'), findsOneWidget);
  });
}
