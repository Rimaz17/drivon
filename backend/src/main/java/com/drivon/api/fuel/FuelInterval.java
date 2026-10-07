package com.drivon.api.fuel;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.util.UUID;

/**
 * The stretch driven between two full-tank fills: the fuel burned over it is everything added after
 * the first full fill, up to and including the second.
 *
 * @param closingFillId the full fill that ends the stretch; its record shows this km/L
 * @param startDate date of the full fill that starts the stretch
 * @param endDate date of the closing full fill
 * @param distanceKm odometer difference, always positive
 * @param litres fuel added after the starting fill, including the closing fill
 * @param amount what that fuel cost
 */
record FuelInterval(
    UUID closingFillId,
    LocalDate startDate,
    LocalDate endDate,
    int distanceKm,
    BigDecimal litres,
    BigDecimal amount) {

  BigDecimal kmPerLitre() {
    return BigDecimal.valueOf(distanceKm).divide(litres, 2, RoundingMode.HALF_UP);
  }
}
