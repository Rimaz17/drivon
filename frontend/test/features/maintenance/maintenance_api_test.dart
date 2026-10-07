import 'package:dio/dio.dart';
import 'package:drivon/core/utils/fixed_decimal.dart';
import 'package:drivon/features/maintenance/data/maintenance_api.dart';
import 'package:drivon/features/maintenance/data/maintenance_repository.dart';
import 'package:drivon/features/maintenance/domain/maintenance_record.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

void main() {
  late FakeHttpAdapter adapter;
  late MaintenanceRepository repository;
  final responses = <String, ResponseBody Function()>{};
  const path = '/api/v1/vehicles/vehicle-1/maintenance-records';

  setUp(() {
    responses.clear();
    adapter = FakeHttpAdapter((request) async {
      final respond = responses['${request.method} ${request.uri.path}'];
      if (respond == null) throw StateError('Unexpected ${request.uri}');
      return respond();
    });
    repository = MaintenanceRepository(
      MaintenanceApi(
        Dio(BaseOptions(baseUrl: 'http://api.test'))
          ..httpClientAdapter = adapter,
      ),
      newId: () => 'client-id-1',
    );
  });

  Map<String, dynamic> recordJson({Object? odometerKm = 46500}) => {
    'id': 'service-1',
    'vehicleId': 'vehicle-1',
    'serviceType': 'OIL_CHANGE',
    'date': '2026-10-07',
    'odometerKm': odometerKm,
    'cost': '9800.00',
    'notes': 'Lanka Auto Care',
    'nextServiceDate': '2027-04-07',
    'nextServiceKm': 51500,
  };

  test('reads services and filters by type', () async {
    responses['GET $path'] = () => jsonBody(200, {
      'content': [recordJson(), recordJson(odometerKm: null)],
      'hasNext': false,
    });

    final page = await repository.list(
      'vehicle-1',
      page: 0,
      type: ServiceType.oilChange,
    );

    final record = page.items.first;
    expect(record.serviceType, ServiceType.oilChange);
    expect(record.cost, FixedDecimal.parse('9800', scale: 2));
    expect(record.nextServiceDate, DateTime(2027, 4, 7));
    expect(record.nextServiceKm, 51500);
    expect(page.items.last.odometerKm, isNull);
    expect(adapter.requests.single.queryParameters, {
      'page': 0,
      'size': 20,
      'serviceType': 'OIL_CHANGE',
    });
  });

  test('sends a new service with its client ID and optional fields', () async {
    responses['POST $path'] = () => jsonBody(201, recordJson());

    await repository.create(
      'vehicle-1',
      MaintenanceDraft(
        serviceType: ServiceType.brakeService,
        date: DateTime(2026, 10, 7),
        cost: FixedDecimal.parse('4500', scale: 2),
        notes: '  ',
      ),
    );

    expect(adapter.requests.single.data, {
      'id': 'client-id-1',
      'serviceType': 'BRAKE_SERVICE',
      'date': '2026-10-07',
      'odometerKm': null,
      'cost': '4500.00',
      'notes': null,
      'nextServiceDate': null,
      'nextServiceKm': null,
    });
  });

  test('reads upcoming services', () async {
    responses['GET $path/upcoming'] = () => jsonBody(200, [
      {
        'serviceType': 'TYRE_ROTATION',
        'recordId': 'service-2',
        'lastServicedOn': '2025-10-01',
        'dueDate': '2026-10-04',
        'dueKm': null,
        'daysRemaining': -3,
        'kmRemaining': null,
        'overdue': true,
      },
    ]);

    final upcoming = await repository.upcoming('vehicle-1');

    expect(upcoming.single.overdue, isTrue);
    expect(upcoming.single.daysRemaining, -3);
    expect(upcoming.single.kmRemaining, isNull);
  });
}
