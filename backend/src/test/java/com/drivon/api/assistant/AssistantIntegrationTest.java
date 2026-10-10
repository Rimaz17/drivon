package com.drivon.api.assistant;

import static org.assertj.core.api.Assertions.assertThat;

import com.drivon.api.assistant.llm.LlmMessage;
import com.drivon.api.common.time.BusinessCalendar;
import com.drivon.api.support.ApiClient;
import com.drivon.api.support.ApiClient.Session;
import com.drivon.api.support.IntegrationTest;
import com.drivon.api.support.ScriptedLlmClient;
import com.drivon.api.support.TestAssistantConfiguration;
import com.jayway.jsonpath.JsonPath;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.http.HttpStatus;
import org.springframework.test.web.servlet.assertj.MockMvcTester;
import org.springframework.test.web.servlet.assertj.MvcTestResult;

/** Ask My Vehicle end to end, with scripted models and real tools against Postgres. */
@IntegrationTest
class AssistantIntegrationTest {

  private static final LocalDate TODAY = LocalDate.now(BusinessCalendar.ZONE);

  @Autowired private MockMvcTester mvc;

  @Autowired
  @Qualifier(TestAssistantConfiguration.PRIMARY) private ScriptedLlmClient gemini;

  @Autowired
  @Qualifier(TestAssistantConfiguration.FALLBACK) private ScriptedLlmClient groq;

  private ApiClient api;

  @BeforeEach
  void setUp() {
    api = new ApiClient(mvc);
    gemini.reset();
    groq.reset();
  }

  /**
   * A full-tank fill-up today; the vehicle was added today, so earlier dates would be out of order.
   */
  private void fillUp(
      Session session,
      String vehicleId,
      String litres,
      String amount,
      int odometer,
      String station) {
    MvcTestResult result =
        api.postJson(
            "/api/v1/vehicles/" + vehicleId + "/fuel-records",
            """
            {"date": "%s", "litres": "%s", "amount": "%s", "odometerKm": %d,
             "fullTank": true, "station": "%s"}
            """
                .formatted(TODAY, litres, amount, odometer, station),
            session.bearer());
    assertThat(result).hasStatus(HttpStatus.CREATED);
  }

  private MvcTestResult ask(Session session, String vehicleId, String message) {
    return api.postJson(
        "/api/v1/assistant/chat",
        """
        {"message": "%s", "vehicleId": "%s",
         "history": [{"role": "USER", "text": "Hi"}, {"role": "ASSISTANT", "text": "Hello!"}]}
        """
            .formatted(message, vehicleId),
        session.bearer());
  }

  /** The tool results the model received in its last request, in order. */
  private List<String> toolResults(ScriptedLlmClient model) {
    List<LlmMessage> messages = model.requests().get(model.requests().size() - 1).messages();
    return messages.stream()
        .filter(LlmMessage.ToolResult.class::isInstance)
        .map(message -> ((LlmMessage.ToolResult) message).json())
        .toList();
  }

  @Test
  void answersFromTheUsersOwnDataThroughTools() {
    Session session = api.register();
    String vehicleId = api.createVehicle(session, "CAB-1234", 45_000);
    fillUp(session, vehicleId, "40.000", "14600.00", 45_100, "Ceypetco Kandy");
    fillUp(session, vehicleId, "30.000", "11100.00", 45_550, " ceypetco kandy ");
    fillUp(session, vehicleId, "35.000", "12600.00", 46_000, "LIOC Peradeniya");
    gemini
        .thenCall("getFuelStationStats", "{}")
        .thenCall("getFuelHistory", "{\"limit\": 2}")
        .thenCall("getMaintenanceHistory", "{\"serviceType\": \"OIL_CHANGE\"}")
        .thenCall("getVehicleExpenses", "{\"category\": \"PARKING\"}")
        .thenCall("getFuelPriceTrend", "{}")
        .thenAnswer("You fill up most at Ceypetco Kandy.");

    MvcTestResult result = ask(session, vehicleId, "Where do I fill up most?");

    assertThat(result)
        .hasStatusOk()
        .bodyJson()
        .extractingPath("$.reply")
        .isEqualTo("You fill up most at Ceypetco Kandy.");
    List<String> results = toolResults(gemini);
    assertThat(results).hasSize(5);
    String stations = results.get(0);
    // Spellings that differ only in case and spaces count as one station.
    assertThat(JsonPath.<List<String>>read(stations, "$[*].station"))
        .map(String::toLowerCase)
        .containsExactly("ceypetco kandy", "lioc peradeniya");
    assertThat(JsonPath.<Integer>read(stations, "$[0].fillUps")).isEqualTo(2);
    // Decimals stay exact strings: 25,700 / 70 L.
    assertThat(JsonPath.<String>read(stations, "$[0].averagePricePerLitre")).isEqualTo("367.14");
    assertThat(JsonPath.<List<String>>read(results.get(1), "$[*].station"))
        .containsExactly("LIOC Peradeniya", "ceypetco kandy");
    assertThat(results.get(2)).isEqualTo("[]");
    assertThat(results.get(3)).isEqualTo("[]");
    assertThat(JsonPath.<List<Object>>read(results.get(4), "$")).isNotEmpty();
    // The earlier turns went to the model too.
    assertThat(gemini.requests().get(0).messages().get(0)).isEqualTo(new LlmMessage.User("Hi"));
  }

