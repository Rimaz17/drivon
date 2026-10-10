package com.drivon.api.notification;

import java.util.Map;

/**
 * A notification for one user's devices.
 *
 * @param data string values the app reads when the notification is tapped
 * @param tag notifications with the same tag replace each other on the device instead of stacking
 */
public record PushMessage(String title, String body, Map<String, String> data, String tag) {

  public PushMessage {
    data = Map.copyOf(data);
  }
}
