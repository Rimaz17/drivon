package com.drivon.api.auth;

import com.drivon.api.common.error.RateLimitedException;
import com.github.benmanes.caffeine.cache.Cache;
import com.github.benmanes.caffeine.cache.Caffeine;
import io.github.bucket4j.Bucket;
import io.github.bucket4j.ConsumptionProbe;
import java.time.Duration;
import org.springframework.stereotype.Component;

/**
 * Slows down password guessing and account spam with an in-memory token bucket per client key (the
 * caller's IP). In-memory is enough for a single instance; idle buckets are evicted so memory stays
 * bounded.
 */
@Component
class AuthRateLimiter {

  private static final int MAX_TRACKED_CLIENTS = 10_000;

  private final AuthRateLimitProperties properties;
  private final Cache<String, Bucket> buckets;

  AuthRateLimiter(AuthRateLimitProperties properties) {
    this.properties = properties;
    this.buckets =
        Caffeine.newBuilder()
            .maximumSize(MAX_TRACKED_CLIENTS)
            .expireAfterAccess(
                properties.refillPeriod().multipliedBy(2).plus(Duration.ofMinutes(1)))
            .build();
  }

  /** Takes one attempt for the client, or throws if its limit is used up. */
  void consume(String clientKey) {
    Bucket bucket = buckets.get(clientKey, key -> newBucket());
    ConsumptionProbe probe = bucket.tryConsumeAndReturnRemaining(1);
    if (!probe.isConsumed()) {
      throw new RateLimitedException(Duration.ofNanos(probe.getNanosToWaitForRefill()));
    }
  }

  private Bucket newBucket() {
    return Bucket.builder()
        .addLimit(
            limit ->
                limit
                    .capacity(properties.capacity())
                    .refillGreedy(properties.capacity(), properties.refillPeriod()))
        .build();
  }
}
