package com.drivon.api.config;

import com.drivon.api.common.error.ErrorCode;
import com.drivon.api.common.error.GlobalExceptionHandler;
import com.drivon.api.common.security.CurrentUserId;
import com.drivon.api.common.web.RequestIdFilter;
import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.ExternalDocumentation;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.info.License;
import io.swagger.v3.oas.models.media.ArraySchema;
import io.swagger.v3.oas.models.media.Content;
import io.swagger.v3.oas.models.media.IntegerSchema;
import io.swagger.v3.oas.models.media.MediaType;
import io.swagger.v3.oas.models.media.ObjectSchema;
import io.swagger.v3.oas.models.media.Schema;
import io.swagger.v3.oas.models.media.StringSchema;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import io.swagger.v3.oas.models.security.SecurityScheme;
import io.swagger.v3.oas.models.tags.Tag;
import java.math.BigDecimal;
import java.util.Arrays;
import java.util.Comparator;
import java.util.List;
import org.springdoc.core.customizers.OpenApiCustomizer;
import org.springdoc.core.utils.SpringDocUtils;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * OpenAPI metadata served at {@code /v3/api-docs} and rendered by Swagger UI. A copy is committed
 * as {@code docs/api/openapi.json}; {@code OpenApiSpecIntegrationTest} keeps it current.
 */
@Configuration
public class OpenApiConfig {

  static final String BEARER_AUTH = "bearerAuth";

  static final String PROBLEM_SCHEMA = "Problem";

  private static final String PROBLEM_MEDIA_TYPE = "application/problem+json";

  /** Swagger UI's group order: the user's journey through the app, then the plumbing. */
  private static final List<String> TAG_ORDER =
      List.of(
          "Authentication",
          "Users",
          "Vehicles",
          "Odometer",
          "Fuel",
          "Maintenance",
          "Expenses",
          "Spending",
          "Analytics",
          "Documents",
          "Reminders",
          "Ask My Vehicle",
          "Devices",
          "Jobs");

  static {
    // Filled from the access token, so it is not a client-facing parameter.
    SpringDocUtils.getConfig().addAnnotationsToIgnore(CurrentUserId.class);
    // Decimals travel as strings (see JacksonConfig).
    SpringDocUtils.getConfig()
        .replaceWithSchema(
            BigDecimal.class, new StringSchema().format("decimal").example("18500.00"));
  }

  @Bean
  OpenAPI drivonOpenApi(@Value("${info.app.version:dev}") String version) {
    return new OpenAPI()
        .info(
            new Info()
                .title("Drivon API")
                .version(version)
                .description(
                    "REST API for Drivon, a personal vehicle companion: vehicles, fuel,"
                        + " maintenance, expenses, analytics, documents, reminders and the Ask My"
                        + " Vehicle assistant. Endpoints outside Authentication need a bearer"
                        + " access token (the internal job uses a shared secret instead), and every"
                        + " error is an RFC 9457 Problem Details body with a stable `code`.")
                .license(new License().name("MIT")))
        .externalDocs(
            new ExternalDocumentation()
                .description("Source code and documentation")
                .url("https://github.com/Rimaz17/drivon"))
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

  /**
   * Fixes what annotations can't express once: every 4xx/5xx response is a Problem Details body (by
   * default springdoc would show the operation's success schema), and tags follow {@link
   * #TAG_ORDER} instead of class-scanning order, which differs between machines.
   */
  @Bean
  OpenApiCustomizer drivonOpenApiCustomizer() {
    return openApi -> {
      openApi.getComponents().addSchemas(PROBLEM_SCHEMA, problemSchema());
      Content problemContent =
          new Content()
              .addMediaType(
                  PROBLEM_MEDIA_TYPE,
                  new MediaType()
                      .schema(new Schema<>().$ref("#/components/schemas/" + PROBLEM_SCHEMA)));
      openApi.getPaths().values().stream()
          .flatMap(path -> path.readOperations().stream())
          .flatMap(operation -> operation.getResponses().entrySet().stream())
          .filter(
              response -> response.getKey().startsWith("4") || response.getKey().startsWith("5"))
          .forEach(response -> response.getValue().setContent(problemContent));
      if (openApi.getTags() != null) {
        openApi.setTags(
            openApi.getTags().stream()
                .sorted(Comparator.comparingInt(OpenApiConfig::tagRank).thenComparing(Tag::getName))
                .toList());
      }
    };
  }

  private static int tagRank(Tag tag) {
    int rank = TAG_ORDER.indexOf(tag.getName());
    return rank < 0 ? TAG_ORDER.size() : rank;
  }

  private static Schema<?> problemSchema() {
    List<String> codes = Arrays.stream(ErrorCode.values()).map(Enum::name).toList();
    Schema<?> fieldError =
        new ObjectSchema()
            .addProperty("field", new StringSchema().example("litres"))
            .addProperty("message", new StringSchema().example("must be greater than 0"));
    Schema<?> problem =
        new ObjectSchema()
            .description(
                "RFC 9457 Problem Details. Branch on `code`; some rules add members such as"
                    + " `minKm` or `maxBytes` to explain the limit.")
            .addProperty("title", new StringSchema().example("Validation failed"))
            .addProperty("status", new IntegerSchema().example(400))
            .addProperty("detail", new StringSchema().example("One or more fields are invalid."))
            .addProperty(
                "instance", new StringSchema().format("uri-reference").example("/api/v1/vehicles"))
            .addProperty(
                GlobalExceptionHandler.CODE,
                new StringSchema()
                    ._enum(codes)
                    .description("Stable, machine-readable error code")
                    .example(ErrorCode.VALIDATION_FAILED.name()))
            .addProperty(
                GlobalExceptionHandler.REQUEST_ID,
                new StringSchema()
                    .description(
                        "Also in the "
                            + RequestIdFilter.HEADER
                            + " response header; quote it when reporting a problem"))
            .addProperty(
                GlobalExceptionHandler.ERRORS,
                new ArraySchema()
                    .items(fieldError)
                    .description("Field errors, only for VALIDATION_FAILED"));
    problem.setAdditionalProperties(true);
    problem.setRequired(List.of("title", "status", GlobalExceptionHandler.CODE));
    return problem;
  }
}
