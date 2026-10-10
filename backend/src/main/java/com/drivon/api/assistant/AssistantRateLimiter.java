package com.drivon.api.assistant;

import com.drivon.api.common.error.RateLimitedException;
import com.drivon.api.config.AssistantProperties;
import com.github.benmanes.caffeine.cache.Cache;
import com.github.benmanes.caffeine.cache.Caffeine;
import io.github.bucket4j.Bucket;
import io.github.bucket4j.ConsumptionProbe;
import java.time.Duration;
import java.util.UUID;
import org.springframework.stereotype.Component;

/**
 * Limits questions per user with an in-memory token bucket, so one user can't use up the AI
 * providers' free daily quotas. In-memory is enough for a single instance.
 */
@Component
class AssistantRateLimiter {

  private static final int MAX_TRACKED_USERS = 10_000;

  private final AssistantProperties.RateLimit limit;
  private final Cache<UUID, Bucket> buckets;

  AssistantRateLimiter(AssistantProperties properties) {
    this.limit = properties.rateLimit();
    this.buckets =
        Caffeine.newBuilder()
            .maximumSize(MAX_TRACKED_USERS)
            .expireAfterAccess(limit.refillPeriod().multipliedBy(2).plus(Duration.ofMinutes(1)))
            .build();
  }

  /** Takes one question from the user's allowance, or throws {@code RATE_LIMITED}. */
  void consume(UUID userId) {
    Bucket bucket = buckets.get(userId, key -> newBucket());
    ConsumptionProbe probe = bucket.tryConsumeAndReturnRemaining(1);
    if (!probe.isConsumed()) {
      throw new RateLimitedException(Duration.ofNanos(probe.getNanosToWaitForRefill()));
    }
  }

  private Bucket newBucket() {
    return Bucket.builder()
        .addLimit(
            bandwidth ->
                bandwidth
                    .capacity(limit.capacity())
                    .refillGreedy(limit.capacity(), limit.refillPeriod()))
        .build();
  }
}
