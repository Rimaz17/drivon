package com.drivon.api.reminder;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.drivon.api.common.error.DrivonException;
import com.drivon.api.common.error.ErrorCode;
import com.drivon.api.common.time.BusinessCalendar;
import com.drivon.api.common.web.CreateResult;
import com.drivon.api.document.DocumentExpiry;
import com.drivon.api.document.DocumentService;
import com.drivon.api.document.DocumentType;
import com.drivon.api.document.DocumentsChangedEvent;
import com.drivon.api.maintenance.MaintenanceService;
import com.drivon.api.maintenance.ServiceDue;
import com.drivon.api.maintenance.ServiceScheduleChangedEvent;
import com.drivon.api.maintenance.ServiceType;
import com.drivon.api.vehicle.FuelType;
import com.drivon.api.vehicle.Vehicle;
import com.drivon.api.vehicle.VehicleResponse;
import com.drivon.api.vehicle.VehicleService;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

class ReminderServiceTest {

  private static final UUID USER = UUID.randomUUID();
  private static final UUID VEHICLE = UUID.randomUUID();
  private static final LocalDate TODAY = LocalDate.of(2026, 10, 10);
  private static final int ODOMETER = 48_000;

  private final ReminderRepository reminders = mock(ReminderRepository.class);
  private final VehicleService vehicles = mock(VehicleService.class);
  private final MaintenanceService maintenance = mock(MaintenanceService.class);
  private final DocumentService documents = mock(DocumentService.class);
  private final Vehicle vehicle = mock(Vehicle.class);
  private final ReminderService service =
      new ReminderService(
          reminders,
          vehicles,
          maintenance,
          documents,
          new BusinessCalendar(Clock.fixed(Instant.parse("2026-10-10T04:30:00Z"), ZoneOffset.UTC)));

  @BeforeEach
  void setUp() {
    when(vehicle.getId()).thenReturn(VEHICLE);
    when(vehicle.getCurrentOdometerKm()).thenReturn(ODOMETER);
    when(vehicles.requireOwned(USER, VEHICLE)).thenReturn(vehicle);
    when(reminders.saveAndFlush(any())).thenAnswer(i -> i.getArgument(0));
    when(reminders.findById(any())).thenReturn(Optional.empty());
  }

  private static ReminderRequest request(String title, LocalDate dueDate, Integer dueKm) {
    return new ReminderRequest(null, title, dueDate, dueKm);
  }

  private static ErrorCode codeOf(Throwable error) {
    return ((DrivonException) error).code();
  }

  @Test
  void addsAReminderDueByDateOrMileage() {
    CreateResult<ReminderResponse> result =
        service.create(USER, VEHICLE, request("  Emission test  ", TODAY.plusDays(5), 50_000));

    ReminderResponse saved = result.record();
    assertThat(result.created()).isTrue();
    assertThat(saved.source()).isEqualTo(ReminderSource.MANUAL);
    assertThat(saved.title()).isEqualTo("Emission test");
    assertThat(saved.daysRemaining()).isEqualTo(5);
    assertThat(saved.kmRemaining()).isEqualTo(2_000);
    assertThat(saved.status()).isEqualTo(ReminderStatus.DUE_SOON);
    assertThat(saved.remindFrom()).isEqualTo(TODAY.minusDays(2));
  }

  @Test
  void resendingTheSameIdReturnsTheSavedReminder() {
    Reminder existing = Reminder.manual(UUID.randomUUID(), VEHICLE, "Wash", TODAY, null);
    when(reminders.findById(existing.getId())).thenReturn(Optional.of(existing));

    CreateResult<ReminderResponse> result =
        service.create(
            USER, VEHICLE, new ReminderRequest(existing.getId(), "Wash", TODAY.plusDays(1), null));

    assertThat(result.created()).isFalse();
    assertThat(result.record().dueDate()).isEqualTo(TODAY);
    verify(reminders, never()).saveAndFlush(any());
  }

