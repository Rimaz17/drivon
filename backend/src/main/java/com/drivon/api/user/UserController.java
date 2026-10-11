package com.drivon.api.user;

import com.drivon.api.common.security.CurrentUserId;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.UUID;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/users")
@Tag(name = "Users", description = "The signed-in user's account")
class UserController {

  private final UserService users;

  UserController(UserService users) {
    this.users = users;
  }

  @GetMapping("/me")
  @Operation(summary = "Get the signed-in user's profile")
  @ApiResponse(responseCode = "200", description = "Profile")
  @ApiResponse(responseCode = "401", description = "UNAUTHENTICATED")
  UserResponse me(@CurrentUserId UUID userId) {
    return users.getProfile(userId);
  }

  @PutMapping("/me")
  @Operation(summary = "Update the signed-in user's name and email")
  @ApiResponse(responseCode = "200", description = "Updated profile")
  @ApiResponse(responseCode = "400", description = "VALIDATION_FAILED")
  @ApiResponse(responseCode = "401", description = "UNAUTHENTICATED")
  @ApiResponse(responseCode = "409", description = "EMAIL_ALREADY_REGISTERED")
  UserResponse update(
      @CurrentUserId UUID userId, @Valid @RequestBody UpdateProfileRequest request) {
    return users.updateProfile(userId, request);
  }
}
