package com.drivon.api.fuel;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * Fill-ups at one station.
 *
 * @param averagePricePerLitre total paid there ÷ litres bought there
 */
public record FuelStationStats(
    String station,
    long fillUps,
    BigDecimal totalLitres,
    BigDecimal totalSpend,
    BigDecimal averagePricePerLitre,
    BigDecimal lowestPricePerLitre,
    BigDecimal highestPricePerLitre,
    LocalDate lastVisit) {}
