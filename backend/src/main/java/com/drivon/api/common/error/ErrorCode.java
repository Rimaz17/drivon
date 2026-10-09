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
  INVALID_SORT(HttpStatus.BAD_REQUEST, "Invalid sort"),
  INVALID_DATE_RANGE(HttpStatus.BAD_REQUEST, "Invalid date range"),

  // 401 / 403
  UNAUTHENTICATED(HttpStatus.UNAUTHORIZED, "Authentication required"),
  INVALID_CREDENTIALS(HttpStatus.UNAUTHORIZED, "Invalid email or password"),
  INVALID_REFRESH_TOKEN(HttpStatus.UNAUTHORIZED, "Invalid refresh token"),
  ACCESS_DENIED(HttpStatus.FORBIDDEN, "Access denied"),

  // 404 / 405 / 415
  NOT_FOUND(HttpStatus.NOT_FOUND, "Not found"),
  VEHICLE_NOT_FOUND(HttpStatus.NOT_FOUND, "Vehicle not found"),
  ODOMETER_READING_NOT_FOUND(HttpStatus.NOT_FOUND, "Odometer reading not found"),
  FUEL_RECORD_NOT_FOUND(HttpStatus.NOT_FOUND, "Fuel record not found"),
  MAINTENANCE_RECORD_NOT_FOUND(HttpStatus.NOT_FOUND, "Service record not found"),
  EXPENSE_NOT_FOUND(HttpStatus.NOT_FOUND, "Expense not found"),
  DOCUMENT_NOT_FOUND(HttpStatus.NOT_FOUND, "Document not found"),
  METHOD_NOT_ALLOWED(HttpStatus.METHOD_NOT_ALLOWED, "Method not allowed"),
  UNSUPPORTED_MEDIA_TYPE(HttpStatus.UNSUPPORTED_MEDIA_TYPE, "Unsupported media type"),

  // 409
  CONFLICT(HttpStatus.CONFLICT, "Conflict"),
  EMAIL_ALREADY_REGISTERED(HttpStatus.CONFLICT, "Email already registered"),
  REGISTRATION_NUMBER_IN_USE(HttpStatus.CONFLICT, "Registration number already in use"),
  RECORD_ID_CONFLICT(HttpStatus.CONFLICT, "Record ID already in use"),

  // 422: well-formed requests that break a business rule
  VEHICLE_LIMIT_REACHED(HttpStatus.UNPROCESSABLE_CONTENT, "Vehicle limit reached"),
  ODOMETER_DECREASE(HttpStatus.UNPROCESSABLE_CONTENT, "Odometer cannot go backwards"),
  ODOMETER_OUT_OF_ORDER(
      HttpStatus.UNPROCESSABLE_CONTENT, "Odometer reading out of order with other dates"),
  ODOMETER_READING_LOCKED(HttpStatus.UNPROCESSABLE_CONTENT, "Odometer reading can't be changed"),
  INVALID_MODEL_YEAR(HttpStatus.UNPROCESSABLE_CONTENT, "Invalid model year"),
  DATE_IN_FUTURE(HttpStatus.UNPROCESSABLE_CONTENT, "Date in the future"),
  NEXT_SERVICE_DATE_INVALID(
      HttpStatus.UNPROCESSABLE_CONTENT, "Next service date must be after the service"),
  NEXT_SERVICE_KM_INVALID(
      HttpStatus.UNPROCESSABLE_CONTENT, "Next service mileage must be above the odometer"),
  FUEL_PRICE_MISMATCH(
      HttpStatus.UNPROCESSABLE_CONTENT, "Price per litre doesn't match the amount and litres"),
  DOCUMENT_DATES_INVALID(
      HttpStatus.UNPROCESSABLE_CONTENT, "Expiry date must be after the issue date"),
  UNSUPPORTED_FILE_TYPE(HttpStatus.UNPROCESSABLE_CONTENT, "File type not supported"),
  FILE_TOO_LARGE(HttpStatus.UNPROCESSABLE_CONTENT, "File too large"),
  DOCUMENT_LIMIT_REACHED(HttpStatus.UNPROCESSABLE_CONTENT, "Document limit reached"),
  UPLOAD_NOT_FOUND(HttpStatus.UNPROCESSABLE_CONTENT, "File not uploaded yet"),
  UPLOAD_MISMATCH(HttpStatus.UNPROCESSABLE_CONTENT, "Uploaded file doesn't match the request"),

  // 429 / 5xx
  RATE_LIMITED(HttpStatus.TOO_MANY_REQUESTS, "Too many requests"),
  INTERNAL_ERROR(HttpStatus.INTERNAL_SERVER_ERROR, "Internal error"),
  STORAGE_UNAVAILABLE(HttpStatus.SERVICE_UNAVAILABLE, "File storage unavailable");

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
