package com.drivon.api.notification;

import com.drivon.api.common.security.CurrentUserId;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/device-tokens")
@Tag(name = "Devices", description = "Push notification registration for app installations")
class DeviceTokenController {

  private final DeviceTokenService devices;

  DeviceTokenController(DeviceTokenService devices) {
    this.devices = devices;
  }

  @PutMapping
  @ResponseStatus(HttpStatus.NO_CONTENT)
  @Operation(
      summary = "Register this installation for push notifications",
      description =
          "Idempotent. Send the Firebase Cloud Messaging token after sign-in and whenever it"
              + " changes. A token registered by another account moves to this one.")
  @ApiResponse(responseCode = "204", description = "Registered")
  @ApiResponse(responseCode = "400", description = "VALIDATION_FAILED")
  void register(@CurrentUserId UUID userId, @Valid @RequestBody DeviceTokenRequest request) {
    devices.register(userId, request);
  }

  @DeleteMapping("/{token}")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  @Operation(
      summary = "Stop push notifications to this installation",
      description = "Call before signing out. Idempotent: unknown tokens are ignored.")
  @ApiResponse(responseCode = "204", description = "Unregistered")
  @ApiResponse(responseCode = "400", description = "VALIDATION_FAILED")
  void unregister(
      @CurrentUserId UUID userId,
      @PathVariable @Size(max = 512) @Pattern(regexp = DeviceTokenRequest.TOKEN_PATTERN) String token) {
    devices.unregister(userId, token);
  }
}
