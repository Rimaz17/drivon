import 'package:dio/dio.dart';
import 'package:drivon/features/analytics/data/analytics_api.dart';
import 'package:drivon/features/analytics/data/analytics_repository.dart';
import 'package:drivon/features/analytics/domain/analytics.dart';
import 'package:drivon/features/expenses/data/expense_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

void main() {
  late FakeHttpAdapter adapter;
  late AnalyticsRepository repository;
  final responses = <String, ResponseBody Function()>{};
  const analytics = '/api/v1/vehicles/vehicle-1/analytics';
  final today = DateTime(2026, 10, 7);

  setUp(() {
    responses.clear();
    adapter = FakeHttpAdapter((request) async {
      final respond = responses['${request.method} ${request.uri.path}'];
      if (respond == null) throw StateError('Unexpected ${request.uri}');
      return respond();
    });
    repository = AnalyticsRepository(
      AnalyticsApi(
        Dio(BaseOptions(baseUrl: 'http://api.test'))
          ..httpClientAdapter = adapter,
      ),
    );
  });

  test('reads cost per km with its parts for a period', () async {
    responses['GET $analytics/cost-per-km'] = () => jsonBody(200, {
      'from': '2026-01-01',
      'to': '2026-10-07',
      'distanceKm': 800,
      'totalCost': '74875.00',
      'costPerKm': '93.59',
      'breakdown': [
        {'group': 'FUEL', 'total': '20075.00', 'costPerKm': '25.09'},
        {'group': 'MAINTENANCE', 'total': '9800.00', 'costPerKm': '12.25'},
        {'group': 'OTHER', 'total': '45000.00', 'costPerKm': '56.25'},
      ],
    });

    final cost = await repository.costPerKm(
      'vehicle-1',
      SpendingPeriod.thisYear,
      today,
    );

    expect(cost.distanceKm, 800);
    expect(cost.costPerKm!.toPlainString(), '93.59');
    expect(cost.breakdown.map((g) => g.group), CostGroup.values);
    expect(cost.breakdown.last.costPerKm!.toPlainString(), '56.25');
    expect(adapter.requests.single.queryParameters, {'from': '2026-01-01'});
  });

  test('keeps cost per km unknown without distance', () async {
    responses['GET $analytics/cost-per-km'] = () => jsonBody(200, {
      'distanceKm': 0,
      'totalCost': '45000.00',
      'costPerKm': null,
      'breakdown': [
        {'group': 'FUEL', 'total': '0.00', 'costPerKm': null},
        {'group': 'MAINTENANCE', 'total': '0.00', 'costPerKm': null},
        {'group': 'OTHER', 'total': '45000.00', 'costPerKm': null},
      ],
    });

    final cost = await repository.costPerKm(
      'vehicle-1',
      SpendingPeriod.allTime,
      today,
    );

    expect(cost.costPerKm, isNull);
    expect(adapter.requests.single.queryParameters, isEmpty);
  });

  test('reads six months of costs', () async {
    responses['GET $analytics/monthly-costs'] = () => jsonBody(200, [
      {
        'month': '2026-10',
        'fuel': '20075.00',
        'maintenance': '9800.00',
        'other': '45000.00',
        'total': '74875.00',
        'distanceKm': 800,
        'costPerKm': '93.59',
      },
    ]);

    final months = await repository.monthlyCosts('vehicle-1');

    expect(months.single.month, DateTime(2026, 10));
    expect(months.single.other.toPlainString(), '45000.00');
    expect(adapter.requests.single.queryParameters, {'months': 6});
  });

  test('asks for tanks of the last twelve calendar months', () async {
    responses['GET $analytics/efficiency-trend'] = () => jsonBody(200, [
      {
        'startDate': '2026-09-20',
        'endDate': '2026-10-07',
        'distanceKm': 500,
        'litres': '25.000',
        'kmPerLitre': '20.00',
        'costPerKm': '18.25',
      },
    ]);

    final trend = await repository.efficiencyTrend('vehicle-1', today);

    expect(trend.single.kmPerLitre.toPlainString(), '20.00');
    expect(trend.single.litres.toPlainString(), '25.000');
    expect(adapter.requests.single.queryParameters, {'from': '2025-11-01'});
  });

  test('reads the vehicle comparison', () async {
    responses['GET /api/v1/analytics/vehicle-comparison'] = () =>
        jsonBody(200, {
          'from': '2026-10-01',
          'to': '2026-10-07',
          'vehicles': [
            {
              'vehicleId': 'vehicle-2',
              'make': 'Honda',
              'model': 'Dio',
              'registrationNumber': 'BGH-4521',
              'distanceKm': 0,
              'totalCost': '0.00',
              'costPerKm': null,
              'breakdown': [
                {'group': 'FUEL', 'total': '0.00', 'costPerKm': null},
                {'group': 'MAINTENANCE', 'total': '0.00', 'costPerKm': null},
                {'group': 'OTHER', 'total': '0.00', 'costPerKm': null},
              ],
              'averageKmPerLitre': null,
            },
          ],
        });

    final vehicles = await repository.compareVehicles(
      SpendingPeriod.thisMonth,
      today,
    );

    expect(vehicles.single.make, 'Honda');
    expect(vehicles.single.costPerKm, isNull);
    expect(vehicles.single.averageKmPerLitre, isNull);
    expect(adapter.requests.single.queryParameters, {'from': '2026-10-01'});
  });
}
