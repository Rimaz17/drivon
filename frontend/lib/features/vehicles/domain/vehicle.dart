import 'package:freezed_annotation/freezed_annotation.dart';

import 'fuel_type.dart';

part 'vehicle.freezed.dart';

/// Product rule: each user can keep at most two vehicles.
const int maxVehiclesPerUser = 2;

@freezed
abstract class Vehicle with _$Vehicle {
  const factory Vehicle({
    required String id,
    required String make,
    required String model,
    required int year,
    required String registrationNumber,
    required FuelType fuelType,
    required int currentOdometerKm,
  }) = _Vehicle;

  const Vehicle._();

  String get displayName => '$make $model';
}

/// The editable details of a vehicle, for creating or updating one.
@freezed
abstract class VehicleDraft with _$VehicleDraft {
  const factory VehicleDraft({
    required String make,
    required String model,
    required int year,
    required String registrationNumber,
    required FuelType fuelType,
    required int currentOdometerKm,
  }) = _VehicleDraft;
}
