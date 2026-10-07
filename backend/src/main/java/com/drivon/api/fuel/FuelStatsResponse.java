package com.drivon.api.fuel;

import java.math.BigDecimal;
import java.time.LocalDate;
import org.jspecify.annotations.Nullable;

/**
 * Fuel figures for a date range. Spend, litres and fill-ups count every fill-up dated in the range.
 * Efficiency figures use the full-to-full stretches that ended in the range, and are null until the
 * vehicle has two full fills.
 *
 * @param from start of the range; 1900-01-01 when the request left it open
 * @param to end of the range; today when the request left it open
 * @param averageKmPerLitre total distance over total litres of those stretches
 * @param bestKmPerLitre the most efficient stretch
 * @param latestKmPerLitre the stretch that ended last
 * @param costPerKm fuel cost per km over those stretches
 * @param trackedDistanceKm distance covered by those stretches
 */
public record FuelStatsResponse(
    LocalDate from,
    LocalDate to,
    BigDecimal totalSpend,
    BigDecimal totalLitres,
    long fillUps,
    @Nullable BigDecimal averageKmPerLitre,
    @Nullable BigDecimal bestKmPerLitre,
    @Nullable BigDecimal latestKmPerLitre,
    @Nullable BigDecimal costPerKm,
    int trackedDistanceKm) {}
