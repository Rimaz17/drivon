package com.drivon.api.vehicle;

import java.time.YearMonth;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.jspecify.annotations.Nullable;

/**
 * Distance driven, from the odometer timeline. Readings never go down over time (ADR 0007), so the
 * odometer at the end of a day is the highest reading dated on or before it. The distance of a
 * period is that value at the period's end minus the value just before it starts; when the vehicle
 * has no reading before the period (it was added during it), its first reading in the period is the
 * starting point. Periods without readings have no distance.
 */
final class OdometerDistance {

  private OdometerDistance() {}

  /**
   * @param before highest reading dated before the period, if any
   * @param firstInPeriod lowest reading dated in the period, if any
   * @param atEnd highest reading dated on or before the period's last day, if any
   */
  static int between(
      @Nullable Integer before, @Nullable Integer firstInPeriod, @Nullable Integer atEnd) {
    Integer start = before != null ? before : firstInPeriod;
    if (start == null || atEnd == null) {
      return 0;
    }
    return Math.max(0, atEnd - start);
  }

  /**
   * Distance in each of the {@code count} months ending with {@code last}, oldest first.
   *
   * @param before highest reading dated before the first month, if any
   * @param spans lowest and highest reading of each month that has readings
   */
  static List<MonthlyDistance> byMonth(
      YearMonth last, int count, @Nullable Integer before, List<MonthSpan> spans) {
    Map<YearMonth, MonthSpan> byMonth = new HashMap<>();
    for (MonthSpan span : spans) {
      byMonth.put(span.month(), span);
    }
    List<MonthlyDistance> distances = new ArrayList<>(count);
    Integer odometer = before;
    for (YearMonth month = last.minusMonths(count - 1L);
        !month.isAfter(last);
        month = month.plusMonths(1)) {
      MonthSpan span = byMonth.get(month);
      if (span == null) {
        distances.add(new MonthlyDistance(month, 0));
        continue;
      }
      distances.add(new MonthlyDistance(month, between(odometer, span.minKm(), span.maxKm())));
      odometer = span.maxKm();
    }
    return distances;
  }

  /** The lowest and highest odometer reading dated in one calendar month. */
  record MonthSpan(YearMonth month, int minKm, int maxKm) {}
}
