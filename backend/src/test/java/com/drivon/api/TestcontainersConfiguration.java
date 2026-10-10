package com.drivon.api;

import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.context.annotation.Bean;
import org.springframework.test.context.DynamicPropertyRegistrar;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.containers.wait.strategy.Wait;
import org.testcontainers.postgresql.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;

/**
 * Runs tests against the same Postgres major version as production (Neon, Postgres 17), and against
 * S3Mock, a local S3-compatible server, in place of Cloudflare R2. Tests never reach a real bucket.
 */
@TestConfiguration(proxyBeanMethods = false)
public class TestcontainersConfiguration {

  public static final String POSTGRES_IMAGE = "postgres:17.11-alpine";

  public static final String S3MOCK_IMAGE = "adobe/s3mock:5.2.3";

  public static final String DOCUMENTS_BUCKET = "drivon-test-documents";

  private static final int S3MOCK_HTTP_PORT = 9090;

  @Bean
  @ServiceConnection
  PostgreSQLContainer postgresContainer() {
    return new PostgreSQLContainer(DockerImageName.parse(POSTGRES_IMAGE));
  }

  @Bean
  GenericContainer<?> s3MockContainer() {
    return new GenericContainer<>(DockerImageName.parse(S3MOCK_IMAGE))
        .withExposedPorts(S3MOCK_HTTP_PORT)
        .withEnv("COM_ADOBE_TESTING_S3MOCK_STORE_INITIAL_BUCKETS", DOCUMENTS_BUCKET)
        .waitingFor(Wait.forHttp("/").forPort(S3MOCK_HTTP_PORT));
  }

  /** Points the R2 client at S3Mock; it accepts any credentials. */
  @Bean
  DynamicPropertyRegistrar s3MockProperties(GenericContainer<?> s3MockContainer) {
    return registry -> {
      registry.add(
          "drivon.storage.r2.endpoint",
          () ->
              "http://"
                  + s3MockContainer.getHost()
                  + ":"
                  + s3MockContainer.getMappedPort(S3MOCK_HTTP_PORT));
      registry.add("drivon.storage.r2.access-key-id", () -> "test-access-key");
      registry.add("drivon.storage.r2.secret-access-key", () -> "test-secret-key");
      registry.add("drivon.storage.r2.bucket", () -> DOCUMENTS_BUCKET);
    };
  }
}
