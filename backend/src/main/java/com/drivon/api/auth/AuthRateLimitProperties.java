package com.drivon.api.auth;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import java.time.Duration;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

/**
 * Auth endpoint limit ({@code drivon.security.auth-rate-limit.*}): each client IP may make {@code
 * capacity} attempts, refilled gradually over {@code refillPeriod}.
 */
@Validated
@ConfigurationProperties("drivon.security.auth-rate-limit")
public record AuthRateLimitProperties(@Positive int capacity, @NotNull Duration refillPeriod) {}
