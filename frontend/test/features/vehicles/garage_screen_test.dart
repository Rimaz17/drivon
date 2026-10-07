import 'package:drivon/app/app.dart';
import 'package:drivon/core/errors/app_exception.dart';
import 'package:drivon/core/storage/token_store.dart';
import 'package:drivon/features/auth/presentation/session_controller.dart';
import 'package:drivon/features/vehicles/presentation/widgets/vehicle_switcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import '../../support/test_app.dart';
import 'vehicle_test_doubles.dart';

void main() {
  late FakeVehicleApi api;
  late InMemorySelectedVehicleStore selections;
  late ProviderContainer container;

  /// Launches the whole app signed in, on a phone-sized screen.
  Future<void> launch(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1236, 2745);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    container = ProviderContainer(
      overrides: testOverrides(
        tokens: InMemoryTokenStore(
          const AuthTokens(accessToken: 'a', refreshToken: 'r'),
        ),
        vehicleApi: api,
        selections: selections,
      ),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const DrivonApp()),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    api = FakeVehicleApi();
    selections = InMemorySelectedVehicleStore();
  });

  testWidgets('invites a new user to add their first vehicle', (tester) async {
    await launch(tester);

    expect(find.text('Add your first vehicle'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Add vehicle'));
    await tester.pumpAndSettle();

    expect(find.text('Make'), findsOneWidget);
  });

  testWidgets('shows the vehicle with its odometer and details', (
    tester,
  ) async {
    api.vehicles.add(vehicleDto());
    await launch(tester);

    expect(find.text('Hello, Rimaz'), findsOneWidget);
    expect(find.text('CAB-1234'), findsOneWidget);
    expect(find.textContaining('45,000'), findsOneWidget);
    expect(find.text('Hybrid'), findsOneWidget);
    expect(find.text('Add another vehicle'), findsOneWidget);
    expect(find.byType(VehicleSwitcher), findsNothing);
  });

  testWidgets('switches between two vehicles and remembers the choice', (
    tester,
  ) async {
    api.vehicles.addAll([
      vehicleDto(),
      vehicleDto(
        id: 'vehicle-2',
        make: 'Honda',
        model: 'Dio',
        registrationNumber: 'BGH-4521',
        fuelType: 'PETROL',
        currentOdometerKm: 12000,
      ),
    ]);
    await launch(tester);

    expect(find.text('CAB-1234'), findsOneWidget);
    expect(
      find.text("You've added the maximum of two vehicles."),
      findsOneWidget,
    );

    await tester.tap(find.textContaining('Dio'));
    await tester.pumpAndSettle();

    expect(find.text('BGH-4521'), findsOneWidget);
    expect(find.textContaining('12,000'), findsOneWidget);
    expect(selections.selections['user-1'], 'vehicle-2');
  });

  testWidgets('offers a retry when vehicles fail to load', (tester) async {
    api.nextError = const NoConnectionException();
    await launch(tester);

    expect(find.text("Couldn't load your vehicles"), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Add your first vehicle'), findsOneWidget);
  });

  testWidgets('signs out from the account sheet', (tester) async {
    api.vehicles.add(vehicleDto());
    selections.selections['user-1'] = 'vehicle-1';
    await launch(tester);

    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    expect(find.text('rimaz@example.com'), findsOneWidget);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(container.read(sessionControllerProvider), isA<SignedOut>());
    expect(find.text('Welcome back'), findsOneWidget);
    expect(selections.selections, isEmpty);
  });
}
