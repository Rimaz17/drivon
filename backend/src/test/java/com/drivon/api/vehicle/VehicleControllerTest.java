package com.drivon.api.vehicle;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
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
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.assertj.MockMvcTester;

@WebMvcTest(VehicleController.class)
@Import({SecurityConfig.class, WebConfig.class})
class VehicleControllerTest {

  private static final UUID USER = UUID.randomUUID();
  private static final String VALID_BODY =
      """
      {"make": "Toyota", "model": "Aqua", "year": 2018, "registrationNumber": "CAB-1234",
       "fuelType": "HYBRID", "currentOdometerKm": 45000}
      """;

  @Autowired private MockMvcTester mvc;
  @MockitoBean private VehicleService service;
  @MockitoBean private JwtDecoder jwtDecoder;

  private static VehicleResponse vehicle(UUID id) {
    Instant now = Instant.parse("2026-10-07T10:00:00Z");
    return new VehicleResponse(
        id, "Toyota", "Aqua", 2018, "CAB-1234", FuelType.HYBRID, 45_000, now, now);
  }

  @Test
  void createReturns201WithLocationAndUsesTheTokenSubjectAsOwner() {
    UUID id = UUID.randomUUID();
    when(service.create(eq(USER), any())).thenReturn(vehicle(id));

    assertThat(
            mvc.post()
                .uri("/api/v1/vehicles")
                .with(jwt().jwt(token -> token.subject(USER.toString())))
                .contentType(MediaType.APPLICATION_JSON)
                .content(VALID_BODY))
        .hasStatus(HttpStatus.CREATED)
        .hasHeader(HttpHeaders.LOCATION, "http://localhost/api/v1/vehicles/" + id)
        .bodyJson()
        .extractingPath("$.registrationNumber")
        .isEqualTo("CAB-1234");
    verify(service).create(eq(USER), any());
  }

  @Test
  void invalidBodyIsRejectedBeforeReachingTheService() {
    assertThat(
            mvc.post()
                .uri("/api/v1/vehicles")
                .with(jwt().jwt(token -> token.subject(USER.toString())))
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """
                    {"make": "", "model": "Aqua", "year": 1800, "registrationNumber": "CAB/1234",
                     "fuelType": "HYBRID", "currentOdometerKm": -5}
                    """))
        .hasStatus(HttpStatus.BAD_REQUEST)
        .bodyJson()
        .satisfies(
            json -> {
              json.assertThat().extractingPath("$.code").isEqualTo("VALIDATION_FAILED");
              json.assertThat().extractingPath("$.errors.length()").isEqualTo(4);
            });
    verifyNoInteractions(service);
  }

  @Test
  void unknownFuelTypeIsAMalformedRequest() {
    assertThat(
            mvc.post()
                .uri("/api/v1/vehicles")
                .with(jwt().jwt(token -> token.subject(USER.toString())))
                .contentType(MediaType.APPLICATION_JSON)
                .content(VALID_BODY.replace("HYBRID", "STEAM")))
        .hasStatus(HttpStatus.BAD_REQUEST)
        .bodyJson()
        .extractingPath("$.code")
        .isEqualTo("MALFORMED_REQUEST");
  }

  @Test
  void businessRuleViolationsAre422WithTheirCode() {
    when(service.create(eq(USER), any()))
        .thenThrow(new DrivonException(ErrorCode.VEHICLE_LIMIT_REACHED));

    assertThat(
            mvc.post()
                .uri("/api/v1/vehicles")
                .with(jwt().jwt(token -> token.subject(USER.toString())))
                .contentType(MediaType.APPLICATION_JSON)
                .content(VALID_BODY))
        .hasStatus(HttpStatus.UNPROCESSABLE_CONTENT)
        .bodyJson()
        .extractingPath("$.code")
        .isEqualTo("VEHICLE_LIMIT_REACHED");
  }

  @Test
  void deleteReturns204() {
    UUID id = UUID.randomUUID();

    assertThat(
            mvc.delete()
                .uri("/api/v1/vehicles/{id}", id)
                .with(jwt().jwt(token -> token.subject(USER.toString()))))
        .hasStatus(HttpStatus.NO_CONTENT);
    verify(service).delete(USER, id);
  }

  @Test
  void malformedVehicleIdIsABadRequest() {
    assertThat(
            mvc.get()
                .uri("/api/v1/vehicles/not-a-uuid")
                .with(jwt().jwt(token -> token.subject(USER.toString()))))
        .hasStatus(HttpStatus.BAD_REQUEST);
  }

  @Test
  void requestsWithoutATokenAreRejected() {
    assertThat(mvc.get().uri("/api/v1/vehicles")).hasStatus(HttpStatus.UNAUTHORIZED);
    verifyNoInteractions(service);
  }
}
