import 'package:drivon/core/storage/token_store.dart';
import 'package:drivon/core/utils/fixed_decimal.dart';
import 'package:drivon/features/auth/presentation/session_controller.dart';
import 'package:drivon/features/expenses/data/expense_repository.dart';
import 'package:drivon/features/expenses/domain/expense.dart';
import 'package:drivon/features/expenses/presentation/expense_controllers.dart';
import 'package:drivon/features/fuel/presentation/fuel_controllers.dart';
import 'package:drivon/features/maintenance/domain/maintenance_record.dart';
import 'package:drivon/features/maintenance/presentation/maintenance_controllers.dart';
import 'package:drivon/features/vehicles/presentation/vehicles_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import '../../support/test_app.dart';
import '../fuel/fuel_test_doubles.dart';
import '../maintenance/maintenance_test_doubles.dart';
import '../vehicles/vehicle_test_doubles.dart';
import 'expense_test_doubles.dart';

void main() {
  late FakeMaintenanceApi maintenance;
  late FakeExpenseApi expenses;
  late FakeVehicleApi vehicles;
  late ProviderContainer container;
  const summaryKey = (vehicleId: 'vehicle-1', period: SpendingPeriod.thisMonth);

  Future<void> signedIn() async {
    container = ProviderContainer(
      overrides: testOverrides(
        tokens: InMemoryTokenStore(
          const AuthTokens(accessToken: 'a', refreshToken: 'r'),
        ),
        vehicleApi: vehicles,
        maintenanceApi: maintenance,
        expenseApi: expenses,
      ),
    );
    addTearDown(container.dispose);
    container.read(sessionControllerProvider);
    await pumpEventQueue();
    container
      ..listen(spendingSummaryProvider(summaryKey), (_, _) {})
      ..listen(vehiclesControllerProvider, (_, _) {});
    await container.read(spendingSummaryProvider(summaryKey).future);
    await container.read(vehiclesControllerProvider.future);
  }

  setUp(() {
    maintenance = FakeMaintenanceApi([
      maintenanceRecord(),
      maintenanceRecord(id: 'service-2', serviceType: ServiceType.brakeService),
    ]);
    expenses = FakeExpenseApi([expense()]);
    vehicles = FakeVehicleApi([vehicleDto()]);
  });

  test('the service history can be filtered by type', () async {
    await signedIn();

    final brakes = await container.read(
      maintenanceHistoryProvider((
        vehicleId: 'vehicle-1',
        type: ServiceType.brakeService,
      )).future,
    );

    expect(brakes.items.single.id, 'service-2');
    expect(maintenance.listedTypes.last, ServiceType.brakeService);
  });

  test('a new service refreshes spending and the vehicle', () async {
    await signedIn();
    final summaries = expenses.summaryCalls;
    final vehicleLists = vehicles.listCalls;

    await container
        .read(maintenanceMutationsProvider)
        .add(
          'vehicle-1',
          MaintenanceDraft(
            serviceType: ServiceType.tyreRotation,
            date: DateTime(2026, 10, 7),
            cost: FixedDecimal.parse('2500', scale: 2),
          ),
        );
    await container.read(spendingSummaryProvider(summaryKey).future);
    await pumpEventQueue();

    expect(expenses.summaryCalls, summaries + 1);
    expect(vehicles.listCalls, vehicleLists + 1);
    expect(maintenance.records.first.serviceType, ServiceType.tyreRotation);
  });

  test('a new fill-up refreshes spending too', () async {
    await signedIn();
    final summaries = expenses.summaryCalls;

    await container.read(fuelMutationsProvider).add('vehicle-1', fuelDraft());
    await container.read(spendingSummaryProvider(summaryKey).future);

    expect(expenses.summaryCalls, summaries + 1);
  });

  test('expenses can be added, edited and removed', () async {
    await signedIn();
    final mutations = container.read(expenseMutationsProvider);
    final draft = ExpenseDraft(
      category: ExpenseCategory.parking,
      amount: FixedDecimal.parse('200', scale: 2),
      date: DateTime(2026, 10, 7),
    );

    await mutations.add('vehicle-1', draft);
    expect(expenses.expenses.first.category, ExpenseCategory.parking);

    final id = expenses.expenses.first.id;
    await mutations.edit('vehicle-1', id, draft.copyWith(notes: 'Mall'));
    expect(expenses.expenses.first.notes, 'Mall');

    await mutations.remove('vehicle-1', id);
    expect(expenses.expenses, hasLength(1));
  });

  test('the period picks the summary start date', () async {
    await signedIn();
    container
        .read(spendingPeriodProvider.notifier)
        .select(SpendingPeriod.allTime);

    await container.read(
      spendingSummaryProvider((
        vehicleId: 'vehicle-1',
        period: container.read(spendingPeriodProvider),
      )).future,
    );

    expect(expenses.summaryStarts.first, isNotNull);
    expect(expenses.summaryStarts.last, isNull);
  });
}
