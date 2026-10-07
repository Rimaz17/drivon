package com.drivon.api.common.stats;

import static org.assertj.core.api.Assertions.assertThat;

import java.math.BigDecimal;
import java.time.YearMonth;
import java.util.List;
import org.junit.jupiter.api.Test;

class MonthlySeriesTest {

  private static MonthlySum sum(int year, int month, String total) {
    return new MonthlySum() {
      @Override
      public Integer getYear() {
        return year;
      }

      @Override
      public Integer getMonth() {
        return month;
      }

      @Override
      public BigDecimal getTotal() {
        return new BigDecimal(total);
      }
    };
  }

  @Test
  void fillsMissingMonthsWithZeroOldestFirstAcrossAYearBoundary() {
    List<MonthlyAmount> series =
        MonthlySeries.of(YearMonth.of(2026, 2), 4, List.of(sum(2026, 1, "18500.5")));

    assertThat(series)
        .extracting(MonthlyAmount::month)
        .containsExactly(
            YearMonth.of(2025, 11),
            YearMonth.of(2025, 12),
            YearMonth.of(2026, 1),
            YearMonth.of(2026, 2));
    assertThat(series)
        .extracting(m -> m.total().toPlainString())
        .containsExactly("0.00", "0.00", "18500.50", "0.00");
  }

  @Test
  void addsUpSumsForTheSameMonthAndIgnoresMonthsOutsideTheSeries() {
    List<MonthlyAmount> series =
        MonthlySeries.of(
            YearMonth.of(2026, 10),
            1,
            List.of(sum(2026, 10, "100.00"), sum(2026, 10, "250.25"), sum(2026, 9, "999")));

    assertThat(series)
        .singleElement()
        .satisfies(m -> assertThat(m.total()).isEqualByComparingTo("350.25"));
  }

  @Test
  void theFirstMonthCountsBackFromTheLast() {
    assertThat(MonthlySeries.firstMonth(YearMonth.of(2026, 3), 6))
        .isEqualTo(YearMonth.of(2025, 10));
  }
}
