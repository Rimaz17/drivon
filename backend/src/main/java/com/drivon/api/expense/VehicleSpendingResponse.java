package com.drivon.api.expense;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/** What each of the user's vehicles cost in a date range, oldest vehicle first. */
public record VehicleSpendingResponse(
    LocalDate from, LocalDate to, BigDecimal total, List<VehicleTotal> vehicles) {

  public record VehicleTotal(
      UUID vehicleId, String make, String model, String registrationNumber, BigDecimal total) {}
}
