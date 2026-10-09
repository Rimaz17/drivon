import 'package:drivon/app/app.dart';
import 'package:drivon/core/errors/app_exception.dart';
import 'package:drivon/core/storage/token_store.dart';
import 'package:drivon/features/analytics/domain/analytics.dart';
import 'package:drivon/features/expenses/domain/expense.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import '../../support/test_app.dart';
import '../expenses/expense_test_doubles.dart';
import '../vehicles/vehicle_test_doubles.dart';
import 'analytics_test_doubles.dart';

void main() {
  late FakeAnalyticsApi analytics;
  late FakeVehicleApi vehicles;
  late FakeExpenseApi expenses;

  Future<void> openInsights(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1236, 2745);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: testOverrides(
        tokens: InMemoryTokenStore(
          const AuthTokens(accessToken: 'a', refreshToken: 'r'),
        ),
        vehicleApi: vehicles,
        analyticsApi: analytics,
        expenseApi: expenses,
      ),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const DrivonApp()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Insights').last);
    await tester.pumpAndSettle();
  }

  Future<void> scrollTo(WidgetTester tester, Finder finder) =>
      tester.scrollUntilVisible(
        finder,
        300,
        scrollable: find.byType(Scrollable).last,
      );

  setUp(() {
    analytics = FakeAnalyticsApi();
    vehicles = FakeVehicleApi([vehicleDto()]);
    expenses = FakeExpenseApi();
  });

  testWidgets('leads with the running cost per km and its parts', (
    tester,
  ) async {
    analytics.costResponse = runningCost(
      distanceKm: 800,
      fuel: '20075',
      maintenance: '9800',
      other: '45000',
    );
    await openInsights(tester);

    expect(find.text('Rs. 93.59'), findsOneWidget);
    expect(find.text('Rs. 74,875 over 800 km'), findsOneWidget);
    Finder legend(String text) => find.text(text, findRichText: true);
    expect(legend('Fuel Rs. 25.09 / km'), findsOneWidget);
    expect(legend('Maintenance Rs. 12.25 / km'), findsOneWidget);
    expect(legend('Other Rs. 56.25 / km'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Per km: fuel Rs. 25.09, maintenance Rs. 12.25, other Rs. 56.25',
      ),
      findsOneWidget,
    );
  });

  testWidgets('explains a cost without distance instead of a figure', (
    tester,
  ) async {
    analytics.costResponse = runningCost(distanceKm: 0, other: '45000');
    await openInsights(tester);

    expect(
      find.text(
        'Rs. 45,000 spent. Log odometer readings, fill-ups or services to '
        'see the cost per km.',
      ),
      findsOneWidget,
    );
    expect(find.text('Other Rs. 45,000', findRichText: true), findsOneWidget);
  });

  testWidgets('a new vehicle is told what to log first', (tester) async {
    await openInsights(tester);

    expect(
      find.text(
        'Log fill-ups, services and expenses to see what this vehicle costs '
        'per km.',
      ),
      findsOneWidget,
    );
    await scrollTo(tester, find.text('Shown after two full-tank fill-ups.'));
    expect(
      find.text('Nothing logged in the last 6 months yet.'),
      findsOneWidget,
    );
    expect(
      find.text('Shown once two months have both costs and distance.'),
      findsOneWidget,
    );
  });

  testWidgets('switching the period reloads the figures for it', (
    tester,
  ) async {
    await openInsights(tester);
    final today = DateTime.now();
    expect(analytics.costStarts.last, DateTime(today.year));

    await tester.tap(find.text('This month'));
    await tester.pumpAndSettle();
    expect(analytics.costStarts.last, DateTime(today.year, today.month));

    await tester.tap(find.text('All time'));
    await tester.pumpAndSettle();
    expect(analytics.costStarts.last, isNull);
  });

  testWidgets('shows each category with its share of the total', (
    tester,
  ) async {
    expenses.summaryResponse = spendingSummary({
      ExpenseCategory.fuel: '30000',
      ExpenseCategory.insurance: '10000',
    });
    await openInsights(tester);

    await scrollTo(tester, find.text('Where the money goes'));
    expect(find.text('Rs. 30,000 · 75%'), findsOneWidget);
    expect(find.text('Rs. 10,000 · 25%'), findsOneWidget);
  });

  testWidgets('compares vehicles only when there are two', (tester) async {
    vehicles = FakeVehicleApi([
      vehicleDto(),
      vehicleDto(
        id: 'vehicle-2',
        make: 'Honda',
        model: 'Dio',
        registrationNumber: 'BGH-4521',
        fuelType: 'PETROL',
      ),
    ]);
    analytics.comparisonResponse = [
      VehicleCost(
        vehicleId: 'vehicle-1',
        make: 'Toyota',
        model: 'Aqua',
        registrationNumber: 'CAB-1234',
        distanceKm: 1000,
        totalCost: money('32000'),
        costPerKm: money('32.00'),
        breakdown: breakdown('32000', '0', '0'),
        averageKmPerLitre: money('19.40'),
      ),
      VehicleCost(
        vehicleId: 'vehicle-2',
        make: 'Honda',
        model: 'Dio',
        registrationNumber: 'BGH-4521',
        distanceKm: 1000,
        totalCost: money('8000'),
        costPerKm: money('8.00'),
        breakdown: breakdown('8000', '0', '0'),
      ),
    ];
    await openInsights(tester);

    await scrollTo(tester, find.text('Vehicles compared'));
    await scrollTo(tester, find.text('Honda Dio'));
    expect(find.text('Rs. 32.00 / km'), findsOneWidget);
    expect(find.text('Rs. 8.00 / km'), findsOneWidget);
    expect(find.text('CAB-1234 · 1,000 km · 19.40 km/L'), findsOneWidget);
    expect(find.text('BGH-4521 · 1,000 km'), findsOneWidget);
  });

  testWidgets('one vehicle has nothing to compare', (tester) async {
    await openInsights(tester);

    await scrollTo(tester, find.text('Where the money goes'));
    expect(find.text('Vehicles compared'), findsNothing);
  });

  testWidgets('shows an error with a retry when the figures fail', (
    tester,
  ) async {
    analytics.nextError = const NoConnectionException();
    await openInsights(tester);

    expect(find.text("Couldn't load insights"), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Running cost'), findsOneWidget);
  });

  testWidgets('a group without distance shows its total instead', (
    tester,
  ) async {
    analytics.costResponse = CostPerKm(
      distanceKm: 0,
      totalCost: money('9800'),
      breakdown: breakdown('0', '9800', '0'),
    );
    await openInsights(tester);

    expect(
      find.text('Maintenance Rs. 9,800', findRichText: true),
      findsOneWidget,
    );
  });
}
