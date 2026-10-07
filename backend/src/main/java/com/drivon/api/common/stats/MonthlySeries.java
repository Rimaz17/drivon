package com.drivon.api.common.stats;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.YearMonth;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Stream;

/** Builds month-by-month series from {@code GROUP BY} month sums, for charts and trend lists. */
public final class MonthlySeries {

  private MonthlySeries() {}

  /**
   * One total for each of the {@code count} months ending with {@code last}, oldest first. Sums for
   * the same month (e.g. from different tables) are added up; months without data are zero.
   */
  public static List<MonthlyAmount> of(
      YearMonth last, int count, Collection<? extends MonthlySum> sums) {
    Map<YearMonth, BigDecimal> totals = new HashMap<>();
    for (MonthlySum sum : sums) {
      totals.merge(sum.yearMonth(), sum.getTotal(), BigDecimal::add);
    }
    YearMonth first = last.minusMonths(count - 1L);
    return Stream.iterate(first, month -> month.plusMonths(1))
        .limit(count)
        .map(
            month ->
                new MonthlyAmount(
                    month,
                    totals.getOrDefault(month, BigDecimal.ZERO).setScale(2, RoundingMode.HALF_UP)))
        .toList();
  }

  /** The oldest month in a series of {@code count} months ending with {@code last}. */
  public static YearMonth firstMonth(YearMonth last, int count) {
    return last.minusMonths(count - 1L);
  }
}
