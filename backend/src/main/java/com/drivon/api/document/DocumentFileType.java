package com.drivon.api.document;

import java.util.Arrays;
import java.util.Locale;
import java.util.Optional;
import org.jspecify.annotations.Nullable;

/**
 * File formats a document may be stored as. The app compresses photos to JPEG before uploading; PNG
 * covers screenshots and PDF covers e-documents such as insurance certificates.
 */
public enum DocumentFileType {
  JPEG("image/jpeg", "jpg"),
  PNG("image/png", "png"),
  PDF("application/pdf", "pdf");

  /** Largest file accepted, from the product overview's free-tier plan. */
  public static final long MAX_BYTES = 5L * 1024 * 1024;

  private final String contentType;
  private final String extension;

  DocumentFileType(String contentType, String extension) {
    this.contentType = contentType;
    this.extension = extension;
  }

  public String contentType() {
    return contentType;
  }

  public String extension() {
    return extension;
  }

  /** The type for a MIME type such as {@code image/jpeg; charset=binary}, ignoring parameters. */
  public static Optional<DocumentFileType> fromContentType(@Nullable String value) {
    if (value == null) {
      return Optional.empty();
    }
    String mime = value.split(";", 2)[0].strip().toLowerCase(Locale.ROOT);
    return Arrays.stream(values()).filter(type -> type.contentType.equals(mime)).findFirst();
  }
}
