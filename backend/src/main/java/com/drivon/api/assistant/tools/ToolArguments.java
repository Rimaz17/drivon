package com.drivon.api.assistant.tools;

import java.time.LocalDate;
import java.time.format.DateTimeParseException;
import java.util.Arrays;
import java.util.Locale;
import java.util.UUID;
import org.jspecify.annotations.Nullable;
import tools.jackson.databind.JsonNode;

/**
 * The arguments of one tool call, read defensively: the model chose them, so every value is checked
 * and a bad one becomes a {@link ToolArgumentException} the model can learn from. Missing and null
 * values both count as "not given".
 */
public final class ToolArguments {

  private final JsonNode values;

  public ToolArguments(JsonNode values) {
    this.values = values;
  }

  private @Nullable String text(String name) {
    JsonNode value = values.get(name);
    if (value == null || value.isNull()) {
      return null;
    }
    String text = value.isString() ? value.asString() : value.toString();
    return text.isBlank() ? null : text.strip();
  }

  public @Nullable UUID uuid(String name) {
    String text = text(name);
    if (text == null) {
      return null;
    }
    try {
      return UUID.fromString(text);
    } catch (IllegalArgumentException e) {
      throw new ToolArgumentException(name + " must be an ID returned by listVehicles.");
    }
  }

  /** A calendar date written as YYYY-MM-DD. */
  public @Nullable LocalDate date(String name) {
    String text = text(name);
    if (text == null) {
      return null;
    }
    try {
      return LocalDate.parse(text);
    } catch (DateTimeParseException e) {
      throw new ToolArgumentException(name + " must be a date written as YYYY-MM-DD.");
    }
  }

  /** A whole number from {@code min} to {@code max}; {@code fallback} when not given. */
  public int integer(String name, int min, int max, int fallback) {
    JsonNode value = values.get(name);
    if (value == null || value.isNull()) {
      return fallback;
    }
    int number;
    if (value.isIntegralNumber()) {
      number = value.asInt();
    } else {
      try {
        number = Integer.parseInt(value.asString("").strip());
      } catch (NumberFormatException e) {
        throw new ToolArgumentException(name + " must be a whole number.");
      }
    }
    if (number < min || number > max) {
      throw new ToolArgumentException(name + " must be from " + min + " to " + max + ".");
    }
    return number;
  }

  /** One of an enum's constants, matched ignoring case. */
  public <E extends Enum<E>> @Nullable E choice(String name, Class<E> type) {
    String text = text(name);
    if (text == null) {
      return null;
    }
    String wanted = text.toUpperCase(Locale.ROOT).replace(' ', '_').replace('-', '_');
    for (E constant : type.getEnumConstants()) {
      if (constant.name().equals(wanted)) {
        return constant;
      }
    }
    throw new ToolArgumentException(
        name + " must be one of " + Arrays.toString(type.getEnumConstants()) + ".");
  }
}
