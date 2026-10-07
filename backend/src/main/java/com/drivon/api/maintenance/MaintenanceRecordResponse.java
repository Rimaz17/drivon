package com.drivon.api.maintenance;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;
import org.jspecify.annotations.Nullable;

public record MaintenanceRecordResponse(
    UUID id,
    UUID vehicleId,
    ServiceType serviceType,
    LocalDate date,
    @Nullable Integer odometerKm,
    BigDecimal cost,
    @Nullable String notes,
    @Nullable LocalDate nextServiceDate,
    @Nullable Integer nextServiceKm,
    Instant createdAt,
    Instant updatedAt) {

  static MaintenanceRecordResponse from(MaintenanceRecord record) {
    return new MaintenanceRecordResponse(
        record.getId(),
        record.getVehicleId(),
        record.getServiceType(),
        record.getDate(),
        record.getOdometerKm(),
        record.getCost(),
        record.getNotes(),
        record.getNextServiceDate(),
        record.getNextServiceKm(),
        record.getCreatedAt(),
        record.getUpdatedAt());
  }
}
