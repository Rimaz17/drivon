package com.drivon.api.vehicle;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.drivon.api.common.error.DrivonException;
import com.drivon.api.common.error.ErrorCode;
import com.drivon.api.common.time.BusinessCalendar;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.test.util.ReflectionTestUtils;

class OdometerServiceTest {

  private static final UUID USER = UUID.randomUUID();
  private static final UUID VEHICLE = UUID.randomUUID();

  /** 10:00 on 7 October 2026 in Colombo. */
  private static final LocalDate TODAY = LocalDate.of(2026, 10, 7);

  private final OdometerReadingRepository readings = mock(OdometerReadingRepository.class);
  private final VehicleRepository vehicles = mock(VehicleRepository.class);
  private final ApplicationEventPublisher events = mock(ApplicationEventPublisher.class);
  private final OdometerService service =
      new OdometerService(
          readings,
          vehicles,
          new BusinessCalendar(Clock.fixed(Instant.parse("2026-10-07T04:30:00Z"), ZoneOffset.UTC)),
          events);

  private Vehicle vehicle;

  @BeforeEach
  void setUp() {
    vehicle = new Vehicle(USER, "Toyota", "Aqua", 2018, "CAB-1234", FuelType.HYBRID, 45_000);
    // The database assigns vehicle IDs; set the one the stubs below expect.
    ReflectionTestUtils.setField(vehicle, "id", VEHICLE);
    when(vehicles.findByIdAndUserIdForUpdate(VEHICLE, USER)).thenReturn(Optional.of(vehicle));
    when(vehicles.findByIdAndUserId(VEHICLE, USER)).thenReturn(Optional.of(vehicle));
    when(readings.saveAndFlush(any())).thenAnswer(i -> i.getArgument(0));
    when(readings.findMaxBefore(any(), any(), any())).thenReturn(Optional.empty());
    when(readings.findMinAfter(any(), any(), any())).thenReturn(Optional.empty());
  }

  private static OdometerReadingRequest request(int km, LocalDate date) {
    return new OdometerReadingRequest(km, date);
  }

  private OdometerReading stored(OdometerSource source, int km) {
    UUID sourceId = source.isLinked() ? UUID.randomUUID() : null;
    OdometerReading reading = new OdometerReading(VEHICLE, source, sourceId, TODAY, km);
    when(readings.findByIdAndVehicleId(reading.getId(), VEHICLE)).thenReturn(Optional.of(reading));
    return reading;
  }

  private static ErrorCode codeOf(Throwable error) {
    return ((DrivonException) error).code();
  }

  @Test
  void addsAReadingThatFitsBetweenItsNeighboursAndSyncsTheVehicle() {
    when(readings.findMaxBefore(eq(VEHICLE), eq(LocalDate.of(2026, 9, 10)), any()))
        .thenReturn(Optional.of(45_000));
    when(readings.findMinAfter(eq(VEHICLE), eq(LocalDate.of(2026, 9, 10)), any()))
        .thenReturn(Optional.of(47_000));
    when(readings.findMaxReading(VEHICLE)).thenReturn(Optional.of(47_000));

    OdometerReadingResponse response =
        service.add(USER, VEHICLE, request(46_000, LocalDate.of(2026, 9, 10)));

    assertThat(response.readingKm()).isEqualTo(46_000);
    assertThat(response.source()).isEqualTo(OdometerSource.MANUAL);
    assertThat(vehicle.getCurrentOdometerKm()).isEqualTo(47_000);
  }

  @Test
  void acceptsAReadingEqualToItsNeighbours() {
    when(readings.findMaxBefore(any(), any(), any())).thenReturn(Optional.of(45_000));
    when(readings.findMinAfter(any(), any(), any())).thenReturn(Optional.of(45_000));

    assertThat(service.add(USER, VEHICLE, request(45_000, TODAY)).readingKm()).isEqualTo(45_000);
  }

