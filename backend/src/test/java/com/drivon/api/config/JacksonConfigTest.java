package com.drivon.api.config;

import static org.assertj.core.api.Assertions.assertThat;

import java.math.BigDecimal;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.json.JsonMapper;

class JacksonConfigTest {

  private final JsonMapper mapper =
      JsonMapper.builder().addModule(new JacksonConfig().decimalsAsStringsModule()).build();

  record Amount(BigDecimal value) {}

  @Test
  void writesDecimalsAsPlainStrings() {
    assertThat(mapper.writeValueAsString(new Amount(new BigDecimal("18500.00"))))
        .isEqualTo("{\"value\":\"18500.00\"}");
    assertThat(mapper.writeValueAsString(new Amount(new BigDecimal("1E+3"))))
        .isEqualTo("{\"value\":\"1000\"}");
  }

  @Test
  void readsDecimalsFromStringsAndNumbers() {
    assertThat(mapper.readValue("{\"value\":\"365.50\"}", Amount.class).value())
        .isEqualByComparingTo("365.50");
    assertThat(mapper.readValue("{\"value\":365.5}", Amount.class).value())
        .isEqualByComparingTo("365.50");
  }
}
