package com.drivon.api.maintenance;

import com.drivon.api.common.error.DrivonException;
import com.drivon.api.common.error.ErrorCode;
import com.drivon.api.common.stats.MonthlySum;
import com.drivon.api.common.stats.SpendTotal;
import com.drivon.api.common.time.BusinessCalendar;
import com.drivon.api.common.web.CreateResult;
import com.drivon.api.common.web.PageResponse;
import com.drivon.api.common.web.SortOptions;
import com.drivon.api.maintenance.MaintenanceRecord.ServiceDetails;
import com.drivon.api.vehicle.OdometerService;
import com.drivon.api.vehicle.OdometerSource;
import com.drivon.api.vehicle.Vehicle;
import com.drivon.api.vehicle.VehicleService;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import org.jspecify.annotations.Nullable;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.domain.Sort.Direction;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Service records for the signed-in user's vehicles. Every method checks that the vehicle belongs
 * to the user; a record under someone else's vehicle is reported as not found.
 */
@Service
public class MaintenanceService {

  static final SortOptions SORT =
      new SortOptions(
          Map.of("date", "date", "cost", "cost", "odometerKm", "odometerKm"),
          Sort.by(Direction.DESC, "date"),
          Sort.by(Direction.DESC, "createdAt"));

  /** Overdue first, then by due date, then services due only by mileage. */
  static final Comparator<UpcomingServiceResponse> SOONEST_FIRST =
      Comparator.comparing((UpcomingServiceResponse u) -> !u.overdue())
          .thenComparing(
              UpcomingServiceResponse::dueDate, Comparator.nullsLast(Comparator.naturalOrder()))
          .thenComparing(
              UpcomingServiceResponse::kmRemaining,
              Comparator.nullsLast(Comparator.naturalOrder()));

  private final MaintenanceRecordRepository records;
  private final VehicleService vehicles;
  private final OdometerService odometer;
  private final BusinessCalendar calendar;

  MaintenanceService(
      MaintenanceRecordRepository records,
      VehicleService vehicles,
      OdometerService odometer,
      BusinessCalendar calendar) {
    this.records = records;
    this.vehicles = vehicles;
    this.odometer = odometer;
    this.calendar = calendar;
  }

  /** Newest first, optionally only one service type. */
  @Transactional(readOnly = true)
  public PageResponse<MaintenanceRecordResponse> list(
      UUID userId, UUID vehicleId, @Nullable ServiceType serviceType, Pageable pageable) {
    vehicles.requireOwned(userId, vehicleId);
    Pageable page = SORT.apply(pageable);
    Page<MaintenanceRecord> found =
        serviceType == null
            ? records.findByVehicleId(vehicleId, page)
            : records.findByVehicleIdAndServiceType(vehicleId, serviceType, page);
    return PageResponse.of(found, MaintenanceRecordResponse::from);
  }

  @Transactional(readOnly = true)
  public MaintenanceRecordResponse get(UUID userId, UUID vehicleId, UUID recordId) {
    vehicles.requireOwned(userId, vehicleId);
    return MaintenanceRecordResponse.from(find(vehicleId, recordId));
  }

  /**
   * Logs a service; its odometer, if given, goes on the vehicle's timeline. Resending an ID that
   * was already saved for this vehicle returns that record unchanged.
   */
  @Transactional
  public CreateResult<MaintenanceRecordResponse> create(
      UUID userId, UUID vehicleId, MaintenanceRecordRequest request) {
    Vehicle vehicle = odometer.lockVehicle(userId, vehicleId);
    Optional<MaintenanceRecord> earlier =
        request.id() == null ? Optional.empty() : records.findById(request.id());
    if (earlier.isPresent()) {
      if (!earlier.get().getVehicleId().equals(vehicleId)) {
        throw new DrivonException(
            ErrorCode.RECORD_ID_CONFLICT, "This ID is already used by another record.");
      }
      return new CreateResult<>(MaintenanceRecordResponse.from(earlier.get()), false);
    }
    ServiceDetails details = validate(request);
    MaintenanceRecord record = new MaintenanceRecord(request.id(), vehicleId, details);
    syncOdometer(vehicle, record.getId(), details);
    records.saveAndFlush(record);
    return new CreateResult<>(MaintenanceRecordResponse.from(record), true);
  }

  /** Replaces a service's details; its odometer reading moves, appears or goes with it. */
  @Transactional
  public MaintenanceRecordResponse update(
      UUID userId, UUID vehicleId, UUID recordId, MaintenanceRecordRequest request) {
    Vehicle vehicle = odometer.lockVehicle(userId, vehicleId);
    MaintenanceRecord record = find(vehicleId, recordId);
    ServiceDetails details = validate(request);
    syncOdometer(vehicle, record.getId(), details);
    record.update(details);
    return MaintenanceRecordResponse.from(records.saveAndFlush(record));
  }

