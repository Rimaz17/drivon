package com.drivon.api.document;

import java.util.UUID;

/**
 * Published inside the transaction that made a vehicle's document visible, changed its details or
 * deleted it, after the change was flushed, so listeners see the current expiry dates.
 */
public record DocumentsChangedEvent(UUID vehicleId) {}
