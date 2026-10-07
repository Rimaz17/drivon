package com.drivon.api.vehicle;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;

class RegistrationNumbersTest {

  @ParameterizedTest
  @CsvSource({
    "CAB-1234, CAB-1234",
    "cab-1234, CAB-1234",
    "'  wp cab - 1234 ', WP CAB-1234",
    "'WP   CAB-1234', WP CAB-1234",
    "'BBK 1234', BBK 1234",
  })
  void normalizesCaseSpacingAndHyphens(String raw, String expected) {
    assertThat(RegistrationNumbers.normalize(raw)).isEqualTo(expected);
  }
}
