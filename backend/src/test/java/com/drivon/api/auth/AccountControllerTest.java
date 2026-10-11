package com.drivon.api.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;

import com.drivon.api.common.error.DrivonException;
import com.drivon.api.common.error.ErrorCode;
import com.drivon.api.common.error.RateLimitedException;
import com.drivon.api.config.SecurityConfig;
import com.drivon.api.config.WebConfig;
import java.time.Duration;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.assertj.MockMvcTester;

@WebMvcTest(AccountController.class)
@Import({SecurityConfig.class, WebConfig.class})
class AccountControllerTest {

  private static final UUID USER = UUID.randomUUID();
  private static final DeleteAccountRequest REQUEST =
      new DeleteAccountRequest("correct-horse-battery");
  private static final String BODY =
      """
      {"password": "correct-horse-battery"}
      """;

  @Autowired private MockMvcTester mvc;
  @MockitoBean private AuthService auth;
  @MockitoBean private AuthRateLimiter rateLimiter;
  @MockitoBean private JwtDecoder jwtDecoder;

  @Test
  void deletesTheTokenSubjectsAccountAndReturns204() {
    assertThat(
            mvc.post()
                .uri("/api/v1/users/me/deletion")
                .with(jwt().jwt(token -> token.subject(USER.toString())))
                .contentType(MediaType.APPLICATION_JSON)
                .content(BODY))
        .hasStatus(HttpStatus.NO_CONTENT);
    verify(rateLimiter).consume("account-deletion:" + USER);
    verify(auth).deleteAccount(USER, REQUEST);
  }

  @Test
  void wrongPasswordIs422SoTheSessionIsKept() {
    doThrow(new DrivonException(ErrorCode.PASSWORD_INCORRECT))
        .when(auth)
        .deleteAccount(USER, REQUEST);

    assertThat(
            mvc.post()
                .uri("/api/v1/users/me/deletion")
                .with(jwt().jwt(token -> token.subject(USER.toString())))
                .contentType(MediaType.APPLICATION_JSON)
                .content(BODY))
        .hasStatus(HttpStatus.UNPROCESSABLE_CONTENT)
        .bodyJson()
        .extractingPath("$.code")
        .isEqualTo("PASSWORD_INCORRECT");
  }

  @Test
  void blankPasswordIsRejectedBeforeReachingTheService() {
    assertThat(
            mvc.post()
                .uri("/api/v1/users/me/deletion")
                .with(jwt().jwt(token -> token.subject(USER.toString())))
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """
                    {"password": ""}
                    """))
        .hasStatus(HttpStatus.BAD_REQUEST)
        .bodyJson()
        .extractingPath("$.code")
        .isEqualTo("VALIDATION_FAILED");
    verifyNoInteractions(auth);
  }

  @Test
  void tooManyAttemptsAreRateLimited() {
    doThrow(new RateLimitedException(Duration.ofSeconds(30)))
        .when(rateLimiter)
        .consume(anyString());

    assertThat(
            mvc.post()
                .uri("/api/v1/users/me/deletion")
                .with(jwt().jwt(token -> token.subject(USER.toString())))
                .contentType(MediaType.APPLICATION_JSON)
                .content(BODY))
        .hasStatus(HttpStatus.TOO_MANY_REQUESTS);
    verifyNoInteractions(auth);
  }

  @Test
  void deletionNeedsAToken() {
    assertThat(
            mvc.post()
                .uri("/api/v1/users/me/deletion")
                .contentType(MediaType.APPLICATION_JSON)
                .content(BODY))
        .hasStatus(HttpStatus.UNAUTHORIZED);
    verifyNoInteractions(auth);
  }
}
