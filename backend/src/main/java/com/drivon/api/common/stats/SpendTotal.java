package com.drivon.api.common.stats;

import java.math.BigDecimal;

/**
 * What was spent on a kind of record in a period, and how many records it covers.
 *
 * @param amount rupees, scale 2
 */
public record SpendTotal(BigDecimal amount, long count) {}
