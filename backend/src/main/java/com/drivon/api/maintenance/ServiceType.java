package com.drivon.api.maintenance;

/**
 * Kinds of service work. Each type's latest record says when that service is next due, so a vehicle
 * has at most one upcoming service per type.
 */
public enum ServiceType {
  OIL_CHANGE,
  GENERAL_SERVICE,
  TYRE_ROTATION,
  TYRE_REPLACEMENT,
  BRAKE_SERVICE,
  BATTERY_REPLACEMENT,
  WHEEL_ALIGNMENT,
  AIR_CONDITIONING,
  OTHER
}
