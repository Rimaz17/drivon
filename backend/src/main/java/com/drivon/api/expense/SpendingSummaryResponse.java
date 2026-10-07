package com.drivon.api.expense;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

/**
 * Everything spent on a vehicle in a date range, by category.
 *
 * @param from start of the range; 1900-01-01 when the request left it open
 * @param to end of the range; today when the request left it open
 * @param categories every category, largest first; FUEL includes fill-ups and MAINTENANCE includes
 *     services
 */
public record SpendingSummaryResponse(
    LocalDate from, LocalDate to, BigDecimal total, List<CategoryTotal> categories) {

  /**
   * @param count how many records (fill-ups, services, expenses) make up the total
   */
  public record CategoryTotal(ExpenseCategory category, BigDecimal total, long count) {}
}
