package com.drivon.api.vehicle;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.drivon.api.common.error.DrivonException;
import com.drivon.api.common.error.ErrorCode;
import com.drivon.api.user.UserService;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.mockito.InOrder;
import org.springframework.context.ApplicationEventPublisher;

class VehicleServiceTest {

  private static final UUID USER = UUID.randomUUID();
  private static final Clock CLOCK =
      Clock.fixed(Instant.parse("2026-10-07T10:00:00Z"), ZoneOffset.UTC);

  private final VehicleRepository repository = mock(VehicleRepository.class);
  private final OdometerService odometer = mock(OdometerService.class);
  private final UserService users = mock(UserService.class);
  private final ApplicationEventPublisher events = mock(ApplicationEventPublisher.class);
  private final VehicleService service =
      new VehicleService(repository, odometer, users, events, CLOCK);

  private static VehicleRequest request(String registration, int year, int odometer) {
    return new VehicleRequest(" Toyota ", "Aqua", year, registration, FuelType.HYBRID, odometer);
  }

  @Test
  void createsVehicleWithTrimmedFieldsAndNormalizedRegistration() {
    when(repository.saveAndFlush(any())).thenAnswer(i -> i.getArgument(0));

    VehicleResponse response = service.create(USER, request("cab - 1234", 2018, 45_000));

    assertThat(response.make()).isEqualTo("Toyota");
    assertThat(response.registrationNumber()).isEqualTo("CAB-1234");
    assertThat(response.currentOdometerKm()).isEqualTo(45_000);
  }

  @Test
  void startsTheOdometerTimelineOfANewVehicle() {
    when(repository.saveAndFlush(any())).thenAnswer(i -> i.getArgument(0));

    service.create(USER, request("CAB-1234", 2018, 45_000));

    ArgumentCaptor<Vehicle> saved = ArgumentCaptor.forClass(Vehicle.class);
    verify(odometer).recordInitial(saved.capture());
    assertThat(saved.getValue().getCurrentOdometerKm()).isEqualTo(45_000);
  }

  @Test
  void locksTheUserBeforeCountingVehicles() {
    when(repository.saveAndFlush(any())).thenAnswer(i -> i.getArgument(0));

    service.create(USER, request("CAB-1234", 2018, 0));

    InOrder order = inOrder(users, repository);
    order.verify(users).lockForUpdate(USER);
    order.verify(repository).countByUserId(USER);
  }

  @Test
  void refusesAThirdVehicle() {
    when(repository.countByUserId(USER)).thenReturn(2L);

    assertThatThrownBy(() -> service.create(USER, request("CAB-1234", 2018, 0)))
        .extracting(e -> ((DrivonException) e).code())
        .isEqualTo(ErrorCode.VEHICLE_LIMIT_REACHED);
    verify(repository, never()).saveAndFlush(any());
  }

  @Test
  void allowsTheSecondVehicle() {
    when(repository.countByUserId(USER)).thenReturn(1L);
    when(repository.saveAndFlush(any())).thenAnswer(i -> i.getArgument(0));

    assertThat(service.create(USER, request("BBK-1234", 2015, 0))).isNotNull();
  }

  @Test
  void refusesDuplicateRegistrationForTheSameUser() {
    when(repository.existsByUserIdAndRegistrationNumber(USER, "CAB-1234")).thenReturn(true);

    assertThatThrownBy(() -> service.create(USER, request("cab-1234", 2018, 0)))
        .extracting(e -> ((DrivonException) e).code())
        .isEqualTo(ErrorCode.REGISTRATION_NUMBER_IN_USE);
  }

  @Test
  void acceptsNextYearsModelButNotLater() {
    when(repository.saveAndFlush(any())).thenAnswer(i -> i.getArgument(0));

    assertThat(service.create(USER, request("CAB-1234", 2027, 0))).isNotNull();
    assertThatThrownBy(() -> service.create(USER, request("CAB-1235", 2028, 0)))
        .extracting(e -> ((DrivonException) e).code())
        .isEqualTo(ErrorCode.INVALID_MODEL_YEAR);
  }

