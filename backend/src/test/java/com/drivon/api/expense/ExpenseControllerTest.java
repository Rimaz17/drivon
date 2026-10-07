package com.drivon.api.expense;

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

@WebMvcTest(ExpenseController.class)
@Import({SecurityConfig.class, WebConfig.class, JacksonConfig.class})
class ExpenseControllerTest {

  private static final UUID USER = UUID.randomUUID();
  private static final UUID VEHICLE = UUID.randomUUID();
  private static final String PATH = "/api/v1/vehicles/" + VEHICLE + "/expenses";

  @Autowired private MockMvcTester mvc;
  @MockitoBean private ExpenseService service;
  @MockitoBean private JwtDecoder jwtDecoder;

  @Test
  void createReturns201WithLocation() {
    UUID id = UUID.randomUUID();
    Instant now = Instant.parse("2026-10-07T04:30:00Z");
    when(service.create(eq(USER), eq(VEHICLE), any()))
        .thenReturn(
            new CreateResult<>(
                new ExpenseResponse(
                    id,
                    VEHICLE,
                    ExpenseCategory.INSURANCE,
                    new BigDecimal("45000.00"),
                    LocalDate.of(2026, 10, 7),
                    null,
                    now,
                    now),
                true));

    assertThat(
            mvc.post()
                .uri(PATH)
                .with(jwt().jwt(token -> token.subject(USER.toString())))
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """
                    {"category": "INSURANCE", "amount": "45000", "date": "2026-10-07"}
                    """))
        .hasStatus(HttpStatus.CREATED)
        .hasHeader(HttpHeaders.LOCATION, "http://localhost" + PATH + "/" + id)
        .bodyJson()
        .extractingPath("$.amount")
        .isEqualTo("45000.00");
  }

  @Test
  void invalidExpensesAreRejectedBeforeReachingTheService() {
    assertThat(
            mvc.post()
                .uri(PATH)
                .with(jwt().jwt(token -> token.subject(USER.toString())))
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"amount\": \"0\"}"))
        .hasStatus(HttpStatus.BAD_REQUEST)
        .bodyJson()
        .satisfies(
            json -> {
              json.assertThat().extractingPath("$.code").isEqualTo("VALIDATION_FAILED");
              // amount, category, date
              json.assertThat().extractingPath("$.errors.length()").isEqualTo(3);
            });
    assertThat(
            mvc.post()
                .uri(PATH)
                .with(jwt().jwt(token -> token.subject(USER.toString())))
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """
                    {"category": "LUNCH", "amount": "10", "date": "2026-10-07"}
                    """))
        .hasStatus(HttpStatus.BAD_REQUEST)
        .bodyJson()
        .extractingPath("$.code")
        .isEqualTo("MALFORMED_REQUEST");
    verifyNoInteractions(service);
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
}
