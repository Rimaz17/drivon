import 'package:freezed_annotation/freezed_annotation.dart';

import '../domain/fuel_type.dart';
import '../domain/vehicle.dart';

part 'vehicle_dto.freezed.dart';
part 'vehicle_dto.g.dart';

/// `VehicleResponse` from the API.
@freezed
abstract class VehicleDto with _$VehicleDto {
  const factory VehicleDto({
    required String id,
    required String make,
    required String model,
    required int year,
    required String registrationNumber,
    required String fuelType,
    required int currentOdometerKm,
  }) = _VehicleDto;

  const VehicleDto._();

  factory VehicleDto.fromJson(Map<String, dynamic> json) =>
      _$VehicleDtoFromJson(json);

  Vehicle toDomain() => Vehicle(
    id: id,
    make: make,
    model: model,
    year: year,
    registrationNumber: registrationNumber,
    fuelType: FuelType.fromWire(fuelType),
    currentOdometerKm: currentOdometerKm,
  );
}

/// `VehicleRequest` body for create and update.
Map<String, dynamic> vehicleRequestJson(VehicleDraft draft) => {
  'make': draft.make.trim(),
  'model': draft.model.trim(),
  'year': draft.year,
  'registrationNumber': draft.registrationNumber.trim(),
  'fuelType': draft.fuelType.wireValue,
  'currentOdometerKm': draft.currentOdometerKm,
};
