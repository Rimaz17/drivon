package com.drivon.api.vehicle;

import com.drivon.api.common.error.DrivonException;
import com.drivon.api.common.error.ErrorCode;
import com.drivon.api.common.time.BusinessCalendar;
import com.drivon.api.common.web.PageResponse;
import com.drivon.api.common.web.SortOptions;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.domain.Sort.Direction;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/**
 * Keeps each vehicle's odometer timeline consistent: a reading can't be lower than one on an
 * earlier date or higher than one on a later date (readings on the same date may be in any order).
 * The vehicle's current odometer always equals its highest reading.
 *
 * <p>Fill-ups and services record their odometer through {@link #recordLinked} inside their own
 * transaction, after {@link #lockVehicle}, so concurrent writes for one vehicle run one at a time.
 * Initial and manual readings can be corrected here; that is the explicit way to fix a mistyped
 * odometer. See docs/adr/0007-odometer-timeline.md.
 */
@Service
public class OdometerService {

  static final SortOptions SORT =
      new SortOptions(
          Map.of("date", "date", "readingKm", "readingKm"),
          Sort.by(Direction.DESC, "date").and(Sort.by(Direction.DESC, "readingKm")),
          Sort.by(Direction.DESC, "createdAt"));

  private final OdometerReadingRepository readings;
  private final VehicleRepository vehicles;
  private final BusinessCalendar calendar;

  OdometerService(
      OdometerReadingRepository readings, VehicleRepository vehicles, BusinessCalendar calendar) {
    this.readings = readings;
    this.vehicles = vehicles;
    this.calendar = calendar;
  }

  @Transactional(readOnly = true)
  public PageResponse<OdometerReadingResponse> list(
      UUID userId, UUID vehicleId, Pageable pageable) {
    findOwned(userId, vehicleId);
    return PageResponse.of(
        readings.findByVehicleId(vehicleId, SORT.apply(pageable)),
        OdometerReadingMapper::toResponse);
  }

  @Transactional(readOnly = true)
  public OdometerReadingResponse get(UUID userId, UUID vehicleId, UUID readingId) {
    findOwned(userId, vehicleId);
    return OdometerReadingMapper.toResponse(findReading(vehicleId, readingId));
  }

  /** Adds a reading the user entered, e.g. from the dashboard on a given day. */
  @Transactional
  public OdometerReadingResponse add(UUID userId, UUID vehicleId, OdometerReadingRequest request) {
    Vehicle vehicle = lockVehicle(userId, vehicleId);
    OdometerReading reading =
        new OdometerReading(
            vehicleId, OdometerSource.MANUAL, null, request.date(), request.readingKm());
    place(vehicle, reading, request.date(), request.readingKm());
    return OdometerReadingMapper.toResponse(reading);
  }

  /**
   * Corrects an initial or manual reading. Readings of fill-ups and services change only through
   * those records, so the two never disagree.
   */
  @Transactional
  public OdometerReadingResponse correct(
      UUID userId, UUID vehicleId, UUID readingId, OdometerReadingRequest request) {
    Vehicle vehicle = lockVehicle(userId, vehicleId);
    OdometerReading reading = findReading(vehicleId, readingId);
    if (reading.getSource().isLinked()) {
      throw linkedReading(reading.getSource());
    }
    place(vehicle, reading, request.date(), request.readingKm());
    return OdometerReadingMapper.toResponse(reading);
  }

  /** Deletes a manual reading. The initial reading can only be corrected. */
  @Transactional
  public void delete(UUID userId, UUID vehicleId, UUID readingId) {
    Vehicle vehicle = lockVehicle(userId, vehicleId);
    OdometerReading reading = findReading(vehicleId, readingId);
    if (reading.getSource().isLinked()) {
      throw linkedReading(reading.getSource());
    }
    if (reading.getSource() == OdometerSource.INITIAL) {
      throw new DrivonException(
          ErrorCode.ODOMETER_READING_LOCKED,
          "The reading the vehicle was added with can be corrected but not deleted.");
    }
    readings.delete(reading);
    readings.flush();
    syncVehicle(vehicle);
  }

  /**
   * Kilometres driven in an inclusive date range, from the odometer timeline. The caller must have
   * checked that the vehicle belongs to the user.
   */
  @Transactional(readOnly = true)
  public int distanceBetween(UUID vehicleId, LocalDate from, LocalDate to) {
    return OdometerDistance.between(
        readings.findMaxOnOrBefore(vehicleId, from.minusDays(1)).orElse(null),
        readings.findMinBetween(vehicleId, from, to).orElse(null),
        readings.findMaxOnOrBefore(vehicleId, to).orElse(null));
  }

  /**
   * Kilometres driven in each of the {@code months} months ending with {@code last}, oldest first.
   * The caller must have checked that the vehicle belongs to the user.
   */
  @Transactional(readOnly = true)
  public List<MonthlyDistance> distanceByMonth(UUID vehicleId, YearMonth last, int months) {
    YearMonth first = last.minusMonths(months - 1L);
    List<OdometerDistance.MonthSpan> spans =
        readings.findMonthReadings(vehicleId, first.atDay(1), last.atEndOfMonth()).stream()
            .map(
                month ->
                    new OdometerDistance.MonthSpan(
                        YearMonth.of(month.getYear(), month.getMonth()),
                        month.getMinKm(),
                        month.getMaxKm()))
            .toList();
    return OdometerDistance.byMonth(
        last,
        months,
        readings.findMaxOnOrBefore(vehicleId, first.atDay(1).minusDays(1)).orElse(null),
        spans);
  }

