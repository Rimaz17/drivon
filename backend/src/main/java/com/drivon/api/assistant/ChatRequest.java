package com.drivon.api.assistant;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.util.List;
import java.util.UUID;
import org.jspecify.annotations.Nullable;

/**
 * A question for Ask My Vehicle.
 *
 * @param vehicleId the vehicle selected in the app; questions that don't name one are about it
 * @param history the latest turns of this conversation, oldest first, so follow-up questions make
 *     sense; the server keeps no conversation state
 */
public record ChatRequest(
    @NotBlank @Size(max = 1000) String message,
    @Nullable UUID vehicleId,
    @Size(max = ChatRequest.MAX_HISTORY) @Nullable List<@Valid @NotNull Turn> history) {

  /** Enough context for follow-ups while keeping requests small for the free quotas. */
  public static final int MAX_HISTORY = 10;

  /** An earlier question or answer. */
  public record Turn(@NotNull Role role, @NotBlank @Size(max = 4000) String text) {}

  public enum Role {
    USER,
    ASSISTANT
  }
}
