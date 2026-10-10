package com.drivon.api.document;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.drivon.api.common.error.DrivonException;
import com.drivon.api.common.error.ErrorCode;
import com.drivon.api.common.storage.ObjectStorage;
import com.drivon.api.common.storage.PresignedRequest;
import com.drivon.api.common.storage.StorageUnavailableException;
import com.drivon.api.common.storage.StoredObject;
import com.drivon.api.common.time.BusinessCalendar;
import com.drivon.api.common.web.CreateResult;
import com.drivon.api.document.Document.DocumentDetails;
import com.drivon.api.document.Document.StoredFile;
import com.drivon.api.vehicle.VehicleDeletingEvent;
import com.drivon.api.vehicle.VehicleService;
import java.net.URI;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.context.ApplicationEventPublisher;

class DocumentServiceTest {

  private static final UUID USER = UUID.randomUUID();
  private static final UUID VEHICLE = UUID.randomUUID();
  // 10:00 on 7 October in Colombo.
  private static final Clock CLOCK =
      Clock.fixed(Instant.parse("2026-10-07T04:30:00Z"), ZoneOffset.UTC);
  private static final LocalDate TODAY = LocalDate.of(2026, 10, 7);
  private static final PresignedRequest UPLOAD_URL =
      new PresignedRequest(
          URI.create("https://storage.example/upload"),
          "PUT",
          Map.of("content-type", "image/jpeg"),
          Instant.parse("2026-10-07T04:40:00Z"));

  private final DocumentRepository documents = mock(DocumentRepository.class);
  private final VehicleService vehicles = mock(VehicleService.class);
  private final ObjectStorage storage = mock(ObjectStorage.class);
  private final ApplicationEventPublisher events = mock(ApplicationEventPublisher.class);
  private final DocumentService service =
      new DocumentService(documents, vehicles, storage, new BusinessCalendar(CLOCK), CLOCK, events);

  @BeforeEach
  void setUp() {
    when(documents.saveAndFlush(any())).thenAnswer(invocation -> invocation.getArgument(0));
    when(storage.presignUpload(anyString(), anyString(), anyLong())).thenReturn(UPLOAD_URL);
  }

  private static DocumentUploadRequest upload(UUID id, String contentType, long size) {
    return new DocumentUploadRequest(
        id,
        DocumentType.INSURANCE,
        LocalDate.of(2026, 3, 1),
        LocalDate.of(2027, 2, 28),
        "  Ceylinco comprehensive  ",
        contentType,
        size);
  }

  private static Document document(UUID id, boolean active) {
    Document document =
        new Document(
            id,
            VEHICLE,
            new DocumentDetails(
                DocumentType.REVENUE_LICENCE,
                LocalDate.of(2026, 3, 1),
                LocalDate.of(2027, 3, 1),
                null),
            new StoredFile(
                DocumentService.objectKey(USER, VEHICLE, id, DocumentFileType.PDF),
                DocumentFileType.PDF,
                200_000));
    if (active) {
      document.activate();
    }
    return document;
  }

  private static ErrorCode codeOf(Throwable error) {
    return ((DrivonException) error).code();
  }

  @Test
  void startsAPendingUploadUnderAKeyWithoutTheOriginalFileName() {
    UUID id = UUID.randomUUID();

    CreateResult<DocumentUploadResponse> result =
        service.startUpload(USER, VEHICLE, upload(id, "image/jpeg", 812_345));

    String key = "users/" + USER + "/vehicles/" + VEHICLE + "/documents/" + id + ".jpg";
    assertThat(result.created()).isTrue();
    assertThat(result.record().document().status()).isEqualTo(DocumentStatus.PENDING);
    assertThat(result.record().document().notes()).isEqualTo("Ceylinco comprehensive");
    assertThat(result.record().upload().url()).isEqualTo(UPLOAD_URL.url());
    verify(storage).presignUpload(key, "image/jpeg", 812_345);
  }

  @Test
  void normalizesTheContentTypeBeforeSigning() {
    service.startUpload(USER, VEHICLE, upload(UUID.randomUUID(), "Application/PDF; q=1", 10));

    verify(storage).presignUpload(any(), eq("application/pdf"), eq(10L));
  }

