package com.drivon.api.fuel;

import java.math.BigDecimal;
import java.time.YearMonth;

/**
 * What a vehicle's fuel cost per litre in one month.
 *
 * @param averagePricePerLitre total paid ÷ litres bought, so bigger fill-ups weigh more
 */
public record FuelPriceMonth(
    YearMonth month,
    BigDecimal averagePricePerLitre,
    BigDecimal lowestPricePerLitre,
    BigDecimal highestPricePerLitre,
    long fillUps) {}
