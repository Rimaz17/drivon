package com.drivon.api.user;

import java.time.Instant;
import java.util.UUID;

/** Public view of an account. Never includes the password hash. */
public record UserResponse(UUID id, String name, String email, Instant createdAt) {

  public static UserResponse from(User user) {
    return new UserResponse(user.getId(), user.getName(), user.getEmail(), user.getCreatedAt());
  }
}
