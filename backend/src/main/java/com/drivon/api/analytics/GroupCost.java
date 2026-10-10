package com.drivon.api.analytics;

import java.math.BigDecimal;
import org.jspecify.annotations.Nullable;

/**
 * One part of a running cost.
 *
 * @param costPerKm that part's cost per km driven; null when no distance was recorded
 */
public record GroupCost(CostGroup group, BigDecimal total, @Nullable BigDecimal costPerKm) {}
