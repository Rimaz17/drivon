package com.drivon.api.config;

import java.nio.charset.StandardCharsets;
import org.jspecify.annotations.Nullable;
import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * The shared secret the scheduled reminders workflow sends ({@code drivon.reminders.*}). Without
 * one, the job endpoint is switched off. Production requires it (see application-prod.yml).
 */
@ConfigurationProperties("drivon.reminders")
public record ReminderJobProperties(@Nullable String jobSecret) {

  /** Short secrets could be guessed; generate one with {@code openssl rand -base64 32}. */
  public static final int MIN_SECRET_LENGTH = 32;

  public ReminderJobProperties {
    if (jobSecret != null && jobSecret.isBlank()) {
      jobSecret = null;
    }
    if (jobSecret != null && jobSecret.strip().length() < MIN_SECRET_LENGTH) {
      throw new IllegalStateException(
          "REMINDERS_JOB_SECRET must be at least " + MIN_SECRET_LENGTH + " characters long");
    }
  }

  public boolean enabled() {
    return jobSecret != null;
  }

  public byte[] secretBytes() {
    return jobSecret == null ? new byte[0] : jobSecret.strip().getBytes(StandardCharsets.UTF_8);
  }
}
