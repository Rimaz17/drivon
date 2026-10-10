package com.drivon.api.reminder;

/** Where a reminder comes from. Only {@link #MANUAL} reminders are edited directly. */
public enum ReminderSource {
  /** Created by the user. */
  MANUAL,
  /** Follows the latest service record of one type that sets a next date or mileage. */
  SERVICE,
  /** Follows the latest expiry date of one document type. */
  DOCUMENT
}
