package com.drivon.api.vehicle;

/**
 * Fuels the MVP can track in litres. Battery-electric vehicles are out of scope until charging
 * (kWh) tracking exists; see docs/adr/0006-vehicle-model.md.
 */
public enum FuelType {
  PETROL,
  DIESEL,
  HYBRID
}
