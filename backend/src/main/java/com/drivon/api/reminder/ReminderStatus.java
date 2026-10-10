package com.drivon.api.reminder;

/** How urgent a reminder is today; worked out from its due date, mileage and the odometer. */
public enum ReminderStatus {
  /** Past the due date or mileage, whichever came first. */
  OVERDUE,
  /** Due within the reminder's lead time (days or kilometres), including today. */
  DUE_SOON,
  UPCOMING
}
