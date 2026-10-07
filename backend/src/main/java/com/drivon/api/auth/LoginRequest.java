package com.drivon.api.auth;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/** No format rules beyond size: a wrong email and a wrong password must look the same. */
public record LoginRequest(
    @NotBlank @Size(max = 254) String email, @NotBlank @Size(max = 200) String password) {}
