package com.drivon.api.auth;

import static org.assertj.core.api.Assertions.assertThat;

import com.drivon.api.support.ApiClient;
import com.drivon.api.support.ApiClient.Session;
import com.drivon.api.support.IntegrationTest;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.assertj.MockMvcTester;

/** Changing and deleting an account, as the app does it. */
@IntegrationTest
class AccountIntegrationTest {

  private static final String PASSWORD = "correct-horse-battery";

  @Autowired private MockMvcTester mvc;
  @Autowired private JdbcTemplate jdbc;
  private ApiClient api;

  @BeforeEach
  void setUp() {
    api = new ApiClient(mvc);
  }

  private static String login(String email, String password) {
    return """
        {"email": "%s", "password": "%s"}
        """
        .formatted(email, password);
  }

  private static String deletion(String password) {
    return """
        {"password": "%s"}
        """
        .formatted(password);
  }

  @Test
  void theNewEmailIsUsedToSignInAfterAProfileChange() {
    Session session = api.register();
    String newEmail = ApiClient.uniqueEmail();

    assertThat(
            api.putJson(
                "/api/v1/users/me",
                """
                {"name": " Rimaz Saththar ", "email": "%s"}
                """
                    .formatted(newEmail.toUpperCase()),
                session.bearer()))
        .hasStatusOk()
        .bodyJson()
        .satisfies(
            json -> {
              json.assertThat().extractingPath("$.name").isEqualTo("Rimaz Saththar");
              json.assertThat().extractingPath("$.email").isEqualTo(newEmail);
            });

    assertThat(api.postJson("/api/v1/auth/login", login(newEmail, PASSWORD), null)).hasStatusOk();
    assertThat(api.postJson("/api/v1/auth/login", login(session.email(), PASSWORD), null))
        .hasStatus(HttpStatus.UNAUTHORIZED);
  }

  @Test
  void anotherAccountsEmailIsAConflict() {
    Session session = api.register();
    Session other = api.register();

    assertThat(
            api.putJson(
                "/api/v1/users/me",
                """
                {"name": "Test Driver", "email": "%s"}
                """
                    .formatted(other.email()),
                session.bearer()))
        .hasStatus(HttpStatus.CONFLICT)
        .bodyJson()
        .extractingPath("$.code")
        .isEqualTo("EMAIL_ALREADY_REGISTERED");
  }

  @Test
  void aWrongPasswordKeepsTheAccount() {
    Session session = api.register();

    assertThat(
            api.postJson(
                "/api/v1/users/me/deletion", deletion("not-the-password"), session.bearer()))
        .hasStatus(HttpStatus.UNPROCESSABLE_CONTENT)
        .bodyJson()
        .extractingPath("$.code")
        .isEqualTo("PASSWORD_INCORRECT");

    assertThat(api.get("/api/v1/users/me", session.bearer())).hasStatusOk();
  }

  @Test
  void deletingTheAccountRemovesItsDataAndEndsItsSessions() {
    Session session = api.register();
    String vehicleId = api.createVehicle(session, "CAB-3001", 46_000);
    Session other = api.register();
    String otherVehicleId = api.createVehicle(other, "CAB-3001", 12_000);

    assertThat(api.postJson("/api/v1/users/me/deletion", deletion(PASSWORD), session.bearer()))
        .hasStatus(HttpStatus.NO_CONTENT);

    UUID userId = UUID.fromString(session.userId());
    assertThat(count("select count(*) from users where id = ?", userId)).isZero();
    assertThat(count("select count(*) from vehicles where user_id = ?", userId)).isZero();
    assertThat(
            count(
                "select count(*) from odometer_readings where vehicle_id = ?",
                UUID.fromString(vehicleId)))
        .isZero();
    assertThat(count("select count(*) from refresh_tokens where user_id = ?", userId)).isZero();
    assertThat(api.get("/api/v1/users/me", session.bearer())).hasStatus(HttpStatus.UNAUTHORIZED);
    assertThat(
            api.postJson(
                "/api/v1/auth/refresh",
                """
                {"refreshToken": "%s"}
                """
                    .formatted(session.refreshToken()),
                null))
        .hasStatus(HttpStatus.UNAUTHORIZED);
    assertThat(api.postJson("/api/v1/auth/login", login(session.email(), PASSWORD), null))
        .hasStatus(HttpStatus.UNAUTHORIZED);

    assertThat(api.get("/api/v1/vehicles/" + otherVehicleId, other.bearer())).hasStatusOk();
  }

  private long count(String sql, UUID id) {
    Long count = jdbc.queryForObject(sql, Long.class, id);
    return count == null ? 0 : count;
  }
}
