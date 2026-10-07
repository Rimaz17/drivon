package com.drivon.api.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.drivon.api.common.error.RateLimitedException;
import java.time.Duration;
import org.junit.jupiter.api.Test;

class AuthRateLimiterTest {

  // A long refill period keeps the test deterministic: no token comes back mid-test.
  private final AuthRateLimiter limiter =
      new AuthRateLimiter(new AuthRateLimitProperties(3, Duration.ofHours(1)));

  @Test
  void allowsAttemptsUpToCapacity() {
    assertThatCode(
            () -> {
              limiter.consume("10.0.0.1");
              limiter.consume("10.0.0.1");
              limiter.consume("10.0.0.1");
            })
        .doesNotThrowAnyException();
  }

  @Test
  void rejectsAttemptsBeyondCapacityWithRetryHint() {
    for (int i = 0; i < 3; i++) {
      limiter.consume("10.0.0.2");
    }

    assertThatThrownBy(() -> limiter.consume("10.0.0.2"))
        .isInstanceOfSatisfying(
            RateLimitedException.class, e -> assertThat(e.retryAfterSeconds()).isPositive());
  }

  @Test
  void limitsEachClientSeparately() {
    for (int i = 0; i < 3; i++) {
      limiter.consume("10.0.0.3");
    }

    assertThatCode(() -> limiter.consume("10.0.0.4")).doesNotThrowAnyException();
  }
}