  @Test
  void resendingAnIdResumesThePendingUploadWithAFreshUrl() {
    UUID id = UUID.randomUUID();
    Document pending = document(id, false);
    when(documents.findById(id)).thenReturn(Optional.of(pending));

    CreateResult<DocumentUploadResponse> result =
        service.startUpload(USER, VEHICLE, upload(id, "image/jpeg", 1));

    assertThat(result.created()).isFalse();
    assertThat(result.record().upload()).isNotNull();
    // Signed for the file announced first, not the one in the retry.
    verify(storage).presignUpload(pending.getFileKey(), "application/pdf", 200_000);
    verify(documents, never()).saveAndFlush(any());
  }

  @Test
  void resendingAnIdAfterConfirmingReturnsTheDocumentWithoutAnUpload() {
    UUID id = UUID.randomUUID();
    when(documents.findById(id)).thenReturn(Optional.of(document(id, true)));

    CreateResult<DocumentUploadResponse> result =
        service.startUpload(USER, VEHICLE, upload(id, "image/jpeg", 1));

    assertThat(result.created()).isFalse();
    assertThat(result.record().upload()).isNull();
    verifyNoInteractions(storage);
  }

  @Test
  void anIdUsedUnderAnotherVehicleConflicts() {
    UUID id = UUID.randomUUID();
    Document elsewhere = document(id, true);
    when(documents.findById(id)).thenReturn(Optional.of(elsewhere));

    assertThatThrownBy(
            () -> service.startUpload(USER, UUID.randomUUID(), upload(id, "image/jpeg", 1)))
        .extracting(DocumentServiceTest::codeOf)
        .isEqualTo(ErrorCode.RECORD_ID_CONFLICT);
  }

  @ParameterizedTest
  @ValueSource(strings = {"image/gif", "image/heic", "text/plain", "application/octet-stream"})
  void rejectsFileTypesOtherThanJpegPngAndPdf(String contentType) {
    assertThatThrownBy(
            () -> service.startUpload(USER, VEHICLE, upload(UUID.randomUUID(), contentType, 10)))
        .isInstanceOfSatisfying(
            DrivonException.class,
            e -> {
              assertThat(e.code()).isEqualTo(ErrorCode.UNSUPPORTED_FILE_TYPE);
              assertThat(e.properties())
                  .containsEntry(
                      "allowedContentTypes", List.of("image/jpeg", "image/png", "application/pdf"));
            });
    verifyNoInteractions(storage);
  }

  @Test
  void acceptsFilesUpToFiveMegabytes() {
    service.startUpload(USER, VEHICLE, upload(UUID.randomUUID(), "image/png", 5_242_880));

    assertThatThrownBy(
            () ->
                service.startUpload(
                    USER, VEHICLE, upload(UUID.randomUUID(), "image/png", 5_242_881)))
        .isInstanceOfSatisfying(
            DrivonException.class,
            e -> {
              assertThat(e.code()).isEqualTo(ErrorCode.FILE_TOO_LARGE);
              assertThat(e.properties()).containsEntry("maxBytes", 5_242_880L);
            });
  }

  @Test
  void theExpiryDateMustBeAfterTheIssueDate() {
    DocumentUploadRequest sameDay =
        new DocumentUploadRequest(
            null,
            DocumentType.INSURANCE,
            LocalDate.of(2026, 3, 1),
            LocalDate.of(2026, 3, 1),
            null,
            "image/jpeg",
            10);

    assertThatThrownBy(() -> service.startUpload(USER, VEHICLE, sameDay))
        .extracting(DocumentServiceTest::codeOf)
        .isEqualTo(ErrorCode.DOCUMENT_DATES_INVALID);
  }

  @Test
  void eitherDateMayBeLeftOut() {
    DocumentUploadRequest receipt =
        new DocumentUploadRequest(
            null, DocumentType.RECEIPT, null, null, "   ", "application/pdf", 10);

    DocumentResponse saved = service.startUpload(USER, VEHICLE, receipt).record().document();

    assertThat(saved.issueDate()).isNull();
    assertThat(saved.expiryDate()).isNull();
    assertThat(saved.notes()).isNull();
  }

  @Test
  void aVehicleHoldsAtMostOneHundredDocuments() {
    when(documents.countByVehicleId(VEHICLE)).thenReturn(100L);

    assertThatThrownBy(
            () -> service.startUpload(USER, VEHICLE, upload(UUID.randomUUID(), "image/jpeg", 1)))
        .extracting(DocumentServiceTest::codeOf)
        .isEqualTo(ErrorCode.DOCUMENT_LIMIT_REACHED);
  }

