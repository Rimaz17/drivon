package com.drivon.api.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.drivon.api.common.error.DrivonException;
import com.drivon.api.common.error.ErrorCode;
import com.drivon.api.user.User;
import com.drivon.api.user.UserRepository;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.util.ReflectionTestUtils;

class AuthServiceTest {

  private static final Instant NOW = Instant.parse("2026-10-07T10:00:00Z");

  private final UserRepository users = mock(UserRepository.class);
  private final RefreshTokenRepository refreshTokens = mock(RefreshTokenRepository.class);
  private final PasswordEncoder passwordEncoder = mock(PasswordEncoder.class);
  private final TokenService tokens = mock(TokenService.class);
  private AuthService auth;

  @BeforeEach
  void setUp() {
    when(passwordEncoder.encode(anyString())).thenAnswer(i -> "hashed:" + i.getArgument(0));
    when(passwordEncoder.matches(anyString(), anyString()))
        .thenAnswer(i -> ("hashed:" + i.getArgument(0)).equals(i.getArgument(1)));
    when(tokens.issueAccessToken(any()))
        .thenReturn(new TokenService.IssuedToken("access", NOW.plus(Duration.ofMinutes(15))));
    when(tokens.newRefreshToken())
        .thenReturn(new TokenService.IssuedToken("refresh", NOW.plus(Duration.ofDays(30))));
    auth =
        new AuthService(
            users, refreshTokens, passwordEncoder, tokens, Clock.fixed(NOW, ZoneOffset.UTC));
  }

  @Test
  void registersWithNormalizedEmailAndHashedPassword() {
    when(users.saveAndFlush(any())).thenAnswer(i -> withId(i.getArgument(0)));

    AuthResponse response =
        auth.register(new RegisterRequest("  Rimaz ", " Rimaz@Example.COM ", "password1"));

    ArgumentCaptor<User> saved = ArgumentCaptor.forClass(User.class);
    verify(users).saveAndFlush(saved.capture());
    assertThat(saved.getValue().getEmail()).isEqualTo("rimaz@example.com");
    assertThat(saved.getValue().getName()).isEqualTo("Rimaz");
    assertThat(saved.getValue().getPasswordHash()).isEqualTo("hashed:password1");
    assertThat(response.accessToken()).isEqualTo("access");
    assertThat(response.refreshToken()).isEqualTo("refresh");
    assertThat(response.tokenType()).isEqualTo("Bearer");
  }

  @Test
  void storesOnlyTheHashOfTheIssuedRefreshToken() {
    when(users.saveAndFlush(any())).thenAnswer(i -> withId(i.getArgument(0)));

    auth.register(new RegisterRequest("Rimaz", "rimaz@example.com", "password1"));

    ArgumentCaptor<RefreshToken> saved = ArgumentCaptor.forClass(RefreshToken.class);
    verify(refreshTokens).save(saved.capture());
    assertThat(saved.getValue().getTokenHash()).isEqualTo(TokenService.hash("refresh"));
  }

  @Test
  void rejectsRegistrationForExistingEmailRegardlessOfCase() {
    when(users.existsByEmail("rimaz@example.com")).thenReturn(true);

    assertThatThrownBy(
            () -> auth.register(new RegisterRequest("R", "RIMAZ@example.com", "password1")))
        .extracting(e -> ((DrivonException) e).code())
        .isEqualTo(ErrorCode.EMAIL_ALREADY_REGISTERED);
    verify(users, never()).saveAndFlush(any());
  }

  @Test
  void rejectsPasswordsLongerThanBcryptCanHash() {
    String longPassword = "é".repeat(40); // 80 bytes in UTF-8

    assertThatThrownBy(() -> auth.register(new RegisterRequest("R", "r@example.com", longPassword)))
        .extracting(e -> ((DrivonException) e).code())
        .isEqualTo(ErrorCode.VALIDATION_FAILED);
  }

  @Test
  void logsInWithCorrectPassword() {
    User user = withId(new User("Rimaz", "rimaz@example.com", "hashed:password1"));
    when(users.findByEmail("rimaz@example.com")).thenReturn(Optional.of(user));

    AuthResponse response = auth.login(new LoginRequest("Rimaz@Example.com", "password1"));

    assertThat(response.user().id()).isEqualTo(user.getId());
  }

