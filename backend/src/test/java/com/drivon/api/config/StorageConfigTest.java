package com.drivon.api.config;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.drivon.api.common.error.ErrorCode;
import com.drivon.api.common.storage.ObjectStorage;
import com.drivon.api.common.storage.PresignedRequest;
import com.drivon.api.common.storage.R2ObjectStorage;
import com.drivon.api.common.storage.StorageUnavailableException;
import com.drivon.api.common.storage.UnconfiguredObjectStorage;
import java.net.URI;
import java.time.Duration;
import java.time.Instant;
import org.junit.jupiter.api.Test;

class StorageConfigTest {

  private static final String KEY = "users/u1/vehicles/v1/documents/d1.jpg";

  private static R2Properties properties(String accountId, String bucket) {
    return new R2Properties(
        accountId,
        "test-access-key",
        "test-secret-key",
        bucket,
        null,
        Duration.ofMinutes(10),
        Duration.ofMinutes(5));
  }

  @Test
  void usesTheUnconfiguredStorageWhenCredentialsAreMissing() {
    ObjectStorage storage = new StorageConfig().objectStorage(properties("abc123", " "));

    assertThat(storage).isInstanceOf(UnconfiguredObjectStorage.class);
    assertThatThrownBy(() -> storage.presignUpload(KEY, "image/jpeg", 10))
        .isInstanceOfSatisfying(
            StorageUnavailableException.class,
            e -> assertThat(e.code()).isEqualTo(ErrorCode.STORAGE_UNAVAILABLE));
  }

  @Test
  void derivesTheR2EndpointFromTheAccountId() {
    assertThat(properties("abc123", "docs").resolvedEndpoint())
        .isEqualTo(URI.create("https://abc123.r2.cloudflarestorage.com"));
  }

  @Test
  void signsUploadsForOneContentTypeAndLength() throws Exception {
    try (R2ObjectStorage storage =
        (R2ObjectStorage) new StorageConfig().objectStorage(properties("abc123", "docs"))) {
      Instant before = Instant.now();

      PresignedRequest upload = storage.presignUpload(KEY, "image/jpeg", 123_456);

      assertThat(upload.method()).isEqualTo("PUT");
      assertThat(upload.url().getHost()).isEqualTo("abc123.r2.cloudflarestorage.com");
      assertThat(upload.url().getPath()).isEqualTo("/docs/" + KEY);
      assertThat(upload.url().getQuery())
          .contains("X-Amz-Expires=600")
          .contains("X-Amz-SignedHeaders=content-length;content-type;host")
          // A checksum parameter would force clients to send a matching checksum header.
          .doesNotContainIgnoringCase("checksum");
      assertThat(upload.headers())
          .containsEntry("content-type", "image/jpeg")
          .containsEntry("content-length", "123456")
          .doesNotContainKey("host");
      assertThat(upload.expiresAt())
          .isBetween(before.plus(Duration.ofMinutes(9)), before.plus(Duration.ofMinutes(11)));
    }
  }

  @Test
  void signsShortLivedDownloadsThatOpenInline() throws Exception {
    try (R2ObjectStorage storage =
        (R2ObjectStorage) new StorageConfig().objectStorage(properties("abc123", "docs"))) {
      PresignedRequest download = storage.presignDownload(KEY, "insurance.pdf");

      assertThat(download.method()).isEqualTo("GET");
      assertThat(download.url().getQuery())
          .contains("X-Amz-Expires=300")
          .contains("response-content-disposition=inline; filename=\"insurance.pdf\"");
      assertThat(download.headers()).isEmpty();
    }
  }
}
