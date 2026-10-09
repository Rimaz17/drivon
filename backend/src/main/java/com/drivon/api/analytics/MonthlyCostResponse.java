package com.drivon.api.analytics;

import java.math.BigDecimal;
import java.time.YearMonth;
import org.jspecify.annotations.Nullable;

/**
 * One month's running cost, split like {@link CostGroup}, with the distance driven.
 *
 * @param month serialized as {@code "2026-10"}
 * @param costPerKm null when no distance was recorded that month
 */
public record MonthlyCostResponse(
    YearMonth month,
    BigDecimal fuel,
    BigDecimal maintenance,
    BigDecimal other,
    BigDecimal total,
    int distanceKm,
    @Nullable BigDecimal costPerKm) {}
