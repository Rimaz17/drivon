package com.drivon.api.notification;

import java.time.Clock;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Registers the signed-in user's app installations for push notifications. */
@Service
public class DeviceTokenService {

  /** Older installations beyond this are forgotten; they would be reinstalls or old phones. */
  static final int MAX_DEVICES_PER_USER = 10;

  private final DeviceTokenRepository tokens;
  private final Clock clock;

  DeviceTokenService(DeviceTokenRepository tokens, Clock clock) {
    this.tokens = tokens;
    this.clock = clock;
  }

  /**
   * Remembers that pushes for {@code userId} go to this installation. Registering again is
   * harmless; a token another user registered before moves to this user.
   */
  @Transactional
  public void register(UUID userId, DeviceTokenRequest request) {
    DeviceToken token =
        tokens
            .findByToken(request.token())
            .map(
                existing -> {
                  existing.register(userId, request.platform(), clock.instant());
                  return existing;
                })
            .orElseGet(
                () ->
                    new DeviceToken(userId, request.token(), request.platform(), clock.instant()));
    tokens.saveAndFlush(token);
    List<DeviceToken> devices = tokens.findByUserIdOrderByRegisteredAtDesc(userId);
    if (devices.size() > MAX_DEVICES_PER_USER) {
      tokens.deleteAll(devices.subList(MAX_DEVICES_PER_USER, devices.size()));
    }
  }

  /** Stops pushes to this installation, e.g. on sign-out. Unknown tokens are ignored. */
  @Transactional
  public void unregister(UUID userId, String token) {
    tokens.deleteByUserIdAndToken(userId, token);
  }
}
