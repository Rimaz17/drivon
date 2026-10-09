package com.drivon.api.document;

import com.drivon.api.common.security.CurrentUserId;
import com.drivon.api.common.web.CreateResult;
import com.drivon.api.common.web.PageResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import java.util.List;
import java.util.UUID;
import org.jspecify.annotations.Nullable;
import org.springdoc.core.annotations.ParameterObject;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
@Tag(
    name = "Documents",
    description =
        "Insurance, revenue licence, registration, invoices and receipts, with files in private"
            + " storage")
class DocumentController {

  private static final String DOCUMENTS = "/vehicles/{vehicleId}/documents";

  private final DocumentService documents;

  DocumentController(DocumentService documents) {
    this.documents = documents;
  }

  @GetMapping(DOCUMENTS)
  @Operation(
      summary = "List documents, newest first",
      description =
          "Only documents whose upload was confirmed. Sortable by `createdAt`, `issueDate` and"
              + " `expiryDate`.")
  @ApiResponse(responseCode = "200", description = "A page of documents")
  @ApiResponse(responseCode = "400", description = "INVALID_SORT, MALFORMED_REQUEST")
  @ApiResponse(responseCode = "404", description = "VEHICLE_NOT_FOUND")
  PageResponse<DocumentResponse> list(
      @CurrentUserId UUID userId,
      @PathVariable UUID vehicleId,
      @Parameter(description = "Only this type") @RequestParam(required = false)
          @Nullable DocumentType type,
      @ParameterObject Pageable pageable) {
    return documents.list(userId, vehicleId, type, pageable);
  }

  @GetMapping(DOCUMENTS + "/{documentId}")
  @Operation(summary = "Get one document's details")
  @ApiResponse(responseCode = "404", description = "VEHICLE_NOT_FOUND, DOCUMENT_NOT_FOUND")
  DocumentResponse get(
      @CurrentUserId UUID userId, @PathVariable UUID vehicleId, @PathVariable UUID documentId) {
    return documents.get(userId, vehicleId, documentId);
  }

  @PostMapping(DOCUMENTS)
  @Operation(
      summary = "Start a document upload",
      description =
          """
          Saves the document as pending and returns a presigned `upload`. Send the file with \
          that method, URL and headers straight to storage (not to this API, and without the \
          Authorization header), then call `POST .../{documentId}/confirm`. The URL expires \
          after 10 minutes. Resending the same `id` returns the same document with a fresh URL, \
          or with `upload: null` once confirmed. Files: JPEG, PNG or PDF, up to 5 MB.""")
  @ApiResponse(responseCode = "201", description = "Pending; Location points to the document")
  @ApiResponse(responseCode = "200", description = "Already started earlier with this ID")
  @ApiResponse(responseCode = "400", description = "VALIDATION_FAILED")
  @ApiResponse(responseCode = "404", description = "VEHICLE_NOT_FOUND")
  @ApiResponse(responseCode = "409", description = "RECORD_ID_CONFLICT")
  @ApiResponse(
      responseCode = "422",
      description =
          "DOCUMENT_DATES_INVALID, UNSUPPORTED_FILE_TYPE, FILE_TOO_LARGE, DOCUMENT_LIMIT_REACHED")
  @ApiResponse(responseCode = "503", description = "STORAGE_UNAVAILABLE")
  ResponseEntity<DocumentUploadResponse> startUpload(
      @CurrentUserId UUID userId,
      @PathVariable UUID vehicleId,
      @Valid @RequestBody DocumentUploadRequest request) {
    CreateResult<DocumentUploadResponse> result = documents.startUpload(userId, vehicleId, request);
    return result.toResponse(result.record().document().id());
  }

  @PostMapping(DOCUMENTS + "/{documentId}/confirm")
  @Operation(
      summary = "Confirm a finished upload",
      description = "Checks the stored file's size and type, then makes the document visible.")
  @ApiResponse(responseCode = "200", description = "The document, now ACTIVE")
  @ApiResponse(responseCode = "404", description = "VEHICLE_NOT_FOUND, DOCUMENT_NOT_FOUND")
  @ApiResponse(
      responseCode = "422",
      description = "UPLOAD_NOT_FOUND (upload first), UPLOAD_MISMATCH (upload again)")
  @ApiResponse(responseCode = "503", description = "STORAGE_UNAVAILABLE")
  DocumentResponse confirm(
      @CurrentUserId UUID userId, @PathVariable UUID vehicleId, @PathVariable UUID documentId) {
    return documents.confirmUpload(userId, vehicleId, documentId);
  }

  @PutMapping(DOCUMENTS + "/{documentId}")
  @Operation(summary = "Replace a document's details", description = "The file stays the same.")
  @ApiResponse(responseCode = "200", description = "Updated document")
  @ApiResponse(responseCode = "404", description = "VEHICLE_NOT_FOUND, DOCUMENT_NOT_FOUND")
  @ApiResponse(responseCode = "422", description = "DOCUMENT_DATES_INVALID")
  DocumentResponse update(
      @CurrentUserId UUID userId,
      @PathVariable UUID vehicleId,
      @PathVariable UUID documentId,
      @Valid @RequestBody DocumentRequest request) {
    return documents.update(userId, vehicleId, documentId, request);
  }

  @DeleteMapping(DOCUMENTS + "/{documentId}")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  @Operation(
      summary = "Delete a document and its file",
      description = "Also removes an upload that was never confirmed.")
  @ApiResponse(responseCode = "204", description = "Deleted")
  @ApiResponse(responseCode = "404", description = "VEHICLE_NOT_FOUND, DOCUMENT_NOT_FOUND")
  void delete(
      @CurrentUserId UUID userId, @PathVariable UUID vehicleId, @PathVariable UUID documentId) {
    documents.delete(userId, vehicleId, documentId);
  }

  @GetMapping(DOCUMENTS + "/{documentId}/download-url")
  @Operation(
      summary = "Get a short-lived URL to the document's file",
      description =
          "A presigned GET, valid for 5 minutes; open it without the Authorization header.")
  @ApiResponse(responseCode = "200", description = "The URL")
  @ApiResponse(responseCode = "404", description = "VEHICLE_NOT_FOUND, DOCUMENT_NOT_FOUND")
  @ApiResponse(responseCode = "503", description = "STORAGE_UNAVAILABLE")
  PresignedUrlResponse downloadUrl(
      @CurrentUserId UUID userId, @PathVariable UUID vehicleId, @PathVariable UUID documentId) {
    return documents.downloadUrl(userId, vehicleId, documentId);
  }

  @GetMapping("/documents/expiring")
  @Operation(
      summary = "Documents expiring soon, across the user's vehicles",
      description = "Includes documents that already expired. Soonest expiry first.")
  @ApiResponse(responseCode = "200", description = "The documents")
  @ApiResponse(responseCode = "400", description = "VALIDATION_FAILED (withinDays outside 0–365)")
  List<DocumentResponse> expiring(
      @CurrentUserId UUID userId,
      @Parameter(description = "Days from today, 0 to 365")
          @RequestParam(defaultValue = "30")
          @Min(0) @Max(365) int withinDays) {
    return documents.expiring(userId, withinDays);
  }
}
