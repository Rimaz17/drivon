package com.drivon.api.assistant.llm;

/**
 * A language model that can call tools. Implemented for Google Gemini and Groq; which one is
 * primary is configured (see docs/adr/0014-ask-my-vehicle.md).
 */
public interface LlmClient {

  /** Short name for logs, e.g. {@code gemini}. */
  String name();

  /** False when no API key is set; {@link #complete} must not be called then. */
  boolean configured();

  /**
   * Asks the model for its next turn: a text answer, tool calls, or both.
   *
   * @throws LlmException when the provider fails, times out, rate-limits or answers with nothing
   *     usable
   */
  LlmMessage.Assistant complete(LlmRequest request);
}
