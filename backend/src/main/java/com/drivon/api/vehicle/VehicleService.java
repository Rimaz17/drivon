package com.drivon.api.vehicle;

import com.drivon.api.common.error.DrivonException;
import com.drivon.api.common.error.ErrorCode;
import com.drivon.api.user.UserService;
import java.time.Clock;
import java.time.Year;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Vehicle management for the signed-in user. Every method takes the owner's ID; a vehicle that
 * belongs to someone else is reported as not found so its existence is never revealed.
 */
@Service
public class VehicleService {

  /** MVP limit from the product overview. */
  static final int MAX_VEHICLES_PER_USER = 2;

  private final VehicleRepository vehicles;
  private final OdometerService odometer;
  private final UserService users;
  private final Clock clock;

  VehicleService(
      VehicleRepository vehicles, OdometerService odometer, UserService users, Clock clock) {
    this.vehicles = vehicles;
    this.odometer = odometer;
    this.users = users;
    this.clock = clock;
  }

  @Transactional(readOnly = true)
  public List<VehicleResponse> list(UUID userId) {
    return vehicles.findAllByUserIdOrderByCreatedAtAsc(userId).stream()
        .map(VehicleMapper::toResponse)
        .toList();
  }

  @Transactional(readOnly = true)
  public VehicleResponse get(UUID userId, UUID vehicleId) {
    return VehicleMapper.toResponse(findOwned(userId, vehicleId));
  }

  /** Adds a vehicle, enforcing the per-user limit even under concurrent requests. */
  @Transactional
  public VehicleResponse create(UUID userId, VehicleRequest request) {
    users.lockForUpdate(userId);
    if (vehicles.countByUserId(userId) >= MAX_VEHICLES_PER_USER) {
      throw new DrivonException(
          ErrorCode.VEHICLE_LIMIT_REACHED,
          "You can add up to " + MAX_VEHICLES_PER_USER + " vehicles.");
    }
    checkModelYear(request.year());
    String registration = RegistrationNumbers.normalize(request.registrationNumber());
    if (vehicles.existsByUserIdAndRegistrationNumber(userId, registration)) {
      throw registrationInUse();
    }
    Vehicle vehicle =
        new Vehicle(
            userId,
            request.make().strip(),
            request.model().strip(),
            request.year(),
            registration,
            request.fuelType(),
            request.currentOdometerKm());
    Vehicle saved = vehicles.saveAndFlush(vehicle);
    odometer.recordInitial(saved);
    return VehicleMapper.toResponse(saved);
  }

  /**
   * Replaces a vehicle's details. The odometer may stay the same or increase, never decrease; a
   * higher value is saved as a manual reading for today. A mistyped reading is fixed by correcting
   * it in the odometer history instead (see {@link OdometerService#correct}).
   */
  @Transactional
  public VehicleResponse update(UUID userId, UUID vehicleId, VehicleRequest request) {
    Vehicle vehicle =
        vehicles
            .findByIdAndUserIdForUpdate(vehicleId, userId)
            .orElseThrow(() -> new DrivonException(ErrorCode.VEHICLE_NOT_FOUND));
    checkModelYear(request.year());
    if (request.currentOdometerKm() < vehicle.getCurrentOdometerKm()) {
      throw new DrivonException(
          ErrorCode.ODOMETER_DECREASE,
          "The odometer can't be lower than the current reading of "
              + vehicle.getCurrentOdometerKm()
              + " km.");
    }
    String registration = RegistrationNumbers.normalize(request.registrationNumber());
    if (vehicles.existsByUserIdAndRegistrationNumberAndIdNot(userId, registration, vehicleId)) {
      throw registrationInUse();
    }
    vehicle.update(
        request.make().strip(),
        request.model().strip(),
        request.year(),
        registration,
        request.fuelType());
    if (request.currentOdometerKm() > vehicle.getCurrentOdometerKm()) {
      odometer.recordRaised(vehicle, request.currentOdometerKm());
    }
    // Flush so the response carries the new updatedAt timestamp.
    return VehicleMapper.toResponse(vehicles.saveAndFlush(vehicle));
  }

  @Transactional
  public void delete(UUID userId, UUID vehicleId) {
    vehicles.delete(findOwned(userId, vehicleId));
  }

  private Vehicle findOwned(UUID userId, UUID vehicleId) {
    return vehicles
        .findByIdAndUserId(vehicleId, userId)
        .orElseThrow(() -> new DrivonException(ErrorCode.VEHICLE_NOT_FOUND));
  }

  /** Next year's models go on sale this year, so allow up to one year ahead. */
  private void checkModelYear(int year) {
    int latest = Year.now(clock).getValue() + 1;
    if (year > latest) {
      throw new DrivonException(
          ErrorCode.INVALID_MODEL_YEAR, "The model year can't be later than " + latest + ".");
    }
  }

  private static DrivonException registrationInUse() {
    return new DrivonException(
        ErrorCode.REGISTRATION_NUMBER_IN_USE,
        "You already have a vehicle with this registration number.");
  }
}
