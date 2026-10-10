package com.drivon.api.config;

import com.drivon.api.notification.FcmPushSender;
import com.drivon.api.notification.PushSender;
import com.drivon.api.notification.UnconfiguredPushSender;
import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/** Builds the push sender: Firebase Cloud Messaging when a service account is configured. */
@Configuration
public class NotificationConfig {

  private static final Logger log = LoggerFactory.getLogger(NotificationConfig.class);

  /** Firebase calls run inside reminder jobs and requests; don't let a slow network stall them. */
  private static final int TIMEOUT_MILLIS = 10_000;

  @Bean
  PushSender pushSender(FirebaseProperties properties) {
    if (!properties.configured()) {
      log.warn(
          "Firebase is not configured (FIREBASE_SERVICE_ACCOUNT_BASE64); push notifications are"
              + " disabled");
      return new UnconfiguredPushSender();
    }
    GoogleCredentials credentials;
    try {
      credentials =
          GoogleCredentials.fromStream(new ByteArrayInputStream(properties.serviceAccountJson()));
    } catch (IOException | RuntimeException e) {
      throw new IllegalStateException(
          "FIREBASE_SERVICE_ACCOUNT_BASE64 doesn't hold a Firebase service account JSON file", e);
    }
    FirebaseOptions options =
        FirebaseOptions.builder()
            .setCredentials(credentials)
            .setConnectTimeout(TIMEOUT_MILLIS)
            .setReadTimeout(TIMEOUT_MILLIS)
            .build();
    // A unique name keeps several application contexts (as in tests) from clashing.
    FirebaseApp app = FirebaseApp.initializeApp(options, "drivon-" + UUID.randomUUID());
    return new FcmPushSender(app);
  }
}
