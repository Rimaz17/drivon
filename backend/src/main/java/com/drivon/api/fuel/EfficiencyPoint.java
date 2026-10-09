package com.drivon.api.fuel;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;

/**
 * One tank's efficiency: the stretch between two full-tank fills (full-tank method).
 *
 * @param startDate date of the full fill that started the stretch
 * @param endDate date of the full fill that closed it; charts plot the point here
 * @param litres fuel added after the starting fill, up to and including the closing one
 * @param costPerKm what that fuel cost per km driven
 */
public record EfficiencyPoint(
    LocalDate startDate,
    LocalDate endDate,
    int distanceKm,
    BigDecimal litres,
    BigDecimal kmPerLitre,
    BigDecimal costPerKm) {

  static EfficiencyPoint from(FuelInterval interval) {
    return new EfficiencyPoint(
        interval.startDate(),
        interval.endDate(),
        interval.distanceKm(),
        interval.litres().setScale(3, RoundingMode.HALF_UP),
        interval.kmPerLitre(),
        interval
            .amount()
            .divide(BigDecimal.valueOf(interval.distanceKm()), 2, RoundingMode.HALF_UP));
  }
}