  @Test
  void rejectsWrongPasswordWithGenericError() {
    User user = withId(new User("Rimaz", "rimaz@example.com", "hashed:password1"));
    when(users.findByEmail("rimaz@example.com")).thenReturn(Optional.of(user));

    assertThatThrownBy(() -> auth.login(new LoginRequest("rimaz@example.com", "wrong-pass")))
        .extracting(e -> ((DrivonException) e).code())
        .isEqualTo(ErrorCode.INVALID_CREDENTIALS);
  }

  @Test
  void rejectsUnknownEmailWithSameErrorAfterComparingAPassword() {
    when(users.findByEmail(anyString())).thenReturn(Optional.empty());

    assertThatThrownBy(() -> auth.login(new LoginRequest("nobody@example.com", "password1")))
        .extracting(e -> ((DrivonException) e).code())
        .isEqualTo(ErrorCode.INVALID_CREDENTIALS);
    verify(passwordEncoder).matches(eq("password1"), anyString());
  }

  @Test
  void refreshRotatesTokenWithinTheSameFamily() {
    User user = withId(new User("Rimaz", "rimaz@example.com", "hash"));
    UUID family = UUID.randomUUID();
    RefreshToken current = token(user.getId(), family, NOW.plus(Duration.ofDays(1)));
    when(refreshTokens.findForUpdateByTokenHash(TokenService.hash("old")))
        .thenReturn(Optional.of(current));
    when(users.findById(user.getId())).thenReturn(Optional.of(user));

    AuthResponse response = auth.refresh(new RefreshRequest("old"));

    assertThat(current.getRevokedAt()).isEqualTo(NOW);
    ArgumentCaptor<RefreshToken> saved = ArgumentCaptor.forClass(RefreshToken.class);
    verify(refreshTokens).save(saved.capture());
    assertThat(saved.getValue().getFamilyId()).isEqualTo(family);
    assertThat(response.refreshToken()).isEqualTo("refresh");
  }

  @Test
  void reuseOfRotatedTokenRevokesTheWholeFamily() {
    UUID family = UUID.randomUUID();
    RefreshToken rotated = token(UUID.randomUUID(), family, NOW.plus(Duration.ofDays(1)));
    rotated.revoke(NOW.minusSeconds(60));
    when(refreshTokens.findForUpdateByTokenHash(anyString())).thenReturn(Optional.of(rotated));

    assertThatThrownBy(() -> auth.refresh(new RefreshRequest("stolen")))
        .extracting(e -> ((DrivonException) e).code())
        .isEqualTo(ErrorCode.INVALID_REFRESH_TOKEN);
    verify(refreshTokens).revokeFamily(family, NOW);
    verify(refreshTokens, never()).save(any());
  }

  @Test
  void rejectsExpiredRefreshToken() {
    RefreshToken expired = token(UUID.randomUUID(), UUID.randomUUID(), NOW);
    when(refreshTokens.findForUpdateByTokenHash(anyString())).thenReturn(Optional.of(expired));

    assertThatThrownBy(() -> auth.refresh(new RefreshRequest("expired")))
        .extracting(e -> ((DrivonException) e).code())
        .isEqualTo(ErrorCode.INVALID_REFRESH_TOKEN);
  }

  @Test
  void rejectsUnknownRefreshToken() {
    when(refreshTokens.findForUpdateByTokenHash(anyString())).thenReturn(Optional.empty());

    assertThatThrownBy(() -> auth.refresh(new RefreshRequest("made-up")))
        .extracting(e -> ((DrivonException) e).code())
        .isEqualTo(ErrorCode.INVALID_REFRESH_TOKEN);
  }

  @Test
  void logoutRevokesTheSessionFamily() {
    UUID family = UUID.randomUUID();
    when(refreshTokens.findByTokenHash(TokenService.hash("current")))
        .thenReturn(Optional.of(token(UUID.randomUUID(), family, NOW.plusSeconds(60))));

    auth.logout(new RefreshRequest("current"));

    verify(refreshTokens).revokeFamily(family, NOW);
  }

  @Test
  void logoutWithUnknownTokenDoesNothing() {
    when(refreshTokens.findByTokenHash(anyString())).thenReturn(Optional.empty());

    auth.logout(new RefreshRequest("unknown"));

    verify(refreshTokens, never()).revokeFamily(any(), any());
  }

  private static RefreshToken token(UUID userId, UUID family, Instant expiresAt) {
    return new RefreshToken(userId, family, "hash", NOW.minus(Duration.ofDays(1)), expiresAt);
  }

  private static User withId(User user) {
    ReflectionTestUtils.setField(user, "id", UUID.randomUUID());
    return user;
  }
}
