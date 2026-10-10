package com.drivon.api.notification;

import com.drivon.api.notification.PushSender.PushResult;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Pushes notifications to every device a user registered, forgetting devices that are gone. */
@Service
public class PushNotifier {

  /** What became of a notification. */
  public enum Outcome {
    /** At least one device accepted it. */
    DELIVERED,
    /** The user has no devices that can receive pushes (e.g. iPhone users in the MVP). */
    NO_DEVICES,
    /** Every device failed for a reason that may pass; worth trying again later. */
    FAILED,
    /** Push isn't set up on this server. */
    NOT_CONFIGURED;

    /** True when trying again wouldn't change anything. */
    public boolean settled() {
      return this == DELIVERED || this == NO_DEVICES;
    }
  }

  private final DeviceTokenRepository tokens;
  private final PushSender sender;

  PushNotifier(DeviceTokenRepository tokens, PushSender sender) {
    this.tokens = tokens;
    this.sender = sender;
  }

  @Transactional
  public Outcome notifyUser(UUID userId, PushMessage message) {
    if (!sender.configured()) {
      return Outcome.NOT_CONFIGURED;
    }
    List<String> devices =
        tokens.findByUserIdOrderByRegisteredAtDesc(userId).stream()
            .map(DeviceToken::getToken)
            .toList();
    if (devices.isEmpty()) {
      return Outcome.NO_DEVICES;
    }
    PushResult result = sender.send(devices, message);
    if (!result.invalidTokens().isEmpty()) {
      tokens.deleteByTokenIn(result.invalidTokens());
    }
    if (result.delivered() > 0) {
      return Outcome.DELIVERED;
    }
    return result.failed() > 0 ? Outcome.FAILED : Outcome.NO_DEVICES;
  }
}
