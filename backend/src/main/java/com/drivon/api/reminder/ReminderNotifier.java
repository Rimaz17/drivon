package com.drivon.api.reminder;

import com.drivon.api.common.time.BusinessCalendar;
import com.drivon.api.notification.PushNotifier;
import com.drivon.api.notification.PushNotifier.Outcome;
import com.drivon.api.vehicle.OdometerChangedEvent;
import com.drivon.api.vehicle.Vehicle;
import com.drivon.api.vehicle.VehicleService;
import java.time.Clock;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * Pushes a notification when a reminder becomes due soon and again when it's due. Safe to run any
 * number of times, and catch-up safe: each run handles everything that reached a new stage since
 * the last one, however long ago, and a stage is pushed at most once ({@code notifiedStage}). A
 * reminder that jumped straight to due gets only the due notification.
 *
 * <p>Runs daily through {@link ReminderJobController} and right after an odometer change, so
 * mileage reminders don't wait for the next day.
 */
@Component
public class ReminderNotifier {

  /** How a run went; returned by the job endpoint for the workflow log. */
  public record RunSummary(int checked, int notified, int failed) {}

  private enum Result {
    NOTIFIED,
    UNCHANGED,
    FAILED
  }

  private static final Logger log = LoggerFactory.getLogger(ReminderNotifier.class);

  private final ReminderRepository reminders;
  private final VehicleService vehicles;
  private final PushNotifier push;
  private final BusinessCalendar calendar;
  private final Clock clock;
  private final TransactionTemplate perReminder;

  ReminderNotifier(
      ReminderRepository reminders,
      VehicleService vehicles,
      PushNotifier push,
      BusinessCalendar calendar,
      Clock clock,
      PlatformTransactionManager transactions) {
    this.reminders = reminders;
    this.vehicles = vehicles;
    this.push = push;
    this.calendar = calendar;
    this.clock = clock;
    // A new transaction per reminder: one failure doesn't undo the others, and it also works after
    // the commit of the request that changed an odometer.
    this.perReminder = new TransactionTemplate(transactions);
    this.perReminder.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);
  }

  /** Notifies about every reminder of every user that reached a stage not pushed yet. */
  public RunSummary notifyAllDue() {
    return run(reminders.findPendingIds(dateHorizon(), ReminderRules.KM_LEAD));
  }

  /** {@link #notifyAllDue} for one vehicle. */
  public RunSummary notifyDue(UUID vehicleId) {
    return run(reminders.findPendingIdsForVehicle(vehicleId, dateHorizon(), ReminderRules.KM_LEAD));
  }

  /**
   * A new odometer reading can bring mileage reminders due. Runs after the change commits and never
   * fails the request that made it; the daily run catches anything missed here.
   */
  @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
  void onOdometerChanged(OdometerChangedEvent event) {
    try {
      notifyDue(event.vehicleId());
    } catch (RuntimeException e) {
      log.warn("Checking reminders after an odometer change failed", e);
    }
  }

  private LocalDate dateHorizon() {
    return calendar.today().plusDays(ReminderRules.maxDateLeadDays());
  }

  private RunSummary run(List<UUID> candidates) {
    int notified = 0;
    int failed = 0;
    for (UUID id : candidates) {
      Result result;
      try {
        result = perReminder.execute(status -> process(id));
      } catch (RuntimeException e) {
        log.warn("Notifying about reminder {} failed", id, e);
        result = Result.FAILED;
      }
      if (result == Result.NOTIFIED) {
        notified++;
      } else if (result == Result.FAILED) {
        failed++;
      }
    }
    return new RunSummary(candidates.size(), notified, failed);
  }

  /** Locks the reminder, so a concurrent run can't push the same stage twice. */
  private Result process(UUID reminderId) {
    Reminder reminder = reminders.findByIdForUpdate(reminderId).orElse(null);
    if (reminder == null) {
      return Result.UNCHANGED;
    }
    Vehicle vehicle = vehicles.findForBackgroundJob(reminder.getVehicleId()).orElse(null);
    if (vehicle == null) {
      return Result.UNCHANGED;
    }
    ReminderTiming timing =
        ReminderRules.timing(
            reminder.getSource(),
            reminder.getDueDate(),
            reminder.getDueKm(),
            calendar.today(),
            vehicle.getCurrentOdometerKm());
    if (!timing.stage().isAfter(reminder.getNotifiedStage())) {
      return Result.UNCHANGED;
    }
    Outcome outcome =
        push.notifyUser(vehicle.getUserId(), ReminderMessages.compose(reminder, vehicle, timing));
    if (!outcome.settled()) {
      // Not configured or temporarily unreachable: leave the stage open for the next run.
      return outcome == Outcome.FAILED ? Result.FAILED : Result.UNCHANGED;
    }
    reminder.markNotified(timing.stage(), clock.instant());
    return outcome == Outcome.DELIVERED ? Result.NOTIFIED : Result.UNCHANGED;
  }
}
