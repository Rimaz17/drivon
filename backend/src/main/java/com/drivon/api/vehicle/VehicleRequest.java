package com.drivon.api.vehicle;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/** Body for creating or fully replacing a vehicle. */
public record VehicleRequest(
    @NotBlank @Size(max = 50) String make,
    @NotBlank @Size(max = 50) String model,
    @NotNull @Min(1900) @Max(2100) Integer year,
    @NotBlank @Size(max = 20) @Pattern(
            regexp = "^[A-Za-z0-9][A-Za-z0-9 -]*$",
            message = "may contain only letters, digits, spaces and hyphens")
        String registrationNumber,
    @NotNull FuelType fuelType,
    @NotNull @Min(0) @Max(2_000_000) Integer currentOdometerKm) {}
