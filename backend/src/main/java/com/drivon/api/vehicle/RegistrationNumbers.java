package com.drivon.api.vehicle;

import java.util.Locale;

/** Normalizes registration numbers so "wp cab - 1234" and "WP CAB-1234" are the same plate. */
final class RegistrationNumbers {

  private RegistrationNumbers() {}

  static String normalize(String raw) {
    return raw.strip()
        .replaceAll("\\s+", " ")
        .replaceAll("\\s*-\\s*", "-")
        .toUpperCase(Locale.ROOT);
  }
}