  @Test
  void removesUploadsAbandonedForADayBeforeStartingANewOne() {
    Document abandoned = document(UUID.randomUUID(), false);
    when(documents.findByVehicleIdAndStatusAndCreatedAtBefore(
            VEHICLE, DocumentStatus.PENDING, Instant.parse("2026-10-06T04:30:00Z")))
        .thenReturn(List.of(abandoned));

    service.startUpload(USER, VEHICLE, upload(UUID.randomUUID(), "image/jpeg", 1));

    verify(documents).deleteAll(List.of(abandoned));
    verify(storage).delete(abandoned.getFileKey());
  }

  @Test
  void anotherUsersVehicleIsNotFoundAndNothingIsSigned() {
    when(vehicles.requireOwned(USER, VEHICLE))
        .thenThrow(new DrivonException(ErrorCode.VEHICLE_NOT_FOUND));

    assertThatThrownBy(
            () -> service.startUpload(USER, VEHICLE, upload(UUID.randomUUID(), "image/jpeg", 1)))
        .extracting(DocumentServiceTest::codeOf)
        .isEqualTo(ErrorCode.VEHICLE_NOT_FOUND);
    verifyNoInteractions(storage, documents);
  }

  @Test
  void storageOutagesSurfaceAsUnavailable() {
    when(storage.presignUpload(anyString(), anyString(), anyLong()))
        .thenThrow(new StorageUnavailableException("down"));

    assertThatThrownBy(
            () -> service.startUpload(USER, VEHICLE, upload(UUID.randomUUID(), "image/jpeg", 1)))
        .extracting(DocumentServiceTest::codeOf)
        .isEqualTo(ErrorCode.STORAGE_UNAVAILABLE);
  }

  @Test
  void confirmingActivatesTheDocumentWhenTheStoredFileMatches() {
    UUID id = UUID.randomUUID();
    Document pending = document(id, false);
    when(documents.findByIdAndVehicleId(id, VEHICLE)).thenReturn(Optional.of(pending));
    when(storage.head(pending.getFileKey()))
        .thenReturn(Optional.of(new StoredObject(200_000, "application/pdf")));

    DocumentResponse confirmed = service.confirmUpload(USER, VEHICLE, id);

    assertThat(confirmed.status()).isEqualTo(DocumentStatus.ACTIVE);
  }

  @Test
  void confirmingBeforeTheFileArrivedAsksForTheUpload() {
    UUID id = UUID.randomUUID();
    Document pending = document(id, false);
    when(documents.findByIdAndVehicleId(id, VEHICLE)).thenReturn(Optional.of(pending));
    when(storage.head(pending.getFileKey())).thenReturn(Optional.empty());

    assertThatThrownBy(() -> service.confirmUpload(USER, VEHICLE, id))
        .extracting(DocumentServiceTest::codeOf)
        .isEqualTo(ErrorCode.UPLOAD_NOT_FOUND);
    assertThat(pending.isActive()).isFalse();
  }

  @Test
  void aStoredFileOfAnotherSizeIsDeletedAndRejected() {
    UUID id = UUID.randomUUID();
    Document pending = document(id, false);
    when(documents.findByIdAndVehicleId(id, VEHICLE)).thenReturn(Optional.of(pending));
    when(storage.head(pending.getFileKey()))
        .thenReturn(Optional.of(new StoredObject(9_000_000, "application/pdf")));

    assertThatThrownBy(() -> service.confirmUpload(USER, VEHICLE, id))
        .extracting(DocumentServiceTest::codeOf)
        .isEqualTo(ErrorCode.UPLOAD_MISMATCH);
    verify(storage).delete(pending.getFileKey());
    assertThat(pending.isActive()).isFalse();
  }

  @Test
  void aStoredFileOfAnotherTypeIsDeletedAndRejected() {
    UUID id = UUID.randomUUID();
    Document pending = document(id, false);
    when(documents.findByIdAndVehicleId(id, VEHICLE)).thenReturn(Optional.of(pending));
    when(storage.head(pending.getFileKey()))
        .thenReturn(Optional.of(new StoredObject(200_000, "text/html")));

    assertThatThrownBy(() -> service.confirmUpload(USER, VEHICLE, id))
        .extracting(DocumentServiceTest::codeOf)
        .isEqualTo(ErrorCode.UPLOAD_MISMATCH);
    verify(storage).delete(pending.getFileKey());
  }

