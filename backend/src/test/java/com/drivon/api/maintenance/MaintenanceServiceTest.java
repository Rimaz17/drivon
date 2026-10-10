package com.drivon.api.maintenance;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.drivon.api.common.error.DrivonException;
import com.drivon.api.common.error.ErrorCode;
import com.drivon.api.common.time.BusinessCalendar;
import com.drivon.api.common.web.CreateResult;
import com.drivon.api.maintenance.MaintenanceRecord.ServiceDetails;
import com.drivon.api.vehicle.OdometerService;
import com.drivon.api.vehicle.OdometerSource;
import com.drivon.api.vehicle.Vehicle;
import com.drivon.api.vehicle.VehicleService;
import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;

class MaintenanceServiceTest {

  private static final UUID USER = UUID.randomUUID();
  private static final UUID VEHICLE = UUID.randomUUID();
  private static final LocalDate TODAY = LocalDate.of(2026, 10, 7);

  private final MaintenanceRecordRepository records = mock(MaintenanceRecordRepository.class);
  private final VehicleService vehicles = mock(VehicleService.class);
  private final OdometerService odometer = mock(OdometerService.class);
  private final Vehicle vehicle = mock(Vehicle.class);
  private final ApplicationEventPublisher events = mock(ApplicationEventPublisher.class);
  private final MaintenanceService service =
      new MaintenanceService(
          records,
          vehicles,
          odometer,
          new BusinessCalendar(Clock.fixed(Instant.parse("2026-10-07T04:30:00Z"), ZoneOffset.UTC)),
          events);

  @BeforeEach
  void setUp() {
    when(odometer.lockVehicle(USER, VEHICLE)).thenReturn(vehicle);
    when(vehicles.requireOwned(USER, VEHICLE)).thenReturn(vehicle);
    when(records.saveAndFlush(any())).thenAnswer(i -> i.getArgument(0));
    when(records.findById(any())).thenReturn(Optional.empty());
  }

  private static MaintenanceRecordRequest request(
      Integer odometerKm, LocalDate nextDate, Integer nextKm) {
    return new MaintenanceRecordRequest(
        null,
        ServiceType.OIL_CHANGE,
        TODAY,
        odometerKm,
        new BigDecimal("9800"),
        "  Mobil 5W-30  ",
        nextDate,
        nextKm);
  }

  private static MaintenanceRecord record(
      ServiceType type, LocalDate date, LocalDate nextDate, Integer nextKm) {
    return new MaintenanceRecord(
        null,
        VEHICLE,
        new ServiceDetails(type, date, 45_000, new BigDecimal("9800.00"), null, nextDate, nextKm));
  }

  private static ErrorCode codeOf(Throwable error) {
    return ((DrivonException) error).code();
  }

  @Test
  void logsAServiceAndPutsItsOdometerOnTheTimeline() {
    CreateResult<MaintenanceRecordResponse> result =
        service.create(USER, VEHICLE, request(45_000, TODAY.plusMonths(6), 50_000));

    MaintenanceRecordResponse saved = result.record();
    assertThat(result.created()).isTrue();
    assertThat(saved.cost().toPlainString()).isEqualTo("9800.00");
    assertThat(saved.notes()).isEqualTo("Mobil 5W-30");
    verify(odometer).recordLinked(vehicle, OdometerSource.MAINTENANCE, saved.id(), TODAY, 45_000);
  }

  @Test
  void aServiceWithoutAnOdometerLeavesTheTimelineAlone() {
    MaintenanceRecordResponse saved =
        service.create(USER, VEHICLE, request(null, null, null)).record();

    verify(odometer, never()).recordLinked(any(), any(), any(), any(), anyInt());
    assertThat(saved.odometerKm()).isNull();
  }

  @Test
  void theNextServiceDateMustBeAfterTheService() {
    assertThatThrownBy(() -> service.create(USER, VEHICLE, request(45_000, TODAY, null)))
        .extracting(MaintenanceServiceTest::codeOf)
        .isEqualTo(ErrorCode.NEXT_SERVICE_DATE_INVALID);
    verify(records, never()).saveAndFlush(any());
  }

  @Test
  void theNextServiceMileageMustBeAboveTheOdometer() {
    assertThatThrownBy(() -> service.create(USER, VEHICLE, request(45_000, null, 45_000)))
        .isInstanceOfSatisfying(
            DrivonException.class,
            e -> {
              assertThat(e.code()).isEqualTo(ErrorCode.NEXT_SERVICE_KM_INVALID);
              assertThat(e.properties()).containsEntry("minKm", 45_001);
            });
    // Without an odometer any positive mileage is accepted.
    assertThat(service.create(USER, VEHICLE, request(null, null, 5_000)).record().nextServiceKm())
        .isEqualTo(5_000);
  }

  @Test
  void rejectsFutureServices() {
    assertThatThrownBy(
            () ->
                service.create(
                    USER,
                    VEHICLE,
                    new MaintenanceRecordRequest(
                        null,
                        ServiceType.OIL_CHANGE,
                        TODAY.plusDays(1),
                        null,
                        BigDecimal.ONE,
                        null,
                        null,
                        null)))
        .extracting(MaintenanceServiceTest::codeOf)
        .isEqualTo(ErrorCode.DATE_IN_FUTURE);
  }

