package com.drivon.api.maintenance;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;

import com.drivon.api.common.web.CreateResult;
import com.drivon.api.common.web.PageResponse;
import com.drivon.api.config.JacksonConfig;
import com.drivon.api.config.SecurityConfig;
import com.drivon.api.config.WebConfig;
import java.math.BigDecimal;
import java.time.Instant;
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

@WebMvcTest(MaintenanceRecordController.class)
@Import({SecurityConfig.class, WebConfig.class, JacksonConfig.class})
class MaintenanceRecordControllerTest {

  private static final UUID USER = UUID.randomUUID();
  private static final UUID VEHICLE = UUID.randomUUID();
  private static final String PATH = "/api/v1/vehicles/" + VEHICLE + "/maintenance-records";

  @Autowired private MockMvcTester mvc;
  @MockitoBean private MaintenanceService service;
  @MockitoBean private JwtDecoder jwtDecoder;

  private static MaintenanceRecordResponse record(UUID id) {
    Instant now = Instant.parse("2026-10-07T04:30:00Z");
    return new MaintenanceRecordResponse(
        id,
        VEHICLE,
        ServiceType.OIL_CHANGE,
        LocalDate.of(2026, 10, 7),
        46_500,
        new BigDecimal("9800.00"),
        null,
        LocalDate.of(2027, 4, 7),
        51_500,
        now,
        now);
  }

  @Test
  void createReturns201WithLocation() {
    UUID id = UUID.randomUUID();
    when(service.create(eq(USER), eq(VEHICLE), any()))
        .thenReturn(new CreateResult<>(record(id), true));

    assertThat(
            mvc.post()
                .uri(PATH)
                .with(jwt().jwt(token -> token.subject(USER.toString())))
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """
                    {"serviceType": "OIL_CHANGE", "date": "2026-10-07", "odometerKm": 46500,
                     "cost": "9800", "nextServiceDate": "2027-04-07", "nextServiceKm": 51500}
                    """))
        .hasStatus(HttpStatus.CREATED)
        .hasHeader(HttpHeaders.LOCATION, "http://localhost" + PATH + "/" + id)
        .bodyJson()
        .satisfies(
            json -> {
              json.assertThat().extractingPath("$.cost").isEqualTo("9800.00");
              json.assertThat().extractingPath("$.serviceType").isEqualTo("OIL_CHANGE");
            });
  }

  @Test
  void invalidServicesAreRejectedBeforeReachingTheService() {
    assertThat(
            mvc.post()
                .uri(PATH)
                .with(jwt().jwt(token -> token.subject(USER.toString())))
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """
                    {"date": "2026-10-07", "cost": "-1", "odometerKm": -5,
                     "nextServiceKm": 0, "notes": "%s"}
                    """
                        .formatted("x".repeat(501))))
        .hasStatus(HttpStatus.BAD_REQUEST)
        .bodyJson()
        .satisfies(
            json -> {
              json.assertThat().extractingPath("$.code").isEqualTo("VALIDATION_FAILED");
              // serviceType, cost, odometerKm, nextServiceKm, notes
              json.assertThat().extractingPath("$.errors.length()").isEqualTo(5);
            });
    verifyNoInteractions(service);
  }

  @Test
  void filtersByServiceTypeAndRejectsUnknownTypes() {
    when(service.list(eq(USER), eq(VEHICLE), eq(ServiceType.BRAKE_SERVICE), any()))
        .thenReturn(new PageResponse<>(List.of(), 0, 20, 0, 0, false));

    assertThat(
            mvc.get()
                .uri(PATH + "?serviceType=BRAKE_SERVICE")
                .with(jwt().jwt(token -> token.subject(USER.toString()))))
        .hasStatusOk();
    verify(service).list(eq(USER), eq(VEHICLE), eq(ServiceType.BRAKE_SERVICE), any());

    assertThat(
            mvc.get()
                .uri(PATH + "?serviceType=WASH")
                .with(jwt().jwt(token -> token.subject(USER.toString()))))
        .hasStatus(HttpStatus.BAD_REQUEST);
  }

  @Test
  void upcomingIsNotMistakenForARecordId() {
    when(service.upcoming(USER, VEHICLE)).thenReturn(List.of());

    assertThat(
            mvc.get()
                .uri(PATH + "/upcoming")
                .with(jwt().jwt(token -> token.subject(USER.toString()))))
        .hasStatusOk()
        .bodyJson()
        .extractingPath("$.length()")
        .isEqualTo(0);
  }
}
