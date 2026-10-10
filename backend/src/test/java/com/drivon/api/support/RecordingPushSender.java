package com.drivon.api.support;

import com.drivon.api.notification.PushMessage;
import com.drivon.api.notification.PushSender;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;

/**
 * Records pushes instead of calling Firebase. Tokens starting with {@code gone-} are reported as
 * uninstalled. Integration tests share one instance; filter by token, since other tests' pushes may
 * be recorded too.
 */
public final class RecordingPushSender implements PushSender {

  /** One delivery of a message to a token. */
  public record Sent(String token, PushMessage message) {}

  private final List<Sent> sent = new CopyOnWriteArrayList<>();

  @Override
  public boolean configured() {
    return true;
  }

  @Override
  public PushResult send(List<String> tokens, PushMessage message) {
    List<String> gone = new ArrayList<>();
    int delivered = 0;
    for (String token : tokens) {
      if (token.startsWith("gone-")) {
        gone.add(token);
      } else {
        sent.add(new Sent(token, message));
        delivered++;
      }
    }
    return new PushResult(delivered, gone, 0);
  }

  /** Messages delivered to {@code token}, oldest first. */
  public List<PushMessage> sentTo(String token) {
    return sent.stream().filter(s -> s.token().equals(token)).map(Sent::message).toList();
  }
}