  @Test
  void removingTheOdometerOnUpdateRemovesItsReading() {
    MaintenanceRecord existing = record(ServiceType.OIL_CHANGE, TODAY, null, null);
    when(records.findByIdAndVehicleId(existing.getId(), VEHICLE)).thenReturn(Optional.of(existing));

    service.update(USER, VEHICLE, existing.getId(), request(null, null, null));

    verify(odometer).removeLinked(vehicle, existing.getId());
    assertThat(existing.getOdometerKm()).isNull();
  }

  @Test
  void deleteRemovesTheRecordAndItsReading() {
    MaintenanceRecord existing = record(ServiceType.OIL_CHANGE, TODAY, null, null);
    when(records.findByIdAndVehicleId(existing.getId(), VEHICLE)).thenReturn(Optional.of(existing));

    service.delete(USER, VEHICLE, existing.getId());

    verify(records).delete(existing);
    verify(odometer).removeLinked(vehicle, existing.getId());
  }

  @Test
  void aRetriedCreateReturnsTheSavedRecord() {
    MaintenanceRecord existing = record(ServiceType.OIL_CHANGE, TODAY, null, null);
    when(records.findById(existing.getId())).thenReturn(Optional.of(existing));

    CreateResult<MaintenanceRecordResponse> retry =
        service.create(
            USER,
            VEHICLE,
            new MaintenanceRecordRequest(
                existing.getId(),
                ServiceType.OTHER,
                TODAY,
                null,
                BigDecimal.ONE,
                null,
                null,
                null));

    assertThat(retry.created()).isFalse();
    assertThat(retry.record().serviceType()).isEqualTo(ServiceType.OIL_CHANGE);
    verify(records, never()).saveAndFlush(any());
  }

  @Test
  void aRecordUnderAnotherVehicleIsNotFound() {
    UUID id = UUID.randomUUID();
    when(records.findByIdAndVehicleId(id, VEHICLE)).thenReturn(Optional.empty());

    assertThatThrownBy(() -> service.get(USER, VEHICLE, id))
        .extracting(MaintenanceServiceTest::codeOf)
        .isEqualTo(ErrorCode.MAINTENANCE_RECORD_NOT_FOUND);
  }

  @Test
  void listsOneServiceTypeWhenAsked() {
    when(records.findByVehicleIdAndServiceType(eq(VEHICLE), eq(ServiceType.OIL_CHANGE), any()))
        .thenReturn(new PageImpl<>(List.of(), PageRequest.of(0, 20), 0));

    service.list(USER, VEHICLE, ServiceType.OIL_CHANGE, PageRequest.of(0, 20));

    verify(vehicles).requireOwned(USER, VEHICLE);
    verify(records).findByVehicleIdAndServiceType(eq(VEHICLE), eq(ServiceType.OIL_CHANGE), any());
  }

  @Test
  void upcomingServicesComeFromTheLatestRecordOfEachTypeSoonestFirst() {
    when(vehicle.getCurrentOdometerKm()).thenReturn(46_000);
    when(records.findLatestOfEachType(VEHICLE))
        .thenReturn(
            List.of(
                record(ServiceType.GENERAL_SERVICE, TODAY.minusMonths(5), TODAY.plusDays(30), null),
                record(ServiceType.OIL_CHANGE, TODAY.minusMonths(2), null, 50_000),
                record(ServiceType.TYRE_ROTATION, TODAY.minusYears(1), TODAY.minusDays(3), null),
                record(ServiceType.BRAKE_SERVICE, TODAY.minusMonths(1), null, null)));

    List<UpcomingServiceResponse> upcoming = service.upcoming(USER, VEHICLE);

    assertThat(upcoming)
        .extracting(UpcomingServiceResponse::serviceType)
        .containsExactly(
            ServiceType.TYRE_ROTATION, ServiceType.GENERAL_SERVICE, ServiceType.OIL_CHANGE);
    assertThat(upcoming.get(0).overdue()).isTrue();
    assertThat(upcoming.get(0).daysRemaining()).isEqualTo(-3);
    assertThat(upcoming.get(1).daysRemaining()).isEqualTo(30);
    assertThat(upcoming.get(2).kmRemaining()).isEqualTo(4_000);
    assertThat(upcoming.get(2).overdue()).isFalse();
  }

  @Test
  void aServiceIsOverdueByMileageEvenBeforeItsDate() {
    UpcomingServiceResponse due =
        MaintenanceService.toUpcoming(
            record(ServiceType.OIL_CHANGE, TODAY, TODAY.plusMonths(3), 46_000), TODAY, 46_200);

    assertThat(due.kmRemaining()).isEqualTo(-200);
    assertThat(due.overdue()).isTrue();
  }

  @Test
  void dueTodayIsNotYetOverdue() {
    UpcomingServiceResponse due =
        MaintenanceService.toUpcoming(
            record(ServiceType.OIL_CHANGE, TODAY.minusMonths(6), TODAY, null), TODAY, 0);

    assertThat(due.daysRemaining()).isZero();
    assertThat(due.overdue()).isFalse();
  }
}
