package com.drivon.api.analytics;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;

import com.drivon.api.config.JacksonConfig;
import com.drivon.api.config.SecurityConfig;
import com.drivon.api.config.WebConfig;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpStatus;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.assertj.MockMvcTester;

@WebMvcTest(AnalyticsController.class)
@Import({SecurityConfig.class, WebConfig.class, JacksonConfig.class})
class AnalyticsControllerTest {

  private static final UUID USER = UUID.randomUUID();
  private static final UUID VEHICLE = UUID.randomUUID();
  private static final String PATH = "/api/v1/vehicles/" + VEHICLE + "/analytics";

  @Autowired private MockMvcTester mvc;
  @MockitoBean private AnalyticsService service;
  @MockitoBean private JwtDecoder jwtDecoder;

  @Test
  void costPerKmPassesTheDatesAndWritesDecimalsAsStrings() {
    LocalDate from = LocalDate.of(2026, 1, 1);
    LocalDate to = LocalDate.of(2026, 6, 30);
    when(service.costPerKm(USER, VEHICLE, from, to))
        .thenReturn(
            new CostPerKmResponse(
                from,
                to,
                1_000,
                new BigDecimal("32000.00"),
                new BigDecimal("32.00"),
                List.of(
                    new GroupCost(
                        CostGroup.FUEL, new BigDecimal("32000.00"), new BigDecimal("32.00")))));

    assertThat(
            mvc.get()
                .uri(PATH + "/cost-per-km?from=2026-01-01&to=2026-06-30")
                .with(jwt().jwt(token -> token.subject(USER.toString()))))
        .hasStatusOk()
        .bodyJson()
        .satisfies(
            json -> {
              json.assertThat().extractingPath("$.costPerKm").isEqualTo("32.00");
              json.assertThat().extractingPath("$.breakdown[0].group").isEqualTo("FUEL");
            });
  }

  @Test
  void monthlyCostsDefaultToSixMonthsAndAcceptUpToTwentyFour() {
    when(service.monthlyCosts(USER, VEHICLE, 6)).thenReturn(List.of());

    assertThat(
            mvc.get()
                .uri(PATH + "/monthly-costs")
                .with(jwt().jwt(token -> token.subject(USER.toString()))))
        .hasStatusOk();
    verify(service).monthlyCosts(USER, VEHICLE, 6);

    assertThat(
            mvc.get()
                .uri(PATH + "/monthly-costs?months=25")
                .with(jwt().jwt(token -> token.subject(USER.toString()))))
        .hasStatus(HttpStatus.BAD_REQUEST)
        .bodyJson()
        .extractingPath("$.code")
        .isEqualTo("VALIDATION_FAILED");
  }

  @Test
  void malformedDatesAreRejected() {
    assertThat(
            mvc.get()
                .uri(PATH + "/efficiency-trend?from=last-year")
                .with(jwt().jwt(token -> token.subject(USER.toString()))))
        .hasStatus(HttpStatus.BAD_REQUEST);
    verifyNoInteractions(service);
  }
}
