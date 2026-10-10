package com.drivon.api.config;

import java.util.Base64;
import org.jspecify.annotations.Nullable;
import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * Firebase settings ({@code drivon.notifications.firebase.*}). Push notifications are sent only
 * when a service account is set; otherwise reminders are shown in the app only. Production sets it
 * (see application-prod.yml).
 *
 * @param serviceAccountBase64 the service account JSON file from the Firebase console, Base64
 *     encoded so it fits in one environment variable
 */
@ConfigurationProperties("drivon.notifications.firebase")
public record FirebaseProperties(@Nullable String serviceAccountBase64) {

  public boolean configured() {
    return serviceAccountBase64 != null && !serviceAccountBase64.isBlank();
  }

  /** The service account JSON. Fails with a clear message if the value isn't valid Base64. */
  public byte[] serviceAccountJson() {
    try {
      // The MIME decoder tolerates the line breaks some tools add to long Base64 output.
      return Base64.getMimeDecoder().decode(serviceAccountBase64.strip());
    } catch (IllegalArgumentException e) {
      throw new IllegalStateException(
          "FIREBASE_SERVICE_ACCOUNT_BASE64 is not valid Base64; encode the service account JSON"
              + " file again",
          e);
    }
  }
}
