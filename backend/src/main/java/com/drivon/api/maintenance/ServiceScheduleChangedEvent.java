package com.drivon.api.maintenance;

import java.util.UUID;

/**
 * Published inside the transaction that added, changed or deleted a service record, after the
 * change was flushed, so listeners see when each service type is now next due.
 */
public record ServiceScheduleChangedEvent(UUID vehicleId) {}
