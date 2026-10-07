import 'package:drivon/core/errors/app_exception.dart';
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
