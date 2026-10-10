package com.drivon.api.assistant.llm;

import java.util.List;

/** Everything a model needs for one step of a conversation. */
public record LlmRequest(String systemPrompt, List<LlmMessage> messages, List<ToolSpec> tools) {

  public LlmRequest {
    messages = List.copyOf(messages);
    tools = List.copyOf(tools);
  }
}
