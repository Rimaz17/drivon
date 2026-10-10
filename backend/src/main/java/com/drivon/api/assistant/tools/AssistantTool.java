package com.drivon.api.assistant.tools;

import com.drivon.api.assistant.llm.ToolSpec;

/**
 * A read-only lookup the model can ask for. The handler calls existing services, which check
 * ownership and hold the business rules; it only turns arguments into a service call.
 */
public record AssistantTool(ToolSpec spec, Handler handler) {

  /** Runs the lookup; returns any value that serializes to JSON. */
  @FunctionalInterface
  public interface Handler {
    Object run(ToolContext context, ToolArguments arguments);
  }
}
