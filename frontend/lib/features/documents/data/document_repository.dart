import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/paged.dart';
import '../../../core/network/storage_client.dart';
import '../../../core/services/picked_file.dart';
import '../../../core/utils/uuid.dart';
import '../domain/vehicle_document.dart';
import 'document_api.dart';

/// Documents and their files. Files go straight to private storage through
/// links the API signs; the API checks each upload before showing it.
class DocumentRepository {
  DocumentRepository(this._api, this._storage, {this._newId = uuidV4});

  final DocumentApi _api;
  final StorageClient _storage;
  final String Function() _newId;

  /// An ID for a new document. Keep it for the whole add-document attempt:
  /// retrying [upload] with it resumes instead of starting over.
  String newDocumentId() => _newId();

  Future<Paged<VehicleDocument>> list(String vehicleId, {required int page}) =>
      _api.list(vehicleId, page: page);

  Future<VehicleDocument> get(String vehicleId, String id) =>
      _api.get(vehicleId, id);

  /// Creates document [id] with [file]: the API reserves it and signs an
  /// upload, the file goes to storage, then the API checks and confirms it.
  /// A failed attempt can be repeated with the same [id].
  Future<VehicleDocument> upload(
    String vehicleId,
    DocumentDraft draft,
    PickedFile file, {
    required String id,
    void Function(double fraction)? onProgress,
  }) async {
    final ticket = await _api.startUpload(
      vehicleId,
      draft,
      id: id,
      contentType: file.contentType,
      sizeBytes: file.sizeBytes,
    );
    final request = ticket.upload;
    if (request == null) return ticket.document;
    await _storage.upload(request, file.bytes, onProgress: onProgress);
    return _api.confirm(vehicleId, id);
  }

  Future<VehicleDocument> update(
    String vehicleId,
    String id,
    DocumentDraft draft,
  ) => _api.update(vehicleId, id, draft);

  Future<void> delete(String vehicleId, String id) =>
      _api.delete(vehicleId, id);

  /// A link to the document's file that works for a few minutes.
  Future<Uri> fileUrl(String vehicleId, String id) =>
      _api.downloadUrl(vehicleId, id);

  /// Documents expired or expiring within [VehicleDocument.expiringSoonDays].
  Future<List<VehicleDocument>> expiringSoon() =>
      _api.expiring(withinDays: VehicleDocument.expiringSoonDays);
}

final documentRepositoryProvider = Provider<DocumentRepository>(
  (ref) => DocumentRepository(
    ref.watch(documentApiProvider),
    ref.watch(storageClientProvider),
  ),
);
