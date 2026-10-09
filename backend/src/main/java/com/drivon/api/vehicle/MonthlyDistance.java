package com.drivon.api.vehicle;

import java.time.YearMonth;

/**
 * Kilometres driven in one calendar month, from the odometer timeline.
 *
 * @param month serialized as {@code "2026-10"}
 */
public record MonthlyDistance(YearMonth month, int distanceKm) {}
