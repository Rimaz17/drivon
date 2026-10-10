package com.drivon.api.reminder;

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
import com.drivon.api.vehicle.Vehicle;
import com.drivon.api.vehicle.VehicleResponse;
import com.drivon.api.vehicle.VehicleService;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.UUID;
import java.util.stream.Collectors;
import org.jspecify.annotations.Nullable;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Reminders of the signed-in user's vehicles. Service and document reminders are kept in step with
 * their records through {@link ServiceScheduleChangedEvent} and {@link DocumentsChangedEvent}; the
 * user adds, edits and deletes only their own ({@code MANUAL}) reminders. Every request method
 * checks that the vehicle belongs to the user. See docs/adr/0013-reminders-and-notifications.md.
 */
@Service
public class ReminderService {

  /** Keeps one vehicle's list short enough to show and notify about without paging. */
  static final int MAX_MANUAL_PER_VEHICLE = 50;

  /** Overdue first, then due soon, then upcoming; within each, the soonest date, then mileage. */
  static final Comparator<ReminderResponse> MOST_URGENT_FIRST =
      Comparator.comparing(ReminderResponse::status)
          .thenComparing(ReminderResponse::dueDate, Comparator.nullsLast(Comparator.naturalOrder()))
          .thenComparing(
              ReminderResponse::kmRemaining, Comparator.nullsLast(Comparator.naturalOrder()))
          .thenComparing(ReminderResponse::id);

  private final ReminderRepository reminders;
  private final VehicleService vehicles;
  private final MaintenanceService maintenance;
  private final DocumentService documents;
  private final BusinessCalendar calendar;

  ReminderService(
      ReminderRepository reminders,
      VehicleService vehicles,
      MaintenanceService maintenance,
      DocumentService documents,
      BusinessCalendar calendar) {
    this.reminders = reminders;
    this.vehicles = vehicles;
    this.maintenance = maintenance;
    this.documents = documents;
    this.calendar = calendar;
  }

  /**
   * The user's reminders, most urgent first: for one vehicle when {@code vehicleId} is given, else
   * across all of them, optionally only those with {@code status}.
   */
  @Transactional(readOnly = true)
  public List<ReminderResponse> list(
      UUID userId, @Nullable UUID vehicleId, @Nullable ReminderStatus status) {
    Map<UUID, Integer> odometers;
    if (vehicleId != null) {
      Vehicle vehicle = vehicles.requireOwned(userId, vehicleId);
      odometers = Map.of(vehicle.getId(), vehicle.getCurrentOdometerKm());
    } else {
      odometers =
          vehicles.list(userId).stream()
              .collect(Collectors.toMap(VehicleResponse::id, VehicleResponse::currentOdometerKm));
    }
    if (odometers.isEmpty()) {
      return List.of();
    }
    LocalDate today = calendar.today();
    return reminders.findByVehicleIdIn(odometers.keySet()).stream()
        .map(reminder -> respond(reminder, today, odometers.get(reminder.getVehicleId())))
        .filter(reminder -> status == null || reminder.status() == status)
        .sorted(MOST_URGENT_FIRST)
        .toList();
  }

  @Transactional(readOnly = true)
  public ReminderResponse get(UUID userId, UUID vehicleId, UUID reminderId) {
    Vehicle vehicle = vehicles.requireOwned(userId, vehicleId);
    return respond(find(vehicleId, reminderId), calendar.today(), vehicle.getCurrentOdometerKm());
  }

  /** Adds one of the user's own reminders. Resending an ID already saved returns that reminder. */
  @Transactional
  public CreateResult<ReminderResponse> create(
      UUID userId, UUID vehicleId, ReminderRequest request) {
    Vehicle vehicle = vehicles.requireOwned(userId, vehicleId);
    LocalDate today = calendar.today();
    Optional<Reminder> earlier =
        request.id() == null ? Optional.empty() : reminders.findById(request.id());
    if (earlier.isPresent()) {
      Reminder reminder = earlier.get();
      if (!reminder.getVehicleId().equals(vehicleId) || !reminder.isManual()) {
        throw new DrivonException(
            ErrorCode.RECORD_ID_CONFLICT, "This ID is already used by another record.");
      }
      return new CreateResult<>(respond(reminder, today, vehicle.getCurrentOdometerKm()), false);
    }
    checkDue(request, vehicle, today, null);
    if (reminders.countByVehicleIdAndSource(vehicleId, ReminderSource.MANUAL)
        >= MAX_MANUAL_PER_VEHICLE) {
      throw new DrivonException(
              ErrorCode.REMINDER_LIMIT_REACHED,
              "A vehicle can have up to " + MAX_MANUAL_PER_VEHICLE + " of your own reminders.")
          .with("maxReminders", MAX_MANUAL_PER_VEHICLE);
    }
    Reminder reminder =
        Reminder.manual(
            request.id(), vehicleId, request.title().strip(), request.dueDate(), request.dueKm());
    reminders.saveAndFlush(reminder);
    return new CreateResult<>(respond(reminder, today, vehicle.getCurrentOdometerKm()), true);
  }

