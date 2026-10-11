package com.drivon.api.auth;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/** The account's password, asked again before deleting it. */
public record DeleteAccountRequest(@NotBlank @Size(max = 200) String password) {}
