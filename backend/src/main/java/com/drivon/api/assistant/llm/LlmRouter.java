package com.drivon.api.assistant.llm;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Sends model calls to the primary provider and, when it fails (error, timeout, HTTP 429 or 5xx, an
 * unusable answer), retries once with the fallback. A conversation that failed over stays with the
 * fallback for its remaining calls, so one question isn't slowed down by repeated failures.
 */
public final class LlmRouter {

  private static final Logger log = LoggerFactory.getLogger(LlmRouter.class);

  private final LlmClient primary;
  private final LlmClient fallback;

  public LlmRouter(LlmClient primary, LlmClient fallback) {
    this.primary = primary;
    this.fallback = fallback;
  }

  /** True when at least one provider has an API key. */
  public boolean available() {
    return primary.configured() || fallback.configured();
  }

  /** Starts the model calls for one question. */
  public Conversation conversation() {
    return new Conversation();
  }

  /** The model calls of one question. Not thread-safe; use one per request. */
  public final class Conversation {

    private boolean primaryFailed;

    private Conversation() {}

    /**
     * The next model turn, from the primary provider or else the fallback.
     *
     * @throws LlmException when no configured provider produced an answer
     */
    public LlmMessage.Assistant complete(LlmRequest request) {
      if (primary.configured() && !primaryFailed) {
        try {
          return primary.complete(request);
        } catch (RuntimeException e) {
          primaryFailed = true;
          if (!fallback.configured()) {
            throw asLlmException(primary, e);
          }
          log.warn("{} failed ({}); trying {}", primary.name(), e.getMessage(), fallback.name());
        }
      }
      if (!fallback.configured()) {
        throw new LlmException("no AI provider is configured");
      }
      try {
        return fallback.complete(request);
      } catch (RuntimeException e) {
        throw asLlmException(fallback, e);
      }
    }

    private static LlmException asLlmException(LlmClient client, RuntimeException e) {
      return e instanceof LlmException llm
          ? llm
          : new LlmException(client.name() + " failed: " + e.getClass().getSimpleName(), e);
    }
  }
}
