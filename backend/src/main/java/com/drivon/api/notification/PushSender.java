package com.drivon.api.notification;

import java.util.List;

/** Delivers notifications to device tokens. Implemented with Firebase Cloud Messaging. */
public interface PushSender {

  /** False when push isn't set up on this server; {@link #send} must not be called then. */
  boolean configured();

  /** Sends {@code message} to each token; never throws for delivery failures. */
  PushResult send(List<String> tokens, PushMessage message);

  /**
   * What happened to one send.
   *
   * @param delivered tokens the message was accepted for
   * @param invalidTokens tokens that no longer exist (app uninstalled, data cleared) and should be
   *     forgotten
   * @param failed tokens that couldn't be reached this time and may work later
   */
  record PushResult(int delivered, List<String> invalidTokens, int failed) {

    public PushResult {
      invalidTokens = List.copyOf(invalidTokens);
    }
  }
}
