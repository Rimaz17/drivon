package com.drivon.api.fuel;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import org.jspecify.annotations.Nullable;

/**
 * Fuel efficiency by the full-tank method: when the tank is filled to full twice, the distance
 * between the two fills divided by the litres added after the first one (partial fills in between
 * plus the second full fill) is the km/L for that stretch.
 *
 * <ul>
 *   <li>Fills before the first full fill can't be attributed to a stretch and are ignored.
 *   <li>Partial fills after the last full fill wait for the next full fill.
 *   <li>A stretch with no distance (two full fills at the same odometer) is skipped, and the second
 *       fill starts the next stretch.
 *   <li>Averages are weighted by distance (total km over total litres), not means of ratios.
 * </ul>
 *
 * <p>The backend is the single source of truth for these numbers; the app only displays them.
 */
final class FuelEfficiencyCalculator {

  private FuelEfficiencyCalculator() {}

  /**
   * Splits fill-ups into full-to-full stretches.
   *
   * @param fills one vehicle's fills in odometer order (ties by date, then entry order)
   */
  static List<FuelInterval> intervals(List<FuelFill> fills) {
    List<FuelInterval> intervals = new ArrayList<>();
    FuelFill lastFull = null;
    BigDecimal litres = BigDecimal.ZERO;
    BigDecimal amount = BigDecimal.ZERO;
    for (FuelFill fill : fills) {
      if (lastFull != null) {
        litres = litres.add(fill.litres());
        amount = amount.add(fill.amount());
      }
      if (fill.fullTank()) {
        if (lastFull != null) {
          int distance = fill.odometerKm() - lastFull.odometerKm();
          if (distance > 0) {
            intervals.add(
                new FuelInterval(
                    fill.id(), lastFull.date(), fill.date(), distance, litres, amount));
          }
        }
        lastFull = fill;
        litres = BigDecimal.ZERO;
        amount = BigDecimal.ZERO;
      }
    }
    return intervals;
  }

  /** Efficiency figures over the given stretches, or {@link Summary#EMPTY} when there are none. */
  static Summary summarize(List<FuelInterval> intervals) {
    if (intervals.isEmpty()) {
      return Summary.EMPTY;
    }
    int distance = intervals.stream().mapToInt(FuelInterval::distanceKm).sum();
    BigDecimal litres =
        intervals.stream().map(FuelInterval::litres).reduce(BigDecimal.ZERO, BigDecimal::add);
    BigDecimal amount =
        intervals.stream().map(FuelInterval::amount).reduce(BigDecimal.ZERO, BigDecimal::add);
    BigDecimal best =
        intervals.stream()
            .map(FuelInterval::kmPerLitre)
            .max(Comparator.naturalOrder())
            .orElseThrow();
    return new Summary(
        BigDecimal.valueOf(distance).divide(litres, 2, RoundingMode.HALF_UP),
        best,
        intervals.get(intervals.size() - 1).kmPerLitre(),
        amount.divide(BigDecimal.valueOf(distance), 2, RoundingMode.HALF_UP),
        distance,
        litres,
        amount);
  }

  /**
   * @param averageKmPerLitre total distance over total litres
   * @param latestKmPerLitre the stretch that ended last (highest odometer)
   * @param costPerKm what the fuel burned over these stretches cost per km
   * @param distanceKm distance covered by complete stretches
   * @param litres fuel burned over that distance
   * @param amount what that fuel cost
   */
  record Summary(
      @Nullable BigDecimal averageKmPerLitre,
      @Nullable BigDecimal bestKmPerLitre,
      @Nullable BigDecimal latestKmPerLitre,
      @Nullable BigDecimal costPerKm,
      int distanceKm,
      BigDecimal litres,
      BigDecimal amount) {

    static final Summary EMPTY =
        new Summary(null, null, null, null, 0, BigDecimal.ZERO, BigDecimal.ZERO);
  }
}