  @Test
  void confirmingTwiceIsHarmless() {
    UUID id = UUID.randomUUID();
    when(documents.findByIdAndVehicleId(id, VEHICLE)).thenReturn(Optional.of(document(id, true)));

    assertThat(service.confirmUpload(USER, VEHICLE, id).status()).isEqualTo(DocumentStatus.ACTIVE);
    verifyNoInteractions(storage);
  }

  @Test
  void pendingDocumentsCantBeReadEditedOrDownloaded() {
    UUID id = UUID.randomUUID();
    when(documents.findByIdAndVehicleId(id, VEHICLE)).thenReturn(Optional.of(document(id, false)));
    DocumentRequest edit = new DocumentRequest(DocumentType.OTHER, null, null, null);

    assertThatThrownBy(() -> service.get(USER, VEHICLE, id))
        .extracting(DocumentServiceTest::codeOf)
        .isEqualTo(ErrorCode.DOCUMENT_NOT_FOUND);
    assertThatThrownBy(() -> service.update(USER, VEHICLE, id, edit))
        .extracting(DocumentServiceTest::codeOf)
        .isEqualTo(ErrorCode.DOCUMENT_NOT_FOUND);
    assertThatThrownBy(() -> service.downloadUrl(USER, VEHICLE, id))
        .extracting(DocumentServiceTest::codeOf)
        .isEqualTo(ErrorCode.DOCUMENT_NOT_FOUND);
  }

  @Test
  void editingChangesTheDetailsButNotTheFile() {
    UUID id = UUID.randomUUID();
    Document active = document(id, true);
    when(documents.findByIdAndVehicleId(id, VEHICLE)).thenReturn(Optional.of(active));

    DocumentResponse edited =
        service.update(
            USER,
            VEHICLE,
            id,
            new DocumentRequest(
                DocumentType.INSURANCE, null, LocalDate.of(2027, 1, 1), " Renewed "));

    assertThat(edited.type()).isEqualTo(DocumentType.INSURANCE);
    assertThat(edited.issueDate()).isNull();
    assertThat(edited.notes()).isEqualTo("Renewed");
    assertThat(edited.contentType()).isEqualTo("application/pdf");
    assertThat(edited.sizeBytes()).isEqualTo(200_000);
  }

  @Test
  void downloadsUseAReadableFileName() {
    UUID id = UUID.randomUUID();
    Document active = document(id, true);
    when(documents.findByIdAndVehicleId(id, VEHICLE)).thenReturn(Optional.of(active));
    when(storage.presignDownload(active.getFileKey(), "revenue-licence-2026-03-01.pdf"))
        .thenReturn(
            new PresignedRequest(
                URI.create("https://storage.example/get"),
                "GET",
                Map.of(),
                Instant.parse("2026-10-07T04:35:00Z")));

    PresignedUrlResponse url = service.downloadUrl(USER, VEHICLE, id);

    assertThat(url.method()).isEqualTo("GET");
    assertThat(url.url()).isEqualTo(URI.create("https://storage.example/get"));
  }

  @Test
  void deletingRemovesTheRowAndTheFile() {
    UUID id = UUID.randomUUID();
    Document pending = document(id, false);
    when(documents.findByIdAndVehicleId(id, VEHICLE)).thenReturn(Optional.of(pending));

    service.delete(USER, VEHICLE, id);

    verify(documents).delete(pending);
    verify(storage).delete(pending.getFileKey());
  }

  @Test
  void aFailedFileDeletionDoesNotFailTheRequest() {
    UUID id = UUID.randomUUID();
    Document active = document(id, true);
    when(documents.findByIdAndVehicleId(id, VEHICLE)).thenReturn(Optional.of(active));
    doThrow(new StorageUnavailableException("down")).when(storage).delete(active.getFileKey());

    service.delete(USER, VEHICLE, id);

    verify(documents).delete(active);
  }

  @Test
  void deletingAVehicleDeletesItsFiles() {
    when(documents.findFileKeysByVehicleId(VEHICLE)).thenReturn(List.of("a.jpg", "b.pdf"));

    service.onVehicleDeleting(new VehicleDeletingEvent(VEHICLE));

    verify(storage).delete("a.jpg");
    verify(storage).delete("b.pdf");
  }

  @Test
  void expiringCountsDaysFromTodayInColombo() {
    service.expiring(USER, 30);

    verify(documents).findExpiring(USER, TODAY.plusDays(30));
  }
}
