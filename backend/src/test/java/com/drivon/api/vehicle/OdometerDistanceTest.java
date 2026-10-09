package com.drivon.api.vehicle;

import static org.assertj.core.api.Assertions.assertThat;

import com.drivon.api.vehicle.OdometerDistance.MonthSpan;
import java.time.YearMonth;
import java.util.List;
import org.junit.jupiter.api.Test;

class OdometerDistanceTest {

  private static final YearMonth OCTOBER = YearMonth.of(2026, 10);

  @Test
  void aPeriodWithoutAnyReadingsHasNoDistance() {
    assertThat(OdometerDistance.between(null, null, null)).isZero();
  }

  @Test
  void countsFromTheLastReadingBeforeThePeriod() {
    assertThat(OdometerDistance.between(45_000, 45_400, 46_200)).isEqualTo(1_200);
  }

  @Test
  void aVehicleAddedDuringThePeriodCountsFromItsFirstReading() {
    assertThat(OdometerDistance.between(null, 46_000, 46_500)).isEqualTo(500);
  }

  @Test
  void noReadingsInThePeriodMeansNoDistanceEvenWithEarlierOnes() {
    // The odometer at the end of the period is still the earlier reading.
    assertThat(OdometerDistance.between(45_000, null, 45_000)).isZero();
  }

  @Test
  void neverReportsANegativeDistance() {
    assertThat(OdometerDistance.between(46_000, 45_900, 45_900)).isZero();
  }

  @Test
  void splitsDistanceByMonthAndZeroFillsQuietMonths() {
    List<MonthlyDistance> months =
        OdometerDistance.byMonth(
            OCTOBER,
            4,
            44_000,
            List.of(
                new MonthSpan(YearMonth.of(2026, 7), 44_100, 44_900),
                new MonthSpan(YearMonth.of(2026, 9), 45_200, 46_000)));

    assertThat(months)
        .containsExactly(
            new MonthlyDistance(YearMonth.of(2026, 7), 900),
            new MonthlyDistance(YearMonth.of(2026, 8), 0),
            // Driven across August and September; the September reading reveals it.
            new MonthlyDistance(YearMonth.of(2026, 9), 1_100),
            new MonthlyDistance(OCTOBER, 0));
  }

  @Test
  void theFirstMonthOfANewVehicleCountsFromItsInitialReading() {
    List<MonthlyDistance> months =
        OdometerDistance.byMonth(OCTOBER, 2, null, List.of(new MonthSpan(OCTOBER, 46_000, 46_750)));

    assertThat(months)
        .containsExactly(
            new MonthlyDistance(YearMonth.of(2026, 9), 0), new MonthlyDistance(OCTOBER, 750));
  }

  @Test
  void crossesYearBoundaries() {
    List<MonthlyDistance> months =
        OdometerDistance.byMonth(
            YearMonth.of(2027, 1),
            2,
            10_000,
            List.of(
                new MonthSpan(YearMonth.of(2026, 12), 10_100, 10_400),
                new MonthSpan(YearMonth.of(2027, 1), 10_500, 10_600)));

    assertThat(months).extracting(MonthlyDistance::distanceKm).containsExactly(400, 200);
  }
}
