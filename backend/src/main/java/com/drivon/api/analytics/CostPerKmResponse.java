package com.drivon.api.analytics;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import org.jspecify.annotations.Nullable;

/**
 * What a vehicle cost per kilometre driven in a date range: everything spent in the range
 * (fill-ups, services and expenses) over the distance its odometer advanced in the range.
 *
 * @param from start of the range; 1900-01-01 when the request left it open
 * @param to end of the range; today when the request left it open
 * @param costPerKm null when no distance was recorded in the range
 * @param breakdown fuel, maintenance and other, always in that order
 */
public record CostPerKmResponse(
    LocalDate from,
    LocalDate to,
    int distanceKm,
    BigDecimal totalCost,
    @Nullable BigDecimal costPerKm,
    List<GroupCost> breakdown) {}
