package com.drivon.api.fuel;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;

import com.drivon.api.common.stats.MonthlyAmount;
import com.drivon.api.config.JacksonConfig;
import com.drivon.api.config.SecurityConfig;
import com.drivon.api.config.WebConfig;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.YearMonth;
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

@WebMvcTest(FuelStatsController.class)
@Import({SecurityConfig.class, WebConfig.class, JacksonConfig.class})
class FuelStatsControllerTest {

  private static final UUID USER = UUID.randomUUID();
  private static final UUID VEHICLE = UUID.randomUUID();
  private static final String PATH = "/api/v1/vehicles/" + VEHICLE + "/fuel-stats";

  @Autowired private MockMvcTester mvc;
  @MockitoBean private FuelService service;
  @MockitoBean private JwtDecoder jwtDecoder;

  @Test
  void passesTheIsoDateRangeToTheService() {
    LocalDate from = LocalDate.of(2026, 9, 1);
    LocalDate to = LocalDate.of(2026, 9, 30);
    when(service.stats(USER, VEHICLE, from, to))
        .thenReturn(
            new FuelStatsResponse(
                from,
                to,
                new BigDecimal("18500.00"),
                new BigDecimal("50.000"),
                2,
                null,
                null,
                null,
                null,
                0));

    assertThat(
            mvc.get()
                .uri(PATH + "?from=2026-09-01&to=2026-09-30")
                .with(jwt().jwt(token -> token.subject(USER.toString()))))
        .hasStatusOk()
        .bodyJson()
        .satisfies(
            json -> {
              json.assertThat().extractingPath("$.totalSpend").isEqualTo("18500.00");
              json.assertThat().extractingPath("$.averageKmPerLitre").isNull();
            });
  }

  @Test
  void monthlyDefaultsToSixMonthsAndWritesMonthsAsYearMonth() {
    when(service.monthlySpend(USER, VEHICLE, 6))
        .thenReturn(List.of(new MonthlyAmount(YearMonth.of(2026, 10), new BigDecimal("1.50"))));

    assertThat(
            mvc.get()
                .uri(PATH + "/monthly")
                .with(jwt().jwt(token -> token.subject(USER.toString()))))
        .hasStatusOk()
        .bodyJson()
        .satisfies(
            json -> {
              json.assertThat().extractingPath("$[0].month").isEqualTo("2026-10");
              json.assertThat().extractingPath("$[0].total").isEqualTo("1.50");
            });
    verify(service).monthlySpend(USER, VEHICLE, 6);
  }

  @Test
  void rejectsBadParametersBeforeReachingTheService() {
    assertThat(
            mvc.get()
                .uri(PATH + "/monthly?months=25")
                .with(jwt().jwt(token -> token.subject(USER.toString()))))
        .hasStatus(HttpStatus.BAD_REQUEST)
        .bodyJson()
        .extractingPath("$.code")
        .isEqualTo("VALIDATION_FAILED");
    assertThat(
            mvc.get()
                .uri(PATH + "?from=yesterday")
                .with(jwt().jwt(token -> token.subject(USER.toString()))))
        .hasStatus(HttpStatus.BAD_REQUEST);
    verifyNoInteractions(service);
  }
}