  /**
   * Loads the user's vehicle and locks it until the caller's transaction ends, so concurrent
   * odometer changes for the vehicle are checked one at a time.
   */
  @Transactional(propagation = Propagation.MANDATORY)
  public Vehicle lockVehicle(UUID userId, UUID vehicleId) {
    return vehicles
        .findByIdAndUserIdForUpdate(vehicleId, userId)
        .orElseThrow(() -> new DrivonException(ErrorCode.VEHICLE_NOT_FOUND));
  }

  /**
   * Adds or moves the reading that belongs to a fill-up or service. Call {@link #lockVehicle} first
   * in the same transaction.
   */
  @Transactional(propagation = Propagation.MANDATORY)
  public void recordLinked(
      Vehicle vehicle, OdometerSource source, UUID sourceId, LocalDate date, int readingKm) {
    if (!source.isLinked()) {
      throw new IllegalArgumentException("Only fill-ups and services have linked readings");
    }
    OdometerReading reading =
        readings
            .findBySourceId(sourceId)
            .orElseGet(
                () -> new OdometerReading(vehicle.getId(), source, sourceId, date, readingKm));
    place(vehicle, reading, date, readingKm);
  }

  /** Removes the reading of a deleted fill-up or service, if it had one. */
  @Transactional(propagation = Propagation.MANDATORY)
  public void removeLinked(Vehicle vehicle, UUID sourceId) {
    readings.findBySourceId(sourceId).ifPresent(readings::delete);
    readings.flush();
    syncVehicle(vehicle);
  }

  /** Starts a new vehicle's timeline with the odometer it was added with. */
  void recordInitial(Vehicle vehicle) {
    readings.saveAndFlush(
        new OdometerReading(
            vehicle.getId(),
            OdometerSource.INITIAL,
            null,
            calendar.today(),
            vehicle.getCurrentOdometerKm()));
  }

  /** Records a higher odometer typed into the vehicle form as a manual reading for today. */
  void recordRaised(Vehicle vehicle, int readingKm) {
    LocalDate today = calendar.today();
    place(
        vehicle,
        new OdometerReading(vehicle.getId(), OdometerSource.MANUAL, null, today, readingKm),
        today,
        readingKm);
  }

  private void place(Vehicle vehicle, OdometerReading reading, LocalDate date, int readingKm) {
    calendar.requireNotFuture(date);
    checkFitsTimeline(vehicle.getId(), reading.getId(), date, readingKm);
    reading.moveTo(date, readingKm);
    readings.saveAndFlush(reading);
    syncVehicle(vehicle);
  }

  private void checkFitsTimeline(UUID vehicleId, UUID readingId, LocalDate date, int readingKm) {
    Integer floor = readings.findMaxBefore(vehicleId, date, readingId).orElse(null);
    Integer ceiling = readings.findMinAfter(vehicleId, date, readingId).orElse(null);
    boolean tooLow = floor != null && readingKm < floor;
    boolean tooHigh = ceiling != null && readingKm > ceiling;
    if (tooLow || tooHigh) {
      throw outOfOrder(floor, ceiling);
    }
  }

  private void syncVehicle(Vehicle vehicle) {
    readings.findMaxReading(vehicle.getId()).ifPresent(vehicle::syncOdometer);
  }

  private void findOwned(UUID userId, UUID vehicleId) {
    if (vehicles.findByIdAndUserId(vehicleId, userId).isEmpty()) {
      throw new DrivonException(ErrorCode.VEHICLE_NOT_FOUND);
    }
  }

  private OdometerReading findReading(UUID vehicleId, UUID readingId) {
    return readings
        .findByIdAndVehicleId(readingId, vehicleId)
        .orElseThrow(() -> new DrivonException(ErrorCode.ODOMETER_READING_NOT_FOUND));
  }

  private static DrivonException outOfOrder(Integer floor, Integer ceiling) {
    String detail;
    if (floor != null && ceiling != null) {
      detail =
          "For this date the odometer must be between %s and %s km."
              .formatted(km(floor), km(ceiling));
    } else if (floor != null) {
      detail =
          "For this date the odometer must be at least %s km, the reading on an earlier date."
              .formatted(km(floor));
    } else {
      detail =
          "For this date the odometer must be at most %s km, the reading on a later date."
              .formatted(km(ceiling));
    }
    return new DrivonException(ErrorCode.ODOMETER_OUT_OF_ORDER, detail)
        .with("minKm", floor)
        .with("maxKm", ceiling);
  }

  private static DrivonException linkedReading(OdometerSource source) {
    String record = source == OdometerSource.FUEL ? "fill-up" : "service";
    return new DrivonException(
        ErrorCode.ODOMETER_READING_LOCKED,
        "This reading belongs to a " + record + ". Edit the " + record + " instead.");
  }

  private static String km(int value) {
    return String.format(Locale.ROOT, "%,d", value);
  }
}
