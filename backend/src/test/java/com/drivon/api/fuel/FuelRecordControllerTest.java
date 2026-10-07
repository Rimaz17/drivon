package com.drivon.api.fuel;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;

import com.drivon.api.common.web.CreateResult;
import com.drivon.api.config.JacksonConfig;
import com.drivon.api.config.SecurityConfig;
import com.drivon.api.config.WebConfig;
import java.math.BigDecimal;
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

@WebMvcTest(FuelRecordController.class)
@Import({SecurityConfig.class, WebConfig.class, JacksonConfig.class})
class FuelRecordControllerTest {

  private static final UUID USER = UUID.randomUUID();
  private static final UUID VEHICLE = UUID.randomUUID();
  private static final String PATH = "/api/v1/vehicles/" + VEHICLE + "/fuel-records";
  private static final String VALID_BODY =
      """
      {"date": "2026-10-07", "litres": "30.000", "amount": "10950.00",
       "odometerKm": 10450, "fullTank": true, "station": "Ceypetco"}
      """;

  @Autowired private MockMvcTester mvc;
  @MockitoBean private FuelService service;
  @MockitoBean private JwtDecoder jwtDecoder;

  private static FuelRecordResponse record(UUID id) {
    Instant now = Instant.parse("2026-10-07T04:30:00Z");
    return new FuelRecordResponse(
        id,
        VEHICLE,
        LocalDate.of(2026, 10, 7),
        new BigDecimal("30.000"),
        new BigDecimal("10950.00"),
        new BigDecimal("365.00"),
        10_450,
        true,
        "Ceypetco",
        new BigDecimal("15.00"),
        now,
        now);
  }

  @Test
  void createReturns201WithLocationAndDecimalsAsStrings() {
    UUID id = UUID.randomUUID();
    when(service.create(eq(USER), eq(VEHICLE), any()))
        .thenReturn(new CreateResult<>(record(id), true));

    assertThat(
            mvc.post()
                .uri(PATH)
                .with(jwt().jwt(token -> token.subject(USER.toString())))
                .contentType(MediaType.APPLICATION_JSON)
                .content(VALID_BODY))
        .hasStatus(HttpStatus.CREATED)
        .hasHeader(HttpHeaders.LOCATION, "http://localhost" + PATH + "/" + id)
        .bodyJson()
        .satisfies(
            json -> {
              json.assertThat().extractingPath("$.amount").isEqualTo("10950.00");
              json.assertThat().extractingPath("$.litres").isEqualTo("30.000");
              json.assertThat().extractingPath("$.kmPerLitre").isEqualTo("15.00");
            });
  }

  @Test
  void aRetryOfASavedRecordReturns200WithoutLocation() {
    UUID id = UUID.randomUUID();
    when(service.create(eq(USER), eq(VEHICLE), any()))
        .thenReturn(new CreateResult<>(record(id), false));

    assertThat(
            mvc.post()
                .uri(PATH)
                .with(jwt().jwt(token -> token.subject(USER.toString())))
                .contentType(MediaType.APPLICATION_JSON)
                .content(VALID_BODY))
        .hasStatusOk()
        .doesNotContainHeader(HttpHeaders.LOCATION);
  }

  @Test
  void invalidFillUpsAreRejectedBeforeReachingTheService() {
    assertThat(
            mvc.post()
                .uri(PATH)
                .with(jwt().jwt(token -> token.subject(USER.toString())))
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """
                    {"date": "2026-10-07", "litres": "0", "amount": "10950.123",
                     "pricePerLitre": "-1", "odometerKm": -5, "station": "%s"}
                    """
                        .formatted("x".repeat(101))))
        .hasStatus(HttpStatus.BAD_REQUEST)
        .bodyJson()
        .satisfies(
            json -> {
              json.assertThat().extractingPath("$.code").isEqualTo("VALIDATION_FAILED");
              // litres, amount, pricePerLitre, odometerKm, fullTank, station
              json.assertThat().extractingPath("$.errors.length()").isEqualTo(6);
            });
    verifyNoInteractions(service);
  }

  @Test
  void numbersAreAcceptedAsWellAsStrings() {
    when(service.create(eq(USER), eq(VEHICLE), any()))
        .thenReturn(new CreateResult<>(record(UUID.randomUUID()), true));

    assertThat(
            mvc.post()
                .uri(PATH)
                .with(jwt().jwt(token -> token.subject(USER.toString())))
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """
                    {"date": "2026-10-07", "litres": 30, "amount": 10950,
                     "odometerKm": 10450, "fullTank": true}
                    """))
        .hasStatus(HttpStatus.CREATED);
  }

  @Test
  void deleteReturns204() {
    UUID id = UUID.randomUUID();

    assertThat(
            mvc.delete()
                .uri(PATH + "/{id}", id)
                .with(jwt().jwt(token -> token.subject(USER.toString()))))
        .hasStatus(HttpStatus.NO_CONTENT);
    verify(service).delete(USER, VEHICLE, id);
  }

  @Test
  void requestsWithoutATokenAreRejected() {
    assertThat(mvc.get().uri(PATH)).hasStatus(HttpStatus.UNAUTHORIZED);
    verifyNoInteractions(service);
  }
}
