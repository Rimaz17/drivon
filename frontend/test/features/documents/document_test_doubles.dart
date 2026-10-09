import 'dart:typed_data';

import 'package:drivon/core/errors/app_exception.dart';
import 'package:drivon/core/models/paged.dart';
import 'package:drivon/core/network/storage_client.dart';
import 'package:drivon/core/services/file_picker_service.dart';
import 'package:drivon/core/services/picked_file.dart';
import 'package:drivon/features/documents/data/document_api.dart';
import 'package:drivon/features/documents/domain/vehicle_document.dart';

VehicleDocument vehicleDocument({
  String id = 'doc-1',
  String vehicleId = 'vehicle-1',
  DocumentType type = DocumentType.insurance,
  String contentType = DocumentContentTypes.pdf,
  DateTime? issueDate,
  DateTime? expiryDate,
  String? notes,
}) => VehicleDocument(
  id: id,
  vehicleId: vehicleId,
  type: type,
  contentType: contentType,
  sizeBytes: 840 * 1024,
  issueDate: issueDate,
  expiryDate: expiryDate,
  notes: notes,
);

final _uploadUrl = PresignedRequest(
  url: Uri.parse('https://storage.test/upload'),
  method: 'PUT',
  headers: const {'content-type': 'image/jpeg'},
  expiresAt: DateTime.utc(2026, 10, 7, 5),
);

/// In-memory [DocumentApi] for tests.
class FakeDocumentApi implements DocumentApi {
  FakeDocumentApi([List<VehicleDocument>? documents])
    : documents = documents ?? [];

  final List<VehicleDocument> documents;
  List<VehicleDocument> expiringResponse = [];

  /// When set, the next call throws it once.
  AppException? nextError;

  /// When set, the next confirm throws it once (the upload step failed).
  AppException? nextConfirmError;
  final List<String> startedIds = [];
  final List<DocumentDraft> savedDrafts = [];
  int confirmCalls = 0;

  @override
  Future<Paged<VehicleDocument>> list(
    String vehicleId, {
    required int page,
    int size = 20,
  }) async {
    _throwIfScripted();
    return Paged(
      items: [
        for (final document in documents)
          if (document.vehicleId == vehicleId) document,
      ],
      hasMore: false,
    );
  }

  @override
  Future<VehicleDocument> get(String vehicleId, String id) async {
    _throwIfScripted();
    return documents.firstWhere((document) => document.id == id);
  }

  @override
  Future<UploadTicket> startUpload(
    String vehicleId,
    DocumentDraft draft, {
    required String id,
    required String contentType,
    required int sizeBytes,
  }) async {
    _throwIfScripted();
    startedIds.add(id);
    savedDrafts.add(draft);
    return UploadTicket(
      document: VehicleDocument(
        id: id,
        vehicleId: vehicleId,
        type: draft.type,
        contentType: contentType,
        sizeBytes: sizeBytes,
        issueDate: draft.issueDate,
        expiryDate: draft.expiryDate,
        notes: draft.notes,
      ),
      upload: _uploadUrl,
    );
  }

  @override
  Future<VehicleDocument> confirm(String vehicleId, String id) async {
    _throwIfScripted();
    confirmCalls++;
    final error = nextConfirmError;
    if (error != null) {
      nextConfirmError = null;
      throw error;
    }
    final draft = savedDrafts.last;
    final document = VehicleDocument(
      id: id,
      vehicleId: vehicleId,
      type: draft.type,
      contentType: DocumentContentTypes.jpeg,
      sizeBytes: 4,
      issueDate: draft.issueDate,
      expiryDate: draft.expiryDate,
      notes: draft.notes,
    );
    documents.insert(0, document);
    return document;
  }

  @override
  Future<VehicleDocument> update(
    String vehicleId,
    String id,
    DocumentDraft draft,
  ) async {
    _throwIfScripted();
    savedDrafts.add(draft);
    final index = documents.indexWhere((document) => document.id == id);
    final updated = documents[index].copyWith(
      type: draft.type,
      issueDate: draft.issueDate,
      expiryDate: draft.expiryDate,
      notes: draft.notes,
    );
    documents[index] = updated;
    return updated;
  }

  @override
  Future<void> delete(String vehicleId, String id) async {
    _throwIfScripted();
    documents.removeWhere((document) => document.id == id);
  }

  @override
  Future<Uri> downloadUrl(String vehicleId, String id) async {
    _throwIfScripted();
    return Uri.parse('https://storage.test/$id');
  }

  @override
  Future<List<VehicleDocument>> expiring({required int withinDays}) async {
    _throwIfScripted();
    return List.of(expiringResponse);
  }

  void _throwIfScripted() {
    final error = nextError;
    if (error != null) {
      nextError = null;
      throw error;
    }
  }
}

/// Records uploads instead of sending them.
class FakeStorageClient implements StorageClient {
  final List<PresignedRequest> uploads = [];

  @override
  Future<void> upload(
    PresignedRequest request,
    Uint8List bytes, {
    void Function(double fraction)? onProgress,
  }) async {
    uploads.add(request);
    onProgress?.call(0.5);
    onProgress?.call(1);
  }
}

/// Returns scripted files instead of opening the camera or file picker.
class FakeFilePickerService implements FilePickerService {
  PickedFile? photo = PickedFile(
    bytes: Uint8List.fromList(List.filled(4, 0)),
    contentType: 'image/jpeg',
    name: 'insurance.jpg',
  );
  PickedFile? pdf;

  /// When set, the next pick throws it once.
  FilePickException? nextError;
  final List<PhotoSource> photoSources = [];

  @override
  Future<PickedFile?> pickPhoto(PhotoSource source) async {
    photoSources.add(source);
    final error = nextError;
    if (error != null) {
      nextError = null;
      throw error;
    }
    return photo;
  }

  @override
  Future<PickedFile?> pickPdf() async => pdf;
}
