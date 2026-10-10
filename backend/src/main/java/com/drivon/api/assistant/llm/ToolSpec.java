package com.drivon.api.assistant.llm;

import tools.jackson.databind.JsonNode;

/**
 * A tool the model may call, written once and translated for each provider.
 *
 * @param parameters a JSON Schema object (types {@code object}, {@code string}, {@code integer};
 *     {@code enum}, {@code description}, {@code minimum}, {@code maximum}) that both providers
 *     understand
 */
public record ToolSpec(String name, String description, JsonNode parameters) {}
