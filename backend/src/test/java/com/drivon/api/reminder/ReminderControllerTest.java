package com.drivon.api.reminder;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;

import com.drivon.api.common.error.DrivonException;
import com.drivon.api.common.error.ErrorCode;
import com.drivon.api.common.web.CreateResult;
import com.drivon.api.config.JacksonConfig;
import com.drivon.api.config.SecurityConfig;
import com.drivon.api.config.WebConfig;
import com.drivon.api.maintenance.ServiceType;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.assertj.MockMvcTester;

@WebMvcTest(ReminderController.class)
@Import({SecurityConfig.class, WebConfig.class, JacksonConfig.class})
class ReminderControllerTest {

  private static final UUID USER = UUID.randomUUID();
  private static final UUID VEHICLE = UUID.randomUUID();
  private static final String PATH = "/api/v1/vehicles/" + VEHICLE + "/reminders";

  @Autowired private MockMvcTester mvc;
  @MockitoBean private ReminderService service;
  @MockitoBean private JwtDecoder jwtDecoder;

  private static ReminderResponse manual(UUID id) {
    return new ReminderResponse(
        id,
        VEHICLE,
        ReminderSource.MANUAL,
        null,
        null,
        null,
        "Emission test",
        LocalDate.of(2026, 10, 15),
        null,
        LocalDate.of(2026, 10, 8),
        5L,
        null,
        ReminderStatus.DUE_SOON);
  }

  @Test
  void listsAVehiclesReminders() {
    ReminderResponse service =
        new ReminderResponse(
            UUID.randomUUID(),
            VEHICLE,
            ReminderSource.SERVICE,
            ServiceType.OIL_CHANGE,
            null,
            UUID.randomUUID(),
            null,
            null,
            50_000,
            null,
            null,
            -200,
            ReminderStatus.OVERDUE);
    when(this.service.list(USER, VEHICLE, null)).thenReturn(List.of(service));

    assertThat(mvc.get().uri(PATH).with(jwt().jwt(t -> t.subject(USER.toString()))))
        .hasStatusOk()
        .bodyJson()
        .isLenientlyEqualTo(
            """
            [{"source": "SERVICE", "serviceType": "OIL_CHANGE", "dueKm": 50000,
              "kmRemaining": -200, "status": "OVERDUE", "dueDate": null, "title": null}]
            """);
  }

  @Test
  void filtersAllRemindersByStatus() {
    when(service.list(USER, null, ReminderStatus.OVERDUE)).thenReturn(List.of());

    assertThat(
            mvc.get()
                .uri("/api/v1/reminders?status=OVERDUE")
                .with(jwt().jwt(t -> t.subject(USER.toString()))))
        .hasStatusOk();
    verify(service).list(USER, null, ReminderStatus.OVERDUE);
  }

  @Test
  void anUnknownStatusIsABadRequest() {
    assertThat(
            mvc.get()
                .uri("/api/v1/reminders?status=SOMEDAY")
                .with(jwt().jwt(t -> t.subject(USER.toString()))))
        .hasStatus(HttpStatus.BAD_REQUEST);
  }

  @Test
  void addingAReminderReturns201WithItsLocation() {
    UUID id = UUID.randomUUID();
    when(service.create(eq(USER), eq(VEHICLE), any()))
        .thenReturn(new CreateResult<>(manual(id), true));

    assertThat(
            mvc.post()
                .uri(PATH)
                .with(jwt().jwt(t -> t.subject(USER.toString())))
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """
                    {"id": "%s", "title": "Emission test", "dueDate": "2026-10-15"}
                    """
                        .formatted(id)))
        .hasStatus(HttpStatus.CREATED)
        .hasHeader(HttpHeaders.LOCATION, "http://localhost" + PATH + "/" + id);
  }

  @Test
  void aBlankTitleIsAValidationError() {
    assertThat(
            mvc.post()
                .uri(PATH)
                .with(jwt().jwt(t -> t.subject(USER.toString())))
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """
                    {"title": "  ", "dueKm": 0}
                    """))
        .hasStatus(HttpStatus.BAD_REQUEST)
        .bodyJson()
        .isLenientlyEqualTo(
            """
            {"code": "VALIDATION_FAILED",
             "errors": [{"field": "dueKm"}, {"field": "title"}]}
            """);
    verifyNoInteractions(service);
  }

  @Test
  void businessRulesAre422WithTheirCode() {
    when(service.update(eq(USER), eq(VEHICLE), any(), any()))
        .thenThrow(new DrivonException(ErrorCode.REMINDER_READ_ONLY, "Change the document."));

    assertThat(
            mvc.put()
                .uri(PATH + "/" + UUID.randomUUID())
                .with(jwt().jwt(t -> t.subject(USER.toString())))
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"title\": \"Insurance\", \"dueDate\": \"2026-12-01\"}"))
        .hasStatus(HttpStatus.UNPROCESSABLE_CONTENT)
        .bodyJson()
        .extractingPath("$.code")
        .isEqualTo("REMINDER_READ_ONLY");
  }

  @Test
  void deletingReturns204() {
    UUID id = UUID.randomUUID();

    assertThat(mvc.delete().uri(PATH + "/" + id).with(jwt().jwt(t -> t.subject(USER.toString()))))
        .hasStatus(HttpStatus.NO_CONTENT);
    verify(service).delete(USER, VEHICLE, id);
  }

  @Test
  void needsSigningIn() {
    assertThat(mvc.get().uri(PATH)).hasStatus(HttpStatus.UNAUTHORIZED);
    verifyNoInteractions(service);
  }
}
