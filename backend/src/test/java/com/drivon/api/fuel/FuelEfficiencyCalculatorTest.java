package com.drivon.api.fuel;

import static org.assertj.core.api.Assertions.assertThat;

import com.drivon.api.fuel.FuelEfficiencyCalculator.Summary;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class FuelEfficiencyCalculatorTest {

  private static int day = 0;

  private static FuelFill full(int odometer, String litres, String amount) {
    return fill(odometer, litres, amount, true);
  }

  private static FuelFill partial(int odometer, String litres, String amount) {
    return fill(odometer, litres, amount, false);
  }

  private static FuelFill fill(int odometer, String litres, String amount, boolean full) {
    return new FuelFill(
        UUID.randomUUID(),
        LocalDate.of(2026, 9, 1).plusDays(day++),
        odometer,
        new BigDecimal(litres),
        new BigDecimal(amount),
        full);
  }

  @Test
  void noFillsMeanNoStretches() {
    assertThat(FuelEfficiencyCalculator.intervals(List.of())).isEmpty();
    assertThat(FuelEfficiencyCalculator.summarize(List.of())).isEqualTo(Summary.EMPTY);
  }

  @Test
  void aSingleFullFillIsOnlyAStartingPoint() {
    assertThat(FuelEfficiencyCalculator.intervals(List.of(full(10_000, "35.000", "12775.00"))))
        .isEmpty();
  }

  @Test
  void calculatesEfficiencyBetweenTwoFullFills() {
    FuelFill first = full(10_000, "35.000", "12775.00");
    FuelFill second = full(10_450, "30.000", "10950.00");

    List<FuelInterval> intervals = FuelEfficiencyCalculator.intervals(List.of(first, second));

    assertThat(intervals).hasSize(1);
    FuelInterval interval = intervals.get(0);
    assertThat(interval.closingFillId()).isEqualTo(second.id());
    assertThat(interval.startDate()).isEqualTo(first.date());
    assertThat(interval.endDate()).isEqualTo(second.date());
    assertThat(interval.distanceKm()).isEqualTo(450);
    // The first fill's litres were burned before this stretch and don't count.
    assertThat(interval.litres()).isEqualByComparingTo("30");
    assertThat(interval.amount()).isEqualByComparingTo("10950");
    assertThat(interval.kmPerLitre()).isEqualByComparingTo("15.00");
  }

  @Test
  void partialFillsBetweenFullFillsCountTowardsTheStretch() {
    FuelFill closing = full(10_500, "15.000", "5475.00");
    List<FuelInterval> intervals =
        FuelEfficiencyCalculator.intervals(
            List.of(
                full(10_000, "35.000", "12775.00"), partial(10_200, "10.000", "3650.00"), closing));

    assertThat(intervals).hasSize(1);
    assertThat(intervals.get(0).closingFillId()).isEqualTo(closing.id());
    assertThat(intervals.get(0).litres()).isEqualByComparingTo("25");
    assertThat(intervals.get(0).amount()).isEqualByComparingTo("9125");
    assertThat(intervals.get(0).kmPerLitre()).isEqualByComparingTo("20.00");
  }

  @Test
  void partialFillsBeforeTheFirstFullFillAreIgnored() {
    List<FuelInterval> intervals =
        FuelEfficiencyCalculator.intervals(
            List.of(
                partial(9_800, "5.000", "1825.00"),
                full(10_000, "30.000", "10950.00"),
                full(10_300, "20.000", "7300.00")));

    assertThat(intervals)
        .singleElement()
        .satisfies(i -> assertThat(i.litres()).isEqualByComparingTo("20"));
  }

  @Test
  void partialFillsAfterTheLastFullFillWaitForTheNextOne() {
    List<FuelFill> fills =
        List.of(
            full(10_000, "30.000", "10950.00"),
            full(10_300, "20.000", "7300.00"),
            partial(10_400, "8.000", "2920.00"));

    assertThat(FuelEfficiencyCalculator.intervals(fills)).hasSize(1);
    assertThat(
            FuelEfficiencyCalculator.summarize(FuelEfficiencyCalculator.intervals(fills)).litres())
        .isEqualByComparingTo("20");
  }

  @Test
  void aStretchWithNoDistanceIsSkippedAndTheChainRestarts() {
    FuelFill closing = full(10_400, "20.000", "7300.00");
    List<FuelInterval> intervals =
        FuelEfficiencyCalculator.intervals(
            List.of(full(10_000, "30.000", "10950.00"), full(10_000, "0.500", "182.50"), closing));

    assertThat(intervals)
        .singleElement()
        .satisfies(
            i -> {
              assertThat(i.closingFillId()).isEqualTo(closing.id());
              assertThat(i.distanceKm()).isEqualTo(400);
              assertThat(i.litres()).isEqualByComparingTo("20");
            });
  }

  @Test
  void consecutiveStretchesEachGetTheirOwnEfficiency() {
    List<FuelInterval> intervals =
        FuelEfficiencyCalculator.intervals(
            List.of(
                full(10_000, "30.000", "10950.00"),
                full(10_300, "20.000", "7300.00"),
                partial(10_350, "5.000", "1825.00"),
                full(10_400, "5.000", "1825.00")));

    assertThat(intervals)
        .extracting(FuelInterval::kmPerLitre)
        .usingElementComparator(BigDecimal::compareTo)
        .containsExactly(new BigDecimal("15.00"), new BigDecimal("10.00"));
  }

  @Test
  void theAverageIsWeightedByDistanceNotAMeanOfRatios() {
    Summary summary =
        FuelEfficiencyCalculator.summarize(
            FuelEfficiencyCalculator.intervals(
                List.of(
                    full(10_000, "30.000", "10950.00"),
                    full(10_300, "20.000", "7300.00"), // 15 km/L
                    full(10_400, "10.000", "3650.00")))); // 10 km/L

    // 400 km / 30 L, not (15 + 10) / 2.
    assertThat(summary.averageKmPerLitre()).isEqualByComparingTo("13.33");
    assertThat(summary.bestKmPerLitre()).isEqualByComparingTo("15.00");
    assertThat(summary.latestKmPerLitre()).isEqualByComparingTo("10.00");
    assertThat(summary.distanceKm()).isEqualTo(400);
    assertThat(summary.litres()).isEqualByComparingTo("30");
    assertThat(summary.amount()).isEqualByComparingTo("10950");
    // Rs. 10,950 over 400 km.
    assertThat(summary.costPerKm()).isEqualByComparingTo("27.38");
  }

  @Test
  void ratiosAreRoundedHalfUpToTwoDecimals() {
    Summary summary =
        FuelEfficiencyCalculator.summarize(
            FuelEfficiencyCalculator.intervals(
                List.of(full(0, "10.000", "1.00"), full(200, "3.000", "1095.00"))));

    // 200 / 3 = 66.666…, 1095 / 200 = 5.475
    assertThat(summary.averageKmPerLitre()).isEqualByComparingTo("66.67");
    assertThat(summary.costPerKm()).isEqualByComparingTo("5.48");
  }

  @Test
  void fractionalLitresAreExact() {
    List<FuelInterval> intervals =
        FuelEfficiencyCalculator.intervals(
            List.of(
                full(0, "1.000", "1.00"),
                partial(100, "4.125", "1.00"),
                full(250, "5.875", "1.00")));

    assertThat(intervals.get(0).litres()).isEqualByComparingTo("10.000");
    assertThat(intervals.get(0).kmPerLitre()).isEqualByComparingTo("25.00");
  }
}
