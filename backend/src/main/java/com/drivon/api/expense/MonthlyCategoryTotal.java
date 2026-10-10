package com.drivon.api.expense;

import java.math.BigDecimal;
import java.time.YearMonth;

/**
 * What one spending category cost in one month.
 *
 * @param total rupees; fill-ups count as {@code FUEL} and services as {@code MAINTENANCE}
 */
public record MonthlyCategoryTotal(YearMonth month, ExpenseCategory category, BigDecimal total) {}
