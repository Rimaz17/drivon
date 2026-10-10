import 'package:drivon/app/app.dart';
import 'package:drivon/core/errors/app_exception.dart';
import 'package:drivon/core/network/connection_status.dart';
import 'package:drivon/core/storage/token_store.dart';
import 'package:drivon/features/fuel/presentation/fuel_sync_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import '../../support/offline_fakes.dart';
import '../../support/test_app.dart';
import '../vehicles/vehicle_test_doubles.dart';
import 'fuel_offline_test.dart' show FlakyFuelApi;

void main() {
  late FlakyFuelApi fuel;
  late InMemoryLocalStore store;
  late FakeNetworkMonitor network;
  late ProviderContainer container;

  setUp(() {
    fuel = FlakyFuelApi();
    store = InMemoryLocalStore();
    network = FakeNetworkMonitor();
  });

  Future<void> openApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1236, 2745);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    container = ProviderContainer(
      overrides: testOverrides(
        tokens: InMemoryTokenStore(
          const AuthTokens(accessToken: 'a', refreshToken: 'r'),
        ),
        vehicleApi: FakeVehicleApi([vehicleDto(currentOdometerKm: 46000)]),
        fuelApi: fuel,
        localStore: store,
        networkMonitor: network,
      ),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const DrivonApp()),
    );
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  Future<void> logFillUpOffline(WidgetTester tester) async {
    await tester.tap(find.text('Fuel').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Log fill-up'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Odometer reading'), '46500');
    await tester.enterText(field('Litres'), '30');
    await tester.enterText(field('Amount paid'), '10950');
    await tester.pump();
    final save = find.widgetWithText(FilledButton, 'Log fill-up');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
  }

  /// The section sits below the figures on the sheet.
  Future<void> showWaiting(WidgetTester tester) => tester.scrollUntilVisible(
    find.text('Waiting to sync'),
    200,
    scrollable: find.byType(Scrollable).last,
  );

  testWidgets('a fill-up logged offline waits on the Fuel tab, then syncs', (
    tester,
  ) async {
    await openApp(tester);
    await logFillUpOffline(tester);

    expect(
      find.text(
        "No connection. The fill-up is saved on this phone and will sync when you're back online.",
      ),
      findsOneWidget,
    );
    expect(container.read(fuelSyncProvider).pending, hasLength(1));
    await showWaiting(tester);
    expect(find.text('Waiting to sync'), findsOneWidget);
    expect(find.text('Not synced yet'), findsOneWidget);
    expect(find.text('30 L · Rs. 10,950'), findsOneWidget);

    fuel.offline = false;
    await tester.tap(find.text('Sync now'));
    await tester.pumpAndSettle();

    expect(find.text('Waiting to sync'), findsNothing);
    expect(fuel.createdIds, hasLength(1));
  });

  testWidgets('a refused fill-up says why and can be discarded', (
    tester,
  ) async {
    await openApp(tester);
    await logFillUpOffline(tester);
    fuel.offline = false;
    fuel.rejection = const ApiProblemException(
      statusCode: 422,
      code: ApiErrorCodes.odometerOutOfOrder,
    );
    await showWaiting(tester);

    await tester.tap(find.text('Sync now'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining("the odometer doesn't fit the readings"),
      findsOneWidget,
    );

    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard').last);
    await tester.pumpAndSettle();
    expect(find.text('Waiting to sync'), findsNothing);
    expect(store.storedDrafts, isEmpty);
  });

  testWidgets('the app says when it shows saved data', (tester) async {
    await openApp(tester);
    expect(find.textContaining("You're offline"), findsNothing);

    container.read(connectionStatusProvider.notifier).lostServer();
    await tester.pumpAndSettle();
    expect(
      find.text("You're offline. Showing what was saved on this phone."),
      findsOneWidget,
    );

    container.read(connectionStatusProvider.notifier).reachedServer();
    await tester.pumpAndSettle();
    expect(find.textContaining("You're offline"), findsNothing);
  });

  testWidgets('signing out warns about unsynced fill-ups and clears them', (
    tester,
  ) async {
    await openApp(tester);
    await logFillUpOffline(tester);
    // Let the "saved on this phone" message go away.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Garage').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out without syncing?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(store.storedDrafts, hasLength(1));

    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out').last);
    await tester.pumpAndSettle();

    expect(store.storedDrafts, isEmpty);
    expect(find.text('Welcome back'), findsOneWidget);
  });
}
