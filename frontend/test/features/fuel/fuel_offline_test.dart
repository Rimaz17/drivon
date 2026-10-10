import 'package:drivon/core/errors/app_exception.dart';
import 'package:drivon/core/storage/token_store.dart';
import 'package:drivon/features/fuel/data/fuel_dto.dart';
import 'package:drivon/features/fuel/domain/fuel_record.dart';
import 'package:drivon/features/fuel/presentation/fuel_controllers.dart';
import 'package:drivon/features/fuel/presentation/fuel_sync_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import '../../support/offline_fakes.dart';
import '../../support/test_app.dart';
import '../vehicles/vehicle_test_doubles.dart';
import 'fuel_test_doubles.dart';

/// A fuel API whose writes fail while [offline], or once with [rejection].
class FlakyFuelApi extends FakeFuelApi {
  bool offline = true;
  AppException? rejection;
  final List<String> attemptedIds = [];

  @override
  Future<FuelRecordDto> create(
    String vehicleId,
    FuelDraft draft, {
    required String id,
  }) async {
    attemptedIds.add(id);
    if (offline) throw const NoConnectionException();
    final refused = rejection;
    if (refused != null) {
      rejection = null;
      throw refused;
    }
    return super.create(vehicleId, draft, id: id);
  }
}

void main() {
  late FlakyFuelApi fuel;
  late InMemoryLocalStore store;
  late FakeNetworkMonitor network;

  setUp(() {
    fuel = FlakyFuelApi();
    store = InMemoryLocalStore();
    network = FakeNetworkMonitor();
  });

  Future<void> settle() async {
    for (var i = 0; i < 10; i++) {
      await pumpEventQueue();
    }
  }

  Future<ProviderContainer> signedIn() async {
    final container = ProviderContainer(
      overrides: testOverrides(
        tokens: InMemoryTokenStore(
          const AuthTokens(accessToken: 'a', refreshToken: 'r'),
        ),
        vehicleApi: FakeVehicleApi([vehicleDto()]),
        fuelApi: fuel,
        localStore: store,
        networkMonitor: network,
      ),
    );
    addTearDown(container.dispose);
    container.listen(fuelSyncProvider, (_, _) {});
    await settle();
    return container;
  }

  test('a fill-up logged offline is kept and sent once back online', () async {
    final container = await signedIn();

    final saved = await container
        .read(fuelMutationsProvider)
        .add('vehicle-1', fuelDraft());

    expect(saved, isNull);
    final pending = container.read(fuelSyncProvider).pending;
    expect(pending.single.vehicleId, 'vehicle-1');
    expect(pending.single.draft, fuelDraft());
    expect(store.storedDrafts, hasLength(1));

    fuel.offline = false;
    network.connect();
    await settle();

    expect(container.read(fuelSyncProvider).pending, isEmpty);
    expect(store.storedDrafts, isEmpty);
    // The same ID both times: the server can't save it twice.
    expect(fuel.createdIds.single, pending.single.id);
    expect(fuel.attemptedIds.toSet(), {pending.single.id});
  });

  test('waiting fill-ups survive a restart and sync at sign-in', () async {
    final first = await signedIn();
    await first.read(fuelMutationsProvider).add('vehicle-1', fuelDraft());
    first.dispose();

    fuel.offline = false;
    final second = await signedIn();

    expect(second.read(fuelSyncProvider).pending, isEmpty);
    expect(fuel.createdIds, hasLength(1));
  });

  test('a fill-up the server refuses waits with the reason', () async {
    final container = await signedIn();
    await container.read(fuelMutationsProvider).add('vehicle-1', fuelDraft());
    fuel
      ..offline = false
      ..rejection = const ApiProblemException(
        statusCode: 422,
        code: ApiErrorCodes.odometerOutOfOrder,
        detail: 'For this date the odometer must be at most 9,000 km.',
      );

    await container.read(fuelSyncProvider.notifier).syncNow();

    final refused = container.read(fuelSyncProvider).pending.single;
    expect(refused.rejected, isTrue);
    expect(refused.rejection!.code, ApiErrorCodes.odometerOutOfOrder);
    expect(store.storedDrafts.values.single.error, isNotNull);

    // Not sent again on its own…
    network.connect();
    await settle();
    expect(fuel.attemptedIds, hasLength(2));

    // …only when the user retries.
    await container.read(fuelSyncProvider.notifier).retry(refused.id);
    expect(container.read(fuelSyncProvider).pending, isEmpty);
    expect(fuel.createdIds, [refused.id]);
  });

  test('a server error leaves fill-ups waiting', () async {
    final container = await signedIn();
    await container.read(fuelMutationsProvider).add('vehicle-1', fuelDraft());
    fuel
      ..offline = false
      ..rejection = const ApiProblemException(
        statusCode: 503,
        code: 'INTERNAL_ERROR',
      );

    await container.read(fuelSyncProvider.notifier).syncNow();

    expect(container.read(fuelSyncProvider).pending.single.rejected, isFalse);
  });

  test('a discarded fill-up is gone', () async {
    final container = await signedIn();
    await container.read(fuelMutationsProvider).add('vehicle-1', fuelDraft());
    final id = container.read(fuelSyncProvider).pending.single.id;

    await container.read(fuelSyncProvider.notifier).discard(id);

    expect(container.read(fuelSyncProvider).pending, isEmpty);
    expect(store.storedDrafts, isEmpty);
  });

  test('the draft round-trips through its stored form', () {
    final draft = fuelDraft(station: null);

    expect(fuelDraftFromRequestJson(fuelRequestJson(draft)), draft);
  });
}
