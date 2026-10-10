package com.drivon.api.notification;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import java.util.stream.IntStream;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

class DeviceTokenServiceTest {

  private static final Instant NOW = Instant.parse("2026-10-10T04:30:00Z");
  private static final UUID USER = UUID.randomUUID();

  private final DeviceTokenRepository tokens = mock(DeviceTokenRepository.class);
  private final DeviceTokenService service =
      new DeviceTokenService(tokens, Clock.fixed(NOW, ZoneOffset.UTC));

  @BeforeEach
  void setUp() {
    when(tokens.findByToken(any())).thenReturn(Optional.empty());
  }

  @Test
  void registersANewDevice() {
    service.register(USER, new DeviceTokenRequest("token-1", DevicePlatform.ANDROID));

    ArgumentCaptor<DeviceToken> saved = ArgumentCaptor.forClass(DeviceToken.class);
    verify(tokens).saveAndFlush(saved.capture());
    assertThat(saved.getValue().getUserId()).isEqualTo(USER);
    assertThat(saved.getValue().getToken()).isEqualTo("token-1");
    assertThat(saved.getValue().getPlatform()).isEqualTo(DevicePlatform.ANDROID);
    assertThat(saved.getValue().getRegisteredAt()).isEqualTo(NOW);
  }

  @Test
  void aTokenRegisteredBySomeoneElseMovesToTheNewUser() {
    DeviceToken existing =
        new DeviceToken(UUID.randomUUID(), "token-1", DevicePlatform.ANDROID, Instant.EPOCH);
    when(tokens.findByToken("token-1")).thenReturn(Optional.of(existing));

    service.register(USER, new DeviceTokenRequest("token-1", DevicePlatform.ANDROID));

    verify(tokens).saveAndFlush(existing);
    assertThat(existing.getUserId()).isEqualTo(USER);
    assertThat(existing.getRegisteredAt()).isEqualTo(NOW);
  }

  @Test
  void keepsOnlyTheNewestDevices() {
    List<DeviceToken> devices =
        IntStream.range(0, DeviceTokenService.MAX_DEVICES_PER_USER + 2)
            .mapToObj(
                i ->
                    new DeviceToken(
                        USER, "token-" + i, DevicePlatform.ANDROID, NOW.minusSeconds(i)))
            .toList();
    when(tokens.findByUserIdOrderByRegisteredAtDesc(USER)).thenReturn(devices);

    service.register(USER, new DeviceTokenRequest("token-0", DevicePlatform.ANDROID));

    verify(tokens).deleteAll(devices.subList(DeviceTokenService.MAX_DEVICES_PER_USER, 12));
  }

  @Test
  void aFewDevicesAreAllKept() {
    when(tokens.findByUserIdOrderByRegisteredAtDesc(USER))
        .thenReturn(List.of(new DeviceToken(USER, "token-1", DevicePlatform.ANDROID, NOW)));

    service.register(USER, new DeviceTokenRequest("token-1", DevicePlatform.ANDROID));

    verify(tokens, never()).deleteAll(any());
  }

  @Test
  void unregistersOnlyTheUsersOwnToken() {
    service.unregister(USER, "token-1");

    verify(tokens).deleteByUserIdAndToken(USER, "token-1");
  }
}
