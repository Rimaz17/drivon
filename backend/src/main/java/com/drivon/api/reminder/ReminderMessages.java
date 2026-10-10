package com.drivon.api.reminder;

import com.drivon.api.document.DocumentType;
import com.drivon.api.maintenance.ServiceType;
import com.drivon.api.notification.PushMessage;
import com.drivon.api.vehicle.Vehicle;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;

/**
 * The text of reminder notifications. The app is English-only, so the server writes the text; the
 * data fields let the app open the vehicle's reminders when the notification is tapped.
 */
final class ReminderMessages {

  static final String TYPE_KEY = "type";
  static final String TYPE_REMINDER = "reminder";
  static final String VEHICLE_KEY = "vehicleId";
  static final String REMINDER_KEY = "reminderId";

  private static final DateTimeFormatter DATE =
      DateTimeFormatter.ofPattern("d MMM yyyy", Locale.ENGLISH);

  private ReminderMessages() {}

  static PushMessage compose(Reminder reminder, Vehicle vehicle, ReminderTiming timing) {
    String label = label(reminder);
    boolean document = reminder.getSource() == ReminderSource.DOCUMENT;
    String title;
    if (timing.stage() == NotificationStage.DUE) {
      boolean overdue = timing.status() == ReminderStatus.OVERDUE;
      if (document) {
        title = label + (overdue ? " has expired" : " expires today");
      } else {
        title = label + (overdue ? " is overdue" : " is due");
      }
    } else {
      title = label + (document ? " expires soon" : " is due soon");
    }
    String vehicleName =
        vehicle.getMake() + " " + vehicle.getModel() + " " + vehicle.getRegistrationNumber();
    String body = vehicleName + ": " + detail(reminder, timing, document);
    return new PushMessage(
        title,
        body,
        Map.of(
            TYPE_KEY, TYPE_REMINDER,
            VEHICLE_KEY, reminder.getVehicleId().toString(),
            REMINDER_KEY, reminder.getId().toString()),
        reminder.getId().toString());
  }

  /** What is due, in words: the service or document type, or the user's own title. */
  static String label(Reminder reminder) {
    return switch (reminder.getSource()) {
      case MANUAL -> Objects.requireNonNull(reminder.getTitle());
      case SERVICE -> serviceLabel(Objects.requireNonNull(reminder.getServiceType()));
      case DOCUMENT -> documentLabel(Objects.requireNonNull(reminder.getDocumentType()));
    };
  }

  private static String detail(Reminder reminder, ReminderTiming timing, boolean document) {
    LocalDate dueDate = reminder.getDueDate();
    if (document) {
      String verb = timing.status() == ReminderStatus.OVERDUE ? "Expired on " : "Expires on ";
      return verb + DATE.format(Objects.requireNonNull(dueDate)) + ".";
    }
    List<String> parts = new ArrayList<>();
    if (dueDate != null) {
      parts.add("on " + DATE.format(dueDate));
    }
    Integer dueKm = reminder.getDueKm();
    Integer kmRemaining = timing.kmRemaining();
    if (dueKm != null && kmRemaining != null) {
      String distance =
          kmRemaining >= 0 ? km(kmRemaining) + " to go" : km(-kmRemaining) + " past it";
      parts.add("at " + km(dueKm) + " (" + distance + ")");
    }
    return "Due " + String.join(" or ", parts) + ".";
  }

  private static String km(int value) {
    return String.format(Locale.ENGLISH, "%,d km", value);
  }

  static String serviceLabel(ServiceType type) {
    return switch (type) {
      case OIL_CHANGE -> "Oil change";
      case GENERAL_SERVICE -> "General service";
      case TYRE_ROTATION -> "Tyre rotation";
      case TYRE_REPLACEMENT -> "Tyre replacement";
      case BRAKE_SERVICE -> "Brake service";
      case BATTERY_REPLACEMENT -> "Battery replacement";
      case WHEEL_ALIGNMENT -> "Wheel alignment";
      case AIR_CONDITIONING -> "Air conditioning service";
      case OTHER -> "Service";
    };
  }

  static String documentLabel(DocumentType type) {
    return switch (type) {
      case INSURANCE -> "Insurance";
      case REVENUE_LICENCE -> "Revenue licence";
      case REGISTRATION -> "Registration";
      case INVOICE -> "Invoice";
      case RECEIPT -> "Receipt";
      case OTHER -> "Document";
    };
  }
}
