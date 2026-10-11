package com.drivon.api.user;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/** New profile details. Same rules as registration. */
public record UpdateProfileRequest(
    @NotBlank @Size(max = 100) String name, @NotBlank @Email @Size(max = 254) String email) {}
