package com.drivon.api.reminder;

import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import org.jspecify.annotations.Nullable;

/**
 * When a reminder is due soon, due and overdue. A reminder with both a date and a mileage is due at
 * whichever comes first. Documents get a longer lead time because renewing one (insurance, revenue
 * licence) takes longer than booking a service.
 */
public final class ReminderRules {

  /** Services and the user's own reminders count as due soon a week ahead. */
  public static final int DATE_LEAD_DAYS = 7;

  /** Matches the app's "expiring soon" window for documents. */
  public static final int DOCUMENT_LEAD_DAYS = 30;

  /** Mileage-based reminders count as due soon this many kilometres ahead. */
  public static final int KM_LEAD = 500;

  private ReminderRules() {}

  public static int dateLeadDays(ReminderSource source) {
    return source == ReminderSource.DOCUMENT ? DOCUMENT_LEAD_DAYS : DATE_LEAD_DAYS;
  }

  /** The longest date lead time, for finding every reminder that might be due soon. */
  public static int maxDateLeadDays() {
    return Math.max(DATE_LEAD_DAYS, DOCUMENT_LEAD_DAYS);
  }

  /**
   * Where a reminder due on {@code dueDate} and/or at {@code dueKm} stands on {@code today} with
   * the vehicle at {@code odometerKm}. At least one of the two must be set.
   */
  public static ReminderTiming timing(
      ReminderSource source,
      @Nullable LocalDate dueDate,
      @Nullable Integer dueKm,
      LocalDate today,
      int odometerKm) {
    if (dueDate == null && dueKm == null) {
      throw new IllegalArgumentException("A reminder needs a due date or mileage");
    }
    int leadDays = dateLeadDays(source);
    Long days = dueDate == null ? null : ChronoUnit.DAYS.between(today, dueDate);
    Integer km = dueKm == null ? null : dueKm - odometerKm;

    boolean overdue = (days != null && days < 0) || (km != null && km < 0);
    boolean reached = (days != null && days <= 0) || (km != null && km <= 0);
    boolean soon = (days != null && days <= leadDays) || (km != null && km <= KM_LEAD);

    ReminderStatus status =
        overdue ? ReminderStatus.OVERDUE : soon ? ReminderStatus.DUE_SOON : ReminderStatus.UPCOMING;
    NotificationStage stage =
        reached
            ? NotificationStage.DUE
            : soon ? NotificationStage.DUE_SOON : NotificationStage.NONE;
    LocalDate remindFrom = dueDate == null ? null : dueDate.minusDays(leadDays);
    return new ReminderTiming(days, km, remindFrom, status, stage);
  }
}
