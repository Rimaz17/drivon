import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drivon/features/documents/domain/vehicle_document.dart';
import 'package:drivon/features/maintenance/domain/maintenance_record.dart';
import 'package:drivon/features/notifications/data/device_token_api.dart';
import 'package:drivon/features/reminders/data/reminder_api.dart';
import 'package:drivon/features/reminders/data/reminder_repository.dart';
import 'package:drivon/features/reminders/domain/reminder.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

void main() {
  late FakeHttpAdapter adapter;
  late Dio dio;
  late ReminderRepository repository;
  final responses = <String, ResponseBody Function()>{};
  const path = '/api/v1/vehicles/vehicle-1/reminders';

  setUp(() {
    responses.clear();
    adapter = FakeHttpAdapter((request) async {
      final respond = responses['${request.method} ${request.uri.path}'];
      if (respond == null) throw StateError('Unexpected ${request.uri}');
      return respond();
    });
    dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
      ..httpClientAdapter = adapter;
    repository = ReminderRepository(
      ReminderApi(dio),
      newId: () => 'client-id-1',
    );
  });

  Map<String, dynamic> serviceJson() => {
    'id': 'reminder-1',
    'vehicleId': 'vehicle-1',
    'source': 'SERVICE',
    'serviceType': 'OIL_CHANGE',
    'documentType': null,
    'sourceId': 'service-1',
    'title': null,
    'dueDate': '2026-11-12',
    'dueKm': 50000,
    'remindFrom': '2026-11-05',
    'daysRemaining': 33,
    'kmRemaining': 420,
    'status': 'DUE_SOON',
  };

  Map<String, dynamic> documentJson() => {
    'id': 'reminder-2',
    'vehicleId': 'vehicle-1',
    'source': 'DOCUMENT',
    'serviceType': null,
    'documentType': 'INSURANCE',
    'sourceId': 'document-1',
    'title': null,
    'dueDate': '2026-10-01',
    'dueKm': null,
    'remindFrom': '2026-09-01',
    'daysRemaining': -9,
    'kmRemaining': null,
    'status': 'OVERDUE',
  };

  test('reads service and document reminders', () async {
    responses['GET $path'] = () =>
        jsonBody(200, [serviceJson(), documentJson()]);

    final reminders = await repository.list('vehicle-1');

    final service = reminders.first;
    expect(service.source, ReminderSource.service);
    expect(service.serviceType, ServiceType.oilChange);
    expect(service.sourceId, 'service-1');
    expect(service.dueDate, DateTime(2026, 11, 12));
    expect(service.remindFrom, DateTime(2026, 11, 5));
    expect(service.kmRemaining, 420);
    expect(service.status, ReminderStatus.dueSoon);
    final document = reminders.last;
    expect(document.documentType, DocumentType.insurance);
    expect(document.daysRemaining, -9);
    expect(document.status, ReminderStatus.overdue);
  });

  test('reads every reminder of the user', () async {
    responses['GET /api/v1/reminders'] = () => jsonBody(200, [serviceJson()]);

    expect(await repository.listAll(), hasLength(1));
  });

  test('adds a reminder with the ID kept for retries', () async {
    responses['POST $path'] = () => jsonBody(201, {
      ...serviceJson(),
      'id': 'client-id-1',
      'source': 'MANUAL',
      'serviceType': null,
      'sourceId': null,
      'title': 'Emission test',
    });

    final id = repository.newReminderId();
    final saved = await repository.create(
      'vehicle-1',
      ReminderDraft(title: '  Emission test ', dueDate: DateTime(2026, 11, 12)),
      id: id,
    );

    expect(saved.isManual, isTrue);
    expect(adapter.requests.single.data, {
      'id': 'client-id-1',
      'title': 'Emission test',
      'dueDate': '2026-11-12',
      'dueKm': null,
    });
  });

  test('updates without an ID and deletes', () async {
    responses['PUT $path/reminder-1'] = () =>
        jsonBody(200, {...serviceJson(), 'source': 'MANUAL', 'title': 'Wash'});
    responses['DELETE $path/reminder-1'] = () =>
        ResponseBody.fromString('', 204);

    await repository.update(
      'vehicle-1',
      'reminder-1',
      const ReminderDraft(title: 'Wash', dueKm: 60000),
    );
    await repository.delete('vehicle-1', 'reminder-1');

    expect(adapter.requests.first.data, {
      'title': 'Wash',
      'dueDate': null,
      'dueKm': 60000,
    });
    expect(adapter.requests.last.method, 'DELETE');
  });

  test('registers and unregisters this phone for push', () async {
    responses['PUT /api/v1/device-tokens'] = () =>
        ResponseBody.fromString('', 204);
    responses['DELETE /api/v1/device-tokens/abc%3Adef-1'] = () =>
        ResponseBody.fromString('', 204);
    final api = DeviceTokenApi(dio);

    await api.register('abc:def-1');
    await api.unregister('abc:def-1');

    expect(
      jsonEncode(adapter.requests.first.data),
      jsonEncode({'token': 'abc:def-1', 'platform': 'ANDROID'}),
    );
    expect(adapter.requests.last.method, 'DELETE');
  });
}
