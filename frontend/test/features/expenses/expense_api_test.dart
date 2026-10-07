import 'package:dio/dio.dart';
import 'package:drivon/core/utils/fixed_decimal.dart';
import 'package:drivon/features/expenses/data/expense_api.dart';
import 'package:drivon/features/expenses/data/expense_repository.dart';
import 'package:drivon/features/expenses/domain/expense.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

void main() {
  late FakeHttpAdapter adapter;
  late ExpenseRepository repository;
  final responses = <String, ResponseBody Function()>{};
  const vehicle = '/api/v1/vehicles/vehicle-1';
  final today = DateTime(2026, 10, 7);

  setUp(() {
    responses.clear();
    adapter = FakeHttpAdapter((request) async {
      final respond = responses['${request.method} ${request.uri.path}'];
      if (respond == null) throw StateError('Unexpected ${request.uri}');
      return respond();
    });
    repository = ExpenseRepository(
      ExpenseApi(
        Dio(BaseOptions(baseUrl: 'http://api.test'))
          ..httpClientAdapter = adapter,
      ),
      newId: () => 'client-id-1',
    );
  });

  test('periods start on the first of the month, the year, or never', () {
    expect(SpendingPeriod.thisMonth.start(today), DateTime(2026, 10));
    expect(SpendingPeriod.thisYear.start(today), DateTime(2026));
    expect(SpendingPeriod.allTime.start(today), isNull);
  });

  test('reads the spending summary for a period', () async {
    responses['GET $vehicle/spending'] = () => jsonBody(200, {
      'from': '2026-01-01',
      'to': '2026-10-07',
      'total': '66750.00',
      'categories': [
        {'category': 'INSURANCE', 'total': '45000.00', 'count': 1},
        {'category': 'FUEL', 'total': '11950.00', 'count': 2},
      ],
    });

    final summary = await repository.summary(
      'vehicle-1',
      SpendingPeriod.thisYear,
      today,
    );

    expect(summary.total.units, 6675000);
    expect(summary.categories.first.category, ExpenseCategory.insurance);
    expect(summary.categories.last.count, 2);
    expect(adapter.requests.single.queryParameters, {'from': '2026-01-01'});
  });

  test('all time sends no start date', () async {
    responses['GET $vehicle/spending'] = () =>
        jsonBody(200, {'total': '0.00', 'categories': <Object>[]});

    await repository.summary('vehicle-1', SpendingPeriod.allTime, today);

    expect(adapter.requests.single.queryParameters, isEmpty);
  });

  test('sends a new expense with its client ID', () async {
    responses['POST $vehicle/expenses'] = () => jsonBody(201, {
      'id': 'client-id-1',
      'vehicleId': 'vehicle-1',
      'category': 'PARKING',
      'amount': '200.00',
      'date': '2026-10-07',
      'notes': null,
    });

    final saved = await repository.create(
      'vehicle-1',
      ExpenseDraft(
        category: ExpenseCategory.parking,
        amount: FixedDecimal.parse('200', scale: 2),
        date: today,
        notes: 'Majestic City',
      ),
    );

    expect(saved.category, ExpenseCategory.parking);
    expect(adapter.requests.single.data, {
      'id': 'client-id-1',
      'category': 'PARKING',
      'amount': '200.00',
      'date': '2026-10-07',
      'notes': 'Majestic City',
    });
  });

  test('reads per-vehicle totals', () async {
    responses['GET /api/v1/spending/vehicles'] = () => jsonBody(200, {
      'total': '67250.00',
      'vehicles': [
        {
          'vehicleId': 'vehicle-1',
          'make': 'Toyota',
          'model': 'Aqua',
          'registrationNumber': 'CAB-1234',
          'total': '66750.00',
        },
      ],
    });

    final totals = await repository.byVehicle(SpendingPeriod.thisMonth, today);

    expect(totals.single.registrationNumber, 'CAB-1234');
    expect(totals.single.total.units, 6675000);
    expect(adapter.requests.single.queryParameters, {'from': '2026-10-01'});
  });
}
