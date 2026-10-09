package com.drivon.api.document;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;
import java.util.UUID;
import org.jspecify.annotations.Nullable;

/**
 * Body for starting a document upload: the document's details plus the file the app is about to
 * send. The type and size are signed into the upload URL.
 *
 * @param id optional app-generated ID; resending it returns the same document (and a fresh upload
 *     URL while the file is still missing)
 * @param contentType {@code image/jpeg}, {@code image/png} or {@code application/pdf}
 * @param sizeBytes exact size of the file, at most 5 MB
 */
public record DocumentUploadRequest(
    @Nullable UUID id,
    @NotNull DocumentType type,
    @Nullable LocalDate issueDate,
    @Nullable LocalDate expiryDate,
    @Size(max = 500) @Nullable String notes,
    @NotBlank @Size(max = 100) String contentType,
    @Positive long sizeBytes) {}
