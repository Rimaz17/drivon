import 'package:drivon/core/errors/app_exception.dart';
import 'package:drivon/core/storage/token_store.dart';
import 'package:drivon/features/auth/presentation/session_controller.dart';
import 'package:drivon/features/fuel/presentation/fuel_controllers.dart';
import 'package:drivon/features/vehicles/presentation/vehicles_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import '../../support/test_app.dart';
import '../vehicles/vehicle_test_doubles.dart';
import 'fuel_test_doubles.dart';

void main() {
  late FakeFuelApi fuel;
  late FakeVehicleApi vehicles;
  late ProviderContainer container;

  Future<void> signedIn() async {
    container = ProviderContainer(
      overrides: testOverrides(
        tokens: InMemoryTokenStore(
          const AuthTokens(accessToken: 'a', refreshToken: 'r'),
        ),
        vehicleApi: vehicles,
        fuelApi: fuel,
      ),
    );
    addTearDown(container.dispose);
    container.read(sessionControllerProvider);
    await pumpEventQueue();
    // Keep the auto-dispose providers alive for the whole test.
    container
      ..listen(fuelHistoryProvider('vehicle-1'), (_, _) {})
      ..listen(fuelSummaryProvider('vehicle-1'), (_, _) {})
      ..listen(vehiclesControllerProvider, (_, _) {});
  }

  setUp(() {
    vehicles = FakeVehicleApi([vehicleDto()]);
    fuel = FakeFuelApi(
      records: [
        for (var i = 0; i < 25; i++)
          fuelRecordDto(id: 'record-$i', odometerKm: 12000 - i * 100),
      ],
    );
  });

  test('loads fill-ups a page at a time', () async {
    await signedIn();

    var history = await container.read(fuelHistoryProvider('vehicle-1').future);
    expect(history.records, hasLength(20));
    expect(history.hasMore, isTrue);

    await container.read(fuelHistoryProvider('vehicle-1').notifier).loadMore();
    history = container.read(fuelHistoryProvider('vehicle-1')).value!;
    expect(history.records, hasLength(25));
    expect(history.records.last.id, 'record-24');
    expect(history.hasMore, isFalse);
  });

  test('a failed next page keeps the list and flags a retry', () async {
    await signedIn();
    await container.read(fuelHistoryProvider('vehicle-1').future);
    fuel.nextError = const NoConnectionException();

    await container.read(fuelHistoryProvider('vehicle-1').notifier).loadMore();

    final history = container.read(fuelHistoryProvider('vehicle-1')).value!;
    expect(history.records, hasLength(20));
    expect(history.loadMoreFailed, isTrue);
    expect(history.loadingMore, isFalse);
  });

  test(
    'logging a fill-up refreshes history, figures and the odometer',
    () async {
      await signedIn();
      await container.read(fuelHistoryProvider('vehicle-1').future);
      await container.read(fuelSummaryProvider('vehicle-1').future);
      await container.read(vehiclesControllerProvider.future);
      final statsCalls = fuel.statsCalls;
      final vehicleCalls = vehicles.listCalls;

      await container
          .read(fuelMutationsProvider)
          .add('vehicle-1', fuelDraft(odometerKm: 12100));
      await pumpEventQueue();

      final history = await container.read(
        fuelHistoryProvider('vehicle-1').future,
      );
      expect(history.records.first.odometerKm, 12100);
      await container.read(fuelSummaryProvider('vehicle-1').future);
      expect(fuel.statsCalls, statsCalls + 1);
      expect(vehicles.listCalls, vehicleCalls + 1);
      expect(fuel.createdIds.single, hasLength(36));
    },
  );

  test('editing and deleting go through the API', () async {
    await signedIn();
    await container.read(fuelHistoryProvider('vehicle-1').future);
    final mutations = container.read(fuelMutationsProvider);

    await mutations.edit('vehicle-1', 'record-0', fuelDraft(odometerKm: 12050));
    expect(fuel.records.first.odometerKm, 12050);

    await mutations.remove('vehicle-1', 'record-0');
    expect(fuel.records.any((r) => r.id == 'record-0'), isFalse);
  });

  test(
    'a rejected fill-up surfaces the API error and changes nothing',
    () async {
      await signedIn();
      await container.read(fuelHistoryProvider('vehicle-1').future);
      fuel.nextError = const ApiProblemException(
        statusCode: 422,
        code: ApiErrorCodes.odometerOutOfOrder,
      );

      await expectLater(
        container.read(fuelMutationsProvider).add('vehicle-1', fuelDraft()),
        throwsA(isA<ApiProblemException>()),
      );
      expect(fuel.records, hasLength(25));
    },
  );

  test('the record to edit comes from the loaded history first', () async {
    await signedIn();
    await container.read(fuelHistoryProvider('vehicle-1').future);
    final loaded = await container.read(
      fuelRecordProvider((vehicleId: 'vehicle-1', recordId: 'record-3')).future,
    );
    expect(loaded.odometerKm, 11700);

    // record-22 is on the second page, so it's fetched.
    final fetched = await container.read(
      fuelRecordProvider((
        vehicleId: 'vehicle-1',
        recordId: 'record-22',
      )).future,
    );
    expect(fetched.id, 'record-22');
  });
}
