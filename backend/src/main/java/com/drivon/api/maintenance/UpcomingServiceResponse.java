package com.drivon.api.maintenance;

import java.time.LocalDate;
import java.util.UUID;
import org.jspecify.annotations.Nullable;

/**
 * When a service type is next due, from its most recent record.
 *
 * @param recordId the record that set the due date or mileage
 * @param daysRemaining days from today (Sri Lanka) to {@code dueDate}; negative when overdue
 * @param kmRemaining km from the vehicle's current odometer to {@code dueKm}; negative when overdue
 * @param overdue past the due date or mileage, whichever comes first
 */
public record UpcomingServiceResponse(
    ServiceType serviceType,
    UUID recordId,
    LocalDate lastServicedOn,
    @Nullable LocalDate dueDate,
    @Nullable Integer dueKm,
    @Nullable Long daysRemaining,
    @Nullable Integer kmRemaining,
    boolean overdue) {}
