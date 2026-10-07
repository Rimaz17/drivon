package com.drivon.api.auth;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/**
 * A refresh token, stored only as a SHA-256 hash. Tokens issued from the same login share a family;
 * see docs/adr/0005-authentication-tokens.md.
 */
@Entity
@Table(name = "refresh_tokens")
public class RefreshToken {

  @Id private UUID id;

  @Column(name = "user_id", nullable = false, updatable = false)
  private UUID userId;

  @Column(name = "family_id", nullable = false, updatable = false)
  private UUID familyId;

  @Column(name = "token_hash", nullable = false, updatable = false, length = 64)
  private String tokenHash;

  @Column(name = "expires_at", nullable = false, updatable = false)
  private Instant expiresAt;

  @Column(name = "revoked_at")
  private Instant revokedAt;

  @Column(name = "created_at", nullable = false, updatable = false)
  private Instant createdAt;

  protected RefreshToken() {}

  RefreshToken(UUID userId, UUID familyId, String tokenHash, Instant createdAt, Instant expiresAt) {
    this.id = UUID.randomUUID();
    this.userId = userId;
    this.familyId = familyId;
    this.tokenHash = tokenHash;
    this.createdAt = createdAt;
    this.expiresAt = expiresAt;
  }

  boolean isRevoked() {
    return revokedAt != null;
  }

  boolean isExpiredAt(Instant now) {
    return !now.isBefore(expiresAt);
  }

  void revoke(Instant now) {
    if (revokedAt == null) {
      revokedAt = now;
    }
  }

  UUID getUserId() {
    return userId;
  }

  UUID getFamilyId() {
    return familyId;
  }

  String getTokenHash() {
    return tokenHash;
  }

  Instant getRevokedAt() {
    return revokedAt;
  }
}
