package com.drivon.api.vehicle;

import java.util.UUID;

/**
 * Published inside the transaction that deletes a vehicle, just before the row goes. The database
 * cascades to the vehicle's records; listeners clean up what lives elsewhere (document files).
 */
public record VehicleDeletingEvent(UUID vehicleId) {}
