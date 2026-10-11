import 'package:drivon/app/app.dart';
import 'package:drivon/core/errors/app_exception.dart';
import 'package:drivon/core/storage/token_store.dart';
import 'package:drivon/features/auth/presentation/session_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import '../../support/offline_fakes.dart';
import '../../support/test_app.dart';
import '../auth/auth_test_doubles.dart';
import '../vehicles/vehicle_test_doubles.dart';

void main() {
  late FakeAuthApi auth;
  late InMemoryTokenStore tokens;
  late InMemorySelectedVehicleStore selections;
  late InMemoryLocalStore localStore;
  late ProviderContainer container;

  /// Launches the app signed in and opens the profile from the Garage.
  Future<void> openProfile(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1236, 2745);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    container = ProviderContainer(
      overrides: testOverrides(
        authApi: auth,
        tokens: tokens,
        vehicleApi: FakeVehicleApi([vehicleDto()]),
        selections: selections,
        localStore: localStore,
      ),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const DrivonApp()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Profile'));
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label).first;

  FilledButton saveButton(WidgetTester tester) => tester.widget<FilledButton>(
    find.widgetWithText(FilledButton, 'Save changes'),
  );

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
  }

  Future<void> openDeleteDialog(WidgetTester tester) async {
    final button = find.widgetWithText(OutlinedButton, 'Delete account');
    await scrollTo(tester, button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  setUp(() {
    auth = FakeAuthApi();
    tokens = InMemoryTokenStore(
      const AuthTokens(accessToken: 'a', refreshToken: 'r'),
    );
    selections = InMemorySelectedVehicleStore()
      ..selections['user-1'] = 'vehicle-1';
    localStore = InMemoryLocalStore()..cache['user-1|/api/v1/vehicles'] = '[]';
  });

  testWidgets('opens as a page with the signed-in details', (tester) async {
    await openProfile(tester);

    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Rimaz Saththar'), findsWidgets);
    expect(find.text('rimaz@example.com'), findsWidgets);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('saves a changed name and email', (tester) async {
    await openProfile(tester);
    expect(saveButton(tester).onPressed, isNull);

    await tester.enterText(field('Your name'), '  Rimaz S ');
    await tester.enterText(field('Email'), 'New@Example.com');
    await tester.pump();
    expect(saveButton(tester).onPressed, isNotNull);
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(auth.lastProfileUpdate, {
      'name': 'Rimaz S',
      'email': 'New@Example.com',
    });
    expect(find.text('Profile saved'), findsOneWidget);
    expect(container.read(currentUserProvider)?.email, 'new@example.com');
    expect(saveButton(tester).onPressed, isNull);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Hello, Rimaz'), findsOneWidget);
  });

  testWidgets('shows a taken email under the field', (tester) async {
    auth.updateProfileResult = const ApiProblemException(
      statusCode: 409,
      code: ApiErrorCodes.emailAlreadyRegistered,
    );
    await openProfile(tester);

    await tester.enterText(field('Email'), 'taken@example.com');
    await tester.pump();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(
      find.text('Another account already uses this email.'),
      findsOneWidget,
    );
    expect(container.read(currentUserProvider)?.email, 'rimaz@example.com');
  });

  testWidgets('signs out from the profile', (tester) async {
    await openProfile(tester);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(container.read(sessionControllerProvider), isA<SignedOut>());
    expect(find.text('Welcome back'), findsOneWidget);
    expect(auth.loggedOutTokens, ['r']);
    expect(selections.selections, isEmpty);
    expect(localStore.cache, isEmpty);
  });

  testWidgets('keeps the account when the password is wrong', (tester) async {
    auth.deleteAccountError = const ApiProblemException(
      statusCode: 422,
      code: ApiErrorCodes.passwordIncorrect,
    );
    await openProfile(tester);
    await openDeleteDialog(tester);

    expect(find.text('Delete your account?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Delete account'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your password.'), findsOneWidget);
    expect(auth.deletionPasswords, isEmpty);

    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextFormField),
      ),
      'wrong-password',
    );
    await tester.tap(find.widgetWithText(TextButton, 'Delete account'));
    await tester.pumpAndSettle();

    expect(auth.deletionPasswords, ['wrong-password']);
    expect(find.text("That password isn't right. Try again."), findsOneWidget);
    expect(container.read(sessionControllerProvider), isA<SignedIn>());
    expect(tokens.tokens, isNotNull);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('deleting the account clears the phone and says so', (
    tester,
  ) async {
    await openProfile(tester);
    await openDeleteDialog(tester);

    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextFormField),
      ),
      'correct-horse',
    );
    await tester.tap(find.widgetWithText(TextButton, 'Delete account'));
    await tester.pumpAndSettle();

    expect(auth.deletionPasswords, ['correct-horse']);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(
      find.text('Your account and its data were deleted.'),
      findsOneWidget,
    );
    expect(tokens.tokens, isNull);
    expect(selections.selections, isEmpty);
    expect(localStore.cache, isEmpty);
    // The server deleted the account; there is no session left to revoke.
    expect(auth.loggedOutTokens, isEmpty);
  });
}
