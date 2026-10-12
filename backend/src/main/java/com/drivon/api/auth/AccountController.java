package com.drivon.api.auth;

import com.drivon.api.common.security.CurrentUserId;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * Account actions that need the password again. Lives with authentication because it checks
 * passwords; the path belongs to the user's own resource.
 */
@RestController
@RequestMapping("/api/v1/users/me")
@Tag(name = "Users")
class AccountController {

  private final AuthService auth;
  private final AuthRateLimiter rateLimiter;

  AccountController(AuthService auth, AuthRateLimiter rateLimiter) {
    this.auth = auth;
    this.rateLimiter = rateLimiter;
  }

  /**
   * A POST rather than a DELETE with a body, because a body on DELETE has no defined meaning and
   * some proxies drop it.
   */
  @PostMapping("/deletion")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  @Operation(
      operationId = "deleteAccount",
      summary = "Delete the signed-in user's account",
      description =
          "Permanently deletes the account with its vehicles, records, documents and sessions."
              + " Needs the account's password.")
  @ApiResponse(responseCode = "204", description = "Account deleted")
  @ApiResponse(responseCode = "400", description = "VALIDATION_FAILED")
  @ApiResponse(responseCode = "401", description = "UNAUTHENTICATED")
  @ApiResponse(responseCode = "422", description = "PASSWORD_INCORRECT")
  @ApiResponse(responseCode = "429", description = "RATE_LIMITED")
  void delete(@CurrentUserId UUID userId, @Valid @RequestBody DeleteAccountRequest request) {
    // Per account, so a stolen access token can't be used to guess the password quickly.
    rateLimiter.consume("account-deletion:" + userId);
    auth.deleteAccount(userId, request);
  }
}
