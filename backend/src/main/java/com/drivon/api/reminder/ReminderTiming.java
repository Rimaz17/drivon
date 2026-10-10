package com.drivon.api.reminder;

import java.time.LocalDate;
import org.jspecify.annotations.Nullable;

/**
 * Where a reminder stands on a given day.
 *
 * @param daysRemaining days from today to the due date; negative once past
 * @param kmRemaining km from the current odometer to the due mileage; negative once past
 * @param remindFrom the first day the reminder counts as due soon, for date-based reminders
 * @param stage the furthest notification the reminder should have had by now
 */
public record ReminderTiming(
    @Nullable Long daysRemaining,
    @Nullable Integer kmRemaining,
    @Nullable LocalDate remindFrom,
    ReminderStatus status,
    NotificationStage stage) {}
