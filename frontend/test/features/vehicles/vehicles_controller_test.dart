import 'package:drivon/core/errors/app_exception.dart';
import 'package:drivon/core/storage/token_store.dart';
import 'package:drivon/features/auth/presentation/session_controller.dart';
import 'package:drivon/features/vehicles/domain/fuel_type.dart';
import 'package:drivon/features/vehicles/domain/vehicle.dart';
import 'package:drivon/features/vehicles/presentation/vehicles_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import '../../support/test_app.dart';
import 'vehicle_test_doubles.dart';

const _draft = VehicleDraft(
  make: 'Honda',
  model: 'Dio',
  year: 2021,
  registrationNumber: 'bgh-4521',
  fuelType: FuelType.petrol,
  currentOdometerKm: 12000,
);

void main() {
  late FakeVehicleApi api;
  late InMemorySelectedVehicleStore selections;
  late ProviderContainer container;

  Future<void> signedInContainer() async {
    container = ProviderContainer(
      overrides: testOverrides(
        tokens: InMemoryTokenStore(
          const AuthTokens(accessToken: 'a', refreshToken: 'r'),
        ),
        vehicleApi: api,
        selections: selections,
      ),
    );
    addTearDown(container.dispose);
    container.read(sessionControllerProvider);
    await pumpEventQueue();
    expect(container.read(sessionControllerProvider), isA<SignedIn>());
  }

  setUp(() {
    api = FakeVehicleApi([vehicleDto()]);
    selections = InMemorySelectedVehicleStore();
  });

  test('loads the user\'s vehicles', () async {
    await signedInContainer();

    final vehicles = await container.read(vehiclesControllerProvider.future);

    expect(vehicles.single.displayName, 'Toyota Aqua');
    expect(vehicles.single.fuelType, FuelType.hybrid);
  });

  test('adds, edits and removes vehicles in place', () async {
    await signedInContainer();
    await container.read(vehiclesControllerProvider.future);
    final controller = container.read(vehiclesControllerProvider.notifier);

    final added = await controller.add(_draft);
    expect(container.read(vehiclesControllerProvider).value, hasLength(2));

    await controller.edit(added.id, _draft.copyWith(currentOdometerKm: 12500));
    expect(
      container.read(vehiclesControllerProvider).value!.last.currentOdometerKm,
      12500,
    );

    await controller.remove(added.id);
    expect(container.read(vehiclesControllerProvider).value, hasLength(1));
  });

  test('a rejected add leaves the list unchanged and reports why', () async {
    await signedInContainer();
    await container.read(vehiclesControllerProvider.future);
    api.nextError = const ApiProblemException(
      statusCode: 409,
      code: ApiErrorCodes.registrationNumberInUse,
    );

    await expectLater(
      container.read(vehiclesControllerProvider.notifier).add(_draft),
      throwsA(isA<ApiProblemException>()),
    );
    expect(container.read(vehiclesControllerProvider).value, hasLength(1));
  });

  test('shows the first vehicle until the user picks another', () async {
    api.vehicles.add(vehicleDto(id: 'vehicle-2', model: 'Dio'));
    await signedInContainer();
    await container.read(vehiclesControllerProvider.future);

    expect(container.read(selectedVehicleProvider)?.id, 'vehicle-1');

    await container
        .read(selectedVehicleIdProvider.notifier)
        .select('vehicle-2');

    expect(container.read(selectedVehicleProvider)?.id, 'vehicle-2');
    expect(selections.selections['user-1'], 'vehicle-2');
  });

  test('restores the remembered vehicle for this user', () async {
    api.vehicles.add(vehicleDto(id: 'vehicle-2', model: 'Dio'));
    selections.selections['user-1'] = 'vehicle-2';
    await signedInContainer();
    await container.read(vehiclesControllerProvider.future);
    container.read(selectedVehicleIdProvider);
    await pumpEventQueue();

    expect(container.read(selectedVehicleProvider)?.id, 'vehicle-2');
  });

  test('falls back to the first vehicle when the chosen one is gone', () async {
    selections.selections['user-1'] = 'deleted-vehicle';
    await signedInContainer();
    await container.read(vehiclesControllerProvider.future);
    container.read(selectedVehicleIdProvider);
    await pumpEventQueue();

    expect(container.read(selectedVehicleProvider)?.id, 'vehicle-1');
  });
}
