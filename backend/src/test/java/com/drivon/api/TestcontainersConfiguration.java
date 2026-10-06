package com.drivon.api;

import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.context.annotation.Bean;
import org.testcontainers.postgresql.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;

/** Runs tests against the same Postgres major version as production (Neon, Postgres 17). */
@TestConfiguration(proxyBeanMethods = false)
public class TestcontainersConfiguration {

  public static final String POSTGRES_IMAGE = "postgres:17.11-alpine";

  @Bean
  @ServiceConnection
  PostgreSQLContainer postgresContainer() {
    return new PostgreSQLContainer(DockerImageName.parse(POSTGRES_IMAGE));
  }
}
