import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/paged.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/network/storage_client.dart';
import '../../../core/utils/date_format.dart';
import '../domain/vehicle_document.dart';

/// `DocumentResponse` from the API.
VehicleDocument documentFromJson(Map<String, dynamic> json) {
  final issueDate = json['issueDate'] as String?;
  final expiryDate = json['expiryDate'] as String?;
  return VehicleDocument(
    id: json['id'] as String,
    vehicleId: json['vehicleId'] as String,
    type: DocumentType.fromWire(json['type'] as String),
    contentType: json['contentType'] as String,
    sizeBytes: (json['sizeBytes'] as num).toInt(),
    issueDate: issueDate == null ? null : ApiDate.parse(issueDate),
    expiryDate: expiryDate == null ? null : ApiDate.parse(expiryDate),
    notes: json['notes'] as String?,
  );
}

/// `DocumentRequest` body: the editable details.
Map<String, dynamic> documentRequestJson(DocumentDraft draft) {
  final notes = draft.notes?.trim();
  final issueDate = draft.issueDate;
  final expiryDate = draft.expiryDate;
  return {
    'type': draft.type.wireValue,
    'issueDate': issueDate == null ? null : ApiDate.format(issueDate),
    'expiryDate': expiryDate == null ? null : ApiDate.format(expiryDate),
    'notes': notes == null || notes.isEmpty ? null : notes,
  };
}

/// A started upload: the pending document and where to send its file, or
/// no [upload] when an earlier attempt already finished it.
@immutable
class UploadTicket {
  const UploadTicket({required this.document, this.upload});

  final VehicleDocument document;
  final PresignedRequest? upload;
}

/// HTTP calls for documents. Throws AppExceptions.
class DocumentApi {
  DocumentApi(this._dio);

  final Dio _dio;

  static String _documents(String vehicleId) =>
      '/api/v1/vehicles/$vehicleId/documents';

  /// Confirmed documents, newest first.
  Future<Paged<VehicleDocument>> list(
    String vehicleId, {
    required int page,
    int size = 20,
  }) => guardApi(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      _documents(vehicleId),
      queryParameters: {'page': page, 'size': size},
    );
    return Paged.fromJson(response.data!, documentFromJson);
  });

  Future<VehicleDocument> get(String vehicleId, String id) =>
      guardApi(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          '${_documents(vehicleId)}/$id',
        );
        return documentFromJson(response.data!);
      });

  /// Saves the document as pending and returns where to upload [sizeBytes]
  /// bytes of [contentType]. Resending [id] resumes the same document.
  Future<UploadTicket> startUpload(
    String vehicleId,
    DocumentDraft draft, {
    required String id,
    required String contentType,
    required int sizeBytes,
  }) => guardApi(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      _documents(vehicleId),
      data: {
        'id': id,
        ...documentRequestJson(draft),
        'contentType': contentType,
        'sizeBytes': sizeBytes,
      },
    );
    final body = response.data!;
    final upload = body['upload'] as Map<String, dynamic>?;
    return UploadTicket(
      document: documentFromJson(body['document'] as Map<String, dynamic>),
      upload: upload == null ? null : PresignedRequest.fromJson(upload),
    );
  });

  /// Asks the API to check the uploaded file and make the document visible.
  Future<VehicleDocument> confirm(String vehicleId, String id) =>
      guardApi(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '${_documents(vehicleId)}/$id/confirm',
        );
        return documentFromJson(response.data!);
      });

  Future<VehicleDocument> update(
    String vehicleId,
    String id,
    DocumentDraft draft,
  ) => guardApi(() async {
    final response = await _dio.put<Map<String, dynamic>>(
      '${_documents(vehicleId)}/$id',
      data: documentRequestJson(draft),
    );
    return documentFromJson(response.data!);
  });

  Future<void> delete(String vehicleId, String id) =>
      guardApi(() => _dio.delete<void>('${_documents(vehicleId)}/$id'));

  /// A link to the file that works for a few minutes.
  Future<Uri> downloadUrl(String vehicleId, String id) => guardApi(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '${_documents(vehicleId)}/$id/download-url',
    );
    return PresignedRequest.fromJson(response.data!).url;
  });

  /// The user's documents expiring within [withinDays] days or already
  /// expired, across vehicles, soonest first.
  Future<List<VehicleDocument>> expiring({required int withinDays}) =>
      guardApi(() async {
        final response = await _dio.get<List<dynamic>>(
          '/api/v1/documents/expiring',
          queryParameters: {'withinDays': withinDays},
        );
        return response.data!
            .cast<Map<String, dynamic>>()
            .map(documentFromJson)
            .toList();
      });
}

final documentApiProvider = Provider<DocumentApi>(
  (ref) => DocumentApi(ref.watch(dioProvider)),
);
