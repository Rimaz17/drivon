import 'package:drivon/app/app.dart';
import 'package:drivon/core/errors/app_exception.dart';
import 'package:drivon/core/storage/token_store.dart';
import 'package:drivon/features/auth/presentation/session_controller.dart';
import 'package:drivon/features/expenses/domain/expense.dart';
import 'package:drivon/features/maintenance/domain/maintenance_record.dart';
import 'package:drivon/features/vehicles/presentation/widgets/vehicle_switcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import '../../support/test_app.dart';
import '../expenses/expense_test_doubles.dart';
import '../fuel/fuel_test_doubles.dart';
import '../maintenance/maintenance_test_doubles.dart';
import 'vehicle_test_doubles.dart';

void main() {
  late FakeVehicleApi api;
  late FakeFuelApi fuel;
  late FakeMaintenanceApi maintenance;
  late FakeExpenseApi expenses;
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
        fuelApi: fuel,
        maintenanceApi: maintenance,
        expenseApi: expenses,
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
    fuel = FakeFuelApi();
    maintenance = FakeMaintenanceApi();
    expenses = FakeExpenseApi();
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
    await tester.scrollUntilVisible(find.text('Add another vehicle'), 200);
    expect(find.text('Hybrid'), findsOneWidget);
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
    await tester.scrollUntilVisible(
      find.text("You've added the maximum of two vehicles."),
      200,
    );
    await tester.scrollUntilVisible(find.textContaining('Dio'), -200);
    // Scrolling back can stop with the switcher partly under the app bar.
    await tester.ensureVisible(find.textContaining('Dio'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Dio'));
    await tester.pumpAndSettle();

    expect(find.text('BGH-4521'), findsOneWidget);
    expect(find.textContaining('12,000'), findsOneWidget);
    expect(selections.selections['user-1'], 'vehicle-2');
  });

  testWidgets('shows efficiency, cost, next service and monthly spend', (
    tester,
  ) async {
    api.vehicles.add(vehicleDto());
    fuel.statsResponse = fuelStatsDto(
      fillUps: 3,
      averageKmPerLitre: '21.40',
      costPerKm: '17.06',
    );
    maintenance.upcomingResponse = [
      UpcomingService(
        serviceType: ServiceType.oilChange,
        recordId: 'service-1',
        lastServicedOn: DateTime(2026, 10, 7),
        dueKm: 51500,
        kmRemaining: 5000,
        overdue: false,
      ),
    ];
    expenses.summaryResponse = spendingSummary({ExpenseCategory.fuel: '18500'});
    await launch(tester);

    await tester.scrollUntilVisible(find.text('Spent this month'), 200);
    expect(find.textContaining('21.40'), findsOneWidget);
    expect(find.textContaining('17.06'), findsOneWidget);
    expect(find.text('Oil change due in 5,000 km'), findsOneWidget);
    expect(find.text('Rs. 18,500'), findsOneWidget);
  });

  testWidgets('explains what is missing before any records exist', (
    tester,
  ) async {
    api.vehicles.add(vehicleDto());
    await launch(tester);

    expect(find.text('After two full fill-ups'), findsNWidgets(2));
    await tester.scrollUntilVisible(
      find.text('Log a service to see when the next one is due.'),
      200,
    );
    await tester.tap(
      find.text('Log a service to see when the next one is due.'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Log service'), findsWidgets);
  });

  testWidgets('opens the Fuel tab from the efficiency tile', (tester) async {
    api.vehicles.add(vehicleDto());
    await launch(tester);

    await tester.tap(find.text('Average'));
    await tester.pumpAndSettle();

    expect(find.text('Log your first fill-up'), findsOneWidget);
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
