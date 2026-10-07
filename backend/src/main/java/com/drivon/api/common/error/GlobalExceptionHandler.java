package com.drivon.api.common.error;

import com.drivon.api.common.web.RequestIdFilter;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import org.jspecify.annotations.Nullable;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.ProblemDetail;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.AuthenticationException;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.context.request.WebRequest;
import org.springframework.web.method.annotation.HandlerMethodValidationException;
import org.springframework.web.servlet.mvc.method.annotation.ResponseEntityExceptionHandler;

/**
 * Turns every error into an RFC 9457 Problem Details body with a stable {@code code} and the
 * request ID. Internal details (stack traces, SQL, class names) are logged, never returned.
 */
@RestControllerAdvice
public class GlobalExceptionHandler extends ResponseEntityExceptionHandler {

  public static final String CODE = "code";
  public static final String ERRORS = "errors";
  public static final String REQUEST_ID = "requestId";

  private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

  @ExceptionHandler(DrivonException.class)
  ResponseEntity<ProblemDetail> handleDrivon(DrivonException ex) {
    HttpHeaders headers = new HttpHeaders();
    if (ex instanceof RateLimitedException limited) {
      headers.set(HttpHeaders.RETRY_AFTER, Long.toString(limited.retryAfterSeconds()));
    }
    ProblemDetail problem = problem(ex.code(), ex.getMessage());
    ex.properties().forEach(problem::setProperty);
    return respond(problem, headers);
  }

  /** Reached from the security filter chain via the authentication entry point. */
  @ExceptionHandler(AuthenticationException.class)
  ResponseEntity<ProblemDetail> handleAuthentication(AuthenticationException ex) {
    return respond(ErrorCode.UNAUTHENTICATED, "Sign in to continue.", new HttpHeaders());
  }

  @ExceptionHandler(AccessDeniedException.class)
  ResponseEntity<ProblemDetail> handleAccessDenied(AccessDeniedException ex) {
    return respond(ErrorCode.ACCESS_DENIED, ErrorCode.ACCESS_DENIED.title(), new HttpHeaders());
  }

  /** Unique-constraint races that slipped past the service-level checks. */
  @ExceptionHandler(DataIntegrityViolationException.class)
  ResponseEntity<ProblemDetail> handleDataIntegrity(DataIntegrityViolationException ex) {
    log.warn("Data integrity violation: {}", ex.getMostSpecificCause().getClass().getSimpleName());
    return respond(
        ErrorCode.CONFLICT, "The request conflicts with existing data.", new HttpHeaders());
  }

  @ExceptionHandler(Exception.class)
  ResponseEntity<ProblemDetail> handleUnexpected(Exception ex) {
    log.error("Unhandled exception", ex);
    return respond(
        ErrorCode.INTERNAL_ERROR, "Something went wrong. Please try again.", new HttpHeaders());
  }

  @Override
  protected ResponseEntity<Object> handleMethodArgumentNotValid(
      MethodArgumentNotValidException ex,
      HttpHeaders headers,
      HttpStatusCode status,
      WebRequest request) {
    List<Map<String, String>> errors =
        ex.getBindingResult().getFieldErrors().stream()
            .sorted(Comparator.comparing(FieldError::getField))
            .map(
                error ->
                    Map.of(
                        "field",
                        error.getField(),
                        "message",
                        String.valueOf(error.getDefaultMessage())))
            .toList();
    ProblemDetail problem = problem(ErrorCode.VALIDATION_FAILED, "One or more fields are invalid.");
    problem.setProperty(ERRORS, errors);
    return ResponseEntity.status(problem.getStatus()).headers(headers).body(problem);
  }

  @Override
  protected ResponseEntity<Object> handleHandlerMethodValidationException(
      HandlerMethodValidationException ex,
      HttpHeaders headers,
      HttpStatusCode status,
      WebRequest request) {
    ProblemDetail problem =
        problem(ErrorCode.VALIDATION_FAILED, "One or more parameters are invalid.");
    return ResponseEntity.status(problem.getStatus()).headers(headers).body(problem);
  }

  /** Adds the stable code and request ID to Spring MVC's own error responses. */
  @Override
  protected ResponseEntity<Object> handleExceptionInternal(
      Exception ex,
      @Nullable Object body,
      HttpHeaders headers,
      HttpStatusCode statusCode,
      WebRequest request) {
    ResponseEntity<Object> response =
        super.handleExceptionInternal(ex, body, headers, statusCode, request);
    if (response != null && response.getBody() instanceof ProblemDetail problem) {
      decorate(problem, ErrorCode.forStatus(statusCode.value()));
    }
    return response;
  }

  private static ResponseEntity<ProblemDetail> respond(
      ErrorCode code, String detail, HttpHeaders headers) {
    return respond(problem(code, detail), headers);
  }

  private static ResponseEntity<ProblemDetail> respond(ProblemDetail problem, HttpHeaders headers) {
    if (problem.getStatus() == 401) {
      headers.set(HttpHeaders.WWW_AUTHENTICATE, "Bearer");
    }
    return ResponseEntity.status(problem.getStatus()).headers(headers).body(problem);
  }

  private static ProblemDetail problem(ErrorCode code, String detail) {
    ProblemDetail problem = ProblemDetail.forStatusAndDetail(code.status(), detail);
    problem.setTitle(code.title());
    decorate(problem, code);
    return problem;
  }

  private static void decorate(ProblemDetail problem, ErrorCode fallbackCode) {
    Map<String, Object> properties = problem.getProperties();
    if (properties == null || !properties.containsKey(CODE)) {
      problem.setProperty(CODE, fallbackCode.name());
    }
    String requestId = MDC.get(RequestIdFilter.MDC_KEY);
    if (requestId != null) {
      problem.setProperty(REQUEST_ID, requestId);
    }
  }
}
