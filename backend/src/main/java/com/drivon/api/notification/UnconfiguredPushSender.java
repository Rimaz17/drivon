package com.drivon.api.notification;

import java.util.List;

/**
 * Stands in when no Firebase service account is configured (e.g. local development without one), so
 * the API still starts and reminders are only shown in the app.
 */
public final class UnconfiguredPushSender implements PushSender {

  @Override
  public boolean configured() {
    return false;
  }

  @Override
  public PushResult send(List<String> tokens, PushMessage message) {
    throw new IllegalStateException("Push notifications are not configured");
  }
}
