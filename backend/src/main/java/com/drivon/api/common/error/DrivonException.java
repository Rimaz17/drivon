package com.drivon.api.common.error;

/**
 * Expected failure that maps to a Problem Details response. The message becomes the response's
 * {@code detail}, so it must be safe to show to API clients (no internal identifiers or SQL).
 */
public class DrivonException extends RuntimeException {

  private final ErrorCode code;

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
}
