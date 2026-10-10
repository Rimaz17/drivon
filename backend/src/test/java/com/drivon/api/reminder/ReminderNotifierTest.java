package com.drivon.api.reminder;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.drivon.api.common.time.BusinessCalendar;
import com.drivon.api.notification.PushMessage;
import com.drivon.api.notification.PushNotifier;
import com.drivon.api.notification.PushNotifier.Outcome;
import com.drivon.api.reminder.ReminderNotifier.RunSummary;
import com.drivon.api.vehicle.OdometerChangedEvent;
import com.drivon.api.vehicle.Vehicle;
import com.drivon.api.vehicle.VehicleService;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.transaction.PlatformTransactionManager;

class ReminderNotifierTest {

  private static final Instant NOW = Instant.parse("2026-10-10T04:30:00Z");
  private static final LocalDate TODAY = LocalDate.of(2026, 10, 10);
  private static final UUID USER = UUID.randomUUID();
  private static final UUID VEHICLE = UUID.randomUUID();
  private static final int ODOMETER = 48_000;

  private final ReminderRepository reminders = mock(ReminderRepository.class);
  private final VehicleService vehicles = mock(VehicleService.class);
  private final PushNotifier push = mock(PushNotifier.class);
  private final Vehicle vehicle = mock(Vehicle.class);
  private final Clock clock = Clock.fixed(NOW, ZoneOffset.UTC);
  private final ReminderNotifier notifier =
      new ReminderNotifier(
          reminders,
          vehicles,
          push,
          new BusinessCalendar(clock),
          clock,
          mock(PlatformTransactionManager.class));

  @BeforeEach
  void setUp() {
    when(vehicle.getId()).thenReturn(VEHICLE);
    when(vehicle.getUserId()).thenReturn(USER);
    when(vehicle.getMake()).thenReturn("Toyota");
    when(vehicle.getModel()).thenReturn("Aqua");
    when(vehicle.getRegistrationNumber()).thenReturn("CAB-1234");
    when(vehicle.getCurrentOdometerKm()).thenReturn(ODOMETER);
    when(vehicles.findForBackgroundJob(VEHICLE)).thenReturn(Optional.of(vehicle));
  }

  private void pending(Reminder... found) {
    when(reminders.findPendingIds(TODAY.plusDays(30), ReminderRules.KM_LEAD))
        .thenReturn(List.of(found).stream().map(Reminder::getId).toList());
    for (Reminder reminder : found) {
      when(reminders.findByIdForUpdate(reminder.getId())).thenReturn(Optional.of(reminder));
    }
  }

  @Test
  void pushesADueSoonReminderOnceAndRemembersIt() {
    Reminder reminder = Reminder.manual(null, VEHICLE, "Emission test", TODAY.plusDays(3), null);
    pending(reminder);
    when(push.notifyUser(eq(USER), any())).thenReturn(Outcome.DELIVERED);

    RunSummary first = notifier.notifyAllDue();
    RunSummary second = notifier.notifyAllDue();

    assertThat(first).isEqualTo(new RunSummary(1, 1, 0));
    assertThat(second).isEqualTo(new RunSummary(1, 0, 0));
    verify(push).notifyUser(eq(USER), any());
    assertThat(reminder.getNotifiedStage()).isEqualTo(NotificationStage.DUE_SOON);
    assertThat(reminder.getLastNotifiedAt()).isEqualTo(NOW);
  }

  @Test
  void aMissedRunGoesStraightToTheDueNotification() {
    Reminder reminder = Reminder.manual(null, VEHICLE, "Emission test", TODAY.minusDays(5), null);
    pending(reminder);
    when(push.notifyUser(eq(USER), any())).thenReturn(Outcome.DELIVERED);

    notifier.notifyAllDue();

    ArgumentCaptor<PushMessage> message = ArgumentCaptor.forClass(PushMessage.class);
    verify(push).notifyUser(eq(USER), message.capture());
    assertThat(message.getValue().title()).isEqualTo("Emission test is overdue");
    assertThat(reminder.getNotifiedStage()).isEqualTo(NotificationStage.DUE);
  }

