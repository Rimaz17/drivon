package com.drivon.api.document;

import org.jspecify.annotations.Nullable;

/**
 * A started (or resumed) upload.
 *
 * @param upload where to {@code PUT} the file, then confirm the upload; null when the document
 *     already has its file (a retry after confirming)
 */
public record DocumentUploadResponse(
    DocumentResponse document, @Nullable PresignedUrlResponse upload) {}
