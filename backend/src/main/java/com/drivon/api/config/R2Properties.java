package com.drivon.api.config;

import jakarta.validation.constraints.NotNull;
import java.net.URI;
import java.time.Duration;
import org.jspecify.annotations.Nullable;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

/**
 * Cloudflare R2 settings ({@code drivon.storage.r2.*}). Documents are stored only when the account,
 * keys and bucket are all set; otherwise document endpoints answer {@code STORAGE_UNAVAILABLE} and
 * the rest of the API keeps working. Production sets every value (see application-prod.yml).
 *
 * @param endpoint overrides the R2 endpoint derived from the account ID; tests point it at a local
 *     S3 stand-in
 * @param uploadUrlTtl how long a presigned upload URL stays valid
 * @param downloadUrlTtl how long a presigned download URL stays valid
 */
@Validated
@ConfigurationProperties("drivon.storage.r2")
public record R2Properties(
    @Nullable String accountId,
    @Nullable String accessKeyId,
    @Nullable String secretAccessKey,
    @Nullable String bucket,
    @Nullable URI endpoint,
    @NotNull Duration uploadUrlTtl,
    @NotNull Duration downloadUrlTtl) {

  /** True when objects can be stored: keys, a bucket and somewhere to send requests. */
  public boolean configured() {
    return present(accessKeyId)
        && present(secretAccessKey)
        && present(bucket)
        && (endpoint != null || present(accountId));
  }

  /** The S3 API endpoint of the account, unless overridden. */
  public URI resolvedEndpoint() {
    if (endpoint != null) {
      return endpoint;
    }
    return URI.create("https://" + accountId.strip() + ".r2.cloudflarestorage.com");
  }

  private static boolean present(@Nullable String value) {
    return value != null && !value.isBlank();
  }
}
