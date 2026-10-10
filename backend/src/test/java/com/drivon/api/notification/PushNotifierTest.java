package com.drivon.api.notification;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.drivon.api.notification.PushNotifier.Outcome;
import com.drivon.api.notification.PushSender.PushResult;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class PushNotifierTest {

  private static final UUID USER = UUID.randomUUID();
  private static final PushMessage MESSAGE =
      new PushMessage("Oil change is due soon", "Toyota Aqua", Map.of("type", "reminder"), "tag");

  private final DeviceTokenRepository tokens = mock(DeviceTokenRepository.class);
  private final PushSender sender = mock(PushSender.class);
  private final PushNotifier notifier = new PushNotifier(tokens, sender);

  @BeforeEach
  void setUp() {
    when(sender.configured()).thenReturn(true);
  }

  private void devices(String... registered) {
    when(tokens.findByUserIdOrderByRegisteredAtDesc(USER))
        .thenReturn(
            List.of(registered).stream()
                .map(t -> new DeviceToken(USER, t, DevicePlatform.ANDROID, Instant.EPOCH))
                .toList());
  }

  @Test
  void sendsToEveryDeviceOfTheUser() {
    devices("phone", "tablet");
    when(sender.send(List.of("phone", "tablet"), MESSAGE))
        .thenReturn(new PushResult(2, List.of(), 0));

    assertThat(notifier.notifyUser(USER, MESSAGE)).isEqualTo(Outcome.DELIVERED);
    verify(tokens, never()).deleteByTokenIn(anyCollection());
  }

  @Test
  void forgetsDevicesThatAreGone() {
    devices("phone", "old-phone");
    when(sender.send(any(), any())).thenReturn(new PushResult(1, List.of("old-phone"), 0));

    assertThat(notifier.notifyUser(USER, MESSAGE)).isEqualTo(Outcome.DELIVERED);
    verify(tokens).deleteByTokenIn(List.of("old-phone"));
  }

  @Test
  void whenEveryDeviceIsGoneThereIsNothingLeftToRetry() {
    devices("old-phone");
    when(sender.send(any(), any())).thenReturn(new PushResult(0, List.of("old-phone"), 0));

    assertThat(notifier.notifyUser(USER, MESSAGE)).isEqualTo(Outcome.NO_DEVICES);
  }

  @Test
  void reportsAFailureWhenNoDeviceCouldBeReached() {
    devices("phone");
    when(sender.send(any(), any())).thenReturn(new PushResult(0, List.of(), 1));

    Outcome outcome = notifier.notifyUser(USER, MESSAGE);

    assertThat(outcome).isEqualTo(Outcome.FAILED);
    assertThat(outcome.settled()).isFalse();
  }

  @Test
  void aUserWithoutDevicesIsSettled() {
    devices();

    Outcome outcome = notifier.notifyUser(USER, MESSAGE);

    assertThat(outcome).isEqualTo(Outcome.NO_DEVICES);
    assertThat(outcome.settled()).isTrue();
    verify(sender, never()).send(any(), any());
  }

  @Test
  void doesNothingWithoutPushConfigured() {
    when(sender.configured()).thenReturn(false);

    assertThat(notifier.notifyUser(USER, MESSAGE)).isEqualTo(Outcome.NOT_CONFIGURED);
    verify(tokens, never()).findByUserIdOrderByRegisteredAtDesc(any());
  }
}
