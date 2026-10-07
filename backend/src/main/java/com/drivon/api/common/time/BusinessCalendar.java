package com.drivon.api.common.time;

import com.drivon.api.common.error.DrivonException;
import com.drivon.api.common.error.ErrorCode;
import java.time.Clock;
import java.time.LocalDate;
import java.time.YearMonth;
import java.time.ZoneId;
import org.jspecify.annotations.Nullable;
import org.springframework.stereotype.Component;

/**
 * Calendar dates as Drivon's users see them. Records carry plain dates (a fill-up happened "on 7
 * October"), so "today" and "this month" are taken in Sri Lanka's time zone, not in UTC.
 */
@Component
public class BusinessCalendar {

  public static final ZoneId ZONE = ZoneId.of("Asia/Colombo");

  /** Start of an open-ended range; older than any vehicle record. */
  public static final LocalDate EARLIEST = LocalDate.of(1900, 1, 1);

  private final Clock clock;

  public BusinessCalendar(Clock clock) {
    this.clock = clock;
  }

  public LocalDate today() {
    return LocalDate.now(clock.withZone(ZONE));
  }

  public YearMonth currentMonth() {
    return YearMonth.from(today());
  }

  /** Records describe things that already happened, so their dates can't be in the future. */
  public void requireNotFuture(LocalDate date) {
    if (date.isAfter(today())) {
      throw new DrivonException(ErrorCode.DATE_IN_FUTURE, "The date can't be in the future.");
    }
  }

  /**
   * An inclusive range from optional query parameters: a missing start means "from the beginning",
   * a missing end means "up to today".
   */
  public DateRange range(@Nullable LocalDate from, @Nullable LocalDate to) {
    LocalDate start = from != null ? from : EARLIEST;
    LocalDate end = to != null ? to : today();
    if (start.isAfter(end)) {
      throw new DrivonException(
          ErrorCode.INVALID_DATE_RANGE, "The start date must be on or before the end date.");
    }
    return new DateRange(start, end);
  }
}
