package com.drivon.api.document;

import com.drivon.api.common.error.DrivonException;
import com.drivon.api.common.error.ErrorCode;
import com.drivon.api.common.storage.ObjectStorage;
import com.drivon.api.common.storage.StoredObject;
import com.drivon.api.common.time.BusinessCalendar;
import com.drivon.api.common.web.CreateResult;
import com.drivon.api.common.web.PageResponse;
import com.drivon.api.common.web.SortOptions;
import com.drivon.api.document.Document.DocumentDetails;
import com.drivon.api.document.Document.StoredFile;
import com.drivon.api.vehicle.VehicleDeletingEvent;
import com.drivon.api.vehicle.VehicleService;
import java.time.Clock;
import java.time.Duration;
import java.time.LocalDate;
import java.util.Arrays;
import java.util.Collection;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import org.jspecify.annotations.Nullable;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.context.event.EventListener;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.domain.Sort.Direction;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

/**
 * Documents of the signed-in user's vehicles, with their files in R2. A document is created in two
 * steps: {@link #startUpload} saves it as pending and returns a presigned upload URL; after the app
 * has uploaded the file, {@link #confirmUpload} checks the object and makes the document visible.
 * Files are deleted from storage only after the database change commits. Changes to visible
 * documents publish a {@link DocumentsChangedEvent}, which keeps expiry reminders current. See
 * docs/adr/0011-documents-on-r2.md.
 */
@Service
public class DocumentService {

  static final SortOptions SORT =
      new SortOptions(
          Map.of("createdAt", "createdAt", "issueDate", "issueDate", "expiryDate", "expiryDate"),
          Sort.by(Direction.DESC, "createdAt"),
          Sort.by(Direction.DESC, "id"));

  /** Keeps one vehicle's files well inside R2's free 10 GB, even at the 5 MB maximum each. */
  static final int MAX_DOCUMENTS_PER_VEHICLE = 100;

  /** An upload not confirmed within this time is abandoned and cleaned up. */
  static final Duration PENDING_UPLOAD_LIFETIME = Duration.ofDays(1);

  private static final Logger log = LoggerFactory.getLogger(DocumentService.class);

  private final DocumentRepository documents;
  private final VehicleService vehicles;
  private final ObjectStorage storage;
  private final BusinessCalendar calendar;
  private final Clock clock;
  private final ApplicationEventPublisher events;

  DocumentService(
      DocumentRepository documents,
      VehicleService vehicles,
      ObjectStorage storage,
      BusinessCalendar calendar,
      Clock clock,
      ApplicationEventPublisher events) {
    this.documents = documents;
    this.vehicles = vehicles;
    this.storage = storage;
    this.calendar = calendar;
    this.clock = clock;
    this.events = events;
  }

  /**
   * Saves a pending document and returns where to upload its file. Resending an ID already used for
   * this vehicle returns that document: with a new upload URL while its file is missing, or without
   * one once the upload was confirmed.
   */
  @Transactional
  public CreateResult<DocumentUploadResponse> startUpload(
      UUID userId, UUID vehicleId, DocumentUploadRequest request) {
    vehicles.requireOwned(userId, vehicleId);
    Optional<Document> earlier =
        request.id() == null ? Optional.empty() : documents.findById(request.id());
    if (earlier.isPresent()) {
      Document document = earlier.get();
      if (!document.getVehicleId().equals(vehicleId)) {
        throw new DrivonException(
            ErrorCode.RECORD_ID_CONFLICT, "This ID is already used by another record.");
      }
      return new CreateResult<>(uploadResponse(document), false);
    }

    DocumentDetails details =
        validate(request.type(), request.issueDate(), request.expiryDate(), request.notes());
    DocumentFileType fileType = checkFile(request.contentType(), request.sizeBytes());
    removeAbandonedUploads(vehicleId);
    if (documents.countByVehicleId(vehicleId) >= MAX_DOCUMENTS_PER_VEHICLE) {
      throw new DrivonException(
              ErrorCode.DOCUMENT_LIMIT_REACHED,
              "A vehicle can have up to " + MAX_DOCUMENTS_PER_VEHICLE + " documents.")
          .with("maxDocuments", MAX_DOCUMENTS_PER_VEHICLE);
    }
    UUID id = request.id() != null ? request.id() : UUID.randomUUID();
    StoredFile file =
        new StoredFile(
            objectKey(userId, vehicleId, id, fileType), fileType, (int) request.sizeBytes());
    Document document = documents.saveAndFlush(new Document(id, vehicleId, details, file));
    return new CreateResult<>(uploadResponse(document), true);
  }

