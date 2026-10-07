package com.drivon.api.common.stats;

import java.math.BigDecimal;
import java.time.YearMonth;

/** Repository projection: a total for one calendar month, from a {@code GROUP BY} query. */
public interface MonthlySum {

  Integer getYear();

  Integer getMonth();

  BigDecimal getTotal();

  default YearMonth yearMonth() {
    return YearMonth.of(getYear(), getMonth());
  }
}
