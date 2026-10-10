package com.drivon.api.document;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;

import com.drivon.api.common.web.CreateResult;
import com.drivon.api.config.JacksonConfig;
import com.drivon.api.config.SecurityConfig;
import com.drivon.api.config.WebConfig;
import java.net.URI;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.assertj.MockMvcTester;

@WebMvcTest(DocumentController.class)
@Import({SecurityConfig.class, WebConfig.class, JacksonConfig.class})
class DocumentControllerTest {

  private static final UUID USER = UUID.randomUUID();
  private static final UUID VEHICLE = UUID.randomUUID();
  private static final String PATH = "/api/v1/vehicles/" + VEHICLE + "/documents";
  private static final Instant NOW = Instant.parse("2026-10-07T04:30:00Z");

  @Autowired private MockMvcTester mvc;
  @MockitoBean private DocumentService service;
  @MockitoBean private JwtDecoder jwtDecoder;

  private static DocumentResponse document(UUID id, DocumentStatus status) {
    return new DocumentResponse(
        id,
        VEHICLE,
        DocumentType.INSURANCE,
        LocalDate.of(2026, 3, 1),
        LocalDate.of(2027, 2, 28),
        null,
        "image/jpeg",
        812_345,
        status,
        NOW,
        NOW);
  }

  @Test
  void startingAnUploadReturns201WithTheUploadInstructions() {
    UUID id = UUID.randomUUID();
    PresignedUrlResponse upload =
        new PresignedUrlResponse(
            URI.create("https://storage.example/put?X-Amz-Signature=abc"),
            "PUT",
            Map.of("content-type", "image/jpeg", "content-length", "812345"),
            NOW.plusSeconds(600));
    when(service.startUpload(eq(USER), eq(VEHICLE), any()))
        .thenReturn(
            new CreateResult<>(
                new DocumentUploadResponse(document(id, DocumentStatus.PENDING), upload), true));

    assertThat(
            mvc.post()
                .uri(PATH)
                .with(jwt().jwt(token -> token.subject(USER.toString())))
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """
                    {"type": "INSURANCE", "issueDate": "2026-03-01", "expiryDate": "2027-02-28",
                     "contentType": "image/jpeg", "sizeBytes": 812345}
                    """))
        .hasStatus(HttpStatus.CREATED)
        .hasHeader(HttpHeaders.LOCATION, "http://localhost" + PATH + "/" + id)
        .bodyJson()
        .satisfies(
            json -> {
              json.assertThat().extractingPath("$.document.status").isEqualTo("PENDING");
              json.assertThat().extractingPath("$.upload.method").isEqualTo("PUT");
              json.assertThat()
                  .extractingPath("$.upload.headers.content-length")
                  .isEqualTo("812345");
            });
  }

  @Test
  void invalidUploadsAreRejectedBeforeReachingTheService() {
    assertThat(
            mvc.post()
                .uri(PATH)
                .with(jwt().jwt(token -> token.subject(USER.toString())))
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"sizeBytes\": 0}"))
        .hasStatus(HttpStatus.BAD_REQUEST)
        .bodyJson()
        .satisfies(
            json -> {
              json.assertThat().extractingPath("$.code").isEqualTo("VALIDATION_FAILED");
              // type, contentType, sizeBytes
              json.assertThat().extractingPath("$.errors.length()").isEqualTo(3);
            });
    assertThat(
            mvc.post()
                .uri(PATH)
                .with(jwt().jwt(token -> token.subject(USER.toString())))
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """
                    {"type": "PASSPORT", "contentType": "image/jpeg", "sizeBytes": 10}
                    """))
        .hasStatus(HttpStatus.BAD_REQUEST)
        .bodyJson()
        .extractingPath("$.code")
        .isEqualTo("MALFORMED_REQUEST");
    verifyNoInteractions(service);
  }

  @Test
  void confirmingReturnsTheActiveDocument() {
    UUID id = UUID.randomUUID();
    when(service.confirmUpload(USER, VEHICLE, id)).thenReturn(document(id, DocumentStatus.ACTIVE));

    assertThat(
            mvc.post()
                .uri(PATH + "/{id}/confirm", id)
                .with(jwt().jwt(token -> token.subject(USER.toString()))))
        .hasStatusOk()
        .bodyJson()
        .extractingPath("$.status")
        .isEqualTo("ACTIVE");
  }

  @Test
  void deleteReturns204() {
    UUID id = UUID.randomUUID();

    assertThat(
            mvc.delete()
                .uri(PATH + "/{id}", id)
                .with(jwt().jwt(token -> token.subject(USER.toString()))))
        .hasStatus(HttpStatus.NO_CONTENT);
    verify(service).delete(USER, VEHICLE, id);
  }

  @Test
  void expiringDefaultsToThirtyDaysAndCapsAtAYear() {
    when(service.expiring(USER, 30)).thenReturn(List.of());

    assertThat(
            mvc.get()
                .uri("/api/v1/documents/expiring")
                .with(jwt().jwt(token -> token.subject(USER.toString()))))
        .hasStatusOk();
    verify(service).expiring(USER, 30);

    assertThat(
            mvc.get()
                .uri("/api/v1/documents/expiring?withinDays=366")
                .with(jwt().jwt(token -> token.subject(USER.toString()))))
        .hasStatus(HttpStatus.BAD_REQUEST)
        .bodyJson()
        .extractingPath("$.code")
        .isEqualTo("VALIDATION_FAILED");
  }

  @Test
  void documentsNeedASignedInUser() {
    assertThat(mvc.get().uri(PATH)).hasStatus(HttpStatus.UNAUTHORIZED);
    verifyNoInteractions(service);
  }
}
