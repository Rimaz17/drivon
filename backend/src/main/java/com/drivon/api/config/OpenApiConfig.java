package com.drivon.api.config;

import com.drivon.api.common.security.CurrentUserId;
import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.info.License;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import io.swagger.v3.oas.models.security.SecurityScheme;
import org.springdoc.core.utils.SpringDocUtils;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/** OpenAPI metadata served at {@code /v3/api-docs} and rendered by Swagger UI. */
@Configuration
public class OpenApiConfig {

  static final String BEARER_AUTH = "bearerAuth";

  static {
    // Filled from the access token, so it is not a client-facing parameter.
    SpringDocUtils.getConfig().addAnnotationsToIgnore(CurrentUserId.class);
  }

  @Bean
  OpenAPI drivonOpenApi(@Value("${info.app.version:dev}") String version) {
    return new OpenAPI()
        .info(
            new Info()
                .title("Drivon API")
                .version(version)
                .description(
                    "REST API for Drivon, a personal vehicle companion: fuel, maintenance,"
                        + " expenses, documents, reminders and analytics.")
                .license(new License().name("MIT")))
        .components(
            new Components()
                .addSecuritySchemes(
                    BEARER_AUTH,
                    new SecurityScheme()
                        .type(SecurityScheme.Type.HTTP)
                        .scheme("bearer")
                        .bearerFormat("JWT")))
        .addSecurityItem(new SecurityRequirement().addList(BEARER_AUTH));
  }
}
