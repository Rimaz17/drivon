package com.drivon.api.reminder;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.LocalDate;
import org.junit.jupiter.api.Test;

class ReminderRulesTest {

  private static final LocalDate TODAY = LocalDate.of(2026, 10, 10);
  private static final int ODOMETER = 48_000;

  private static ReminderTiming service(LocalDate dueDate, Integer dueKm) {
    return ReminderRules.timing(ReminderSource.SERVICE, dueDate, dueKm, TODAY, ODOMETER);
  }

  @Test
  void isUpcomingWhileTheDueDateIsMoreThanAWeekAway() {
    ReminderTiming timing = service(TODAY.plusDays(8), null);

    assertThat(timing.status()).isEqualTo(ReminderStatus.UPCOMING);
    assertThat(timing.stage()).isEqualTo(NotificationStage.NONE);
    assertThat(timing.daysRemaining()).isEqualTo(8);
    assertThat(timing.kmRemaining()).isNull();
    assertThat(timing.remindFrom()).isEqualTo(TODAY.plusDays(1));
  }

  @Test
  void isDueSoonFromSevenDaysBeforeTheDueDate() {
    ReminderTiming timing = service(TODAY.plusDays(7), null);

    assertThat(timing.status()).isEqualTo(ReminderStatus.DUE_SOON);
    assertThat(timing.stage()).isEqualTo(NotificationStage.DUE_SOON);
    assertThat(timing.remindFrom()).isEqualTo(TODAY);
  }

  @Test
  void reachesTheDueStageOnTheDueDateButIsOnlyOverdueTheDayAfter() {
    ReminderTiming onTheDay = service(TODAY, null);
    assertThat(onTheDay.status()).isEqualTo(ReminderStatus.DUE_SOON);
    assertThat(onTheDay.stage()).isEqualTo(NotificationStage.DUE);

    ReminderTiming dayAfter = service(TODAY.minusDays(1), null);
    assertThat(dayAfter.status()).isEqualTo(ReminderStatus.OVERDUE);
    assertThat(dayAfter.stage()).isEqualTo(NotificationStage.DUE);
    assertThat(dayAfter.daysRemaining()).isEqualTo(-1);
  }

  @Test
  void isDueSoonWithinFiveHundredKilometres() {
    assertThat(service(null, ODOMETER + 501).status()).isEqualTo(ReminderStatus.UPCOMING);

    ReminderTiming timing = service(null, ODOMETER + 500);
    assertThat(timing.status()).isEqualTo(ReminderStatus.DUE_SOON);
    assertThat(timing.stage()).isEqualTo(NotificationStage.DUE_SOON);
    assertThat(timing.kmRemaining()).isEqualTo(500);
    assertThat(timing.remindFrom()).isNull();
  }

  @Test
  void isDueAtTheMileageAndOverdueBeyondIt() {
    ReminderTiming reached = service(null, ODOMETER);
    assertThat(reached.status()).isEqualTo(ReminderStatus.DUE_SOON);
    assertThat(reached.stage()).isEqualTo(NotificationStage.DUE);

    ReminderTiming passed = service(null, ODOMETER - 1_200);
    assertThat(passed.status()).isEqualTo(ReminderStatus.OVERDUE);
    assertThat(passed.kmRemaining()).isEqualTo(-1_200);
  }

  @Test
  void aDateAndMileageReminderIsDueAtWhicheverComesFirst() {
    // Mileage nearly reached long before the date.
    ReminderTiming byMileage = service(TODAY.plusMonths(5), ODOMETER + 100);
    assertThat(byMileage.status()).isEqualTo(ReminderStatus.DUE_SOON);

    // Date passed while the mileage is far off.
    ReminderTiming byDate = service(TODAY.minusDays(3), ODOMETER + 4_000);
    assertThat(byDate.status()).isEqualTo(ReminderStatus.OVERDUE);
    assertThat(byDate.stage()).isEqualTo(NotificationStage.DUE);
  }

  @Test
  void documentsAreDueSoonAMonthAhead() {
    ReminderTiming timing =
        ReminderRules.timing(ReminderSource.DOCUMENT, TODAY.plusDays(30), null, TODAY, ODOMETER);

    assertThat(timing.status()).isEqualTo(ReminderStatus.DUE_SOON);
    assertThat(timing.remindFrom()).isEqualTo(TODAY);
    assertThat(
            ReminderRules.timing(ReminderSource.DOCUMENT, TODAY.plusDays(31), null, TODAY, 0)
                .status())
        .isEqualTo(ReminderStatus.UPCOMING);
  }

  @Test
  void manualRemindersUseTheServiceLeadTime() {
    assertThat(ReminderRules.dateLeadDays(ReminderSource.MANUAL))
        .isEqualTo(ReminderRules.DATE_LEAD_DAYS);
    assertThat(ReminderRules.maxDateLeadDays()).isEqualTo(ReminderRules.DOCUMENT_LEAD_DAYS);
  }

  @Test
  void needsADateOrMileage() {
    assertThatThrownBy(() -> service(null, null)).isInstanceOf(IllegalArgumentException.class);
  }

  @Test
  void stagesAreOrdered() {
    assertThat(NotificationStage.DUE.isAfter(NotificationStage.DUE_SOON)).isTrue();
    assertThat(NotificationStage.DUE_SOON.isAfter(NotificationStage.NONE)).isTrue();
    assertThat(NotificationStage.DUE_SOON.isAfter(NotificationStage.DUE_SOON)).isFalse();
  }
}