  /**
   * Checks the uploaded object and makes the document visible. Confirming twice is harmless. An
   * object of the wrong size or type is deleted, so the app can upload again with a fresh URL.
   */
  @Transactional
  public DocumentResponse confirmUpload(UUID userId, UUID vehicleId, UUID documentId) {
    vehicles.requireOwned(userId, vehicleId);
    Document document = findAny(vehicleId, documentId);
    if (document.isActive()) {
      return DocumentResponse.from(document);
    }
    StoredObject stored =
        storage
            .head(document.getFileKey())
            .orElseThrow(
                () ->
                    new DrivonException(
                        ErrorCode.UPLOAD_NOT_FOUND,
                        "The file hasn't arrived in storage. Upload it, then confirm again."));
    boolean sameType =
        DocumentFileType.fromContentType(stored.contentType())
            .map(type -> type.contentType().equals(document.getContentType()))
            .orElse(false);
    if (stored.sizeBytes() != document.getSizeBytes() || !sameType) {
      storage.delete(document.getFileKey());
      throw new DrivonException(
          ErrorCode.UPLOAD_MISMATCH,
          "The uploaded file doesn't match the size or type that was announced. Upload it again.");
    }
    document.activate();
    DocumentResponse confirmed = DocumentResponse.from(documents.saveAndFlush(document));
    events.publishEvent(new DocumentsChangedEvent(vehicleId));
    return confirmed;
  }

  /** A vehicle's visible documents, newest first unless sorted otherwise. */
  @Transactional(readOnly = true)
  public PageResponse<DocumentResponse> list(
      UUID userId, UUID vehicleId, @Nullable DocumentType type, Pageable pageable) {
    vehicles.requireOwned(userId, vehicleId);
    return PageResponse.of(
        documents.findActive(vehicleId, type, SORT.apply(pageable)), DocumentResponse::from);
  }

  @Transactional(readOnly = true)
  public DocumentResponse get(UUID userId, UUID vehicleId, UUID documentId) {
    vehicles.requireOwned(userId, vehicleId);
    return DocumentResponse.from(findActive(vehicleId, documentId));
  }

  /** Replaces a document's details; its file stays the same. */
  @Transactional
  public DocumentResponse update(
      UUID userId, UUID vehicleId, UUID documentId, DocumentRequest request) {
    vehicles.requireOwned(userId, vehicleId);
    Document document = findActive(vehicleId, documentId);
    document.update(
        validate(request.type(), request.issueDate(), request.expiryDate(), request.notes()));
    DocumentResponse updated = DocumentResponse.from(documents.saveAndFlush(document));
    events.publishEvent(new DocumentsChangedEvent(vehicleId));
    return updated;
  }

  /** Deletes a document (also an unfinished upload) and, once that commits, its file. */
  @Transactional
  public void delete(UUID userId, UUID vehicleId, UUID documentId) {
    vehicles.requireOwned(userId, vehicleId);
    Document document = findAny(vehicleId, documentId);
    documents.delete(document);
    documents.flush();
    deleteFilesAfterCommit(List.of(document.getFileKey()));
    events.publishEvent(new DocumentsChangedEvent(vehicleId));
  }

  /** A short-lived URL to view or save the document's file. */
  @Transactional(readOnly = true)
  public PresignedUrlResponse downloadUrl(UUID userId, UUID vehicleId, UUID documentId) {
    vehicles.requireOwned(userId, vehicleId);
    Document document = findActive(vehicleId, documentId);
    return PresignedUrlResponse.from(
        storage.presignDownload(document.getFileKey(), fileName(document)));
  }

  /**
   * The user's documents that expire within {@code withinDays} days from today, including ones that
   * already expired, soonest first.
   */
  @Transactional(readOnly = true)
  public List<DocumentResponse> expiring(UUID userId, int withinDays) {
    LocalDate until = calendar.today().plusDays(withinDays);
    return documents.findExpiring(userId, until).stream().map(DocumentResponse::from).toList();
  }

  /**
   * For each document type, the visible document that expires last; types without an expiry date
   * are left out. Older documents of a type (an expired policy that was renewed) don't count. The
   * caller must have checked that the vehicle belongs to the user.
   */
  @Transactional(readOnly = true)
  public List<DocumentExpiry> latestExpiries(UUID vehicleId) {
    return documents.findLatestExpiryOfEachType(vehicleId).stream()
        .map(d -> new DocumentExpiry(d.getType(), d.getId(), d.getExpiryDate()))
        .toList();
  }

  /**
   * Deleting a vehicle cascades to its document rows in the database; this removes their files from
   * storage once that deletion commits. Runs inside the deleting transaction.
   */
  @EventListener
  void onVehicleDeleting(VehicleDeletingEvent event) {
    deleteFilesAfterCommit(documents.findFileKeysByVehicleId(event.vehicleId()));
  }

