package com.drivon.api.assistant.llm;

import java.util.List;
import org.jspecify.annotations.Nullable;
import tools.jackson.databind.JsonNode;

/**
 * One turn of a conversation with a language model, in a form every provider can translate. The
 * user ID is never part of a message: tools get it from the server, not from the model.
 */
public sealed interface LlmMessage {

  /** What the user asked. */
  record User(String text) implements LlmMessage {}

  /**
   * What the model answered: text, tool calls or both.
   *
   * @param providerContent the provider's own record of this turn, sent back unchanged to the same
   *     provider (Gemini needs its thought signatures returned with tool calls); other providers
   *     ignore it
   */
  record Assistant(String text, List<ToolCall> toolCalls, @Nullable JsonNode providerContent)
      implements LlmMessage {

    public Assistant {
      toolCalls = List.copyOf(toolCalls);
    }

    /** A plain text answer from an earlier exchange. */
    public static Assistant text(String text) {
      return new Assistant(text, List.of(), null);
    }
  }

  /**
   * The result of running one tool call.
   *
   * @param json the result as JSON, or {@code {"error": "..."}}
   */
  record ToolResult(String callId, String name, String json) implements LlmMessage {}
}
