package com.drivon.api.auth;

import com.drivon.api.config.JwtProperties;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Clock;
import java.time.Instant;
import java.util.Base64;
import java.util.HexFormat;
import java.util.UUID;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.stereotype.Service;

/** Creates access tokens (signed JWTs) and refresh tokens (random opaque strings). */
@Service
class TokenService {

  private static final int REFRESH_TOKEN_BYTES = 32;

  private final JwtEncoder encoder;
  private final JwtProperties properties;
  private final Clock clock;
  private final SecureRandom random = new SecureRandom();

  TokenService(JwtEncoder encoder, JwtProperties properties, Clock clock) {
    this.encoder = encoder;
    this.properties = properties;
    this.clock = clock;
  }

  record IssuedToken(String value, Instant expiresAt) {}

  /** A short-lived JWT whose subject is the user ID; it carries no other personal data. */
  IssuedToken issueAccessToken(UUID userId) {
    Instant now = clock.instant();
    Instant expiresAt = now.plus(properties.accessTokenTtl());
    JwtClaimsSet claims =
        JwtClaimsSet.builder()
            .issuer(properties.issuer())
            .subject(userId.toString())
            .issuedAt(now)
            .expiresAt(expiresAt)
            .build();
    JwsHeader header = JwsHeader.with(MacAlgorithm.HS256).build();
    String value = encoder.encode(JwtEncoderParameters.from(header, claims)).getTokenValue();
    return new IssuedToken(value, expiresAt);
  }

  /** 256 random bits, URL-safe. Only its hash is ever stored. */
  IssuedToken newRefreshToken() {
    byte[] bytes = new byte[REFRESH_TOKEN_BYTES];
    random.nextBytes(bytes);
    String value = Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    return new IssuedToken(value, clock.instant().plus(properties.refreshTokenTtl()));
  }

  /** Hex SHA-256. Refresh tokens are high-entropy, so a fast unsalted hash is sufficient. */
  static String hash(String refreshToken) {
    try {
      MessageDigest digest = MessageDigest.getInstance("SHA-256");
      return HexFormat.of().formatHex(digest.digest(refreshToken.getBytes(StandardCharsets.UTF_8)));
    } catch (NoSuchAlgorithmException e) {
      throw new IllegalStateException("SHA-256 is required on every Java platform", e);
    }
  }
}
