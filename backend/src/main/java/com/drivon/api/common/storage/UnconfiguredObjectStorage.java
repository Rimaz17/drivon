package com.drivon.api.common.storage;

import java.util.Optional;

/**
 * Stands in when no R2 bucket is configured (e.g. local development without credentials), so the
 * API still starts and only document features report that storage is unavailable.
 */
public final class UnconfiguredObjectStorage implements ObjectStorage {

  private static final String DETAIL = "Document storage isn't set up on this server.";

  @Override
  public PresignedRequest presignUpload(String key, String contentType, long contentLength) {
    throw new StorageUnavailableException(DETAIL);
  }

  @Override
  public PresignedRequest presignDownload(String key, String fileName) {
    throw new StorageUnavailableException(DETAIL);
  }

  @Override
  public Optional<StoredObject> head(String key) {
    throw new StorageUnavailableException(DETAIL);
  }

  @Override
  public void delete(String key) {
    throw new StorageUnavailableException(DETAIL);
  }
}
