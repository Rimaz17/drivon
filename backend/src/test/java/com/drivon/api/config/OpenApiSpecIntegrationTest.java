package com.drivon.api.config;

import static org.assertj.core.api.Assertions.assertThat;

import com.drivon.api.support.IntegrationTest;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.web.servlet.assertj.MockMvcTester;
import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.SerializationFeature;
import tools.jackson.databind.json.JsonMapper;

/**
 * Keeps the committed API reference ({@code docs/api/openapi.json}) identical to what the API
 * serves. After changing an endpoint or DTO, regenerate it from {@code backend/} with:
 *
 * <pre>./mvnw test -Dtest=OpenApiSpecIntegrationTest -Dopenapi.write=true</pre>
 */
@IntegrationTest
class OpenApiSpecIntegrationTest {

  private static final Path COMMITTED_SPEC = Path.of("..", "docs", "api", "openapi.json");

  private static final String REGENERATE =
      "./mvnw test -Dtest=OpenApiSpecIntegrationTest -Dopenapi.write=true";

  /** Sorted keys, so the file doesn't change with the order Spring happens to find endpoints. */
  private static final JsonMapper JSON =
      JsonMapper.builder()
          .enable(SerializationFeature.INDENT_OUTPUT)
          .enable(SerializationFeature.ORDER_MAP_ENTRIES_BY_KEYS)
          .build();

  @Autowired private MockMvcTester mvc;

  @Test
  void committedSpecMatchesTheApi() throws IOException {
    Map<String, Object> served = servedSpec();
    if (Boolean.getBoolean("openapi.write")) {
      String json = JSON.writeValueAsString(served).replace("\r\n", "\n") + "\n";
      Files.writeString(COMMITTED_SPEC, json, StandardCharsets.UTF_8);
    }

    assertThat(COMMITTED_SPEC).as("Create it with: %s", REGENERATE).exists();
    Map<String, Object> committed =
        JSON.readValue(Files.readString(COMMITTED_SPEC, StandardCharsets.UTF_8), new SpecType());
    assertThat(committed)
        .as("docs/api/openapi.json is out of date. Regenerate it with: %s", REGENERATE)
        .isEqualTo(served);
  }

  @Test
  void everyOperationHasItsOwnId() throws IOException {
    List<String> operationIds = new ArrayList<>();
    asMap(servedSpec().get("paths"))
        .values()
        .forEach(path -> asMap(path).values().forEach(op -> operationIds.add(operationId(op))));

    // springdoc appends _1, _2 to repeated method names, in an order that varies between runs.
    assertThat(operationIds).doesNotHaveDuplicates().noneMatch(id -> id.matches(".*_\\d+"));
  }

  @Test
  void errorResponsesAreProblemDetails() throws IOException {
    Map<String, Object> paths = asMap(servedSpec().get("paths"));
    Map<String, Object> createVehicle = asMap(asMap(paths.get("/api/v1/vehicles")).get("post"));
    Map<String, Object> conflict = asMap(asMap(createVehicle.get("responses")).get("409"));

    assertThat(asMap(conflict.get("content")))
        .containsOnlyKeys("application/problem+json")
        .extractingByKey("application/problem+json")
        .asString()
        .contains("#/components/schemas/" + OpenApiConfig.PROBLEM_SCHEMA);
  }

  /** The served spec without {@code servers}, which names whatever host answered the request. */
  private Map<String, Object> servedSpec() throws IOException {
    String body =
        mvc.get()
            .uri("/v3/api-docs")
            .exchange()
            .getResponse()
            .getContentAsString(StandardCharsets.UTF_8);
    Map<String, Object> spec = JSON.readValue(body, new SpecType());
    spec.remove("servers");
    return spec;
  }

  private static String operationId(Object operation) {
    return String.valueOf(asMap(operation).get("operationId"));
  }

  @SuppressWarnings("unchecked")
  private static Map<String, Object> asMap(Object value) {
    return (Map<String, Object>) value;
  }

  private static final class SpecType extends TypeReference<Map<String, Object>> {}
}
