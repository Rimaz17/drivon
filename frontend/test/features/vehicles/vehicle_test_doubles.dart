import 'package:drivon/core/errors/app_exception.dart';
import 'package:drivon/features/vehicles/data/selected_vehicle_store.dart';
import 'package:drivon/features/vehicles/data/vehicle_api.dart';
import 'package:drivon/features/vehicles/data/vehicle_dto.dart';
import 'package:drivon/features/vehicles/domain/vehicle.dart';

VehicleDto vehicleDto({
  String id = 'vehicle-1',
  String make = 'Toyota',
  String model = 'Aqua',
  int year = 2018,
  String registrationNumber = 'CAB-1234',
  String fuelType = 'HYBRID',
  int currentOdometerKm = 45000,
}) => VehicleDto(
  id: id,
  make: make,
  model: model,
  year: year,
  registrationNumber: registrationNumber,
  fuelType: fuelType,
  currentOdometerKm: currentOdometerKm,
);

/// In-memory [VehicleApi] with the server's main rules, for tests.
class FakeVehicleApi implements VehicleApi {
  FakeVehicleApi([List<VehicleDto>? vehicles]) : vehicles = vehicles ?? [];

  final List<VehicleDto> vehicles;

  /// When set, the next call throws it once.
  AppException? nextError;
  int listCalls = 0;
  int _ids = 100;

  @override
  Future<List<VehicleDto>> list() async {
    listCalls++;
    _throwIfScripted();
    return List.of(vehicles);
  }

  @override
  Future<VehicleDto> create(VehicleDraft draft) async {
    _throwIfScripted();
    if (vehicles.length >= maxVehiclesPerUser) {
      throw const ApiProblemException(
        statusCode: 422,
        code: ApiErrorCodes.vehicleLimitReached,
      );
    }
    final dto = _fromDraft('vehicle-${_ids++}', draft);
    vehicles.add(dto);
    return dto;
  }

  @override
  Future<VehicleDto> update(String id, VehicleDraft draft) async {
    _throwIfScripted();
    final index = vehicles.indexWhere((v) => v.id == id);
    final dto = _fromDraft(id, draft);
    vehicles[index] = dto;
    return dto;
  }

  @override
  Future<void> delete(String id) async {
    _throwIfScripted();
    vehicles.removeWhere((v) => v.id == id);
  }

  void _throwIfScripted() {
    final error = nextError;
    if (error != null) {
      nextError = null;
      throw error;
    }
  }

  static VehicleDto _fromDraft(String id, VehicleDraft draft) => VehicleDto(
    id: id,
    make: draft.make,
    model: draft.model,
    year: draft.year,
    registrationNumber: draft.registrationNumber.toUpperCase(),
    fuelType: draft.fuelType.wireValue,
    currentOdometerKm: draft.currentOdometerKm,
  );
}

class InMemorySelectedVehicleStore implements SelectedVehicleStore {
  final Map<String, String> selections = {};

  @override
  Future<String?> read(String userId) async => selections[userId];

  @override
  Future<void> write(String userId, String vehicleId) async =>
      selections[userId] = vehicleId;

  @override
  Future<void> clear() async => selections.clear();
}
