package com.drivon.api.common.time;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.drivon.api.common.error.DrivonException;
import com.drivon.api.common.error.ErrorCode;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.YearMonth;
import java.time.ZoneOffset;
import org.junit.jupiter.api.Test;

class BusinessCalendarTest {

  /** 20:00 UTC is already 01:30 the next day in Colombo (UTC+05:30). */
  private final BusinessCalendar calendar =
      new BusinessCalendar(Clock.fixed(Instant.parse("2026-10-31T20:00:00Z"), ZoneOffset.UTC));

  @Test
  void todayIsTheDateInSriLanka() {
    assertThat(calendar.today()).isEqualTo(LocalDate.of(2026, 11, 1));
    assertThat(calendar.currentMonth()).isEqualTo(YearMonth.of(2026, 11));
  }

  @Test
  void acceptsTodayButNotTomorrow() {
    assertThatCode(() -> calendar.requireNotFuture(LocalDate.of(2026, 11, 1)))
        .doesNotThrowAnyException();
    assertThatThrownBy(() -> calendar.requireNotFuture(LocalDate.of(2026, 11, 2)))
        .extracting(e -> ((DrivonException) e).code())
        .isEqualTo(ErrorCode.DATE_IN_FUTURE);
  }

  @Test
  void openEndedRangesRunFromTheBeginningUntilToday() {
    DateRange range = calendar.range(null, null);

    assertThat(range.from()).isEqualTo(BusinessCalendar.EARLIEST);
    assertThat(range.to()).isEqualTo(LocalDate.of(2026, 11, 1));
  }

  @Test
  void rangesAreInclusiveAtBothEnds() {
    DateRange september = calendar.range(LocalDate.of(2026, 9, 1), LocalDate.of(2026, 9, 30));

    assertThat(september.contains(LocalDate.of(2026, 9, 1))).isTrue();
    assertThat(september.contains(LocalDate.of(2026, 9, 30))).isTrue();
    assertThat(september.contains(LocalDate.of(2026, 10, 1))).isFalse();
  }

  @Test
  void rejectsARangeThatEndsBeforeItStarts() {
    assertThatThrownBy(() -> calendar.range(LocalDate.of(2026, 9, 2), LocalDate.of(2026, 9, 1)))
        .extracting(e -> ((DrivonException) e).code())
        .isEqualTo(ErrorCode.INVALID_DATE_RANGE);
  }
}
