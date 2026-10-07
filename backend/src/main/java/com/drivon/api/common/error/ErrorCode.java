package com.drivon.api.common.error;

import org.springframework.http.HttpStatus;

/**
 * Stable, machine-readable error codes returned in the {@code code} field of every Problem Details
 * response. Clients branch on these, so existing values must never be renamed.
 */
public enum ErrorCode {
  // 400
  VALIDATION_FAILED(HttpStatus.BAD_REQUEST, "Validation failed"),
  MALFORMED_REQUEST(HttpStatus.BAD_REQUEST, "Malformed request"),

  // 401 / 403
  UNAUTHENTICATED(HttpStatus.UNAUTHORIZED, "Authentication required"),
  INVALID_CREDENTIALS(HttpStatus.UNAUTHORIZED, "Invalid email or password"),
  INVALID_REFRESH_TOKEN(HttpStatus.UNAUTHORIZED, "Invalid refresh token"),
  ACCESS_DENIED(HttpStatus.FORBIDDEN, "Access denied"),

  // 404 / 405 / 415
  NOT_FOUND(HttpStatus.NOT_FOUND, "Not found"),
  VEHICLE_NOT_FOUND(HttpStatus.NOT_FOUND, "Vehicle not found"),
  METHOD_NOT_ALLOWED(HttpStatus.METHOD_NOT_ALLOWED, "Method not allowed"),
  UNSUPPORTED_MEDIA_TYPE(HttpStatus.UNSUPPORTED_MEDIA_TYPE, "Unsupported media type"),

  // 409
  CONFLICT(HttpStatus.CONFLICT, "Conflict"),
  EMAIL_ALREADY_REGISTERED(HttpStatus.CONFLICT, "Email already registered"),
  REGISTRATION_NUMBER_IN_USE(HttpStatus.CONFLICT, "Registration number already in use"),

  // 422: well-formed requests that break a business rule
  VEHICLE_LIMIT_REACHED(HttpStatus.UNPROCESSABLE_CONTENT, "Vehicle limit reached"),
  ODOMETER_DECREASE(HttpStatus.UNPROCESSABLE_CONTENT, "Odometer cannot go backwards"),
  INVALID_MODEL_YEAR(HttpStatus.UNPROCESSABLE_CONTENT, "Invalid model year"),

  // 429 / 5xx
  RATE_LIMITED(HttpStatus.TOO_MANY_REQUESTS, "Too many requests"),
  INTERNAL_ERROR(HttpStatus.INTERNAL_SERVER_ERROR, "Internal error");

  private final HttpStatus status;
  private final String title;

  ErrorCode(HttpStatus status, String title) {
    this.status = status;
    this.title = title;
  }

  public HttpStatus status() {
    return status;
  }

  public String title() {
    return title;
  }

  /** Generic code for framework errors that carry only an HTTP status. */
  public static ErrorCode forStatus(int status) {
    return switch (status) {
      case 400 -> MALFORMED_REQUEST;
      case 401 -> UNAUTHENTICATED;
      case 403 -> ACCESS_DENIED;
      case 404 -> NOT_FOUND;
      case 405 -> METHOD_NOT_ALLOWED;
      case 409 -> CONFLICT;
      case 415 -> UNSUPPORTED_MEDIA_TYPE;
      case 429 -> RATE_LIMITED;
      default -> status >= 500 ? INTERNAL_ERROR : MALFORMED_REQUEST;
    };
  }
}