  @Test
  void anIdUsedByAnotherVehicleConflicts() {
    Reminder other = Reminder.manual(UUID.randomUUID(), UUID.randomUUID(), "Wash", TODAY, null);
    when(reminders.findById(other.getId())).thenReturn(Optional.of(other));

    assertThatThrownBy(
            () ->
                service.create(
                    USER, VEHICLE, new ReminderRequest(other.getId(), "Wash", TODAY, null)))
        .satisfies(e -> assertThat(codeOf(e)).isEqualTo(ErrorCode.RECORD_ID_CONFLICT));
  }

  @Test
  void needsADueDateOrMileage() {
    assertThatThrownBy(() -> service.create(USER, VEHICLE, request("Wash", null, null)))
        .satisfies(e -> assertThat(codeOf(e)).isEqualTo(ErrorCode.REMINDER_DUE_MISSING));
  }

  @Test
  void rejectsAPastDateButAcceptsToday() {
    assertThatThrownBy(
            () -> service.create(USER, VEHICLE, request("Wash", TODAY.minusDays(1), null)))
        .satisfies(e -> assertThat(codeOf(e)).isEqualTo(ErrorCode.REMINDER_DATE_PAST));

    assertThat(service.create(USER, VEHICLE, request("Wash", TODAY, null)).created()).isTrue();
  }

  @Test
  void rejectsAMileageTheOdometerAlreadyReached() {
    assertThatThrownBy(() -> service.create(USER, VEHICLE, request("Tyres", null, ODOMETER)))
        .satisfies(
            e -> {
              assertThat(codeOf(e)).isEqualTo(ErrorCode.REMINDER_KM_PAST);
              assertThat(((DrivonException) e).properties()).containsEntry("minKm", ODOMETER + 1);
            });
  }

  @Test
  void limitsTheUsersOwnRemindersPerVehicle() {
    when(reminders.countByVehicleIdAndSource(VEHICLE, ReminderSource.MANUAL))
        .thenReturn((long) ReminderService.MAX_MANUAL_PER_VEHICLE);

    assertThatThrownBy(() -> service.create(USER, VEHICLE, request("Wash", TODAY, null)))
        .satisfies(e -> assertThat(codeOf(e)).isEqualTo(ErrorCode.REMINDER_LIMIT_REACHED));
  }

  @Test
  void anOverdueReminderCanBeRenamedWithoutMovingItsDate() {
    Reminder overdue = Reminder.manual(UUID.randomUUID(), VEHICLE, "Wash", TODAY, ODOMETER - 10);
    overdue.reschedule(TODAY.minusDays(4), ODOMETER - 10);
    overdue.markNotified(NotificationStage.DUE, Instant.EPOCH);
    when(reminders.findByIdAndVehicleId(overdue.getId(), VEHICLE)).thenReturn(Optional.of(overdue));

    ReminderResponse updated =
        service.update(
            USER, VEHICLE, overdue.getId(), request("Car wash", TODAY.minusDays(4), ODOMETER - 10));

    assertThat(updated.title()).isEqualTo("Car wash");
    assertThat(updated.status()).isEqualTo(ReminderStatus.OVERDUE);
    // Same deadline: nothing is pushed again.
    assertThat(overdue.getNotifiedStage()).isEqualTo(NotificationStage.DUE);
  }

  @Test
  void movingTheDueDateStartsNotificationsOver() {
    Reminder reminder = Reminder.manual(UUID.randomUUID(), VEHICLE, "Wash", TODAY, null);
    reminder.markNotified(NotificationStage.DUE, Instant.EPOCH);
    when(reminders.findByIdAndVehicleId(reminder.getId(), VEHICLE))
        .thenReturn(Optional.of(reminder));

    service.update(USER, VEHICLE, reminder.getId(), request("Wash", TODAY.plusDays(20), null));

    assertThat(reminder.getNotifiedStage()).isEqualTo(NotificationStage.NONE);
    assertThat(reminder.getLastNotifiedAt()).isNull();
  }

