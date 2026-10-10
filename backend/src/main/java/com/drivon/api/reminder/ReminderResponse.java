package com.drivon.api.reminder;

import com.drivon.api.document.DocumentType;
import com.drivon.api.maintenance.ServiceType;
import java.time.LocalDate;
import java.util.UUID;
import org.jspecify.annotations.Nullable;

/**
 * A reminder and where it stands today.
 *
 * @param serviceType set for {@code SERVICE} reminders
 * @param documentType set for {@code DOCUMENT} reminders
 * @param sourceId the service record or document an automatic reminder follows
 * @param title set for {@code MANUAL} reminders; the app names automatic ones from their type
 * @param remindFrom first day the reminder counts as due soon (date-based reminders)
 * @param daysRemaining days from today (Sri Lanka) to {@code dueDate}; negative when overdue
 * @param kmRemaining km from the vehicle's current odometer to {@code dueKm}; negative when overdue
 */
public record ReminderResponse(
    UUID id,
    UUID vehicleId,
    ReminderSource source,
    @Nullable ServiceType serviceType,
    @Nullable DocumentType documentType,
    @Nullable UUID sourceId,
    @Nullable String title,
    @Nullable LocalDate dueDate,
    @Nullable Integer dueKm,
    @Nullable LocalDate remindFrom,
    @Nullable Long daysRemaining,
    @Nullable Integer kmRemaining,
    ReminderStatus status) {

  static ReminderResponse from(Reminder reminder, ReminderTiming timing) {
    return new ReminderResponse(
        reminder.getId(),
        reminder.getVehicleId(),
        reminder.getSource(),
        reminder.getServiceType(),
        reminder.getDocumentType(),
        reminder.getSourceId(),
        reminder.getTitle(),
        reminder.getDueDate(),
        reminder.getDueKm(),
        timing.remindFrom(),
        timing.daysRemaining(),
        timing.kmRemaining(),
        timing.status());
  }
}