  @Test
  void aFailedPushIsTriedAgainOnTheNextRun() {
    Reminder reminder = Reminder.manual(null, VEHICLE, "Emission test", TODAY, null);
    pending(reminder);
    when(push.notifyUser(eq(USER), any())).thenReturn(Outcome.FAILED, Outcome.DELIVERED);

    assertThat(notifier.notifyAllDue()).isEqualTo(new RunSummary(1, 0, 1));
    assertThat(reminder.getNotifiedStage()).isEqualTo(NotificationStage.NONE);

    assertThat(notifier.notifyAllDue()).isEqualTo(new RunSummary(1, 1, 0));
    assertThat(reminder.getNotifiedStage()).isEqualTo(NotificationStage.DUE);
  }

  @Test
  void aUserWithoutDevicesIsSettledSoTheStageIsNotRetriedForever() {
    Reminder reminder = Reminder.manual(null, VEHICLE, "Emission test", TODAY, null);
    pending(reminder);
    when(push.notifyUser(eq(USER), any())).thenReturn(Outcome.NO_DEVICES);

    assertThat(notifier.notifyAllDue()).isEqualTo(new RunSummary(1, 0, 0));
    assertThat(reminder.getNotifiedStage()).isEqualTo(NotificationStage.DUE);
  }

  @Test
  void withoutPushConfiguredNothingIsMarkedAsSent() {
    Reminder reminder = Reminder.manual(null, VEHICLE, "Emission test", TODAY, null);
    pending(reminder);
    when(push.notifyUser(eq(USER), any())).thenReturn(Outcome.NOT_CONFIGURED);

    assertThat(notifier.notifyAllDue()).isEqualTo(new RunSummary(1, 0, 0));
    assertThat(reminder.getNotifiedStage()).isEqualTo(NotificationStage.NONE);
  }

  @Test
  void aReminderStillAheadIsLeftAlone() {
    // Matched by the coarse query (within 30 days) but a service is only due soon a week ahead.
    Reminder reminder = Reminder.manual(null, VEHICLE, "Emission test", TODAY.plusDays(20), null);
    pending(reminder);

    assertThat(notifier.notifyAllDue()).isEqualTo(new RunSummary(1, 0, 0));
    verify(push, never()).notifyUser(any(), any());
  }

  @Test
  void oneBrokenReminderDoesNotStopTheRun() {
    Reminder broken = Reminder.manual(null, VEHICLE, "Broken", TODAY, null);
    Reminder fine = Reminder.manual(null, VEHICLE, "Fine", TODAY, null);
    pending(broken, fine);
    when(reminders.findByIdForUpdate(broken.getId())).thenThrow(new IllegalStateException("db"));
    when(push.notifyUser(eq(USER), any())).thenReturn(Outcome.DELIVERED);

    assertThat(notifier.notifyAllDue()).isEqualTo(new RunSummary(2, 1, 1));
    assertThat(fine.getNotifiedStage()).isEqualTo(NotificationStage.DUE);
  }

  @Test
  void anOdometerChangeChecksThatVehicleAndNeverThrows() {
    Reminder reminder = Reminder.manual(null, VEHICLE, "Tyres", null, ODOMETER + 200);
    when(reminders.findPendingIdsForVehicle(VEHICLE, TODAY.plusDays(30), ReminderRules.KM_LEAD))
        .thenReturn(List.of(reminder.getId()));
    when(reminders.findByIdForUpdate(reminder.getId())).thenReturn(Optional.of(reminder));
    when(push.notifyUser(eq(USER), any())).thenReturn(Outcome.DELIVERED);

    notifier.onOdometerChanged(new OdometerChangedEvent(VEHICLE));
    assertThat(reminder.getNotifiedStage()).isEqualTo(NotificationStage.DUE_SOON);

    when(reminders.findPendingIdsForVehicle(any(), any(), anyInt()))
        .thenThrow(new IllegalStateException("db down"));
    notifier.onOdometerChanged(new OdometerChangedEvent(VEHICLE));
  }
}