  @Test
  void serviceAndDocumentRemindersCantBeEditedOrDeletedDirectly() {
    Reminder fromService =
        Reminder.forService(VEHICLE, ServiceType.OIL_CHANGE, UUID.randomUUID(), TODAY, null);
    when(reminders.findByIdAndVehicleId(fromService.getId(), VEHICLE))
        .thenReturn(Optional.of(fromService));

    assertThatThrownBy(
            () ->
                service.update(
                    USER, VEHICLE, fromService.getId(), request("Oil", TODAY.plusDays(3), null)))
        .satisfies(e -> assertThat(codeOf(e)).isEqualTo(ErrorCode.REMINDER_READ_ONLY));
    assertThatThrownBy(() -> service.delete(USER, VEHICLE, fromService.getId()))
        .satisfies(e -> assertThat(codeOf(e)).isEqualTo(ErrorCode.REMINDER_READ_ONLY));
  }

  @Test
  void aMissingReminderIsNotFound() {
    UUID id = UUID.randomUUID();
    when(reminders.findByIdAndVehicleId(id, VEHICLE)).thenReturn(Optional.empty());

    assertThatThrownBy(() -> service.get(USER, VEHICLE, id))
        .satisfies(e -> assertThat(codeOf(e)).isEqualTo(ErrorCode.REMINDER_NOT_FOUND));
  }

  @Test
  void listsAcrossVehiclesMostUrgentFirstAndFiltersByStatus() {
    UUID otherVehicle = UUID.randomUUID();
    when(vehicles.list(USER))
        .thenReturn(
            List.of(vehicleResponse(VEHICLE, ODOMETER), vehicleResponse(otherVehicle, 10_000)));
    Reminder upcoming = Reminder.manual(null, VEHICLE, "Wash", TODAY.plusDays(40), null);
    Reminder overdue =
        Reminder.forService(otherVehicle, ServiceType.OIL_CHANGE, UUID.randomUUID(), null, 9_000);
    Reminder dueSoon =
        Reminder.forDocument(
            VEHICLE, DocumentType.INSURANCE, UUID.randomUUID(), TODAY.plusDays(20));
    when(reminders.findByVehicleIdIn(anyCollection()))
        .thenReturn(List.of(upcoming, overdue, dueSoon));

    assertThat(service.list(USER, null, null))
        .extracting(ReminderResponse::status)
        .containsExactly(ReminderStatus.OVERDUE, ReminderStatus.DUE_SOON, ReminderStatus.UPCOMING);
    assertThat(service.list(USER, null, ReminderStatus.OVERDUE))
        .extracting(ReminderResponse::id)
        .containsExactly(overdue.getId());
  }

  @Test
  void aUserWithoutVehiclesHasNoReminders() {
    when(vehicles.list(USER)).thenReturn(List.of());

    assertThat(service.list(USER, null, null)).isEmpty();
    verify(reminders, never()).findByVehicleIdIn(anyCollection());
  }

