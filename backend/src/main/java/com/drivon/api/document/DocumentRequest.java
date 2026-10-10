package com.drivon.api.document;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;
import org.jspecify.annotations.Nullable;

/** Body for replacing a document's details. The file itself can't be changed. */
public record DocumentRequest(
    @NotNull DocumentType type,
    @Nullable LocalDate issueDate,
    @Nullable LocalDate expiryDate,
    @Size(max = 500) @Nullable String notes) {}
