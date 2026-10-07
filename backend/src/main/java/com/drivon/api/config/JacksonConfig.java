package com.drivon.api.config;

import java.math.BigDecimal;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import tools.jackson.core.JsonGenerator;
import tools.jackson.databind.JacksonModule;
import tools.jackson.databind.SerializationContext;
import tools.jackson.databind.module.SimpleModule;
import tools.jackson.databind.ser.std.StdSerializer;

/**
 * Writes every {@link BigDecimal} (money, litres, km/L) as a plain JSON string such as {@code
 * "18500.00"}. JSON numbers are read as binary floating point by most clients, including Dart, so
 * strings keep amounts exact end to end. Requests may send either strings or numbers.
 */
@Configuration
public class JacksonConfig {

  @Bean
  JacksonModule decimalsAsStringsModule() {
    return new SimpleModule("DecimalsAsStrings")
        .addSerializer(BigDecimal.class, new PlainDecimalSerializer());
  }

  /** Uses {@link BigDecimal#toPlainString()} so values never appear in exponent form. */
  static final class PlainDecimalSerializer extends StdSerializer<BigDecimal> {

    PlainDecimalSerializer() {
      super(BigDecimal.class);
    }

    @Override
    public void serialize(BigDecimal value, JsonGenerator generator, SerializationContext context) {
      generator.writeString(value.toPlainString());
    }
  }
}
