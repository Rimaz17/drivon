package com.drivon.api.assistant.tools;

import java.util.Arrays;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;
import tools.jackson.databind.node.ArrayNode;
import tools.jackson.databind.node.ObjectNode;

/**
 * Builds the JSON Schema of a tool's parameters with the small set of features both providers
 * understand. Every parameter is optional: the server fills in sensible defaults.
 */
final class Parameters {

  private final ObjectNode schema;
  private final ObjectNode properties;

  Parameters(JsonMapper json) {
    this.schema = json.createObjectNode().put("type", "object");
    this.properties = schema.putObject("properties");
  }

  Parameters vehicleId() {
    return string(
        "vehicleId",
        "ID of one of the user's vehicles, from listVehicles. Leave out to use the vehicle"
            + " selected in the app.");
  }

  Parameters from(String fallback) {
    return string("from", "First day to include, YYYY-MM-DD. Leave out for " + fallback + ".");
  }

  Parameters to() {
    return string("to", "Last day to include, YYYY-MM-DD. Leave out for today.");
  }

  Parameters string(String name, String description) {
    properties.putObject(name).put("type", "string").put("description", description);
    return this;
  }

  Parameters integer(String name, String description, int min, int max) {
    properties
        .putObject(name)
        .put("type", "integer")
        .put("description", description)
        .put("minimum", min)
        .put("maximum", max);
    return this;
  }

  Parameters choice(String name, String description, Enum<?>[] values) {
    ObjectNode property =
        properties.putObject(name).put("type", "string").put("description", description);
    ArrayNode options = property.putArray("enum");
    Arrays.stream(values).map(Enum::name).forEach(options::add);
    return this;
  }

  JsonNode build() {
    return schema;
  }
}
