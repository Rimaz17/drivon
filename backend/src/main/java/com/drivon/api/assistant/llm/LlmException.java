package com.drivon.api.assistant.llm;

/**
 * A model call that didn't produce a usable answer: network error, timeout, rate limit (HTTP 429),
 * server error, a rejected request or an empty reply. The message is for logs only and never
 * contains the API key or the user's data.
 */
public class LlmException extends RuntimeException {

  public LlmException(String message) {
    super(message);
  }

  public LlmException(String message, Throwable cause) {
    super(message, cause);
  }
}
