package com.drivon.api.reminder;

import com.drivon.api.common.persistence.AssignedIdEntity;
import com.drivon.api.document.DocumentType;
import com.drivon.api.maintenance.ServiceType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Table;
import java.time.Instant;
import java.time.LocalDate;
import java.util.Objects;
import java.util.UUID;
import org.jspecify.annotations.Nullable;

/**
 * Something due on a vehicle by date, by mileage or by whichever comes first. Automatic reminders
 * follow a service record or document (see {@link ReminderSource}); rules are enforced by {@link
 * ReminderService}.
 */
@Entity
@Table(name = "reminders")
public class Reminder extends AssignedIdEntity {

  @Column(name = "vehicle_id", nullable = false, updatable = false)
  private UUID vehicleId;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false, updatable = false, length = 10)
  private ReminderSource source;

  @Enumerated(EnumType.STRING)
  @Column(name = "service_type", updatable = false, length = 30)
  private @Nullable ServiceType serviceType;

  @Enumerated(EnumType.STRING)
  @Column(name = "document_type", updatable = false, length = 20)
  private @Nullable DocumentType documentType;

  @Column(name = "source_id")
  private @Nullable UUID sourceId;

  @Column(length = 80)
  private @Nullable String title;

  @Column(name = "due_on")
  private @Nullable LocalDate dueDate;

  @Column(name = "due_km")
  private @Nullable Integer dueKm;

  @Enumerated(EnumType.STRING)
  @Column(name = "notified_stage", nullable = false, length = 10)
  private NotificationStage notifiedStage = NotificationStage.NONE;

  @Column(name = "last_notified_at")
  private @Nullable Instant lastNotifiedAt;

  protected Reminder() {}

  private Reminder(
      @Nullable UUID id,
      UUID vehicleId,
      ReminderSource source,
      @Nullable ServiceType serviceType,
      @Nullable DocumentType documentType) {
    super(id);
    this.vehicleId = vehicleId;
    this.source = source;
    this.serviceType = serviceType;
    this.documentType = documentType;
  }

  /** The user's own reminder. */
  static Reminder manual(
      @Nullable UUID id,
      UUID vehicleId,
      String title,
      @Nullable LocalDate dueDate,
      @Nullable Integer dueKm) {
    Reminder reminder = new Reminder(id, vehicleId, ReminderSource.MANUAL, null, null);
    reminder.title = title;
    reminder.reschedule(dueDate, dueKm);
    return reminder;
  }

  /** Follows the latest service record of {@code type} that says when it's next due. */
  static Reminder forService(
      UUID vehicleId,
      ServiceType type,
      UUID recordId,
      @Nullable LocalDate dueDate,
      @Nullable Integer dueKm) {
    Reminder reminder = new Reminder(null, vehicleId, ReminderSource.SERVICE, type, null);
    reminder.follow(recordId, dueDate, dueKm);
    return reminder;
  }

  /** Follows the document of {@code type} that expires last. */
  static Reminder forDocument(
      UUID vehicleId, DocumentType type, UUID documentId, LocalDate expiryDate) {
    Reminder reminder = new Reminder(null, vehicleId, ReminderSource.DOCUMENT, null, type);
    reminder.follow(documentId, expiryDate, null);
    return reminder;
  }

  /** Points an automatic reminder at its current service record or document. */
  void follow(UUID sourceId, @Nullable LocalDate dueDate, @Nullable Integer dueKm) {
    this.sourceId = sourceId;
    reschedule(dueDate, dueKm);
  }

  void rename(String title) {
    this.title = title;
  }

  /**
   * Sets when the reminder is due. A new due date or mileage starts its notifications over, so the
   * user hears about the new deadline; an unchanged one keeps what was already sent.
   */
  void reschedule(@Nullable LocalDate dueDate, @Nullable Integer dueKm) {
    if (Objects.equals(this.dueDate, dueDate) && Objects.equals(this.dueKm, dueKm)) {
      return;
    }
    this.dueDate = dueDate;
    this.dueKm = dueKm;
    this.notifiedStage = NotificationStage.NONE;
    this.lastNotifiedAt = null;
  }

  /** Records that the user was told about {@code stage}. */
  void markNotified(NotificationStage stage, Instant at) {
    this.notifiedStage = stage;
    this.lastNotifiedAt = at;
  }

  boolean isManual() {
    return source == ReminderSource.MANUAL;
  }

  public UUID getVehicleId() {
    return vehicleId;
  }

  public ReminderSource getSource() {
    return source;
  }

  public @Nullable ServiceType getServiceType() {
    return serviceType;
  }

  public @Nullable DocumentType getDocumentType() {
    return documentType;
  }

  public @Nullable UUID getSourceId() {
    return sourceId;
  }

  public @Nullable String getTitle() {
    return title;
  }

  public @Nullable LocalDate getDueDate() {
    return dueDate;
  }

  public @Nullable Integer getDueKm() {
    return dueKm;
  }

  public NotificationStage getNotifiedStage() {
    return notifiedStage;
  }

  public @Nullable Instant getLastNotifiedAt() {
    return lastNotifiedAt;
  }
}