  /** Deletes a service and its odometer reading. */
  @Transactional
  public void delete(UUID userId, UUID vehicleId, UUID recordId) {
    Vehicle vehicle = odometer.lockVehicle(userId, vehicleId);
    MaintenanceRecord record = find(vehicleId, recordId);
    records.delete(record);
    odometer.removeLinked(vehicle, record.getId());
  }

  /**
   * When each service type is next due, from the latest record of that type, soonest first. A type
   * whose latest record sets no next date or mileage has nothing upcoming.
   */
  @Transactional(readOnly = true)
  public List<UpcomingServiceResponse> upcoming(UUID userId, UUID vehicleId) {
    Vehicle vehicle = vehicles.requireOwned(userId, vehicleId);
    LocalDate today = calendar.today();
    return records.findLatestOfEachType(vehicleId).stream()
        .filter(MaintenanceRecord::hasNextService)
        .map(record -> toUpcoming(record, today, vehicle.getCurrentOdometerKm()))
        .sorted(SOONEST_FIRST)
        .toList();
  }

  /**
   * Service costs of a vehicle in an inclusive date range, for spending totals. The caller must
   * have checked that the vehicle belongs to the user.
   */
  @Transactional(readOnly = true)
  public SpendTotal spendBetween(UUID vehicleId, LocalDate from, LocalDate to) {
    MaintenanceRecordRepository.Totals totals = records.sumBetween(vehicleId, from, to);
    return new SpendTotal(totals.getAmount(), totals.getCount());
  }

  /** Service costs of a vehicle per month in a range; the caller checked ownership. */
  @Transactional(readOnly = true)
  public List<MonthlySum> spendByMonth(UUID vehicleId, LocalDate from, LocalDate to) {
    return records.sumByMonth(vehicleId, from, to);
  }

  static UpcomingServiceResponse toUpcoming(
      MaintenanceRecord record, LocalDate today, int currentOdometerKm) {
    LocalDate dueDate = record.getNextServiceDate();
    Integer dueKm = record.getNextServiceKm();
    Long daysRemaining = dueDate == null ? null : ChronoUnit.DAYS.between(today, dueDate);
    Integer kmRemaining = dueKm == null ? null : dueKm - currentOdometerKm;
    boolean overdue =
        (daysRemaining != null && daysRemaining < 0) || (kmRemaining != null && kmRemaining < 0);
    return new UpcomingServiceResponse(
        record.getServiceType(),
        record.getId(),
        record.getDate(),
        dueDate,
        dueKm,
        daysRemaining,
        kmRemaining,
        overdue);
  }

  private ServiceDetails validate(MaintenanceRecordRequest request) {
    calendar.requireNotFuture(request.date());
    LocalDate next = request.nextServiceDate();
    if (next != null && !next.isAfter(request.date())) {
      throw new DrivonException(
          ErrorCode.NEXT_SERVICE_DATE_INVALID,
          "The next service date must be after the service date.");
    }
    Integer odometerKm = request.odometerKm();
    Integer nextKm = request.nextServiceKm();
    if (nextKm != null && odometerKm != null && nextKm <= odometerKm) {
      throw new DrivonException(
              ErrorCode.NEXT_SERVICE_KM_INVALID,
              "The next service mileage must be higher than the odometer at this service.")
          .with("minKm", odometerKm + 1);
    }
    return new ServiceDetails(
        request.serviceType(),
        request.date(),
        odometerKm,
        request.cost().setScale(2, RoundingMode.HALF_UP),
        blankToNull(request.notes()),
        next,
        nextKm);
  }

  private void syncOdometer(Vehicle vehicle, UUID recordId, ServiceDetails details) {
    Integer km = details.odometerKm();
    if (km == null) {
      odometer.removeLinked(vehicle, recordId);
    } else {
      odometer.recordLinked(vehicle, OdometerSource.MAINTENANCE, recordId, details.date(), km);
    }
  }

  private MaintenanceRecord find(UUID vehicleId, UUID recordId) {
    return records
        .findByIdAndVehicleId(recordId, vehicleId)
        .orElseThrow(() -> new DrivonException(ErrorCode.MAINTENANCE_RECORD_NOT_FOUND));
  }

  private static @Nullable String blankToNull(@Nullable String value) {
    if (value == null || value.isBlank()) {
      return null;
    }
    return value.strip();
  }
}
