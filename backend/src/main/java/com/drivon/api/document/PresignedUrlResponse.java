package com.drivon.api.document;

import com.drivon.api.common.storage.PresignedRequest;
import java.net.URI;
import java.time.Instant;
import java.util.Map;

/**
 * A request for the app to send straight to file storage, not to this API (and without the
 * Authorization header).
 *
 * @param method {@code PUT} to upload, {@code GET} to download
 * @param headers must be sent exactly as given; they are part of the signature
 * @param expiresAt the URL stops working after this instant; ask for a new one
 */
public record PresignedUrlResponse(
    URI url, String method, Map<String, String> headers, Instant expiresAt) {

  static PresignedUrlResponse from(PresignedRequest request) {
    return new PresignedUrlResponse(
        request.url(), request.method(), request.headers(), request.expiresAt());
  }
}
