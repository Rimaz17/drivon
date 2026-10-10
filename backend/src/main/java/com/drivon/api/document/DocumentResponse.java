package com.drivon.api.document;

import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;
import org.jspecify.annotations.Nullable;

/**
 * A document's details and file metadata. The file is fetched separately through a short-lived
 * download URL.
 */
public record DocumentResponse(
    UUID id,
    UUID vehicleId,
    DocumentType type,
    @Nullable LocalDate issueDate,
    @Nullable LocalDate expiryDate,
    @Nullable String notes,
    String contentType,
    int sizeBytes,
    DocumentStatus status,
    Instant createdAt,
    Instant updatedAt) {

  static DocumentResponse from(Document document) {
    return new DocumentResponse(
        document.getId(),
        document.getVehicleId(),
        document.getType(),
        document.getIssueDate(),
        document.getExpiryDate(),
        document.getNotes(),
        document.getContentType(),
        document.getSizeBytes(),
        document.getStatus(),
        document.getCreatedAt(),
        document.getUpdatedAt());
  }
}
