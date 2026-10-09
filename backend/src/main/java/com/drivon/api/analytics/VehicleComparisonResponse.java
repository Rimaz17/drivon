package com.drivon.api.analytics;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;
import org.jspecify.annotations.Nullable;

/** The user's vehicles side by side for a date range, oldest vehicle first. */
public record VehicleComparisonResponse(LocalDate from, LocalDate to, List<VehicleCost> vehicles) {

  /**
   * @param costPerKm null when no distance was recorded in the range
   * @param breakdown fuel, maintenance and other, always in that order
   * @param averageKmPerLitre full-tank average over the range; null until two full fills
   */
  public record VehicleCost(
      UUID vehicleId,
      String make,
      String model,
      String registrationNumber,
      int distanceKm,
      BigDecimal totalCost,
      @Nullable BigDecimal costPerKm,
      List<GroupCost> breakdown,
      @Nullable BigDecimal averageKmPerLitre) {}
}
