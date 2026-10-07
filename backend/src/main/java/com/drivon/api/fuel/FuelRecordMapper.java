package com.drivon.api.fuel;

import java.math.BigDecimal;
import org.jspecify.annotations.Nullable;

final class FuelRecordMapper {

  private FuelRecordMapper() {}

  static FuelRecordResponse toResponse(FuelRecord record, @Nullable BigDecimal kmPerLitre) {
    return new FuelRecordResponse(
        record.getId(),
        record.getVehicleId(),
        record.getDate(),
        record.getLitres(),
        record.getAmount(),
        record.getPricePerLitre(),
        record.getOdometerKm(),
        record.isFullTank(),
        record.getStation(),
        kmPerLitre,
        record.getCreatedAt(),
        record.getUpdatedAt());
  }
}
