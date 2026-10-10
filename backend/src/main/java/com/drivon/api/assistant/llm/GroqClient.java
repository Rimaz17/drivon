package com.drivon.api.assistant.llm;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import org.jspecify.annotations.Nullable;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestClientResponseException;
import tools.jackson.core.JacksonException;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;
import tools.jackson.databind.node.ArrayNode;
import tools.jackson.databind.node.ObjectNode;

/** Groq through its OpenAI-compatible chat completions API with {@code tools}. */
public final class GroqClient implements LlmClient {

  private final RestClient http;
  private final JsonMapper json;
  private final @Nullable String apiKey;
  private final String model;

  public GroqClient(
      RestClient.Builder http,
      JsonMapper json,
      String baseUrl,
      @Nullable String apiKey,
      String model) {
    this.http = http.baseUrl(baseUrl).build();
    this.json = json;
    this.apiKey = apiKey == null ? null : apiKey.strip();
    this.model = model;
  }

  @Override
  public String name() {
    return "groq";
  }

  @Override
  public boolean configured() {
    return apiKey != null && !apiKey.isEmpty();
  }

  @Override
  public LlmMessage.Assistant complete(LlmRequest request) {
    String body = json.writeValueAsString(requestBody(request));
    String response;
    try {
      response =
          http.post()
              .uri("/chat/completions")
              .header(HttpHeaders.AUTHORIZATION, "Bearer " + apiKey)
              .contentType(MediaType.APPLICATION_JSON)
              .accept(MediaType.APPLICATION_JSON)
              .body(body)
              .retrieve()
              .body(String.class);
    } catch (RestClientResponseException e) {
      throw new LlmException("groq answered HTTP " + e.getStatusCode().value(), e);
    } catch (RestClientException e) {
      throw new LlmException("groq unreachable or timed out", e);
    }
    return parse(response);
  }

  ObjectNode requestBody(LlmRequest request) {
    ObjectNode body = json.createObjectNode().put("model", model);
    ArrayNode messages = body.putArray("messages");
    messages.addObject().put("role", "system").put("content", request.systemPrompt());
    for (LlmMessage message : request.messages()) {
      if (message instanceof LlmMessage.User user) {
        messages.addObject().put("role", "user").put("content", user.text());
      } else if (message instanceof LlmMessage.Assistant assistant) {
        ObjectNode turn = messages.addObject().put("role", "assistant");
        if (assistant.toolCalls().isEmpty()) {
          turn.put("content", assistant.text());
        } else {
          if (assistant.text().isBlank()) {
            turn.putNull("content");
          } else {
            turn.put("content", assistant.text());
          }
          ArrayNode calls = turn.putArray("tool_calls");
          for (ToolCall call : assistant.toolCalls()) {
            calls
                .addObject()
                .put("id", call.id())
                .put("type", "function")
                .putObject("function")
                .put("name", call.name())
                .put("arguments", json.writeValueAsString(call.arguments()));
          }
        }
      } else if (message instanceof LlmMessage.ToolResult result) {
        messages
            .addObject()
            .put("role", "tool")
            .put("tool_call_id", result.callId())
            .put("content", result.json());
      }
    }
    if (!request.tools().isEmpty()) {
      ArrayNode tools = body.putArray("tools");
      for (ToolSpec tool : request.tools()) {
        tools
            .addObject()
            .put("type", "function")
            .putObject("function")
            .put("name", tool.name())
            .put("description", tool.description())
            .set("parameters", tool.parameters());
      }
      body.put("tool_choice", "auto");
    }
    body.put("temperature", 0.2);
    return body;
  }

  LlmMessage.Assistant parse(@Nullable String response) {
    JsonNode root = readJson(response == null ? "" : response);
    JsonNode message = root.path("choices").path(0).path("message");
    if (!message.isObject()) {
      throw new LlmException("groq returned no message");
    }
    String text = message.path("content").asString("");
    List<ToolCall> calls = new ArrayList<>();
    for (JsonNode call : message.path("tool_calls")) {
      JsonNode function = call.path("function");
      String id = call.path("id").asString("");
      calls.add(
          new ToolCall(
              id.isEmpty() ? ToolCall.GENERATED_ID_PREFIX + UUID.randomUUID() : id,
              function.path("name").asString(""),
              arguments(function.path("arguments").asString(""))));
    }
    if (text.isBlank() && calls.isEmpty()) {
      throw new LlmException("groq returned an empty answer");
    }
    return new LlmMessage.Assistant(text, calls, null);
  }

  /** Arguments arrive as a JSON string; anything unreadable becomes no arguments. */
  private JsonNode arguments(String raw) {
    try {
      JsonNode parsed = json.readTree(raw.isBlank() ? "{}" : raw);
      return parsed.isObject() ? parsed : json.createObjectNode();
    } catch (JacksonException e) {
      return json.createObjectNode();
    }
  }

  private JsonNode readJson(String text) {
    try {
      return json.readTree(text);
    } catch (JacksonException e) {
      throw new LlmException("groq: unreadable JSON", e);
    }
  }
}