  @Test
  void rejectsAReadingLowerThanOneOnAnEarlierDate() {
    when(readings.findMaxBefore(any(), any(), any())).thenReturn(Optional.of(45_000));

    assertThatThrownBy(() -> service.add(USER, VEHICLE, request(44_999, TODAY)))
        .isInstanceOfSatisfying(
            DrivonException.class,
            e -> {
              assertThat(e.code()).isEqualTo(ErrorCode.ODOMETER_OUT_OF_ORDER);
              assertThat(e.getMessage()).contains("at least 45,000 km");
              assertThat(e.properties()).containsEntry("minKm", 45_000).doesNotContainKey("maxKm");
            });
    verify(readings, never()).saveAndFlush(any());
  }

  @Test
  void rejectsAReadingHigherThanOneOnALaterDate() {
    when(readings.findMinAfter(any(), any(), any())).thenReturn(Optional.of(47_000));

    assertThatThrownBy(() -> service.add(USER, VEHICLE, request(47_001, LocalDate.of(2026, 9, 1))))
        .isInstanceOfSatisfying(
            DrivonException.class,
            e -> {
              assertThat(e.code()).isEqualTo(ErrorCode.ODOMETER_OUT_OF_ORDER);
              assertThat(e.getMessage()).contains("at most 47,000 km");
              assertThat(e.properties()).containsEntry("maxKm", 47_000).doesNotContainKey("minKm");
            });
  }

  @Test
  void namesBothLimitsWhenTheReadingIsSqueezedBetweenTwoDates() {
    when(readings.findMaxBefore(any(), any(), any())).thenReturn(Optional.of(45_000));
    when(readings.findMinAfter(any(), any(), any())).thenReturn(Optional.of(46_000));

    assertThatThrownBy(() -> service.add(USER, VEHICLE, request(46_500, LocalDate.of(2026, 9, 1))))
        .hasMessageContaining("between 45,000 and 46,000 km");
  }

  @Test
  void rejectsReadingsDatedInTheFuture() {
    assertThatThrownBy(() -> service.add(USER, VEHICLE, request(46_000, TODAY.plusDays(1))))
        .extracting(OdometerServiceTest::codeOf)
        .isEqualTo(ErrorCode.DATE_IN_FUTURE);
  }

  @Test
  void correctingAMistypedInitialReadingLowersTheCurrentOdometer() {
    OdometerReading typo = stored(OdometerSource.INITIAL, 450_000);
    when(readings.findMaxReading(VEHICLE)).thenReturn(Optional.of(45_000));

    OdometerReadingResponse corrected =
        service.correct(USER, VEHICLE, typo.getId(), request(45_000, TODAY));

    assertThat(corrected.readingKm()).isEqualTo(45_000);
    assertThat(corrected.source()).isEqualTo(OdometerSource.INITIAL);
    assertThat(vehicle.getCurrentOdometerKm()).isEqualTo(45_000);
  }

  @Test
  void theReadingBeingCorrectedIsNotItsOwnNeighbour() {
    OdometerReading reading = stored(OdometerSource.MANUAL, 46_000);

    service.correct(USER, VEHICLE, reading.getId(), request(45_500, TODAY));

    verify(readings).findMaxBefore(VEHICLE, TODAY, reading.getId());
    verify(readings).findMinAfter(VEHICLE, TODAY, reading.getId());
  }

  @Test
  void aFillUpsReadingCanOnlyChangeThroughTheFillUp() {
    OdometerReading fuel = stored(OdometerSource.FUEL, 46_000);

    assertThatThrownBy(() -> service.correct(USER, VEHICLE, fuel.getId(), request(1, TODAY)))
        .isInstanceOfSatisfying(
            DrivonException.class,
            e -> {
              assertThat(e.code()).isEqualTo(ErrorCode.ODOMETER_READING_LOCKED);
              assertThat(e.getMessage()).contains("fill-up");
            });
    assertThatThrownBy(() -> service.delete(USER, VEHICLE, fuel.getId()))
        .extracting(OdometerServiceTest::codeOf)
        .isEqualTo(ErrorCode.ODOMETER_READING_LOCKED);
  }

  @Test
  void theInitialReadingCanBeCorrectedButNotDeleted() {
    OdometerReading initial = stored(OdometerSource.INITIAL, 45_000);

    assertThatThrownBy(() -> service.delete(USER, VEHICLE, initial.getId()))
        .extracting(OdometerServiceTest::codeOf)
        .isEqualTo(ErrorCode.ODOMETER_READING_LOCKED);
    verify(readings, never()).delete(any());
  }

