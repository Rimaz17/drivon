package com.drivon.api.auth;

import com.drivon.api.user.UserResponse;
import java.time.Instant;

/** Tokens returned after register, login and refresh. */
public record AuthResponse(
    String tokenType,
    String accessToken,
    Instant accessTokenExpiresAt,
    String refreshToken,
    Instant refreshTokenExpiresAt,
    UserResponse user) {

  static final String TOKEN_TYPE = "Bearer";
}
