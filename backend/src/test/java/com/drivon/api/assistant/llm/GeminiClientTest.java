package com.drivon.api.assistant.llm;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.header;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.jsonPath;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.method;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.requestTo;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withStatus;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withSuccess;

import java.util.List;
import org.hamcrest.Matchers;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.web.client.RestClient;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;

class GeminiClientTest {

  private static final String URL = "https://gemini.test/v1beta/models/gemini-test:generateContent";

  private final JsonMapper json = JsonMapper.builder().build();
  private MockRestServiceServer server;
  private GeminiClient client;

  @BeforeEach
  void setUp() {
    RestClient.Builder builder = RestClient.builder();
    server = MockRestServiceServer.bindTo(builder).build();
    client =
        new GeminiClient(
            builder, json, "https://gemini.test/v1beta", " secret-key ", "gemini-test");
  }

  private JsonNode node(String text) {
    return json.readTree(text);
  }

  private LlmRequest request(List<LlmMessage> messages) {
    return new LlmRequest(
        "Be helpful.",
        messages,
        List.of(
            new ToolSpec(
                "getFuelExpenses",
                "Fuel spend.",
                node(
                    """
                    {"type": "object", "properties": {"from": {"type": "string"}}}
                    """))));
  }

  @Test
  void sendsTheQuestionWithToolsAndTheKeyInAHeader() {
    server
        .expect(requestTo(URL))
        .andExpect(method(HttpMethod.POST))
        .andExpect(header("x-goog-api-key", "secret-key"))
        .andExpect(jsonPath("$.systemInstruction.parts[0].text").value("Be helpful."))
        .andExpect(jsonPath("$.contents[0].role").value("user"))
        .andExpect(jsonPath("$.contents[0].parts[0].text").value("Fuel in September?"))
        .andExpect(jsonPath("$.tools[0].functionDeclarations[0].name").value("getFuelExpenses"))
        .andExpect(jsonPath("$.tools[0].functionDeclarations[0].parameters.type").value("OBJECT"))
        .andExpect(
            jsonPath("$.tools[0].functionDeclarations[0].parameters.properties.from.type")
                .value("STRING"))
        .andRespond(
            withSuccess(
                """
                {"candidates": [{"content": {"role": "model", "parts": [
                  {"text": "You spent Rs. 18,500."}]}}]}
                """,
                MediaType.APPLICATION_JSON));

    LlmMessage.Assistant reply =
        client.complete(request(List.of(new LlmMessage.User("Fuel in September?"))));

    assertThat(reply.text()).isEqualTo("You spent Rs. 18,500.");
    assertThat(reply.toolCalls()).isEmpty();
    server.verify();
  }

  @Test
  void readsToolCallsAndSkipsThoughts() {
    server
        .expect(requestTo(URL))
        .andRespond(
            withSuccess(
                """
                {"candidates": [{"content": {"role": "model", "parts": [
                  {"text": "planning", "thought": true},
                  {"functionCall": {"name": "getFuelExpenses", "args": {"from": "2026-09-01"}},
                   "thoughtSignature": "c2lnbmF0dXJl"},
                  {"functionCall": {"id": "call-2", "name": "listVehicles"}}]}}]}
                """,
                MediaType.APPLICATION_JSON));

    LlmMessage.Assistant reply = client.complete(request(List.of(new LlmMessage.User("Hi"))));

    assertThat(reply.text()).isEmpty();
    assertThat(reply.toolCalls()).hasSize(2);
    ToolCall first = reply.toolCalls().get(0);
    assertThat(first.name()).isEqualTo("getFuelExpenses");
    assertThat(first.hasGeneratedId()).isTrue();
    assertThat(first.arguments().path("from").asString()).isEqualTo("2026-09-01");
    assertThat(reply.toolCalls().get(1).id()).isEqualTo("call-2");
    assertThat(reply.toolCalls().get(1).arguments().isObject()).isTrue();
    assertThat(reply.providerContent().path("parts").get(1).path("thoughtSignature").asString())
        .isEqualTo("c2lnbmF0dXJl");
  }

