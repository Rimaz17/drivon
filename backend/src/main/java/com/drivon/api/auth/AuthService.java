package com.drivon.api.auth;

import com.drivon.api.common.error.DrivonException;
import com.drivon.api.common.error.ErrorCode;
import com.drivon.api.user.Emails;
import com.drivon.api.user.User;
import com.drivon.api.user.UserRepository;
import com.drivon.api.user.UserResponse;
import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.Instant;
import java.util.Optional;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Registration, login and the refresh-token lifecycle. Each login starts a token family; refresh
 * rotates within the family, and presenting an already-rotated token revokes the whole family
 * because it may have been stolen. See docs/adr/0005-authentication-tokens.md.
 */
@Service
public class AuthService {

  /** BCrypt only uses the first 72 bytes; longer input would be silently truncated. */
  static final int MAX_PASSWORD_BYTES = 72;

  private static final Logger log = LoggerFactory.getLogger(AuthService.class);

  private final UserRepository users;
  private final RefreshTokenRepository refreshTokens;
  private final PasswordEncoder passwordEncoder;
  private final TokenService tokens;
  private final Clock clock;

  /** Compared against when the email is unknown, so both failure paths take as long. */
  private final String unknownUserHash;

  AuthService(
      UserRepository users,
      RefreshTokenRepository refreshTokens,
      PasswordEncoder passwordEncoder,
      TokenService tokens,
      Clock clock) {
    this.users = users;
    this.refreshTokens = refreshTokens;
    this.passwordEncoder = passwordEncoder;
    this.tokens = tokens;
    this.clock = clock;
    this.unknownUserHash = passwordEncoder.encode("unknown-user-timing-equalizer");
  }

  /** Creates an account and signs it in. */
  @Transactional
  public AuthResponse register(RegisterRequest request) {
    if (isTooLong(request.password())) {
      throw new DrivonException(
          ErrorCode.VALIDATION_FAILED, "Password must be at most 72 bytes long.");
    }
    String email = Emails.normalize(request.email());
    if (users.existsByEmail(email)) {
      throw new DrivonException(
          ErrorCode.EMAIL_ALREADY_REGISTERED, "An account with this email already exists.");
    }
    User user =
        users.saveAndFlush(
            new User(request.name().strip(), email, passwordEncoder.encode(request.password())));
    return issueTokens(user, UUID.randomUUID());
  }

  /** Signs in with email and password. The error never reveals which of the two was wrong. */
  @Transactional
  public AuthResponse login(LoginRequest request) {
    Optional<User> user = users.findByEmail(Emails.normalize(request.email()));
    String hash = user.map(User::getPasswordHash).orElse(unknownUserHash);
    boolean passwordMatches =
        !isTooLong(request.password()) && passwordEncoder.matches(request.password(), hash);
    if (user.isEmpty() || !passwordMatches) {
      throw new DrivonException(
          ErrorCode.INVALID_CREDENTIALS, "The email or password is incorrect.");
    }
    return issueTokens(user.get(), UUID.randomUUID());
  }

  /**
   * Exchanges a refresh token for a new access and refresh token pair. The presented token is
   * revoked. Does not roll back on failure, so a reuse-triggered revocation is kept.
   */
  @Transactional(noRollbackFor = DrivonException.class)
  public AuthResponse refresh(RefreshRequest request) {
    Instant now = clock.instant();
    RefreshToken current =
        refreshTokens
            .findForUpdateByTokenHash(TokenService.hash(request.refreshToken()))
            .orElseThrow(AuthService::invalidRefreshToken);
    if (current.isRevoked()) {
      refreshTokens.revokeFamily(current.getFamilyId(), now);
      log.warn("Refresh token reuse detected; revoked token family {}", current.getFamilyId());
      throw invalidRefreshToken();
    }
    if (current.isExpiredAt(now)) {
      throw invalidRefreshToken();
    }
    current.revoke(now);
    User user = users.findById(current.getUserId()).orElseThrow(AuthService::invalidRefreshToken);
    return issueTokens(user, current.getFamilyId());
  }

  /** Ends the session the refresh token belongs to. Unknown tokens are ignored (idempotent). */
  @Transactional
  public void logout(RefreshRequest request) {
    refreshTokens
        .findByTokenHash(TokenService.hash(request.refreshToken()))
        .ifPresent(token -> refreshTokens.revokeFamily(token.getFamilyId(), clock.instant()));
  }

  private AuthResponse issueTokens(User user, UUID familyId) {
    TokenService.IssuedToken access = tokens.issueAccessToken(user.getId());
    TokenService.IssuedToken refresh = tokens.newRefreshToken();
    refreshTokens.save(
        new RefreshToken(
            user.getId(),
            familyId,
            TokenService.hash(refresh.value()),
            clock.instant(),
            refresh.expiresAt()));
    return new AuthResponse(
        AuthResponse.TOKEN_TYPE,
        access.value(),
        access.expiresAt(),
        refresh.value(),
        refresh.expiresAt(),
        UserResponse.from(user));
  }

  private static boolean isTooLong(String password) {
    return password.getBytes(StandardCharsets.UTF_8).length > MAX_PASSWORD_BYTES;
  }

  private static DrivonException invalidRefreshToken() {
    return new DrivonException(
        ErrorCode.INVALID_REFRESH_TOKEN, "Your session has ended. Please sign in again.");
  }
}
