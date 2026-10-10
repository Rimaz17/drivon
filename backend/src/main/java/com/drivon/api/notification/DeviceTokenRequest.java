package com.drivon.api.notification;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * Body for registering an app installation for push notifications.
 *
 * @param token the Firebase Cloud Messaging registration token
 */
public record DeviceTokenRequest(
    @NotNull @Size(min = 1, max = 512) @Pattern(regexp = DeviceTokenRequest.TOKEN_PATTERN) String token,
    @NotNull DevicePlatform platform) {

  /** FCM tokens use URL-safe characters only, so they also work as a path segment. */
  static final String TOKEN_PATTERN = "[A-Za-z0-9_:\\-]+";
}
