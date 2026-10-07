package com.drivon.api.config;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.time.Duration;
import java.util.Base64;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

/**
 * Token settings ({@code drivon.security.jwt.*}). The secret is Base64 and must decode to at least
 * 256 bits for HS256; generate one with {@code openssl rand -base64 48}.
 */
@Validated
@ConfigurationProperties("drivon.security.jwt")
public record JwtProperties(
    @NotBlank String issuer,
    @NotBlank String secret,
    @NotNull Duration accessTokenTtl,
    @NotNull Duration refreshTokenTtl) {

  private static final int MIN_SECRET_BYTES = 32;

  public JwtProperties {
    if (secret != null && !secret.isBlank() && decode(secret).length < MIN_SECRET_BYTES) {
      throw new IllegalArgumentException(
          "drivon.security.jwt.secret must be Base64 for at least 256 bits");
    }
  }

  public byte[] secretBytes() {
    return decode(secret);
  }

  private static byte[] decode(String value) {
    try {
      return Base64.getDecoder().decode(value.strip());
    } catch (IllegalArgumentException e) {
      throw new IllegalArgumentException("drivon.security.jwt.secret must be valid Base64", e);
    }
  }
}
