package com.drivon.api.support;

import com.drivon.api.assistant.llm.LlmClient;
import com.drivon.api.assistant.llm.LlmException;
import com.drivon.api.assistant.llm.LlmMessage;
import com.drivon.api.assistant.llm.LlmRequest;
import com.drivon.api.assistant.llm.ToolCall;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.function.Function;
import tools.jackson.databind.json.JsonMapper;

/**
 * A model that plays back scripted turns, so tests never call a real AI provider. Each call takes
 * the next step; running out of steps is a failure.
 */
public final class ScriptedLlmClient implements LlmClient {

  private static final JsonMapper JSON = JsonMapper.builder().build();

  private final String name;
  private final Deque<Function<LlmRequest, LlmMessage.Assistant>> steps = new ArrayDeque<>();
  private final List<LlmRequest> requests = new CopyOnWriteArrayList<>();
  private boolean configured = true;

  public ScriptedLlmClient(String name) {
    this.name = name;
  }

  public ScriptedLlmClient then(Function<LlmRequest, LlmMessage.Assistant> step) {
    steps.add(step);
    return this;
  }

  public ScriptedLlmClient thenAnswer(String text) {
    return then(request -> LlmMessage.Assistant.text(text));
  }

  /** A turn that calls one tool with arguments given as JSON. */
  public ScriptedLlmClient thenCall(String tool, String argumentsJson) {
    return then(
        request ->
            new LlmMessage.Assistant(
                "",
                List.of(
                    new ToolCall("call-" + (requests.size()), tool, JSON.readTree(argumentsJson))),
                null));
  }

  public ScriptedLlmClient thenFail(String message) {
    return then(
        request -> {
          throw new LlmException(message);
        });
  }

  public ScriptedLlmClient configured(boolean configured) {
    this.configured = configured;
    return this;
  }

  /** Every request received, oldest first. */
  public List<LlmRequest> requests() {
    return requests;
  }

  public void reset() {
    steps.clear();
    requests.clear();
    configured = true;
  }

  @Override
  public String name() {
    return name;
  }

  @Override
  public boolean configured() {
    return configured;
  }

  @Override
  public LlmMessage.Assistant complete(LlmRequest request) {
    requests.add(request);
    Function<LlmRequest, LlmMessage.Assistant> step = steps.poll();
    if (step == null) {
      throw new LlmException(name + ": script ended");
    }
    return step.apply(request);
  }
}