  @Test
  void toolsNeverReachAnotherUsersVehicle() {
    Session owner = api.register();
    Session other = api.register();
    String ownerVehicle = api.createVehicle(owner, "CAB-1234", 45_000);
    String otherVehicle = api.createVehicle(other, "WP-9999", 10_000);
    fillUp(other, otherVehicle, "10.000", "3700.00", 10_100, "Secret Station");
    gemini
        .thenCall("getFuelHistory", "{\"vehicleId\": \"" + otherVehicle + "\"}")
        .thenCall("getVehicleDetails", "{\"vehicleId\": \"" + otherVehicle + "\"}")
        .thenCall("getReminders", "{\"vehicleId\": \"" + otherVehicle + "\"}")
        .thenAnswer("I can't find that vehicle.");

    assertThat(ask(owner, ownerVehicle, "Show the other car's fill-ups")).hasStatusOk();

    List<String> results = toolResults(gemini);
    assertThat(results)
        .allSatisfy(
            json ->
                assertThat(JsonPath.<String>read(json, "$.error")).isEqualTo("Vehicle not found"));
    assertThat(String.join("", results)).doesNotContain("Secret Station");
  }

  @Test
  void failsOverAndReportsOutages() {
    Session session = api.register();
    String vehicleId = api.createVehicle(session, "CAB-1234", 45_000);
    gemini.thenFail("gemini answered HTTP 429");
    groq.thenCall("listVehicles", "{}").thenAnswer("You have one Toyota Aqua.");

    assertThat(ask(session, vehicleId, "Which vehicles do I have?"))
        .hasStatusOk()
        .bodyJson()
        .extractingPath("$.reply")
        .isEqualTo("You have one Toyota Aqua.");
    assertThat(JsonPath.<List<Map<String, Object>>>read(toolResults(groq).get(0), "$"))
        .singleElement()
        .satisfies(vehicle -> assertThat(vehicle).containsEntry("registrationNumber", "CAB-1234"));

    gemini.thenFail("down");
    groq.thenFail("down too");
    assertThat(ask(session, vehicleId, "Hello?"))
        .hasStatus(HttpStatus.SERVICE_UNAVAILABLE)
        .bodyJson()
        .extractingPath("$.code")
        .isEqualTo("ASSISTANT_UNAVAILABLE");
  }

  @Test
  void validatesTheQuestion() {
    Session session = api.register();

    assertThat(api.postJson("/api/v1/assistant/chat", "{\"message\": \"  \"}", session.bearer()))
        .hasStatus(HttpStatus.BAD_REQUEST)
        .bodyJson()
        .extractingPath("$.code")
        .isEqualTo("VALIDATION_FAILED");
    assertThat(gemini.requests()).isEmpty();
  }

  @Test
  void needsSigningIn() {
    assertThat(api.postJson("/api/v1/assistant/chat", "{\"message\": \"Hi\"}", null))
        .hasStatus(HttpStatus.UNAUTHORIZED);
  }
}
