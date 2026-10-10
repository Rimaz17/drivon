package com.drivon.api.reminder;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;
import java.util.UUID;
import org.jspecify.annotations.Nullable;

/**
 * Body for adding or replacing one of the user's own reminders. Set a due date, a due mileage or
 * both (due at whichever comes first).
 *
 * @param id optional app-generated ID; resending it returns the saved reminder. Ignored on update.
 * @param dueDate today or later
 * @param dueKm above the vehicle's current odometer
 */
public record ReminderRequest(
    @Nullable UUID id,
    @NotBlank @Size(max = 80) String title,
    @Nullable LocalDate dueDate,
    @Min(1) @Max(2_000_000) @Nullable Integer dueKm) {}
