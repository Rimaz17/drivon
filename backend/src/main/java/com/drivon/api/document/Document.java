package com.drivon.api.document;

import com.drivon.api.common.persistence.AssignedIdEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Table;
import java.time.LocalDate;
import java.util.UUID;
import org.jspecify.annotations.Nullable;

/**
 * A vehicle document and the R2 object that holds its file. The file never changes after upload;
 * only the details (type, dates, notes) can be edited. Rules are enforced by {@link
 * DocumentService}.
 */
@Entity
@Table(name = "documents")
public class Document extends AssignedIdEntity {

  @Column(name = "vehicle_id", nullable = false, updatable = false)
  private UUID vehicleId;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false, length = 20)
  private DocumentType type;

  @Column(name = "issued_on")
  private @Nullable LocalDate issueDate;

  @Column(name = "expires_on")
  private @Nullable LocalDate expiryDate;

  @Column(length = 500)
  private @Nullable String notes;

  @Column(name = "file_key", nullable = false, updatable = false, length = 255)
  private String fileKey;

  @Column(name = "content_type", nullable = false, updatable = false, length = 50)
  private String contentType;

  @Column(name = "size_bytes", nullable = false, updatable = false)
  private int sizeBytes;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false, length = 10)
  private DocumentStatus status;

  protected Document() {}

  Document(UUID id, UUID vehicleId, DocumentDetails details, StoredFile file) {
    super(id);
    this.vehicleId = vehicleId;
    this.fileKey = file.key();
    this.contentType = file.type().contentType();
    this.sizeBytes = file.sizeBytes();
    this.status = DocumentStatus.PENDING;
    update(details);
  }

  void update(DocumentDetails details) {
    this.type = details.type();
    this.issueDate = details.issueDate();
    this.expiryDate = details.expiryDate();
    this.notes = details.notes();
  }

  /** Marks the uploaded file as checked, making the document visible. */
  void activate() {
    this.status = DocumentStatus.ACTIVE;
  }

  boolean isActive() {
    return status == DocumentStatus.ACTIVE;
  }

  public UUID getVehicleId() {
    return vehicleId;
  }

  public DocumentType getType() {
    return type;
  }

  public @Nullable LocalDate getIssueDate() {
    return issueDate;
  }

  public @Nullable LocalDate getExpiryDate() {
    return expiryDate;
  }

  public @Nullable String getNotes() {
    return notes;
  }

  public String getFileKey() {
    return fileKey;
  }

  public String getContentType() {
    return contentType;
  }

  public int getSizeBytes() {
    return sizeBytes;
  }

  public DocumentStatus getStatus() {
    return status;
  }

  /** Normalized details of a document, after validation. */
  record DocumentDetails(
      DocumentType type,
      @Nullable LocalDate issueDate,
      @Nullable LocalDate expiryDate,
      @Nullable String notes) {}

  /** The object a document's file is uploaded to. */
  record StoredFile(String key, DocumentFileType type, int sizeBytes) {}
}
