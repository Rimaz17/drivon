package com.drivon.api.config;

import com.drivon.api.common.storage.ObjectStorage;
import com.drivon.api.common.storage.R2ObjectStorage;
import com.drivon.api.common.storage.UnconfiguredObjectStorage;
import java.time.Duration;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.core.checksums.RequestChecksumCalculation;
import software.amazon.awssdk.core.checksums.ResponseChecksumValidation;
import software.amazon.awssdk.core.client.config.ClientOverrideConfiguration;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.S3Configuration;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;

/**
 * Builds the document storage. R2 uses the S3 API with region {@code auto}; path-style URLs work
 * against both R2 and the local stand-in used by tests. Checksums are only sent when an operation
 * requires them, which keeps presigned uploads to plain {@code PUT}s that any HTTP client can make.
 */
@Configuration
public class StorageConfig {

  private static final Logger log = LoggerFactory.getLogger(StorageConfig.class);

  private static final Region R2_REGION = Region.of("auto");

  /** Short timeouts: these calls run inside API requests, and a mobile client is waiting. */
  private static final Duration CALL_TIMEOUT = Duration.ofSeconds(10);

  private static final Duration ATTEMPT_TIMEOUT = Duration.ofSeconds(4);

  @Bean
  ObjectStorage objectStorage(R2Properties properties) {
    if (!properties.configured()) {
      log.warn("R2 is not configured (R2_* variables); document uploads are disabled");
      return new UnconfiguredObjectStorage();
    }
    StaticCredentialsProvider credentials =
        StaticCredentialsProvider.create(
            AwsBasicCredentials.create(
                properties.accessKeyId().strip(), properties.secretAccessKey().strip()));
    S3Configuration pathStyle = S3Configuration.builder().pathStyleAccessEnabled(true).build();
    S3Client client =
        S3Client.builder()
            .endpointOverride(properties.resolvedEndpoint())
            .region(R2_REGION)
            .credentialsProvider(credentials)
            .serviceConfiguration(pathStyle)
            .requestChecksumCalculation(RequestChecksumCalculation.WHEN_REQUIRED)
            .responseChecksumValidation(ResponseChecksumValidation.WHEN_REQUIRED)
            .overrideConfiguration(
                ClientOverrideConfiguration.builder()
                    .apiCallTimeout(CALL_TIMEOUT)
                    .apiCallAttemptTimeout(ATTEMPT_TIMEOUT)
                    .build())
            .build();
    S3Presigner presigner =
        S3Presigner.builder()
            .endpointOverride(properties.resolvedEndpoint())
            .region(R2_REGION)
            .credentialsProvider(credentials)
            .serviceConfiguration(pathStyle)
            .build();
    return new R2ObjectStorage(
        client,
        presigner,
        properties.bucket().strip(),
        properties.uploadUrlTtl(),
        properties.downloadUrlTtl());
  }
}
