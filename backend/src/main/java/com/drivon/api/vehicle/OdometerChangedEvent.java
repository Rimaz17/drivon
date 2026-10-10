package com.drivon.api.vehicle;

import java.util.UUID;

/**
 * Published inside the transaction that changed a vehicle's odometer timeline. Mileage reminders
 * are checked once that transaction commits.
 */
public record OdometerChangedEvent(UUID vehicleId) {}
