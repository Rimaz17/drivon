import 'dart:async';

import 'package:drivon/core/errors/app_exception.dart';
import 'package:drivon/core/storage/token_store.dart';
import 'package:drivon/design_system/design_system.dart';
import 'package:drivon/features/auth/presentation/session_controller.dart';
import 'package:drivon/features/vehicles/presentation/vehicle_form_screen.dart';
import 'package:drivon/features/vehicles/presentation/vehicles_controller.dart';
import 'package:drivon/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fakes.dart';
import '../../support/test_app.dart';
import 'vehicle_test_doubles.dart';

void main() {
  late FakeVehicleApi api;
  late ProviderContainer container;

  /// Opens the form on top of a stub home route so the screen can pop.
  Future<void> openForm(WidgetTester tester, String location) async {
    // A typical phone viewport (412 x 915 logical pixels).
    tester.view.physicalSize = const Size(1236, 2745);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    container = ProviderContainer(
      overrides: testOverrides(
        tokens: InMemoryTokenStore(
          const AuthTokens(accessToken: 'a', refreshToken: 'r'),
        ),
        vehicleApi: api,
      ),
    );
    addTearDown(container.dispose);
    container.read(sessionControllerProvider);
    await tester.pumpAndSettle();
    await container.read(vehiclesControllerProvider.future);

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('Garage')),
        ),
        GoRoute(path: '/new', builder: (_, _) => const VehicleFormScreen()),
        GoRoute(
          path: '/edit/:id',
          builder: (_, state) =>
              VehicleFormScreen(vehicleId: state.pathParameters['id']),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: DrivonTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    unawaited(router.push(location));
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  Future<void> fillValidVehicle(WidgetTester tester) async {
    await tester.enterText(field('Make'), 'Honda');
    await tester.enterText(field('Model'), 'Dio');
    await tester.enterText(field('Model year'), '2021');
    await tester.enterText(field('Registration number'), 'bgh-4521');
    await tester.tap(find.text('Petrol'));
    await tester.enterText(field('Current odometer'), '12000');
  }

  Future<void> tapButton(WidgetTester tester, String label) async {
    final button = find.widgetWithText(FilledButton, label);
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  setUp(() => api = FakeVehicleApi([vehicleDto()]));

  testWidgets('shows every missing field before contacting the server', (
    tester,
  ) async {
    await openForm(tester, '/new');

    await tapButton(tester, 'Add vehicle');

    expect(find.text('Enter the make.'), findsOneWidget);
    expect(find.text('Choose a fuel type.'), findsOneWidget);
    expect(api.vehicles, hasLength(1));
  });

  testWidgets('adds a vehicle, selects it and returns to the garage', (
    tester,
  ) async {
    await openForm(tester, '/new');

    await fillValidVehicle(tester);
    await tapButton(tester, 'Add vehicle');

    expect(api.vehicles, hasLength(2));
    expect(container.read(selectedVehicleProvider)?.model, 'Dio');
    expect(find.text('Garage'), findsOneWidget);
    expect(find.text('Vehicle added'), findsOneWidget);
  });

  testWidgets('shows a duplicate plate under the registration field', (
    tester,
  ) async {
    await openForm(tester, '/new');
    api.nextError = const ApiProblemException(
      statusCode: 409,
      code: ApiErrorCodes.registrationNumberInUse,
    );

    await fillValidVehicle(tester);
    await tapButton(tester, 'Add vehicle');

    expect(
      find.text('You already have a vehicle with this registration number.'),
      findsOneWidget,
    );
    expect(find.text('Garage'), findsNothing);
  });

  testWidgets('editing blocks an odometer below the saved reading', (
    tester,
  ) async {
    await openForm(tester, '/edit/vehicle-1');

    expect(find.text('Toyota'), findsOneWidget);
    await tester.enterText(field('Current odometer'), '40000');
    await tapButton(tester, 'Save changes');

    expect(
      find.text("Can't be lower than 45,000 km, the last saved reading."),
      findsOneWidget,
    );
  });

  testWidgets('deletes only after confirmation', (tester) async {
    await openForm(tester, '/edit/vehicle-1');

    await tester.tap(find.byTooltip('Delete vehicle'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Toyota Aqua?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(api.vehicles, hasLength(1));

    await tester.tap(find.byTooltip('Delete vehicle'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(api.vehicles, isEmpty);
    expect(find.text('Garage'), findsOneWidget);
  });
}