  @Test
  void sendsItsOwnTurnBackUnchangedWithTheResultsTogether() {
    JsonNode modelTurn =
        node(
            """
            {"role": "model", "parts": [
              {"functionCall": {"name": "a", "args": {}}, "thoughtSignature": "c2ln"},
              {"functionCall": {"id": "call-2", "name": "b", "args": {}}}]}
            """);
    LlmMessage.Assistant earlier =
        new LlmMessage.Assistant(
            "",
            List.of(
                new ToolCall(ToolCall.GENERATED_ID_PREFIX + "1", "a", node("{}")),
                new ToolCall("call-2", "b", node("{}"))),
            modelTurn);
    server
        .expect(requestTo(URL))
        .andExpect(jsonPath("$.contents[1].parts[0].thoughtSignature").value("c2ln"))
        .andExpect(jsonPath("$.contents[2].role").value("user"))
        .andExpect(jsonPath("$.contents[2].parts", Matchers.hasSize(2)))
        .andExpect(jsonPath("$.contents[2].parts[0].functionResponse.name").value("a"))
        .andExpect(jsonPath("$.contents[2].parts[0].functionResponse.id").doesNotExist())
        .andExpect(
            jsonPath("$.contents[2].parts[0].functionResponse.response.result.total")
                .value("18500.00"))
        .andExpect(jsonPath("$.contents[2].parts[1].functionResponse.id").value("call-2"))
        .andRespond(
            withSuccess(
                """
                {"candidates": [{"content": {"parts": [{"text": "Done."}]}}]}
                """,
                MediaType.APPLICATION_JSON));

    client.complete(
        request(
            List.of(
                new LlmMessage.User("Hi"),
                earlier,
                new LlmMessage.ToolResult(
                    ToolCall.GENERATED_ID_PREFIX + "1", "a", "{\"total\": \"18500.00\"}"),
                new LlmMessage.ToolResult("call-2", "b", "[]"))));

    server.verify();
  }

  @Test
  void rebuildsTurnsThatCameFromAnotherProvider() {
    LlmMessage.Assistant fromGroq =
        new LlmMessage.Assistant(
            "Let me check.", List.of(new ToolCall("groq-1", "a", node("{\"x\": 1}"))), null);
    server
        .expect(requestTo(URL))
        .andExpect(jsonPath("$.contents[1].role").value("model"))
        .andExpect(jsonPath("$.contents[1].parts[0].text").value("Let me check."))
        .andExpect(jsonPath("$.contents[1].parts[1].functionCall.id").value("groq-1"))
        .andExpect(jsonPath("$.contents[1].parts[1].functionCall.args.x").value(1))
        .andRespond(
            withSuccess(
                "{\"candidates\": [{\"content\": {\"parts\": [{\"text\": \"OK\"}]}}]}",
                MediaType.APPLICATION_JSON));

    client.complete(
        request(
            List.of(
                new LlmMessage.User("Hi"),
                fromGroq,
                new LlmMessage.ToolResult("groq-1", "a", "{}"))));

    server.verify();
  }

  @Test
  void rateLimitsAndServerErrorsAreFailures() {
    server.expect(requestTo(URL)).andRespond(withStatus(HttpStatus.TOO_MANY_REQUESTS));
    assertThatThrownBy(() -> client.complete(request(List.of(new LlmMessage.User("Hi")))))
        .isInstanceOf(LlmException.class)
        .hasMessageContaining("429");

    server.reset();
    server.expect(requestTo(URL)).andRespond(withStatus(HttpStatus.SERVICE_UNAVAILABLE));
    assertThatThrownBy(() -> client.complete(request(List.of(new LlmMessage.User("Hi")))))
        .isInstanceOf(LlmException.class)
        .hasMessageContaining("503");
  }

  @Test
  void aBlockedOrEmptyAnswerIsAFailure() {
    server
        .expect(requestTo(URL))
        .andRespond(
            withSuccess(
                "{\"promptFeedback\": {\"blockReason\": \"SAFETY\"}}", MediaType.APPLICATION_JSON));

    assertThatThrownBy(() -> client.complete(request(List.of(new LlmMessage.User("Hi")))))
        .isInstanceOf(LlmException.class)
        .hasMessageContaining("SAFETY");
  }

  @Test
  void needsAKey() {
    RestClient.Builder builder = RestClient.builder();
    assertThat(new GeminiClient(builder, json, "https://x", " ", "m").configured()).isFalse();
    assertThat(new GeminiClient(builder, json, "https://x", null, "m").configured()).isFalse();
    assertThat(client.configured()).isTrue();
  }
}
