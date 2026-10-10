package com.drivon.api.reminder;

/**
 * The notifications a reminder has reached, in order. Each stage is pushed at most once per due
 * date and mileage, which keeps the notification job idempotent.
 */
public enum NotificationStage {
  NONE,
  DUE_SOON,
  DUE;

  public boolean isAfter(NotificationStage other) {
    return compareTo(other) > 0;
  }
}
