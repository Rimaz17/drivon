package com.drivon.api.auth;

import static org.assertj.core.api.Assertions.assertThat;

import com.drivon.api.support.ApiClient;
import com.drivon.api.support.ApiClient.Session;
import com.drivon.api.support.IntegrationTest;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.test.web.servlet.assertj.MockMvcTester;
import org.springframework.test.web.servlet.assertj.MvcTestResult;

@IntegrationTest
class AuthIntegrationTest {

  @Autowired private MockMvcTester mvc;
  private ApiClient api;

  @BeforeEach
  void setUp() {
    api = new ApiClient(mvc);
  }

  @Test
  void registeredUserCanReadTheirProfileWithTheAccessToken() {
    Session session = api.register();

    assertThat(
            mvc.get().uri("/api/v1/users/me").header(HttpHeaders.AUTHORIZATION, session.bearer()))
        .hasStatusOk()
        .bodyJson()
        .satisfies(
            json -> {
              json.assertThat().extractingPath("$.email").isEqualTo(session.email());
              json.assertThat().doesNotHavePath("$.passwordHash");
            });
  }

  @Test
  void loginIsCaseInsensitiveOnEmail() {
    Session registered = api.register();

    MvcTestResult login =
        api.postJson(
            "/api/v1/auth/login",
            """
            {"email": "%s", "password": "correct-horse-battery"}
            """
                .formatted(registered.email().toUpperCase()),
            null);

    assertThat(login)
        .hasStatusOk()
        .bodyJson()
        .extractingPath("$.user.id")
        .isEqualTo(registered.userId());
  }

  @Test
  void wrongPasswordIsRejectedWithGenericCode() {
    Session registered = api.register();

    assertThat(
            api.postJson(
                "/api/v1/auth/login",
                """
                {"email": "%s", "password": "not-the-password"}
                """
                    .formatted(registered.email()),
                null))
        .hasStatus(HttpStatus.UNAUTHORIZED)
        .bodyJson()
        .extractingPath("$.code")
        .isEqualTo("INVALID_CREDENTIALS");
  }

  @Test
  void duplicateEmailIsAConflict() {
    Session registered = api.register();

    assertThat(
            api.postJson(
                "/api/v1/auth/register",
                """
                {"name": "Copy", "email": "%s", "password": "another-password"}
                """
                    .formatted(registered.email()),
                null))
        .hasStatus(HttpStatus.CONFLICT)
        .bodyJson()
        .extractingPath("$.code")
        .isEqualTo("EMAIL_ALREADY_REGISTERED");
  }

  @Test
  void invalidRegistrationListsTheInvalidFields() {
    assertThat(
            api.postJson(
                "/api/v1/auth/register",
                """
                {"name": "", "email": "not-an-email", "password": "short"}
                """,
                null))
        .hasStatus(HttpStatus.BAD_REQUEST)
        .bodyJson()
        .satisfies(
            json -> {
              json.assertThat().extractingPath("$.code").isEqualTo("VALIDATION_FAILED");
              json.assertThat().extractingPath("$.errors.length()").isEqualTo(3);
            });
  }

  @Test
  void refreshRotatesTokensAndReuseEndsTheSession() {
    Session session = api.register();
    String refreshBody = "{\"refreshToken\": \"%s\"}";

    MvcTestResult first =
        api.postJson("/api/v1/auth/refresh", refreshBody.formatted(session.refreshToken()), null);
    assertThat(first).hasStatusOk();
    Session rotated = ApiClient.session(first, session.email());
    assertThat(rotated.refreshToken()).isNotEqualTo(session.refreshToken());

    // Replaying the old token looks like theft: it fails and revokes the rotated one too.
    assertThat(
            api.postJson(
                "/api/v1/auth/refresh", refreshBody.formatted(session.refreshToken()), null))
        .hasStatus(HttpStatus.UNAUTHORIZED)
        .bodyJson()
        .extractingPath("$.code")
        .isEqualTo("INVALID_REFRESH_TOKEN");
    assertThat(
            api.postJson(
                "/api/v1/auth/refresh", refreshBody.formatted(rotated.refreshToken()), null))
        .hasStatus(HttpStatus.UNAUTHORIZED);
  }

  @Test
  void refreshIgnoresAnExpiredAccessTokenInTheHeader() {
    Session session = api.register();

    assertThat(
            api.postJson(
                "/api/v1/auth/refresh",
                "{\"refreshToken\": \"%s\"}".formatted(session.refreshToken()),
                "Bearer not.a.valid-token"))
        .hasStatusOk();
  }

  @Test
  void logoutRevokesTheRefreshToken() {
    Session session = api.register();
    String body = "{\"refreshToken\": \"%s\"}".formatted(session.refreshToken());

    assertThat(api.postJson("/api/v1/auth/logout", body, null)).hasStatus(HttpStatus.NO_CONTENT);
    assertThat(api.postJson("/api/v1/auth/refresh", body, null)).hasStatus(HttpStatus.UNAUTHORIZED);
  }

  @Test
  void protectedEndpointsRejectMissingAndInvalidTokensWithProblemDetails() {
    assertThat(mvc.get().uri("/api/v1/users/me"))
        .hasStatus(HttpStatus.UNAUTHORIZED)
        .hasHeader(HttpHeaders.WWW_AUTHENTICATE, "Bearer")
        .bodyJson()
        .extractingPath("$.code")
        .isEqualTo("UNAUTHENTICATED");
    assertThat(
            mvc.get()
                .uri("/api/v1/users/me")
                .header(HttpHeaders.AUTHORIZATION, "Bearer forged.token.value"))
        .hasStatus(HttpStatus.UNAUTHORIZED)
        .bodyJson()
        .extractingPath("$.code")
        .isEqualTo("UNAUTHENTICATED");
  }
}
