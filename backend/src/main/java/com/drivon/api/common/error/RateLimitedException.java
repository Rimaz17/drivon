package com.drivon.api.common.error;

import java.time.Duration;

/** Rejects a request that exceeded a rate limit; the handler adds a {@code Retry-After} header. */
public class RateLimitedException extends DrivonException {

  private final Duration retryAfter;

  public RateLimitedException(Duration retryAfter) {
    super(ErrorCode.RATE_LIMITED, "Too many attempts. Try again later.");
    this.retryAfter = retryAfter;
  }

  /** Whole seconds until a retry can succeed, never less than one. */
  public long retryAfterSeconds() {
    return Math.max(1, (retryAfter.toMillis() + 999) / 1000);
  }
}
