package com.drivon.api.vehicle;

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
import java.time.LocalDate;
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

@WebMvcTest(OdometerController.class)
@Import({SecurityConfig.class, WebConfig.class})
class OdometerControllerTest {

  private static final UUID USER = UUID.randomUUID();
  private static final UUID VEHICLE = UUID.randomUUID();
  private static final String PATH = "/api/v1/vehicles/" + VEHICLE + "/odometer-readings";

  @Autowired private MockMvcTester mvc;
  @MockitoBean private OdometerService service;
  @MockitoBean private JwtDecoder jwtDecoder;

  @Test
  void addReturns201WithLocation() {
    UUID id = UUID.randomUUID();
    when(service.add(eq(USER), eq(VEHICLE), any()))
        .thenReturn(
            new OdometerReadingResponse(
                id,
                46_000,
                LocalDate.of(2026, 10, 7),
                OdometerSource.MANUAL,
                null,
                Instant.parse("2026-10-07T04:30:00Z")));

    assertThat(
            mvc.post()
                .uri(PATH)
                .with(jwt().jwt(token -> token.subject(USER.toString())))
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"readingKm\": 46000, \"date\": \"2026-10-07\"}"))
        .hasStatus(HttpStatus.CREATED)
        .hasHeader(HttpHeaders.LOCATION, "http://localhost" + PATH + "/" + id)
        .bodyJson()
        .extractingPath("$.source")
        .isEqualTo("MANUAL");
  }

  @Test
  void invalidReadingsAreRejectedBeforeReachingTheService() {
    assertThat(
            mvc.post()
                .uri(PATH)
                .with(jwt().jwt(token -> token.subject(USER.toString())))
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"readingKm\": -1}"))
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
  void outOfOrderReadingsReportTheAllowedRange() {
    when(service.add(eq(USER), eq(VEHICLE), any()))
        .thenThrow(
            new DrivonException(ErrorCode.ODOMETER_OUT_OF_ORDER, "Too low.")
                .with("minKm", 45_000)
                .with("maxKm", 47_000));

    assertThat(
            mvc.post()
                .uri(PATH)
                .with(jwt().jwt(token -> token.subject(USER.toString())))
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"readingKm\": 1, \"date\": \"2026-10-07\"}"))
        .hasStatus(HttpStatus.UNPROCESSABLE_CONTENT)
        .bodyJson()
        .satisfies(
            json -> {
              json.assertThat().extractingPath("$.minKm").isEqualTo(45_000);
              json.assertThat().extractingPath("$.maxKm").isEqualTo(47_000);
            });
  }
}
