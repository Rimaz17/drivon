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
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.web.client.RestClient;
import tools.jackson.databind.json.JsonMapper;

class GroqClientTest {

  private static final String URL = "https://groq.test/openai/v1/chat/completions";

  private final JsonMapper json = JsonMapper.builder().build();
  private MockRestServiceServer server;
  private GroqClient client;

  @BeforeEach
  void setUp() {
    RestClient.Builder builder = RestClient.builder();
    server = MockRestServiceServer.bindTo(builder).build();
    client =
        new GroqClient(
            builder, json, "https://groq.test/openai/v1", "groq-key", "openai/gpt-oss-120b");
  }

  private LlmRequest request(List<LlmMessage> messages) {
    return new LlmRequest(
        "Be helpful.",
        messages,
        List.of(
            new ToolSpec(
                "listVehicles",
                "The user's vehicles.",
                json.readTree("{\"type\": \"object\", \"properties\": {}}"))));
  }

  @Test
  void sendsAnOpenAiStyleRequestAndReadsToolCalls() {
    server
        .expect(requestTo(URL))
        .andExpect(method(HttpMethod.POST))
        .andExpect(header("Authorization", "Bearer groq-key"))
        .andExpect(jsonPath("$.model").value("openai/gpt-oss-120b"))
        .andExpect(jsonPath("$.messages[0].role").value("system"))
        .andExpect(jsonPath("$.messages[1].content").value("Which cars?"))
        .andExpect(jsonPath("$.tools[0].type").value("function"))
        .andExpect(jsonPath("$.tools[0].function.name").value("listVehicles"))
        .andExpect(jsonPath("$.tools[0].function.parameters.type").value("object"))
        .andExpect(jsonPath("$.tool_choice").value("auto"))
        .andRespond(
            withSuccess(
                """
                {"choices": [{"message": {"role": "assistant", "content": null,
                  "tool_calls": [{"id": "call_1", "type": "function",
                    "function": {"name": "listVehicles", "arguments": "{\\"x\\": 1}"}}]}}]}
                """,
                MediaType.APPLICATION_JSON));

    LlmMessage.Assistant reply =
        client.complete(request(List.of(new LlmMessage.User("Which cars?"))));

    assertThat(reply.text()).isEmpty();
    assertThat(reply.toolCalls())
        .singleElement()
        .satisfies(
            call -> {
              assertThat(call.id()).isEqualTo("call_1");
              assertThat(call.name()).isEqualTo("listVehicles");
              assertThat(call.arguments().path("x").asInt()).isEqualTo(1);
            });
    assertThat(reply.providerContent()).isNull();
    server.verify();
  }

  @Test
  void sendsToolCallsAndResultsBack() {
    LlmMessage.Assistant earlier =
        new LlmMessage.Assistant(
            "", List.of(new ToolCall("call_1", "listVehicles", json.readTree("{}"))), null);
    server
        .expect(requestTo(URL))
        .andExpect(jsonPath("$.messages[2].role").value("assistant"))
        .andExpect(jsonPath("$.messages[2].content").isEmpty())
        .andExpect(jsonPath("$.messages[2].tool_calls[0].id").value("call_1"))
        .andExpect(jsonPath("$.messages[2].tool_calls[0].function.arguments").value("{}"))
        .andExpect(jsonPath("$.messages[3].role").value("tool"))
        .andExpect(jsonPath("$.messages[3].tool_call_id").value("call_1"))
        .andExpect(jsonPath("$.messages[3].content").value("[{\"make\":\"Toyota\"}]"))
        .andExpect(jsonPath("$.messages[4].role").value("assistant"))
        .andExpect(jsonPath("$.messages[4].content").value("Earlier answer"))
        .andRespond(
            withSuccess(
                "{\"choices\": [{\"message\": {\"content\": \"A Toyota.\"}}]}",
                MediaType.APPLICATION_JSON));

    LlmMessage.Assistant reply =
        client.complete(
            request(
                List.of(
                    new LlmMessage.User("Which cars?"),
                    earlier,
                    new LlmMessage.ToolResult("call_1", "listVehicles", "[{\"make\":\"Toyota\"}]"),
                    LlmMessage.Assistant.text("Earlier answer"))));

    assertThat(reply.text()).isEqualTo("A Toyota.");
    server.verify();
  }

  @Test
  void unreadableArgumentsBecomeNoArguments() {
    server
        .expect(requestTo(URL))
        .andRespond(
            withSuccess(
                """
                {"choices": [{"message": {"tool_calls": [{"id": "c", "type": "function",
                  "function": {"name": "listVehicles", "arguments": "not json"}}]}}]}
                """,
                MediaType.APPLICATION_JSON));

    LlmMessage.Assistant reply = client.complete(request(List.of(new LlmMessage.User("Hi"))));

    assertThat(reply.toolCalls().get(0).arguments().isEmpty()).isTrue();
  }

  @Test
  void errorsAndEmptyAnswersAreFailures() {
    server.expect(requestTo(URL)).andRespond(withStatus(HttpStatus.TOO_MANY_REQUESTS));
    assertThatThrownBy(() -> client.complete(request(List.of(new LlmMessage.User("Hi")))))
        .isInstanceOf(LlmException.class)
        .hasMessageContaining("429");

    server.reset();
    server
        .expect(requestTo(URL))
        .andRespond(
            withSuccess(
                "{\"choices\": [{\"message\": {\"content\": \"  \"}}]}",
                MediaType.APPLICATION_JSON));
    assertThatThrownBy(() -> client.complete(request(List.of(new LlmMessage.User("Hi")))))
        .isInstanceOf(LlmException.class);
  }
}
