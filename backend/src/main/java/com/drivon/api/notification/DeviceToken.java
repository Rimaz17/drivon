package com.drivon.api.notification;

import com.drivon.api.common.persistence.AssignedIdEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/** A push notification token of one app installation, owned by the user who registered it last. */
@Entity
@Table(name = "device_tokens")
public class DeviceToken extends AssignedIdEntity {

  @Column(name = "user_id", nullable = false)
  private UUID userId;

  @Column(nullable = false, updatable = false, length = 512)
  private String token;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false, length = 10)
  private DevicePlatform platform;

  @Column(name = "registered_at", nullable = false)
  private Instant registeredAt;

  protected DeviceToken() {}

  DeviceToken(UUID userId, String token, DevicePlatform platform, Instant registeredAt) {
    super(null);
    this.token = token;
    register(userId, platform, registeredAt);
  }

  /** Gives the token to {@code userId}, e.g. after someone else signed in on the same phone. */
  void register(UUID userId, DevicePlatform platform, Instant registeredAt) {
    this.userId = userId;
    this.platform = platform;
    this.registeredAt = registeredAt;
  }

  public UUID getUserId() {
    return userId;
  }

  public String getToken() {
    return token;
  }

  public DevicePlatform getPlatform() {
    return platform;
  }

  public Instant getRegisteredAt() {
    return registeredAt;
  }
}
