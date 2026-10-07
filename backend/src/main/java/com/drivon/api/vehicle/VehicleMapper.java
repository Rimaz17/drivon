package com.drivon.api.vehicle;

final class VehicleMapper {

  private VehicleMapper() {}

  static VehicleResponse toResponse(Vehicle vehicle) {
    return new VehicleResponse(
        vehicle.getId(),
        vehicle.getMake(),
        vehicle.getModel(),
        vehicle.getYear(),
        vehicle.getRegistrationNumber(),
        vehicle.getFuelType(),
        vehicle.getCurrentOdometerKm(),
        vehicle.getCreatedAt(),
        vehicle.getUpdatedAt());
  }
}
