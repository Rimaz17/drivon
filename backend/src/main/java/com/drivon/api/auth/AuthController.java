package com.drivon.api.auth;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirements;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.net.URI;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/auth")
@Tag(name = "Authentication", description = "Accounts, sign-in and session tokens")
@SecurityRequirements
class AuthController {

  private final AuthService auth;
  private final AuthRateLimiter rateLimiter;

  AuthController(AuthService auth, AuthRateLimiter rateLimiter) {
    this.auth = auth;
    this.rateLimiter = rateLimiter;
  }

  @PostMapping("/register")
  @Operation(summary = "Create an account and sign in")
  @ApiResponse(responseCode = "201", description = "Account created; tokens returned")
  @ApiResponse(responseCode = "400", description = "VALIDATION_FAILED")
  @ApiResponse(responseCode = "409", description = "EMAIL_ALREADY_REGISTERED")
  @ApiResponse(responseCode = "429", description = "RATE_LIMITED")
  ResponseEntity<AuthResponse> register(
      @Valid @RequestBody RegisterRequest request, HttpServletRequest http) {
    rateLimiter.consume(http.getRemoteAddr());
    return ResponseEntity.created(URI.create("/api/v1/users/me")).body(auth.register(request));
  }

  @PostMapping("/login")
  @Operation(summary = "Sign in with email and password")
  @ApiResponse(responseCode = "200", description = "Signed in; tokens returned")
  @ApiResponse(responseCode = "401", description = "INVALID_CREDENTIALS")
  @ApiResponse(responseCode = "429", description = "RATE_LIMITED")
  AuthResponse login(@Valid @RequestBody LoginRequest request, HttpServletRequest http) {
    rateLimiter.consume(http.getRemoteAddr());
    return auth.login(request);
  }

  @PostMapping("/refresh")
  @Operation(
      summary = "Exchange a refresh token for new tokens",
      description = "The presented refresh token is revoked; always store the new one.")
  @ApiResponse(responseCode = "200", description = "New access and refresh tokens")
  @ApiResponse(responseCode = "401", description = "INVALID_REFRESH_TOKEN")
  AuthResponse refresh(@Valid @RequestBody RefreshRequest request) {
    return auth.refresh(request);
  }

  @PostMapping("/logout")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  @Operation(summary = "End the session that the refresh token belongs to")
  @ApiResponse(responseCode = "204", description = "Signed out (also for unknown tokens)")
  void logout(@Valid @RequestBody RefreshRequest request) {
    auth.logout(request);
  }
}
