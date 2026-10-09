package com.drivon.api.common.storage;

import java.net.URISyntaxException;
import java.time.Duration;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import software.amazon.awssdk.core.exception.SdkException;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.DeleteObjectRequest;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.model.HeadObjectRequest;
import software.amazon.awssdk.services.s3.model.HeadObjectResponse;
import software.amazon.awssdk.services.s3.model.NoSuchKeyException;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.model.S3Exception;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;

/**
 * {@link ObjectStorage} on a Cloudflare R2 bucket through its S3-compatible API. Clients and
 * presigners are built in {@code StorageConfig}.
 */
public final class R2ObjectStorage implements ObjectStorage, AutoCloseable {

  private static final Logger log = LoggerFactory.getLogger(R2ObjectStorage.class);

  private static final String UNREACHABLE = "File storage can't be reached. Try again shortly.";

  private final S3Client client;
  private final S3Presigner presigner;
  private final String bucket;
  private final Duration uploadTtl;
  private final Duration downloadTtl;

  public R2ObjectStorage(
      S3Client client,
      S3Presigner presigner,
      String bucket,
      Duration uploadTtl,
      Duration downloadTtl) {
    this.client = client;
    this.presigner = presigner;
    this.bucket = bucket;
    this.uploadTtl = uploadTtl;
    this.downloadTtl = downloadTtl;
  }

  @Override
  public PresignedRequest presignUpload(String key, String contentType, long contentLength) {
    PutObjectRequest put =
        PutObjectRequest.builder()
            .bucket(bucket)
            .key(key)
            .contentType(contentType)
            .contentLength(contentLength)
            .build();
    return toPresigned(
        presigner.presignPutObject(
            request -> request.signatureDuration(uploadTtl).putObjectRequest(put)),
        "PUT");
  }

  @Override
  public PresignedRequest presignDownload(String key, String fileName) {
    GetObjectRequest get =
        GetObjectRequest.builder()
            .bucket(bucket)
            .key(key)
            .responseContentDisposition("inline; filename=\"" + fileName + "\"")
            .build();
    return toPresigned(
        presigner.presignGetObject(
            request -> request.signatureDuration(downloadTtl).getObjectRequest(get)),
        "GET");
  }

  @Override
  public Optional<StoredObject> head(String key) {
    try {
      HeadObjectResponse response =
          client.headObject(HeadObjectRequest.builder().bucket(bucket).key(key).build());
      return Optional.of(new StoredObject(response.contentLength(), response.contentType()));
    } catch (NoSuchKeyException e) {
      return Optional.empty();
    } catch (S3Exception e) {
      if (e.statusCode() == 404) {
        return Optional.empty();
      }
      throw unavailable("HEAD", e);
    } catch (SdkException e) {
      throw unavailable("HEAD", e);
    }
  }

  @Override
  public void delete(String key) {
    try {
      client.deleteObject(DeleteObjectRequest.builder().bucket(bucket).key(key).build());
    } catch (SdkException e) {
      throw unavailable("DELETE", e);
    }
  }

  @Override
  public void close() {
    presigner.close();
    client.close();
  }

  /** Copies the signed URL and the headers the client must repeat (the SDK adds Host itself). */
  private static PresignedRequest toPresigned(
      software.amazon.awssdk.awscore.presigner.PresignedRequest presigned, String method) {
    Map<String, String> headers = new LinkedHashMap<>();
    for (Map.Entry<String, List<String>> header : presigned.signedHeaders().entrySet()) {
      if (!header.getKey().equalsIgnoreCase("host")) {
        headers.put(header.getKey(), String.join(",", header.getValue()));
      }
    }
    try {
      return new PresignedRequest(
          presigned.url().toURI(), method, Map.copyOf(headers), presigned.expiration());
    } catch (URISyntaxException e) {
      throw new IllegalStateException("The SDK produced an invalid presigned URL", e);
    }
  }

  private static StorageUnavailableException unavailable(String operation, SdkException e) {
    // The message names the operation and SDK error type only, never keys or credentials.
    log.warn("R2 {} failed: {}", operation, e.getClass().getSimpleName());
    return new StorageUnavailableException(UNREACHABLE, e);
  }
}
