import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drivon/core/errors/app_exception.dart';
import 'package:drivon/core/utils/fixed_decimal.dart';
import 'package:drivon/core/utils/uuid.dart';
import 'package:drivon/features/fuel/data/fuel_api.dart';
import 'package:drivon/features/fuel/data/fuel_repository.dart';
import 'package:drivon/features/fuel/domain/fuel_record.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import 'fuel_test_doubles.dart';

void main() {
  late FakeHttpAdapter adapter;
  late FuelRepository repository;
  final responses = <String, ResponseBody Function()>{};

  setUp(() {
    responses.clear();
    adapter = FakeHttpAdapter((request) async {
      final key = '${request.method} ${request.uri.path}';
      final respond = responses[key];
      if (respond == null) throw StateError('Unexpected $key');
      return respond();
    });
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
      ..httpClientAdapter = adapter;
    repository = FuelRepository(FuelApi(dio), newId: () => 'client-id-1');
  });

  const records = '/api/v1/vehicles/vehicle-1/fuel-records';

  test('reads a page of fill-ups with exact decimals', () async {
    responses['GET $records'] = () => jsonBody(200, {
      'content': [fuelRecordJson(kmPerLitre: '20.00')],
      'page': 0,
      'size': 20,
      'totalElements': 21,
      'totalPages': 2,
      'hasNext': true,
    });

    final page = await repository.list('vehicle-1', page: 0);

    expect(page.hasMore, isTrue);
    final record = page.items.single;
    expect(record.date, DateTime(2026, 10, 7));
    expect(record.litres, FixedDecimal.parse('15.000', scale: 3));
    expect(record.amount.units, 547500);
    expect(record.kmPerLitre!.toPlainString(), '20.00');
    expect(adapter.requests.single.queryParameters, {'page': 0, 'size': 20});
  });

  test(
    'sends a new fill-up with its client ID and decimals as strings',
    () async {
      responses['POST $records'] = () => jsonBody(201, fuelRecordJson());

      await repository.create(
        'vehicle-1',
        fuelDraft(station: '  Ceypetco  '),
        id: repository.newFillUpId(),
      );

      final body = adapter.requests.single.data as Map<String, dynamic>;
      expect(body, {
        'id': 'client-id-1',
        'date': '2026-10-07',
        'litres': '15.000',
        'amount': '5475.00',
        'pricePerLitre': '365.00',
        'odometerKm': 10500,
        'fullTank': true,
        'station': 'Ceypetco',
      });
    },
  );

  test('updates without an ID and leaves out an empty station', () async {
    responses['PUT $records/record-1'] = () => jsonBody(200, fuelRecordJson());

    await repository.update('vehicle-1', 'record-1', fuelDraft(station: ' '));

    final body = adapter.requests.single.data as Map<String, dynamic>;
    expect(body.containsKey('id'), isFalse);
    expect(body.containsKey('station'), isFalse);
  });

  test('loads stats and monthly spend together', () async {
    responses['GET /api/v1/vehicles/vehicle-1/fuel-stats'] = () =>
        jsonBody(200, {
          'from': '1900-01-01',
          'to': '2026-10-07',
          'totalSpend': '20075.00',
          'totalLitres': '55.000',
          'fillUps': 3,
          'averageKmPerLitre': '20.00',
          'bestKmPerLitre': '20.00',
          'latestKmPerLitre': '20.00',
          'costPerKm': '18.25',
          'trackedDistanceKm': 500,
        });
    responses['GET /api/v1/vehicles/vehicle-1/fuel-stats/monthly'] = () =>
        jsonBody(200, [
          {'month': '2026-09', 'total': '0.00'},
          {'month': '2026-10', 'total': '20075.00'},
        ]);

    final summary = await repository.summary('vehicle-1', months: 2);

    expect(summary.stats.hasEfficiency, isTrue);
    expect(summary.stats.costPerKm!.toPlainString(), '18.25');
    expect(summary.stats.fillUps, 3);
    expect(summary.monthlySpend.last.month, DateTime(2026, 10));
    expect(summary.monthlySpend.last.total.units, 2007500);
    final monthly = adapter.requests.firstWhere(
      (r) => r.uri.path.endsWith('/monthly'),
    );
    expect(monthly.queryParameters, {'months': 2});
  });

  test('stats without two full fills have no efficiency', () async {
    final json = {
      'totalSpend': '10950.00',
      'totalLitres': '30.000',
      'fillUps': 1,
      'trackedDistanceKm': 0,
      'averageKmPerLitre': null,
      'bestKmPerLitre': null,
      'latestKmPerLitre': null,
      'costPerKm': null,
    };
    responses['GET /api/v1/vehicles/vehicle-1/fuel-stats'] = () =>
        jsonBody(200, json);
    responses['GET /api/v1/vehicles/vehicle-1/fuel-stats/monthly'] = () =>
        jsonBody(200, <Object>[]);

    final summary = await repository.summary('vehicle-1');

    expect(summary.stats.hasEfficiency, isFalse);
    expect(summary.stats.costPerKm, isNull);
  });

  test('maps API errors to typed exceptions with their details', () async {
    responses['POST $records'] = () => ResponseBody.fromString(
      jsonEncode({
        'code': 'ODOMETER_OUT_OF_ORDER',
        'detail': 'For this date the odometer must be at most 45,000 km.',
        'maxKm': 45000,
      }),
      422,
      headers: {
        Headers.contentTypeHeader: ['application/problem+json'],
      },
    );

    await expectLater(
      repository.create('vehicle-1', fuelDraft(), id: 'client-id-1'),
      throwsA(
        isA<ApiProblemException>().having(
          (e) => e.code,
          'code',
          'ODOMETER_OUT_OF_ORDER',
        ),
      ),
    );
  });

  test('generates random version 4 UUIDs', () {
    final pattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );
    final ids = {for (var i = 0; i < 100; i++) uuidV4()};
    expect(ids, hasLength(100));
    expect(ids.every(pattern.hasMatch), isTrue);
  });

  test('a record turns back into an editable draft', () {
    final record = fuelRecordDto().toDomain();
    expect(record.toDraft(), isA<FuelDraft>());
    expect(record.toDraft().odometerKm, record.odometerKm);
  });
}