  @Test
  @SuppressWarnings("unchecked")
  void keepsOneReminderPerServiceTypeInStepWithTheLatestRecords() {
    UUID oilRecord = UUID.randomUUID();
    UUID tyreRecord = UUID.randomUUID();
    Reminder oil =
        Reminder.forService(VEHICLE, ServiceType.OIL_CHANGE, UUID.randomUUID(), null, 50_000);
    oil.markNotified(NotificationStage.DUE_SOON, Instant.EPOCH);
    Reminder brakes =
        Reminder.forService(VEHICLE, ServiceType.BRAKE_SERVICE, UUID.randomUUID(), TODAY, null);
    when(reminders.findByVehicleIdAndSource(VEHICLE, ReminderSource.SERVICE))
        .thenReturn(List.of(oil, brakes));
    when(maintenance.nextServices(VEHICLE))
        .thenReturn(
            List.of(
                // A newer oil change moved the next one further out.
                new ServiceDue(ServiceType.OIL_CHANGE, oilRecord, null, 55_000),
                new ServiceDue(ServiceType.TYRE_ROTATION, tyreRecord, TODAY.plusMonths(6), null)));

    service.onServiceScheduleChanged(new ServiceScheduleChangedEvent(VEHICLE));

    // Brakes no longer have a next service.
    verify(reminders).delete(brakes);
    ArgumentCaptor<List<Reminder>> saved = ArgumentCaptor.forClass(List.class);
    verify(reminders).saveAllAndFlush(saved.capture());
    assertThat(saved.getValue()).hasSize(2);
    assertThat(oil.getSourceId()).isEqualTo(oilRecord);
    assertThat(oil.getDueKm()).isEqualTo(55_000);
    assertThat(oil.getNotifiedStage()).isEqualTo(NotificationStage.NONE);
    Reminder tyres = saved.getValue().get(1);
    assertThat(tyres.getServiceType()).isEqualTo(ServiceType.TYRE_ROTATION);
    assertThat(tyres.getSourceId()).isEqualTo(tyreRecord);
    assertThat(tyres.getDueDate()).isEqualTo(TODAY.plusMonths(6));
  }

  @Test
  void anUnchangedServiceKeepsWhatWasAlreadyNotified() {
    UUID record = UUID.randomUUID();
    Reminder oil = Reminder.forService(VEHICLE, ServiceType.OIL_CHANGE, record, null, 50_000);
    oil.markNotified(NotificationStage.DUE_SOON, Instant.EPOCH);
    when(reminders.findByVehicleIdAndSource(VEHICLE, ReminderSource.SERVICE))
        .thenReturn(new ArrayList<>(List.of(oil)));
    when(maintenance.nextServices(VEHICLE))
        .thenReturn(List.of(new ServiceDue(ServiceType.OIL_CHANGE, record, null, 50_000)));

    service.onServiceScheduleChanged(new ServiceScheduleChangedEvent(VEHICLE));

    assertThat(oil.getNotifiedStage()).isEqualTo(NotificationStage.DUE_SOON);
    verify(reminders, never()).delete(any());
  }

  @Test
  @SuppressWarnings("unchecked")
  void keepsOneReminderPerDocumentTypeForTheLatestExpiry() {
    UUID renewed = UUID.randomUUID();
    Reminder insurance =
        Reminder.forDocument(VEHICLE, DocumentType.INSURANCE, UUID.randomUUID(), TODAY);
    Reminder licence =
        Reminder.forDocument(VEHICLE, DocumentType.REVENUE_LICENCE, UUID.randomUUID(), TODAY);
    when(reminders.findByVehicleIdAndSource(VEHICLE, ReminderSource.DOCUMENT))
        .thenReturn(List.of(insurance, licence));
    when(documents.latestExpiries(VEHICLE))
        .thenReturn(
            List.of(new DocumentExpiry(DocumentType.INSURANCE, renewed, TODAY.plusYears(1))));

    service.onDocumentsChanged(new DocumentsChangedEvent(VEHICLE));

    verify(reminders).delete(licence);
    ArgumentCaptor<List<Reminder>> saved = ArgumentCaptor.forClass(List.class);
    verify(reminders).saveAllAndFlush(saved.capture());
    assertThat(saved.getValue()).containsExactly(insurance);
    assertThat(insurance.getSourceId()).isEqualTo(renewed);
    assertThat(insurance.getDueDate()).isEqualTo(TODAY.plusYears(1));
  }

  private static VehicleResponse vehicleResponse(UUID id, int odometerKm) {
    return new VehicleResponse(
        id,
        "Toyota",
        "Aqua",
        2018,
        "CAB-1234",
        FuelType.HYBRID,
        odometerKm,
        Instant.EPOCH,
        Instant.EPOCH);
  }
}