  private PresignedUrlResponse presignUpload(Document document) {
    return PresignedUrlResponse.from(
        storage.presignUpload(
            document.getFileKey(), document.getContentType(), document.getSizeBytes()));
  }

  private DocumentUploadResponse uploadResponse(Document document) {
    return new DocumentUploadResponse(
        DocumentResponse.from(document), document.isActive() ? null : presignUpload(document));
  }

  private DocumentDetails validate(
      DocumentType type,
      @Nullable LocalDate issueDate,
      @Nullable LocalDate expiryDate,
      @Nullable String notes) {
    if (issueDate != null && expiryDate != null && !expiryDate.isAfter(issueDate)) {
      throw new DrivonException(
          ErrorCode.DOCUMENT_DATES_INVALID, "The expiry date must be after the issue date.");
    }
    return new DocumentDetails(
        type, issueDate, expiryDate, notes == null || notes.isBlank() ? null : notes.strip());
  }

  private static DocumentFileType checkFile(String contentType, long sizeBytes) {
    DocumentFileType type =
        DocumentFileType.fromContentType(contentType)
            .orElseThrow(
                () ->
                    new DrivonException(
                            ErrorCode.UNSUPPORTED_FILE_TYPE, "Upload a JPEG or PNG photo or a PDF.")
                        .with(
                            "allowedContentTypes",
                            Arrays.stream(DocumentFileType.values())
                                .map(DocumentFileType::contentType)
                                .toList()));
    if (sizeBytes > DocumentFileType.MAX_BYTES) {
      throw new DrivonException(ErrorCode.FILE_TOO_LARGE, "Files can be up to 5 MB.")
          .with("maxBytes", DocumentFileType.MAX_BYTES);
    }
    return type;
  }

  /** Deletes this vehicle's uploads that were started long ago and never confirmed. */
  private void removeAbandonedUploads(UUID vehicleId) {
    List<Document> abandoned =
        documents.findByVehicleIdAndStatusAndCreatedAtBefore(
            vehicleId, DocumentStatus.PENDING, clock.instant().minus(PENDING_UPLOAD_LIFETIME));
    if (abandoned.isEmpty()) {
      return;
    }
    documents.deleteAll(abandoned);
    documents.flush();
    deleteFilesAfterCommit(abandoned.stream().map(Document::getFileKey).toList());
  }

  /**
   * Object keys carry no original file names: {@code
   * users/{userId}/vehicles/{vehicleId}/documents/{documentId}.{ext}}.
   */
  static String objectKey(UUID userId, UUID vehicleId, UUID documentId, DocumentFileType type) {
    return "users/%s/vehicles/%s/documents/%s.%s"
        .formatted(userId, vehicleId, documentId, type.extension());
  }

  /** A readable name for viewers, e.g. {@code revenue-licence-2026-03-01.pdf}. */
  static String fileName(Document document) {
    LocalDate date =
        document.getIssueDate() != null
            ? document.getIssueDate()
            : LocalDate.ofInstant(document.getCreatedAt(), BusinessCalendar.ZONE);
    String type = document.getType().name().toLowerCase(Locale.ROOT).replace('_', '-');
    String extension =
        DocumentFileType.fromContentType(document.getContentType())
            .map(DocumentFileType::extension)
            .orElse("bin");
    return type + "-" + date + "." + extension;
  }

  /**
   * Storage can't take part in the database transaction, so files are removed only after the rows
   * are gone for good. A failure leaves an orphaned object behind; it is logged for cleanup and
   * never fails the request.
   */
  private void deleteFilesAfterCommit(Collection<String> keys) {
    if (keys.isEmpty()) {
      return;
    }
    List<String> toDelete = List.copyOf(keys);
    if (!TransactionSynchronizationManager.isSynchronizationActive()) {
      toDelete.forEach(this::deleteQuietly);
      return;
    }
    TransactionSynchronizationManager.registerSynchronization(
        new TransactionSynchronization() {
          @Override
          public void afterCommit() {
            toDelete.forEach(DocumentService.this::deleteQuietly);
          }
        });
  }

  private void deleteQuietly(String key) {
    try {
      storage.delete(key);
    } catch (RuntimeException e) {
      log.warn("Could not delete document file {}; it is now orphaned", key, e);
    }
  }

  private Document findAny(UUID vehicleId, UUID documentId) {
    return documents
        .findByIdAndVehicleId(documentId, vehicleId)
        .orElseThrow(() -> new DrivonException(ErrorCode.DOCUMENT_NOT_FOUND));
  }

  private Document findActive(UUID vehicleId, UUID documentId) {
    Document document = findAny(vehicleId, documentId);
    if (!document.isActive()) {
      throw new DrivonException(ErrorCode.DOCUMENT_NOT_FOUND);
    }
    return document;
  }
}
