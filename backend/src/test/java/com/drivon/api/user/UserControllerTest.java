package com.drivon.api.user;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;

import com.drivon.api.common.error.DrivonException;
import com.drivon.api.common.error.ErrorCode;
import com.drivon.api.config.SecurityConfig;
import com.drivon.api.config.WebConfig;
import java.time.Instant;
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

@WebMvcTest(UserController.class)
@Import({SecurityConfig.class, WebConfig.class})
class UserControllerTest {

  private static final UUID USER = UUID.randomUUID();
  private static final String VALID_BODY =
      """
      {"name": "Rimaz Saththar", "email": "new@example.com"}
      """;

  @Autowired private MockMvcTester mvc;
  @MockitoBean private UserService service;
  @MockitoBean private JwtDecoder jwtDecoder;

  @Test
  void updateReturnsTheNewProfileOfTheTokenSubject() {
    when(service.updateProfile(eq(USER), any()))
        .thenReturn(
            new UserResponse(
                USER, "Rimaz Saththar", "new@example.com", Instant.parse("2026-10-07T10:00:00Z")));

    assertThat(
            mvc.put()
                .uri("/api/v1/users/me")
                .with(jwt().jwt(token -> token.subject(USER.toString())))
                .contentType(MediaType.APPLICATION_JSON)
                .content(VALID_BODY))
        .hasStatusOk()
        .bodyJson()
        .satisfies(
            json -> {
              json.assertThat().extractingPath("$.email").isEqualTo("new@example.com");
              json.assertThat().doesNotHavePath("$.passwordHash");
            });
  }

  @Test
  void invalidProfileIsRejectedBeforeReachingTheService() {
    assertThat(
            mvc.put()
                .uri("/api/v1/users/me")
                .with(jwt().jwt(token -> token.subject(USER.toString())))
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """
                    {"name": " ", "email": "not-an-email"}
                    """))
        .hasStatus(HttpStatus.BAD_REQUEST)
        .bodyJson()
        .satisfies(
            json -> {
              json.assertThat().extractingPath("$.code").isEqualTo("VALIDATION_FAILED");
              json.assertThat().extractingPath("$.errors.length()").isEqualTo(2);
            });
    verifyNoInteractions(service);
  }

  @Test
  void takenEmailIsAConflict() {
    when(service.updateProfile(eq(USER), any()))
        .thenThrow(new DrivonException(ErrorCode.EMAIL_ALREADY_REGISTERED));

    assertThat(
            mvc.put()
                .uri("/api/v1/users/me")
                .with(jwt().jwt(token -> token.subject(USER.toString())))
                .contentType(MediaType.APPLICATION_JSON)
                .content(VALID_BODY))
        .hasStatus(HttpStatus.CONFLICT)
        .bodyJson()
        .extractingPath("$.code")
        .isEqualTo("EMAIL_ALREADY_REGISTERED");
  }

  @Test
  void updateNeedsAToken() {
    assertThat(
            mvc.put()
                .uri("/api/v1/users/me")
                .contentType(MediaType.APPLICATION_JSON)
                .content(VALID_BODY))
        .hasStatus(HttpStatus.UNAUTHORIZED);
    verifyNoInteractions(service);
  }
}
