package com.drivon.api.config;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import java.time.Duration;
import org.jspecify.annotations.Nullable;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

/**
 * Ask My Vehicle settings ({@code drivon.assistant.*}). Keys come from the environment ({@code
 * GEMINI_API_KEY}, {@code GROQ_API_KEY}); without either, the assistant answers {@code
 * ASSISTANT_UNAVAILABLE} and the rest of the API works.
 *
 * @param primary the provider asked first; the other one takes over when it fails
 * @param callTimeout how long one model call may take
 * @param totalTimeout how long answering one question may take, tool calls included
 * @param maxToolRounds how many rounds of tool calls one question may use
 * @param rateLimit questions per user, to stay inside the providers' free quotas
 */
@Validated
@ConfigurationProperties("drivon.assistant")
public record AssistantProperties(
    @NotNull Provider primary,
    @NotNull @Valid ProviderSettings gemini,
    @NotNull @Valid ProviderSettings groq,
    @NotNull Duration callTimeout,
    @NotNull Duration totalTimeout,
    @Min(1) @Max(10) int maxToolRounds,
    @NotNull @Valid RateLimit rateLimit) {

  public enum Provider {
    GEMINI,
    GROQ
  }

  /**
   * @param apiKey optional; the provider is skipped without one
   * @param baseUrl e.g. {@code https://generativelanguage.googleapis.com/v1beta}
   */
  public record ProviderSettings(
      @Nullable String apiKey, @NotBlank String model, @NotBlank String baseUrl) {}

  /** Each user may ask {@code capacity} questions, refilled gradually over {@code refillPeriod}. */
  public record RateLimit(@Positive int capacity, @NotNull Duration refillPeriod) {}
}
