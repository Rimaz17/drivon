package com.drivon.api.assistant.llm;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.UUID;
import org.jspecify.annotations.Nullable;
import org.springframework.http.MediaType;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestClientResponseException;
import tools.jackson.core.JacksonException;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;
import tools.jackson.databind.node.ArrayNode;
import tools.jackson.databind.node.ObjectNode;

/**
 * Google Gemini through the {@code generateContent} REST method with function declarations. The API
 * key goes in the {@code x-goog-api-key} header, never in the URL, so it can't end up in logs.
 */
public final class GeminiClient implements LlmClient {

  private final RestClient http;
  private final JsonMapper json;
  private final @Nullable String apiKey;
  private final String model;

  public GeminiClient(
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
    return "gemini";
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
              .uri("/models/{model}:generateContent", model)
              .header("x-goog-api-key", apiKey)
              .contentType(MediaType.APPLICATION_JSON)
              .accept(MediaType.APPLICATION_JSON)
              .body(body)
              .retrieve()
              .body(String.class);
    } catch (RestClientResponseException e) {
      throw new LlmException("gemini answered HTTP " + e.getStatusCode().value(), e);
    } catch (RestClientException e) {
      throw new LlmException("gemini unreachable or timed out", e);
    }
    return parse(response);
  }

  ObjectNode requestBody(LlmRequest request) {
    ObjectNode body = json.createObjectNode();
    body.putObject("systemInstruction")
        .putArray("parts")
        .addObject()
        .put("text", request.systemPrompt());
    ArrayNode contents = body.putArray("contents");
    ArrayNode pendingResponses = null;
    for (LlmMessage message : request.messages()) {
      if (message instanceof LlmMessage.ToolResult result) {
        // Results of one turn's calls go back together, in one user turn.
        if (pendingResponses == null) {
          ObjectNode turn = contents.addObject().put("role", "user");
          pendingResponses = turn.putArray("parts");
        }
        ObjectNode response = pendingResponses.addObject().putObject("functionResponse");
        if (!result.callId().startsWith(ToolCall.GENERATED_ID_PREFIX)) {
          response.put("id", result.callId());
        }
        response.put("name", result.name());
        response.putObject("response").set("result", readJson(result.json()));
        continue;
      }
      pendingResponses = null;
      if (message instanceof LlmMessage.User user) {
        contents
            .addObject()
            .put("role", "user")
            .putArray("parts")
            .addObject()
            .put("text", user.text());
      } else if (message instanceof LlmMessage.Assistant assistant) {
        contents.add(modelTurn(assistant));
      }
    }
    if (!request.tools().isEmpty()) {
      ArrayNode declarations = body.putArray("tools").addObject().putArray("functionDeclarations");
      for (ToolSpec tool : request.tools()) {
        declarations
            .addObject()
            .put("name", tool.name())
            .put("description", tool.description())
            .set("parameters", geminiSchema(tool.parameters()));
      }
    }
    body.putObject("generationConfig").put("temperature", 0.2);
    return body;
  }

  /** The model's own turn when it came from Gemini (keeps thought signatures), else rebuilt. */
  private JsonNode modelTurn(LlmMessage.Assistant assistant) {
    JsonNode original = assistant.providerContent();
    if (original != null && original.has("parts")) {
      return original;
    }
    ObjectNode turn = json.createObjectNode().put("role", "model");
    ArrayNode parts = turn.putArray("parts");
    if (!assistant.text().isBlank()) {
      parts.addObject().put("text", assistant.text());
    }
    for (ToolCall call : assistant.toolCalls()) {
      ObjectNode functionCall = parts.addObject().putObject("functionCall");
      if (!call.hasGeneratedId()) {
        functionCall.put("id", call.id());
      }
      functionCall.put("name", call.name()).set("args", call.arguments());
    }
    return turn;
  }

  LlmMessage.Assistant parse(@Nullable String response) {
    JsonNode root = readJson(response == null ? "" : response);
    JsonNode content = root.path("candidates").path(0).path("content");
    JsonNode parts = content.path("parts");
    if (!parts.isArray() || parts.isEmpty()) {
      String reason = root.path("candidates").path(0).path("finishReason").asString("");
      String blocked = root.path("promptFeedback").path("blockReason").asString("");
      throw new LlmException("gemini returned no content (" + reason + blocked + ")");
    }
    StringBuilder text = new StringBuilder();
    List<ToolCall> calls = new ArrayList<>();
    for (JsonNode part : parts) {
      if (part.path("thought").asBoolean(false)) {
        continue;
      }
      if (part.has("text")) {
        text.append(part.path("text").asString(""));
      }
      JsonNode call = part.path("functionCall");
      if (call.isObject()) {
        String id = call.path("id").asString("");
        JsonNode args = call.path("args");
        calls.add(
            new ToolCall(
                id.isEmpty() ? ToolCall.GENERATED_ID_PREFIX + UUID.randomUUID() : id,
                call.path("name").asString(""),
                args.isObject() ? args : json.createObjectNode()));
      }
    }
    if (text.isEmpty() && calls.isEmpty()) {
      throw new LlmException("gemini returned an empty answer");
    }
    ObjectNode turn = ((ObjectNode) content).deepCopy();
    turn.put("role", "model");
    return new LlmMessage.Assistant(text.toString(), calls, turn);
  }

  /** Gemini's schema format names types in capitals (OBJECT, STRING, INTEGER). */
  static JsonNode geminiSchema(JsonNode schema) {
    JsonNode copy = schema.deepCopy();
    upperCaseTypes(copy);
    return copy;
  }

  private static void upperCaseTypes(JsonNode node) {
    if (node instanceof ObjectNode object) {
      JsonNode type = object.get("type");
      if (type != null && type.isString()) {
        object.put("type", type.asString().toUpperCase(Locale.ROOT));
      }
      for (JsonNode child : object.values()) {
        upperCaseTypes(child);
      }
    } else if (node instanceof ArrayNode array) {
      for (JsonNode child : array) {
        upperCaseTypes(child);
      }
    }
  }

  private JsonNode readJson(String text) {
    try {
      return json.readTree(text);
    } catch (JacksonException e) {
      throw new LlmException("gemini: unreadable JSON", e);
    }
  }
}
