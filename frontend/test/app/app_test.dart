import 'package:drivon/app/app.dart';
import 'package:drivon/core/storage/token_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/test_app.dart';

void main() {
  testWidgets('a new user lands on sign-in', (tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: testOverrides(), child: const DrivonApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('a returning user goes straight to the app', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides(
          tokens: InMemoryTokenStore(
            const AuthTokens(accessToken: 'a', refreshToken: 'r'),
          ),
        ),
        child: const DrivonApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsNothing);
    expect(find.text('Drivon'), findsOneWidget);
  });
}
