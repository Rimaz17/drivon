import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drivon/app/app.dart';
import 'package:drivon/core/errors/app_exception.dart';
import 'package:drivon/core/storage/token_store.dart';
import 'package:drivon/features/vehicles/data/odometer_api.dart';
import 'package:drivon/features/vehicles/domain/odometer_reading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import '../../support/test_app.dart';
import '../fuel/fuel_test_doubles.dart';
import 'odometer_test_doubles.dart';
import 'vehicle_test_doubles.dart';

void main() {
  late FakeOdometerApi odometer;
  late FakeFuelApi fuel;

  /// Launches the app signed in and opens the odometer history.
  Future<void> openHistory(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1236, 2745);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: testOverrides(
        tokens: InMemoryTokenStore(
          const AuthTokens(accessToken: 'a', refreshToken: 'r'),
        ),
        vehicleApi: FakeVehicleApi([vehicleDto()]),
        fuelApi: fuel,
        odometerApi: odometer,
      ),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const DrivonApp()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Odometer history'));
    await tester.pumpAndSettle();
  }

  Finder kmField() => find.widgetWithText(TextFormField, 'Odometer reading');

  setUp(() {
    fuel = FakeFuelApi(records: [fuelRecordDto(id: 'fuel-1')]);
    odometer = FakeOdometerApi([
      odometerReading(
        id: 'r-fuel',
        readingKm: 46500,
        date: DateTime(2026, 10, 7),
        source: OdometerSource.fuel,
        sourceId: 'fuel-1',
      ),
      odometerReading(
        id: 'r-manual',
        readingKm: 45500,
        date: DateTime(2026, 10, 3),
        source: OdometerSource.manual,
      ),
      odometerReading(id: 'r-initial'),
    ]);
  });

  testWidgets('lists readings with their source', (tester) async {
    await openHistory(tester);

    expect(find.text('46,500 km'), findsOneWidget);
    expect(find.text('7 Oct 2026 · From a fill-up'), findsOneWidget);
    expect(find.text('3 Oct 2026 · Entered by you'), findsOneWidget);
    expect(find.text('1 Oct 2026 · Added with the vehicle'), findsOneWidget);
  });

  testWidgets('corrects the initial reading', (tester) async {
    await openHistory(tester);
    await tester.tap(find.text('45,000 km'));
    await tester.pumpAndSettle();

    expect(find.text('Correct reading'), findsOneWidget);
    expect(find.byTooltip('Delete reading'), findsNothing);
    await tester.enterText(kmField(), '44000');
    await tester.tap(find.text('Save reading'));
    await tester.pumpAndSettle();

    expect(find.text('Reading corrected'), findsOneWidget);
    expect(odometer.readings.last.readingKm, 44000);
    expect(find.text('44,000 km'), findsOneWidget);
  });

  testWidgets('adds a reading and shows the allowed range when rejected', (
    tester,
  ) async {
    await openHistory(tester);
    await tester.tap(find.text('Add reading'));
    await tester.pumpAndSettle();
    await tester.enterText(kmField(), '40000');
    odometer.nextError = const ApiProblemException(
      statusCode: 422,
      code: ApiErrorCodes.odometerOutOfOrder,
      properties: {'minKm': 46500},
    );

    await tester.tap(find.text('Save reading'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'For this date, enter at least 46,500 km, the reading on an '
        'earlier date.',
      ),
      findsOneWidget,
    );

    await tester.enterText(kmField(), '46800');
    await tester.tap(find.text('Save reading'));
    await tester.pumpAndSettle();
    expect(find.text('Reading added'), findsOneWidget);
    expect(find.text('46,800 km'), findsOneWidget);
  });

  testWidgets('deletes a manual reading after confirmation', (tester) async {
    await openHistory(tester);
    await tester.tap(find.text('45,500 km'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Delete reading'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Reading deleted'), findsOneWidget);
    expect(find.text('45,500 km'), findsNothing);
  });

  testWidgets("a fill-up's reading opens the fill-up", (tester) async {
    await openHistory(tester);
    await tester.tap(find.text('46,500 km'));
    await tester.pumpAndSettle();

    expect(find.text('Edit fill-up'), findsOneWidget);
  });

  test('reads the API response', () async {
    final adapter = FakeHttpAdapter(
      (request) async => jsonBody(200, {
        'content': [
          {
            'id': 'r1',
            'readingKm': 46500,
            'date': '2026-10-07',
            'source': 'FUEL',
            'sourceId': 'f1',
            'createdAt': '2026-10-07T04:30:00Z',
          },
        ],
        'hasNext': false,
      }),
    );
    final api = OdometerApi(
      Dio(BaseOptions(baseUrl: 'http://api.test'))..httpClientAdapter = adapter,
    );

    final page = await api.list('vehicle-1', page: 0);

    expect(page.items.single.source, OdometerSource.fuel);
    expect(page.items.single.source.canCorrect, isFalse);
    expect(page.items.single.date, DateTime(2026, 10, 7));
    expect(
      adapter.requests.single.uri.path,
      '/api/v1/vehicles/vehicle-1/odometer-readings',
    );
    expect(
      jsonEncode(adapter.requests.single.queryParameters),
      '{"page":0,"size":20}',
    );
  });
}
