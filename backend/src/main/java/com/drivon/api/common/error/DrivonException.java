package com.drivon.api.common.error;

import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.Map;
import org.jspecify.annotations.Nullable;

/**
 * Expected failure that maps to a Problem Details response. The message becomes the response's
 * {@code detail}, so it must be safe to show to API clients (no internal identifiers or SQL).
 */
public class DrivonException extends RuntimeException {

  private final ErrorCode code;
  private final Map<String, Object> properties = new LinkedHashMap<>();

  public DrivonException(ErrorCode code) {
    this(code, code.title());
  }

  public DrivonException(ErrorCode code, String detail) {
    super(detail);
    this.code = code;
  }

  public ErrorCode code() {
    return code;
  }

  /**
   * Adds a machine-readable member to the Problem Details body, e.g. the allowed range of a value
   * so a client can explain it. Null values are left out.
   */
  public DrivonException with(String name, @Nullable Object value) {
    if (value != null) {
      properties.put(name, value);
    }
    return this;
  }

  public Map<String, Object> properties() {
    return Collections.unmodifiableMap(properties);
  }
}
