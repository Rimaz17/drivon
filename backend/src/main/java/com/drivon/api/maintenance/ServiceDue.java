package com.drivon.api.maintenance;

import java.time.LocalDate;
import java.util.UUID;
import org.jspecify.annotations.Nullable;

/**
 * When a service type is next due, from its latest record; at least one of the two is set.
 *
 * @param recordId the record that set the due date or mileage
 */
public record ServiceDue(
    ServiceType serviceType, UUID recordId, @Nullable LocalDate dueDate, @Nullable Integer dueKm) {}
