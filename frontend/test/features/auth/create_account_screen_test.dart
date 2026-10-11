import 'package:drivon/features/auth/presentation/create_account_screen.dart';
import 'package:drivon/features/auth/presentation/sign_in_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_app.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(
      ProviderScope(overrides: testOverrides(), child: localizedApp(screen)),
    );
    await tester.pumpAndSettle();
  }

  double fontSizeOf(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style!.fontSize!;

  testWidgets('the create-account title is a step smaller than sign-in', (
    tester,
  ) async {
    await pump(tester, const SignInScreen());
    expect(fontSizeOf(tester, 'Welcome back'), 36);

    await pump(tester, const CreateAccountScreen());
    expect(fontSizeOf(tester, 'Create your account'), 30);
  });
}
