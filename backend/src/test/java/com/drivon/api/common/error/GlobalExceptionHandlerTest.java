package com.drivon.api.common.error;

import static org.assertj.core.api.Assertions.assertThat;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import java.time.Duration;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.assertj.MockMvcTester;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

class GlobalExceptionHandlerTest {

  private final MockMvcTester mvc =
      MockMvcTester.create(
          MockMvcBuilders.standaloneSetup(new ThrowingController())
              .setControllerAdvice(new GlobalExceptionHandler())
              .build());

  @Test
  void mapsDomainExceptionToProblemDetailWithStableCode() {
    assertThat(mvc.get().uri("/limit"))
        .hasStatus(HttpStatus.UNPROCESSABLE_CONTENT)
        .hasContentType(MediaType.APPLICATION_PROBLEM_JSON)
        .bodyJson()
        .satisfies(
            json -> {
              json.assertThat().extractingPath("$.code").isEqualTo("VEHICLE_LIMIT_REACHED");
              json.assertThat().extractingPath("$.title").isEqualTo("Vehicle limit reached");
              json.assertThat().extractingPath("$.detail").isEqualTo("Only two vehicles.");
            });
  }

  @Test
  void listsEveryInvalidFieldOnValidationFailure() {
    assertThat(mvc.post().uri("/validate").contentType(MediaType.APPLICATION_JSON).content("{}"))
        .hasStatus(HttpStatus.BAD_REQUEST)
        .bodyJson()
        .satisfies(
            json -> {
              json.assertThat().extractingPath("$.code").isEqualTo("VALIDATION_FAILED");
              json.assertThat().extractingPath("$.errors[0].field").isEqualTo("name");
            });
  }

  @Test
  void reportsUnreadableJsonAsMalformedRequest() {
    assertThat(mvc.post().uri("/validate").contentType(MediaType.APPLICATION_JSON).content("{oops"))
        .hasStatus(HttpStatus.BAD_REQUEST)
        .bodyJson()
        .extractingPath("$.code")
        .isEqualTo("MALFORMED_REQUEST");
  }

  @Test
  void addsRetryAfterWhenRateLimited() {
    assertThat(mvc.get().uri("/rate-limited"))
        .hasStatus(HttpStatus.TOO_MANY_REQUESTS)
        .hasHeader(HttpHeaders.RETRY_AFTER, "3");
  }

  @Test
  void challengesForBearerTokenOnUnauthorized() {
    assertThat(mvc.get().uri("/bad-credentials"))
        .hasStatus(HttpStatus.UNAUTHORIZED)
        .hasHeader(HttpHeaders.WWW_AUTHENTICATE, "Bearer");
  }

  @Test
  void hidesInternalDetailsOfUnexpectedErrors() {
    assertThat(mvc.get().uri("/boom"))
        .hasStatus(HttpStatus.INTERNAL_SERVER_ERROR)
        .bodyJson()
        .satisfies(
            json -> {
              json.assertThat().extractingPath("$.code").isEqualTo("INTERNAL_ERROR");
              json.assertThat().extractingPath("$.detail").asString().doesNotContain("secret");
            });
  }

  @RestController
  static class ThrowingController {

    record Body(@NotBlank String name) {}

    @GetMapping("/limit")
    void limit() {
      throw new DrivonException(ErrorCode.VEHICLE_LIMIT_REACHED, "Only two vehicles.");
    }

    @PostMapping("/validate")
    void validate(@Valid @RequestBody Body body) {}

    @GetMapping("/rate-limited")
    void rateLimited() {
      throw new RateLimitedException(Duration.ofMillis(2500));
    }

    @GetMapping("/bad-credentials")
    void badCredentials() {
      throw new DrivonException(ErrorCode.INVALID_CREDENTIALS);
    }

    @GetMapping("/boom")
    void boom() {
      throw new IllegalStateException("secret internal state");
    }
  }
}
