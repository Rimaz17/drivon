import 'package:drivon/app/app.dart';
import 'package:drivon/core/errors/app_exception.dart';
import 'package:drivon/core/storage/token_store.dart';
import 'package:drivon/design_system/design_system.dart';
import 'package:drivon/features/maintenance/domain/maintenance_record.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import '../../support/test_app.dart';
import '../vehicles/vehicle_test_doubles.dart';
import 'maintenance_test_doubles.dart';

void main() {
  late FakeMaintenanceApi maintenance;

  Future<void> openServiceTab(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1236, 2745);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: testOverrides(
        tokens: InMemoryTokenStore(
          const AuthTokens(accessToken: 'a', refreshToken: 'r'),
        ),
        vehicleApi: FakeVehicleApi([vehicleDto(currentOdometerKm: 46000)]),
        maintenanceApi: maintenance,
      ),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const DrivonApp()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Service').last);
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);
  Finder saveButton(String label) => find.widgetWithText(FilledButton, label);

  Future<void> tapSave(WidgetTester tester, String label) async {
    await tester.ensureVisible(saveButton(label));
    await tester.tap(saveButton(label));
    await tester.pumpAndSettle();
  }

  setUp(() => maintenance = FakeMaintenanceApi());

  testWidgets('logs the first service with when the next one is due', (
    tester,
  ) async {
    await openServiceTab(tester);
    expect(find.text('Log your first service'), findsOneWidget);
    await tester.tap(saveButton('Log service'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Service type'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oil change').last);
    await tester.pumpAndSettle();
    await tester.enterText(field('Odometer (optional)'), '46500');
    await tester.enterText(field('Cost'), '9800');
    await tester.enterText(field('Notes (optional)'), 'Lanka Auto Care');
    await tester.enterText(field('Next service at'), '51500');
    await tapSave(tester, 'Log service');

    final saved = maintenance.savedDrafts.single;
    expect(saved.serviceType, ServiceType.oilChange);
    expect(saved.odometerKm, 46500);
    expect(saved.cost.toPlainString(), '9800.00');
    expect(saved.nextServiceKm, 51500);
    expect(saved.nextServiceDate, isNull);
    expect(find.text('Service logged'), findsOneWidget);
    expect(find.text('Rs. 9,800'), findsOneWidget);
    expect(find.text('Lanka Auto Care'), findsOneWidget);
  });

  testWidgets('checks the type, cost and next mileage before saving', (
    tester,
  ) async {
    await openServiceTab(tester);
    await tester.tap(saveButton('Log service'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Odometer (optional)'), '46500');
    await tester.enterText(field('Next service at'), '46000');
    await tapSave(tester, 'Log service');

    expect(find.text('Choose a service type.'), findsOneWidget);
    expect(find.text('Enter the cost.'), findsOneWidget);
    expect(
      find.text('Enter more than 46,500 km, the odometer at this service.'),
      findsOneWidget,
    );
    expect(maintenance.savedDrafts, isEmpty);
  });

  testWidgets('a free service costs Rs. 0', (tester) async {
    await openServiceTab(tester);
    await tester.tap(saveButton('Log service'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Service type'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wheel alignment').last);
    await tester.pumpAndSettle();
    await tester.enterText(field('Cost'), '0');
    await tapSave(tester, 'Log service');

    expect(maintenance.savedDrafts.single.cost.isZero, isTrue);
    expect(maintenance.savedDrafts.single.odometerKm, isNull);
  });

  testWidgets('shows the next service on the highlight card', (tester) async {
    maintenance.records.add(maintenanceRecord(nextServiceKm: 51500));
    maintenance.upcomingResponse = [
      UpcomingService(
        serviceType: ServiceType.tyreRotation,
        recordId: 'service-1',
        lastServicedOn: DateTime(2025, 10),
        dueDate: DateTime(2026, 10, 4),
        daysRemaining: -3,
        overdue: true,
      ),
      UpcomingService(
        serviceType: ServiceType.oilChange,
        recordId: 'service-1',
        lastServicedOn: DateTime(2026, 10, 7),
        dueDate: DateTime(2027, 4, 7),
        dueKm: 51500,
        daysRemaining: 182,
        kmRemaining: 5000,
        overdue: false,
      ),
    ];
    await openServiceTab(tester);

    expect(find.text('Coming up'), findsOneWidget);
    final card = find.byWidgetPredicate(
      (w) => w is DrivonCard && w.tone == DrivonCardTone.highlight,
    );
    expect(
      find.descendant(
        of: card,
        matching: find.text('Tyre rotation is overdue'),
      ),
      findsOneWidget,
    );
    expect(find.text('Due 4 Oct 2026'), findsOneWidget);
    expect(find.text('Last done 1 Oct 2025'), findsOneWidget);
    expect(find.text('Oil change due in 182 days'), findsOneWidget);
    expect(
      find.text('Due 7 Apr 2027 or at 51,500 km, whichever comes first'),
      findsOneWidget,
    );
  });

  testWidgets('filters the history by service type', (tester) async {
    maintenance.records.addAll([
      maintenanceRecord(),
      maintenanceRecord(
        id: 'service-2',
        serviceType: ServiceType.brakeService,
        cost: '4500.00',
        odometerKm: null,
      ),
    ]);
    await openServiceTab(tester);
    expect(find.text('Rs. 9,800'), findsOneWidget);
    expect(find.text('Rs. 4,500'), findsOneWidget);

    await tester.ensureVisible(
      find.widgetWithText(ChoiceChip, 'Brake service'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Brake service'));
    await tester.pumpAndSettle();
    expect(find.text('Rs. 9,800'), findsNothing);
    expect(find.text('Rs. 4,500'), findsOneWidget);
    expect(find.text('7 Oct 2026'), findsOneWidget);

    await tester.ensureVisible(
      find.widgetWithText(ChoiceChip, 'Air conditioning'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Air conditioning'));
    await tester.pumpAndSettle();
    expect(find.text('No air conditioning records yet.'), findsOneWidget);
  });

  testWidgets('edits and deletes a service', (tester) async {
    maintenance.records.add(maintenanceRecord());
    await openServiceTab(tester);

    await tester.tap(find.text('Rs. 9,800'));
    await tester.pumpAndSettle();
    expect(find.text('Edit service'), findsOneWidget);
    await tester.enterText(field('Cost'), '10500');
    await tapSave(tester, 'Save changes');
    expect(maintenance.savedDrafts.single.cost.toPlainString(), '10500.00');
    expect(find.text('Rs. 10,500'), findsOneWidget);
    // Let the "Changes saved" snackbar time out so the next one shows.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rs. 10,500'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete service'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Service deleted'), findsOneWidget);
    expect(find.text('Log your first service'), findsOneWidget);
  });

  testWidgets('shows the server rule for the next service date', (
    tester,
  ) async {
    await openServiceTab(tester);
    await tester.tap(saveButton('Log service'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Service type'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oil change').last);
    await tester.pumpAndSettle();
    await tester.enterText(field('Cost'), '9800');
    maintenance.nextError = const ApiProblemException(
      statusCode: 422,
      code: ApiErrorCodes.nextServiceDateInvalid,
    );
    await tapSave(tester, 'Log service');

    expect(find.text('Choose a date after the service date.'), findsOneWidget);
  });
}
