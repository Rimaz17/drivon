import 'package:drivon/app/app.dart';
import 'package:drivon/core/errors/app_exception.dart';
import 'package:drivon/core/storage/token_store.dart';
import 'package:drivon/design_system/design_system.dart';
import 'package:drivon/features/fuel/presentation/widgets/fuel_record_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import '../../support/test_app.dart';
import '../vehicles/vehicle_test_doubles.dart';
import 'fuel_test_doubles.dart';

void main() {
  late FakeFuelApi fuel;
  late FakeVehicleApi vehicles;

  /// Launches the app signed in and opens the Fuel tab.
  Future<void> openFuelTab(
    WidgetTester tester, {
    Size size = const Size(1236, 2745),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: testOverrides(
        tokens: InMemoryTokenStore(
          const AuthTokens(accessToken: 'a', refreshToken: 'r'),
        ),
        vehicleApi: vehicles,
        fuelApi: fuel,
      ),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const DrivonApp()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fuel').last);
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  setUp(() {
    vehicles = FakeVehicleApi([vehicleDto(currentOdometerKm: 46000)]);
    fuel = FakeFuelApi();
  });

  testWidgets('asks to add a vehicle when there is none', (tester) async {
    vehicles.vehicles.clear();
    await openFuelTab(tester);

    expect(find.text('Add a vehicle first'), findsOneWidget);
  });

  testWidgets('logs the first fill-up, calculating the price per litre', (
    tester,
  ) async {
    await openFuelTab(tester);
    expect(find.text('Log your first fill-up'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Log fill-up'));
    await tester.pumpAndSettle();
    expect(find.text('Currently 46,000 km'), findsOneWidget);

    await tester.enterText(field('Odometer reading'), '46500');
    await tester.enterText(field('Litres'), '30');
    await tester.enterText(field('Amount paid'), '10950');
    await tester.pump();
    final price = tester.widget<TextFormField>(field('Price per litre'));
    expect(price.controller!.text, '365');
    expect(find.text('Calculated from the other two'), findsOneWidget);

    await tester.enterText(field('Station (optional)'), 'Ceypetco');
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Log fill-up'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Log fill-up'));
    await tester.pumpAndSettle();

    final saved = fuel.savedDrafts.single;
    expect(saved.odometerKm, 46500);
    expect(saved.litres.toPlainString(), '30.000');
    expect(saved.amount.toPlainString(), '10950.00');
    expect(saved.pricePerLitre.toPlainString(), '365.00');
    expect(saved.fullTank, isTrue);
    expect(find.text('Fill-up logged'), findsOneWidget);
    await tester.scrollUntilVisible(find.byType(FuelRecordTile), 300);
    expect(
      find.descendant(
        of: find.byType(FuelRecordTile),
        matching: find.text('Rs. 10,950'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a known price turns the amount into litres', (tester) async {
    await openFuelTab(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Log fill-up'));
    await tester.pumpAndSettle();

    await tester.enterText(field('Price per litre'), '365');
    await tester.enterText(field('Amount paid'), '5000');
    await tester.pump();

    final litres = tester.widget<TextFormField>(field('Litres'));
    expect(litres.controller!.text, '13.699');
  });

  testWidgets('shows the allowed odometer range the server reports', (
    tester,
  ) async {
    await openFuelTab(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Log fill-up'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Odometer reading'), '40000');
    await tester.enterText(field('Litres'), '30');
    await tester.enterText(field('Amount paid'), '10950');
    fuel.nextError = const ApiProblemException(
      statusCode: 422,
      code: ApiErrorCodes.odometerOutOfOrder,
      properties: {'minKm': 45000, 'maxKm': 47000},
    );

    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Log fill-up'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Log fill-up'));
    await tester.pumpAndSettle();

    expect(
      find.text('For this date, enter a reading from 45,000 to 47,000 km.'),
      findsOneWidget,
    );
    expect(fuel.records, isEmpty);
  });

  testWidgets('requires litres and amount before saving', (tester) async {
    await openFuelTab(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Log fill-up'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Log fill-up'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Log fill-up'));
    await tester.pumpAndSettle();

    expect(find.text('Enter the odometer reading.'), findsOneWidget);
    expect(find.text('Enter the litres.'), findsOneWidget);
    expect(find.text('Enter the amount paid.'), findsOneWidget);
    expect(fuel.savedDrafts, isEmpty);
  });

  testWidgets('shows km/L, spend and the history once there is data', (
    tester,
  ) async {
    fuel.records.addAll([
      fuelRecordDto(id: 'c', odometerKm: 46500, kmPerLitre: '20.00'),
      fuelRecordDto(
        id: 'b',
        odometerKm: 46200,
        litres: '10.000',
        amount: '3650.00',
        fullTank: false,
      ),
      fuelRecordDto(
        id: 'a',
        odometerKm: 46000,
        litres: '30.000',
        amount: '10950.00',
        station: null,
      ),
    ]);
    fuel.statsResponse = fuelStatsDto(
      totalSpend: '20075.00',
      totalLitres: '55.000',
      fillUps: 3,
      trackedDistanceKm: 500,
      averageKmPerLitre: '20.00',
      bestKmPerLitre: '20.00',
      latestKmPerLitre: '20.00',
      costPerKm: '18.25',
    );
    fuel.monthlyResponse = [
      ...fuel.monthlyResponse.take(5),
      fuelMonth(2026, 10, '20075.00'),
    ];
    await openFuelTab(tester);

    expect(find.byType(ArcGauge), findsOneWidget);
    expect(find.text('Last tank'), findsOneWidget);
    expect(find.textContaining('18.25'), findsOneWidget);
    expect(find.text('October 2026'), findsOneWidget);
    expect(
      find.text('All time: Rs. 20,075 on 3 fill-ups, 55 L'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(find.text('Top-up'), 300);
    expect(find.widgetWithText(TagChip, '20.00 km/L'), findsOneWidget);
    expect(find.text('Top-up'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('explains km/L until two full fill-ups exist', (tester) async {
    fuel.records.add(fuelRecordDto());
    fuel.statsResponse = fuelStatsDto(
      totalSpend: '5475.00',
      totalLitres: '15.000',
      fillUps: 1,
    );
    await openFuelTab(tester);

    expect(find.text('km/L comes after two full fill-ups'), findsOneWidget);
    expect(find.text('After two full fill-ups'), findsOneWidget);
    expect(find.byType(ArcGauge), findsNothing);
  });

  testWidgets('edits and deletes a fill-up', (tester) async {
    fuel.records.add(fuelRecordDto(odometerKm: 46500));
    await openFuelTab(tester);

    await tester.scrollUntilVisible(find.text('Rs. 5,475'), 300);
    await tester.tap(find.text('Rs. 5,475'));
    await tester.pumpAndSettle();
    expect(find.text('Edit fill-up'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(field('Odometer reading')).controller!.text,
      '46500',
    );

    await tester.tap(find.byTooltip('Delete fill-up'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this fill-up?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(fuel.records, isEmpty);
    expect(find.text('Fill-up deleted'), findsOneWidget);
    expect(find.text('Log your first fill-up'), findsOneWidget);
  });

  testWidgets('offers a retry when fill-ups fail to load', (tester) async {
    fuel.nextError = const NoConnectionException();
    await openFuelTab(tester);

    expect(find.text("Couldn't load fuel records"), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Log your first fill-up'), findsOneWidget);
  });

  testWidgets('uses a navigation rail on wide screens', (tester) async {
    await openFuelTab(tester, size: const Size(2400, 1800));

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Log your first fill-up'), findsOneWidget);
  });
}
