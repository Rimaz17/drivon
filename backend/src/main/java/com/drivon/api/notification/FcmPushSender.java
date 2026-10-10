package com.drivon.api.notification;

import com.google.firebase.FirebaseApp;
import com.google.firebase.messaging.AndroidConfig;
import com.google.firebase.messaging.AndroidNotification;
import com.google.firebase.messaging.BatchResponse;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.MessagingErrorCode;
import com.google.firebase.messaging.MulticastMessage;
import com.google.firebase.messaging.Notification;
import com.google.firebase.messaging.SendResponse;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import org.jspecify.annotations.Nullable;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Sends notifications through Firebase Cloud Messaging. Android shows them in the app's reminders
 * channel even when the app isn't running. Tokens are never logged.
 */
public final class FcmPushSender implements PushSender, AutoCloseable {

  /** Must match the channel the app creates (NotificationService in the Flutter app). */
  public static final String ANDROID_CHANNEL_ID = "drivon_reminders";

  /**
   * Errors that mean the token is gone for good. {@code INVALID_ARGUMENT} is left out: it can also
   * mean a bad message, and forgetting every token for that would be worse than a retry.
   */
  private static final Set<MessagingErrorCode> GONE =
      Set.of(MessagingErrorCode.UNREGISTERED, MessagingErrorCode.SENDER_ID_MISMATCH);

  private static final Logger log = LoggerFactory.getLogger(FcmPushSender.class);

  private final FirebaseApp app;
  private final FirebaseMessaging messaging;

  public FcmPushSender(FirebaseApp app) {
    this.app = app;
    this.messaging = FirebaseMessaging.getInstance(app);
  }

  @Override
  public boolean configured() {
    return true;
  }

  @Override
  public PushResult send(List<String> tokens, PushMessage message) {
    if (tokens.isEmpty()) {
      return new PushResult(0, List.of(), 0);
    }
    try {
      BatchResponse batch = messaging.sendEachForMulticast(toMulticast(tokens, message));
      int delivered = 0;
      int failed = 0;
      List<String> invalid = new ArrayList<>();
      List<SendResponse> responses = batch.getResponses();
      for (int i = 0; i < responses.size(); i++) {
        SendResponse response = responses.get(i);
        if (response.isSuccessful()) {
          delivered++;
        } else if (isGone(response.getException().getMessagingErrorCode())) {
          invalid.add(tokens.get(i));
        } else {
          failed++;
          log.warn("Push to a device failed: {}", describe(response.getException()));
        }
      }
      return new PushResult(delivered, invalid, failed);
    } catch (FirebaseMessagingException e) {
      log.warn("Push failed: {}", describe(e));
      return new PushResult(0, List.of(), tokens.size());
    }
  }

  /** Some failures (e.g. rejected credentials) carry no messaging error code at all. */
  private static boolean isGone(@Nullable MessagingErrorCode code) {
    return code != null && GONE.contains(code);
  }

  private static String describe(FirebaseMessagingException e) {
    MessagingErrorCode code = e.getMessagingErrorCode();
    return code != null ? code.name() : String.valueOf(e.getErrorCode());
  }

  static MulticastMessage toMulticast(List<String> tokens, PushMessage message) {
    return MulticastMessage.builder()
        .addAllTokens(tokens)
        .setNotification(
            Notification.builder().setTitle(message.title()).setBody(message.body()).build())
        .putAllData(message.data())
        .setAndroidConfig(
            AndroidConfig.builder()
                .setPriority(AndroidConfig.Priority.HIGH)
                .setNotification(
                    AndroidNotification.builder()
                        .setChannelId(ANDROID_CHANNEL_ID)
                        .setTag(message.tag())
                        .build())
                .build())
        .build();
  }

  @Override
  public void close() {
    app.delete();
  }
}
