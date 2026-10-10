package com.drivon.api.reminder;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.drivon.api.document.DocumentType;
import com.drivon.api.maintenance.ServiceType;
import com.drivon.api.notification.PushMessage;
import com.drivon.api.vehicle.Vehicle;
import java.time.LocalDate;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class ReminderMessagesTest {

  private static final UUID VEHICLE = UUID.randomUUID();
  private static final LocalDate TODAY = LocalDate.of(2026, 10, 10);
  private static final int ODOMETER = 48_000;

  private final Vehicle vehicle = mock(Vehicle.class);

  @BeforeEach
  void setUp() {
    when(vehicle.getMake()).thenReturn("Toyota");
    when(vehicle.getModel()).thenReturn("Aqua");
    when(vehicle.getRegistrationNumber()).thenReturn("CAB-1234");
  }

  private static PushMessage compose(Reminder reminder, Vehicle vehicle) {
    ReminderTiming timing =
        ReminderRules.timing(
            reminder.getSource(), reminder.getDueDate(), reminder.getDueKm(), TODAY, ODOMETER);
    return ReminderMessages.compose(reminder, vehicle, timing);
  }

  @Test
  void aServiceDueSoonNamesTheDateAndTheKilometresLeft() {
    Reminder reminder =
        Reminder.forService(
            VEHICLE, ServiceType.OIL_CHANGE, UUID.randomUUID(), LocalDate.of(2026, 11, 12), 48_420);

    PushMessage message = compose(reminder, vehicle);

    assertThat(message.title()).isEqualTo("Oil change is due soon");
    assertThat(message.body())
        .isEqualTo("Toyota Aqua CAB-1234: Due on 12 Nov 2026 or at 48,420 km (420 km to go).");
    assertThat(message.data())
        .containsEntry("type", "reminder")
        .containsEntry("vehicleId", VEHICLE.toString())
        .containsEntry("reminderId", reminder.getId().toString());
    assertThat(message.tag()).isEqualTo(reminder.getId().toString());
  }

  @Test
  void anOverdueMileageSaysHowFarPastItIs() {
    Reminder reminder =
        Reminder.forService(VEHICLE, ServiceType.TYRE_ROTATION, UUID.randomUUID(), null, 47_000);

    PushMessage message = compose(reminder, vehicle);

    assertThat(message.title()).isEqualTo("Tyre rotation is overdue");
    assertThat(message.body()).endsWith("Due at 47,000 km (1,000 km past it).");
  }

  @Test
  void aReminderDueTodayIsDueNotOverdue() {
    PushMessage message =
        compose(Reminder.manual(null, VEHICLE, "Emission test", TODAY, null), vehicle);

    assertThat(message.title()).isEqualTo("Emission test is due");
    assertThat(message.body()).endsWith("Due on 10 Oct 2026.");
  }

  @Test
  void documentsTalkAboutExpiry() {
    assertThat(
            compose(
                    Reminder.forDocument(
                        VEHICLE, DocumentType.INSURANCE, UUID.randomUUID(), TODAY.plusDays(20)),
                    vehicle)
                .title())
        .isEqualTo("Insurance expires soon");
    assertThat(
            compose(
                    Reminder.forDocument(
                        VEHICLE, DocumentType.REVENUE_LICENCE, UUID.randomUUID(), TODAY),
                    vehicle)
                .title())
        .isEqualTo("Revenue licence expires today");
    PushMessage expired =
        compose(
            Reminder.forDocument(
                VEHICLE, DocumentType.INSURANCE, UUID.randomUUID(), TODAY.minusDays(2)),
            vehicle);
    assertThat(expired.title()).isEqualTo("Insurance has expired");
    assertThat(expired.body()).isEqualTo("Toyota Aqua CAB-1234: Expired on 8 Oct 2026.");
  }

  @Test
  void everyTypeHasAReadableName() {
    for (ServiceType type : ServiceType.values()) {
      assertThat(ReminderMessages.serviceLabel(type)).isNotBlank().doesNotContain("_");
    }
    for (DocumentType type : DocumentType.values()) {
      assertThat(ReminderMessages.documentLabel(type)).isNotBlank().doesNotContain("_");
    }
  }
}
