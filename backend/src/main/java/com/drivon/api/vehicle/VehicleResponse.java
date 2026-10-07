package com.drivon.api.vehicle;

import java.time.Instant;
import java.util.UUID;

public record VehicleResponse(
    UUID id,
    String make,
    String model,
    int year,
    String registrationNumber,
    FuelType fuelType,
    int currentOdometerKm,
    Instant createdAt,
    Instant updatedAt) {}
