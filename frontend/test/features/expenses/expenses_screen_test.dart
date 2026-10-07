import 'package:drivon/app/app.dart';
import 'package:drivon/core/errors/app_exception.dart';
import 'package:drivon/core/storage/token_store.dart';
import 'package:drivon/core/utils/fixed_decimal.dart';
import 'package:drivon/features/expenses/domain/expense.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import '../../support/test_app.dart';
import '../vehicles/vehicle_test_doubles.dart';
import 'expense_test_doubles.dart';

void main() {
  late FakeExpenseApi expenses;
  late FakeVehicleApi vehicles;

  Future<void> openExpensesTab(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1236, 2745);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: testOverrides(
        tokens: InMemoryTokenStore(
          const AuthTokens(accessToken: 'a', refreshToken: 'r'),
        ),
        vehicleApi: vehicles,
        expenseApi: expenses,
      ),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const DrivonApp()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Expenses').last);
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  /// Scrolls the tab to its end, where the list's bottom padding keeps the
  /// last row clear of the floating button.
  Future<void> scrollToEnd(WidgetTester tester) async {
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
    await tester.pumpAndSettle();
  }

  setUp(() {
    expenses = FakeExpenseApi();
    vehicles = FakeVehicleApi([vehicleDto()]);
  });

  testWidgets('shows the period total and spend by category', (tester) async {
    expenses.summaryResponse = spendingSummary({
      ExpenseCategory.insurance: '45000.00',
      ExpenseCategory.fuel: '11950.00',
      ExpenseCategory.maintenance: '9800.00',
    });
    await openExpensesTab(tester);

    expect(find.text('Rs. 66,750'), findsOneWidget);
    expect(find.text('Fill-ups, services and expenses'), findsOneWidget);
    expect(find.text('Insurance'), findsOneWidget);
    expect(find.text('Rs. 45,000'), findsOneWidget);
    expect(find.text('Rs. 11,950'), findsOneWidget);
    expect(find.text('Parking'), findsNothing);
    await scrollToEnd(tester);
    expect(find.text('Monthly spending'), findsOneWidget);
    expect(
      find.text(
        'Fill-ups and services are counted automatically. Add other costs '
        'such as insurance, parking and tolls.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('switching the period reloads the totals', (tester) async {
    await openExpensesTab(tester);
    final today = DateTime.now();
    expect(expenses.summaryStarts.last, DateTime(today.year, today.month));

    await tester.tap(find.text('This year'));
    await tester.pumpAndSettle();
    expect(expenses.summaryStarts.last, DateTime(today.year));

    await tester.tap(find.text('All time'));
    await tester.pumpAndSettle();
    expect(expenses.summaryStarts.last, isNull);
    expect(find.text('Nothing spent in this period yet.'), findsOneWidget);
  });

  testWidgets('adds an expense, explaining what fuel already includes', (
    tester,
  ) async {
    await openExpensesTab(tester);
    await tester.tap(find.text('Add expense'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Fuel'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Fill-ups from the Fuel tab are already counted as fuel. Use this for '
        'other fuel costs.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(ChoiceChip, 'Insurance'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Amount'), '45000');
    await tester.enterText(field('Notes (optional)'), 'Annual policy');
    await tester.tap(find.widgetWithText(FilledButton, 'Add expense'));
    await tester.pumpAndSettle();

    final saved = expenses.savedDrafts.single;
    expect(saved.category, ExpenseCategory.insurance);
    expect(saved.amount, FixedDecimal.parse('45000', scale: 2));
    expect(saved.notes, 'Annual policy');
    expect(find.text('Expense added'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Annual policy'), 300);
    expect(find.text('Annual policy'), findsOneWidget);
  });

  testWidgets('requires a category and an amount', (tester) async {
    await openExpensesTab(tester);
    await tester.tap(find.text('Add expense'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add expense'));
    await tester.pumpAndSettle();

    expect(find.text('Choose a category.'), findsOneWidget);
    expect(find.text('Enter the amount paid.'), findsOneWidget);
    expect(expenses.savedDrafts, isEmpty);
  });

  testWidgets('edits and deletes an expense', (tester) async {
    expenses.expenses.add(
      expense(category: ExpenseCategory.tolls, amount: '300'),
    );
    await openExpensesTab(tester);

    await scrollToEnd(tester);
    await tester.tap(find.text('Tolls'));
    await tester.pumpAndSettle();
    expect(find.text('Edit expense'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(field('Amount')).controller!.text,
      '300',
    );

    await tester.tap(find.byTooltip('Delete expense'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Expense deleted'), findsOneWidget);
    expect(expenses.expenses, isEmpty);
  });

  testWidgets('compares the two vehicles for the period', (tester) async {
    vehicles.vehicles.add(
      vehicleDto(
        id: 'vehicle-2',
        make: 'Honda',
        model: 'Dio',
        registrationNumber: 'BGH-4521',
      ),
    );
    expenses.vehicleTotalsResponse = [
      VehicleTotal(
        vehicleId: 'vehicle-1',
        make: 'Toyota',
        model: 'Aqua',
        registrationNumber: 'CAB-1234',
        total: rupees('66750'),
      ),
      VehicleTotal(
        vehicleId: 'vehicle-2',
        make: 'Honda',
        model: 'Dio',
        registrationNumber: 'BGH-4521',
        total: rupees('500'),
      ),
    ];
    await openExpensesTab(tester);

    expect(find.text('Your vehicles'), findsOneWidget);
    expect(find.text('Toyota Aqua'), findsOneWidget);
    expect(find.text('Rs. 500'), findsOneWidget);
  });

  testWidgets('offers a retry when totals fail to load', (tester) async {
    expenses.nextError = const NoConnectionException();
    await openExpensesTab(tester);

    expect(find.text("Couldn't load spending"), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('By category'), findsOneWidget);
  });
}
