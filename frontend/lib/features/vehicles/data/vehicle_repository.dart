import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/vehicle.dart';
import 'vehicle_api.dart';

/// The signed-in user's vehicles. The server is the source of truth.
class VehicleRepository {
  VehicleRepository(this._api);

  final VehicleApi _api;

  Future<List<Vehicle>> list() async =>
      (await _api.list()).map((dto) => dto.toDomain()).toList();

  Future<Vehicle> create(VehicleDraft draft) async =>
      (await _api.create(draft)).toDomain();

  Future<Vehicle> update(String id, VehicleDraft draft) async =>
      (await _api.update(id, draft)).toDomain();

  Future<void> delete(String id) => _api.delete(id);
}

final vehicleRepositoryProvider = Provider<VehicleRepository>(
  (ref) => VehicleRepository(ref.watch(vehicleApiProvider)),
);