  /** Replaces one of the user's own reminders. A new due date or mileage notifies again. */
  @Transactional
  public ReminderResponse update(
      UUID userId, UUID vehicleId, UUID reminderId, ReminderRequest request) {
    Vehicle vehicle = vehicles.requireOwned(userId, vehicleId);
    Reminder reminder = findManual(vehicleId, reminderId);
    LocalDate today = calendar.today();
    checkDue(request, vehicle, today, reminder);
    reminder.rename(request.title().strip());
    reminder.reschedule(request.dueDate(), request.dueKm());
    return respond(reminders.saveAndFlush(reminder), today, vehicle.getCurrentOdometerKm());
  }

  /** Deletes one of the user's own reminders, for example once it's done. */
  @Transactional
  public void delete(UUID userId, UUID vehicleId, UUID reminderId) {
    vehicles.requireOwned(userId, vehicleId);
    reminders.delete(findManual(vehicleId, reminderId));
  }

  /** Keeps one reminder per service type in step with when that service is next due. */
  @EventListener
  void onServiceScheduleChanged(ServiceScheduleChangedEvent event) {
    UUID vehicleId = event.vehicleId();
    Map<ServiceType, ServiceDue> wanted = new EnumMap<>(ServiceType.class);
    maintenance.nextServices(vehicleId).forEach(due -> wanted.put(due.serviceType(), due));
    List<Reminder> keep = new ArrayList<>();
    for (Reminder reminder :
        reminders.findByVehicleIdAndSource(vehicleId, ReminderSource.SERVICE)) {
      ServiceDue due = wanted.remove(reminder.getServiceType());
      if (due == null) {
        reminders.delete(reminder);
      } else {
        reminder.follow(due.recordId(), due.dueDate(), due.dueKm());
        keep.add(reminder);
      }
    }
    for (ServiceDue due : wanted.values()) {
      keep.add(
          Reminder.forService(
              vehicleId, due.serviceType(), due.recordId(), due.dueDate(), due.dueKm()));
    }
    reminders.saveAllAndFlush(keep);
  }

  /** Keeps one reminder per document type in step with the latest expiry date of that type. */
  @EventListener
  void onDocumentsChanged(DocumentsChangedEvent event) {
    UUID vehicleId = event.vehicleId();
    Map<DocumentType, DocumentExpiry> wanted = new EnumMap<>(DocumentType.class);
    documents.latestExpiries(vehicleId).forEach(expiry -> wanted.put(expiry.type(), expiry));
    List<Reminder> keep = new ArrayList<>();
    for (Reminder reminder :
        reminders.findByVehicleIdAndSource(vehicleId, ReminderSource.DOCUMENT)) {
      DocumentExpiry expiry = wanted.remove(reminder.getDocumentType());
      if (expiry == null) {
        reminders.delete(reminder);
      } else {
        reminder.follow(expiry.documentId(), expiry.expiryDate(), null);
        keep.add(reminder);
      }
    }
    for (DocumentExpiry expiry : wanted.values()) {
      keep.add(
          Reminder.forDocument(vehicleId, expiry.type(), expiry.documentId(), expiry.expiryDate()));
    }
    reminders.saveAllAndFlush(keep);
  }

  static ReminderResponse respond(Reminder reminder, LocalDate today, int odometerKm) {
    ReminderTiming timing =
        ReminderRules.timing(
            reminder.getSource(), reminder.getDueDate(), reminder.getDueKm(), today, odometerKm);
    return ReminderResponse.from(reminder, timing);
  }

  /**
   * A due date or mileage must be set and still ahead. When editing, an unchanged value may already
   * be past (the reminder is overdue and only its title changes).
   */
  private static void checkDue(
      ReminderRequest request, Vehicle vehicle, LocalDate today, @Nullable Reminder existing) {
    LocalDate dueDate = request.dueDate();
    Integer dueKm = request.dueKm();
    if (dueDate == null && dueKm == null) {
      throw new DrivonException(
          ErrorCode.REMINDER_DUE_MISSING, "Set a due date, a mileage or both.");
    }
    boolean dateChanged = existing == null || !Objects.equals(existing.getDueDate(), dueDate);
    if (dueDate != null && dateChanged && dueDate.isBefore(today)) {
      throw new DrivonException(ErrorCode.REMINDER_DATE_PAST, "The due date can't be in the past.");
    }
    boolean kmChanged = existing == null || !Objects.equals(existing.getDueKm(), dueKm);
    int odometerKm = vehicle.getCurrentOdometerKm();
    if (dueKm != null && kmChanged && dueKm <= odometerKm) {
      throw new DrivonException(
              ErrorCode.REMINDER_KM_PAST,
              "The due mileage must be higher than the current odometer.")
          .with("minKm", odometerKm + 1);
    }
  }

  private Reminder find(UUID vehicleId, UUID reminderId) {
    return reminders
        .findByIdAndVehicleId(reminderId, vehicleId)
        .orElseThrow(() -> new DrivonException(ErrorCode.REMINDER_NOT_FOUND));
  }

  private Reminder findManual(UUID vehicleId, UUID reminderId) {
    Reminder reminder = find(vehicleId, reminderId);
    if (!reminder.isManual()) {
      String record =
          reminder.getSource() == ReminderSource.SERVICE ? "service record" : "document";
      throw new DrivonException(
          ErrorCode.REMINDER_READ_ONLY,
          "This reminder follows a " + record + ". Change the " + record + " instead.");
    }
    return reminder;
  }
}
