package com.drivon.api.common.storage;

import java.net.URI;
import java.time.Instant;
import java.util.Map;

/**
 * A request the client sends straight to the storage service.
 *
 * @param method {@code PUT} for uploads, {@code GET} for downloads
 * @param headers headers covered by the signature; the client must send them unchanged
 * @param expiresAt after this instant the storage service refuses the URL
 */
public record PresignedRequest(
    URI url, String method, Map<String, String> headers, Instant expiresAt) {}
