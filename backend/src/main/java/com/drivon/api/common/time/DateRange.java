package com.drivon.api.common.time;

import java.time.LocalDate;

/** An inclusive range of calendar dates; build it with {@link BusinessCalendar#range}. */
public record DateRange(LocalDate from, LocalDate to) {

  public boolean contains(LocalDate date) {
    return !date.isBefore(from) && !date.isAfter(to);
  }
}
