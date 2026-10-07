package com.drivon.api.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.drivon.api.config.JwtConfig;
import com.drivon.api.config.JwtProperties;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;
import java.util.UUID;
import javax.crypto.SecretKey;
import org.junit.jupiter.api.Test;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtException;

class TokenServiceTest {

  private static final String SECRET =
      "dGVzdC1vbmx5LWRyaXZvbi1qd3Qtc2VjcmV0LWZvci1hdXRvbWF0ZWQtdGVzdHM=";

  // Real "now" (truncated) because the decoder validates expiry against the system clock.
  private final Instant now = Instant.now().truncatedTo(ChronoUnit.SECONDS);
  private final JwtProperties properties =
      new JwtProperties("drivon-api", SECRET, Duration.ofMinutes(15), Duration.ofDays(30));
  private final JwtConfig config = new JwtConfig();
  private final SecretKey key = config.jwtSigningKey(properties);
  private final JwtDecoder decoder = config.jwtDecoder(key, properties);
  private final TokenService tokens =
      new TokenService(config.jwtEncoder(key), properties, Clock.fixed(now, ZoneOffset.UTC));

  @Test
  void issuesAccessTokenForUserWithConfiguredLifetime() {
    UUID userId = UUID.randomUUID();

    TokenService.IssuedToken token = tokens.issueAccessToken(userId);
    Jwt jwt = decoder.decode(token.value());

    assertThat(jwt.getSubject()).isEqualTo(userId.toString());
    assertThat(jwt.getClaimAsString("iss")).isEqualTo("drivon-api");
    assertThat(jwt.getExpiresAt()).isEqualTo(now.plus(Duration.ofMinutes(15)));
    assertThat(token.expiresAt()).isEqualTo(jwt.getExpiresAt());
  }

  @Test
  void rejectsTokenSignedForAnotherIssuer() {
    JwtProperties other =
        new JwtProperties("someone-else", SECRET, Duration.ofMinutes(15), Duration.ofDays(30));
    TokenService foreign =
        new TokenService(config.jwtEncoder(key), other, Clock.fixed(now, ZoneOffset.UTC));

    String token = foreign.issueAccessToken(UUID.randomUUID()).value();

    assertThatThrownBy(() -> decoder.decode(token)).isInstanceOf(JwtException.class);
  }

  @Test
  void rejectsTamperedToken() {
    String token = tokens.issueAccessToken(UUID.randomUUID()).value();
    String tampered = token.substring(0, token.length() - 2) + "xx";

    assertThatThrownBy(() -> decoder.decode(tampered)).isInstanceOf(JwtException.class);
  }

  @Test
  void createsUniqueRefreshTokensThatExpireAfterConfiguredLifetime() {
    TokenService.IssuedToken first = tokens.newRefreshToken();
    TokenService.IssuedToken second = tokens.newRefreshToken();

    assertThat(first.value()).isNotEqualTo(second.value()).hasSize(43);
    assertThat(first.expiresAt()).isEqualTo(now.plus(Duration.ofDays(30)));
  }

  @Test
  void hashesRefreshTokensDeterministicallyAsHex() {
    assertThat(TokenService.hash("abc"))
        .isEqualTo("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        .isEqualTo(TokenService.hash("abc"));
  }

  @Test
  void refusesSecretsShorterThan256Bits() {
    assertThatThrownBy(
            () ->
                new JwtProperties(
                    "drivon-api", "c2hvcnQ=", Duration.ofMinutes(15), Duration.ofDays(30)))
        .isInstanceOf(IllegalArgumentException.class)
        .hasMessageContaining("256 bits");
  }
}