  @Test
  void reportsAnotherUsersVehicleAsNotFound() {
    UUID vehicleId = UUID.randomUUID();
    when(repository.findByIdAndUserId(vehicleId, USER)).thenReturn(Optional.empty());

    assertThatThrownBy(() -> service.get(USER, vehicleId))
        .extracting(e -> ((DrivonException) e).code())
        .isEqualTo(ErrorCode.VEHICLE_NOT_FOUND);
    assertThatThrownBy(() -> service.delete(USER, vehicleId))
        .extracting(e -> ((DrivonException) e).code())
        .isEqualTo(ErrorCode.VEHICLE_NOT_FOUND);
  }

  @Test
  void announcesADeletionBeforeRemovingTheVehicle() {
    Vehicle existing = existing(50_000);
    UUID id = UUID.randomUUID();
    when(repository.findByIdAndUserId(id, USER)).thenReturn(Optional.of(existing));

    service.delete(USER, id);

    InOrder order = inOrder(events, repository);
    order.verify(events).publishEvent(new VehicleDeletingEvent(id));
    order.verify(repository).delete(existing);
  }

  @Test
  void keepsTheOdometerTimelineWhenTheOdometerStaysTheSame() {
    Vehicle existing = existing(50_000);
    UUID id = UUID.randomUUID();
    when(repository.findByIdAndUserIdForUpdate(id, USER)).thenReturn(Optional.of(existing));
    when(repository.saveAndFlush(existing)).thenReturn(existing);

    VehicleResponse response = service.update(USER, id, request("CAB-1234", 2019, 50_000));

    assertThat(response.year()).isEqualTo(2019);
    assertThat(response.currentOdometerKm()).isEqualTo(50_000);
    verify(odometer, never()).recordRaised(any(), org.mockito.ArgumentMatchers.anyInt());
  }

  @Test
  void recordsAHigherOdometerAsAReadingForToday() {
    Vehicle existing = existing(50_000);
    UUID id = UUID.randomUUID();
    when(repository.findByIdAndUserIdForUpdate(id, USER)).thenReturn(Optional.of(existing));
    when(repository.saveAndFlush(existing)).thenReturn(existing);

    service.update(USER, id, request("CAB-1234", 2018, 51_200));

    verify(odometer).recordRaised(existing, 51_200);
  }

  @Test
  void refusesToMoveTheOdometerBackwards() {
    Vehicle existing = existing(50_000);
    UUID id = UUID.randomUUID();
    when(repository.findByIdAndUserIdForUpdate(id, USER)).thenReturn(Optional.of(existing));

    assertThatThrownBy(() -> service.update(USER, id, request("CAB-1234", 2018, 49_999)))
        .isInstanceOfSatisfying(
            DrivonException.class,
            e -> {
              assertThat(e.code()).isEqualTo(ErrorCode.ODOMETER_DECREASE);
              assertThat(e.getMessage()).contains("50000");
            });
    assertThat(existing.getCurrentOdometerKm()).isEqualTo(50_000);
  }

  @Test
  void keepingTheSameRegistrationOnUpdateIsNotAConflict() {
    Vehicle existing = existing(10);
    UUID id = UUID.randomUUID();
    when(repository.findByIdAndUserIdForUpdate(id, USER)).thenReturn(Optional.of(existing));
    when(repository.saveAndFlush(existing)).thenReturn(existing);

    service.update(USER, id, request("CAB-1234", 2018, 10));

    ArgumentCaptor<UUID> excluded = ArgumentCaptor.forClass(UUID.class);
    verify(repository)
        .existsByUserIdAndRegistrationNumberAndIdNot(
            org.mockito.ArgumentMatchers.eq(USER),
            org.mockito.ArgumentMatchers.eq("CAB-1234"),
            excluded.capture());
    assertThat(excluded.getValue()).isEqualTo(id);
  }

  private static Vehicle existing(int odometer) {
    return new Vehicle(USER, "Toyota", "Aqua", 2018, "CAB-1234", FuelType.HYBRID, odometer);
  }
}
