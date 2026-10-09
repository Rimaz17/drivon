package com.drivon.api.common.storage;

import java.util.Optional;

/**
 * A private bucket of files. The app never streams file contents through the API: clients upload
 * and download directly with short-lived presigned URLs, and the API only signs those URLs, checks
 * what arrived and deletes objects. The bucket is never listed; object keys live in the database.
 *
 * <p>Failures to reach the storage service throw {@link StorageUnavailableException}.
 */
public interface ObjectStorage {

  /**
   * A URL the client can {@code PUT} exactly one file to. The content type and length are part of
   * the signature, so the storage service rejects a different type or size.
   */
  PresignedRequest presignUpload(String key, String contentType, long contentLength);

  /**
   * A URL to {@code GET} the object.
   *
   * @param fileName suggested file name for viewers that save or show it
   */
  PresignedRequest presignDownload(String key, String fileName);

  /** Size and type of a stored object, or empty if nothing was uploaded under the key. */
  Optional<StoredObject> head(String key);

  /** Deletes the object; deleting a missing key is not an error. */
  void delete(String key);
}
