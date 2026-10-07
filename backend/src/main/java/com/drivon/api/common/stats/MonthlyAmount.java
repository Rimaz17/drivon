package com.drivon.api.common.stats;

import java.math.BigDecimal;
import java.time.YearMonth;

/**
 * A money total for one calendar month.
 *
 * @param month serialized as {@code "2026-10"}
 */
public record MonthlyAmount(YearMonth month, BigDecimal total) {}
