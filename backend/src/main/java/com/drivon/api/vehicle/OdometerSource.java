package com.drivon.api.vehicle;

/** Where an odometer reading came from. */
public enum OdometerSource {
  /** The odometer the vehicle was added with. Can be corrected, never deleted. */
  INITIAL,
  /** Entered by the user, or saved when the vehicle form raised the odometer. */
  MANUAL,
  /** The odometer of a fill-up; changes only through that fill-up. */
  FUEL,
  /** The odometer of a service; changes only through that service record. */
  MAINTENANCE;

  /** True for readings owned by another record (a fill-up or a service). */
  public boolean isLinked() {
    return this == FUEL || this == MAINTENANCE;
  }
}