  @Test
  void deletingAManualReadingResyncsTheVehicle() {
    OdometerReading manual = stored(OdometerSource.MANUAL, 48_000);
    when(readings.findMaxReading(VEHICLE)).thenReturn(Optional.of(46_000));

    service.delete(USER, VEHICLE, manual.getId());

    verify(readings).delete(manual);
    assertThat(vehicle.getCurrentOdometerKm()).isEqualTo(46_000);
  }

  @Test
  void aMissingReadingIsNotFound() {
    assertThatThrownBy(() -> service.get(USER, VEHICLE, UUID.randomUUID()))
        .extracting(OdometerServiceTest::codeOf)
        .isEqualTo(ErrorCode.ODOMETER_READING_NOT_FOUND);
  }

  @Test
  void anotherUsersVehicleIsNotFound() {
    UUID stranger = UUID.randomUUID();
    when(vehicles.findByIdAndUserIdForUpdate(VEHICLE, stranger)).thenReturn(Optional.empty());
    when(vehicles.findByIdAndUserId(VEHICLE, stranger)).thenReturn(Optional.empty());

    assertThatThrownBy(() -> service.add(stranger, VEHICLE, request(1, TODAY)))
        .extracting(OdometerServiceTest::codeOf)
        .isEqualTo(ErrorCode.VEHICLE_NOT_FOUND);
    assertThatThrownBy(() -> service.get(stranger, VEHICLE, UUID.randomUUID()))
        .extracting(OdometerServiceTest::codeOf)
        .isEqualTo(ErrorCode.VEHICLE_NOT_FOUND);
  }

  @Test
  void aLinkedReadingIsCreatedOnceAndMovedWithItsRecord() {
    UUID fillUp = UUID.randomUUID();
    when(readings.findBySourceId(fillUp)).thenReturn(Optional.empty());

    service.recordLinked(vehicle, OdometerSource.FUEL, fillUp, TODAY, 46_000);

    var saved = org.mockito.ArgumentCaptor.forClass(OdometerReading.class);
    verify(readings).saveAndFlush(saved.capture());
    OdometerReading created = saved.getValue();
    assertThat(created.getSourceId()).isEqualTo(fillUp);
    assertThat(created.getSource()).isEqualTo(OdometerSource.FUEL);

    when(readings.findBySourceId(fillUp)).thenReturn(Optional.of(created));
    service.recordLinked(vehicle, OdometerSource.FUEL, fillUp, TODAY.minusDays(1), 45_900);

    assertThat(created.getReadingKm()).isEqualTo(45_900);
    assertThat(created.getDate()).isEqualTo(TODAY.minusDays(1));
  }

  @Test
  void onlyFillUpsAndServicesHaveLinkedReadings() {
    assertThatThrownBy(
            () ->
                service.recordLinked(
                    vehicle, OdometerSource.MANUAL, UUID.randomUUID(), TODAY, 46_000))
        .isInstanceOf(IllegalArgumentException.class);
  }

  @Test
  void removingALinkedReadingResyncsTheVehicle() {
    UUID fillUp = UUID.randomUUID();
    OdometerReading reading =
        new OdometerReading(VEHICLE, OdometerSource.FUEL, fillUp, TODAY, 47_000);
    when(readings.findBySourceId(fillUp)).thenReturn(Optional.of(reading));
    when(readings.findMaxReading(any())).thenReturn(Optional.of(45_000));

    service.removeLinked(vehicle, fillUp);

    verify(readings).delete(reading);
    assertThat(vehicle.getCurrentOdometerKm()).isEqualTo(45_000);
  }

  @Test
  void aRaisedVehicleOdometerBecomesAManualReadingForToday() {
    when(readings.findMaxReading(any())).thenReturn(Optional.of(51_200));

    service.recordRaised(vehicle, 51_200);

    var saved = org.mockito.ArgumentCaptor.forClass(OdometerReading.class);
    verify(readings).saveAndFlush(saved.capture());
    assertThat(saved.getValue().getSource()).isEqualTo(OdometerSource.MANUAL);
    assertThat(saved.getValue().getDate()).isEqualTo(TODAY);
    assertThat(vehicle.getCurrentOdometerKm()).isEqualTo(51_200);
  }
}
