import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/paged.dart';
import '../../../core/services/picked_file.dart';
import '../../../core/ui/paged_list_controller.dart';
import '../../auth/presentation/session_controller.dart';
import '../../reminders/presentation/reminder_controllers.dart';
import '../data/document_repository.dart';
import '../domain/vehicle_document.dart';

/// A vehicle's documents, newest first, a page at a time.
class DocumentListController extends PagedListController<VehicleDocument> {
  DocumentListController(this.vehicleId);

  final String vehicleId;

  @override
  Future<Paged<VehicleDocument>> fetchPage(int page) =>
      ref.read(documentRepositoryProvider).list(vehicleId, page: page);
}

final documentListProvider = AsyncNotifierProvider.autoDispose
    .family<DocumentListController, PagedList<VehicleDocument>, String>(
      DocumentListController.new,
      // Failures are shown with a retry button instead of retried silently.
      retry: (_, _) => null,
    );

/// The user's documents that are expired or expire within 30 days, across
/// vehicles, soonest first.
final expiringDocumentsProvider =
    FutureProvider.autoDispose<List<VehicleDocument>>((ref) {
      ref.watch(currentUserProvider);
      return ref.read(documentRepositoryProvider).expiringSoon();
    }, retry: (_, _) => null);

typedef DocumentKey = ({String vehicleId, String documentId});

/// One document, from the loaded list when possible.
final documentProvider = FutureProvider.autoDispose
    .family<VehicleDocument, DocumentKey>((ref, key) {
      final loaded = ref.read(documentListProvider(key.vehicleId)).value;
      for (final document in loaded?.items ?? const <VehicleDocument>[]) {
        if (document.id == key.documentId) return document;
      }
      return ref
          .read(documentRepositoryProvider)
          .get(key.vehicleId, key.documentId);
    }, retry: (_, _) => null);

/// A short-lived link to a document's file. Not cached: links expire after
/// five minutes, so each visit asks for a fresh one.
final documentFileUrlProvider = FutureProvider.autoDispose
    .family<Uri, DocumentKey>(
      (ref, key) => ref
          .read(documentRepositoryProvider)
          .fileUrl(key.vehicleId, key.documentId),
      retry: (_, _) => null,
    );

/// Adds, edits and deletes documents, then refreshes the lists that show
/// them. Throws AppExceptions for screens to explain.
class DocumentMutations {
  DocumentMutations(this._ref);

  final Ref _ref;

  DocumentRepository get _repository => _ref.read(documentRepositoryProvider);

  /// See [DocumentRepository.upload]: keep [id] for retries of one attempt.
  Future<VehicleDocument> add(
    String vehicleId,
    DocumentDraft draft,
    PickedFile file, {
    required String id,
    void Function(double fraction)? onProgress,
  }) async {
    final document = await _repository.upload(
      vehicleId,
      draft,
      file,
      id: id,
      onProgress: onProgress,
    );
    _refresh(vehicleId);
    return document;
  }

  Future<void> edit(String vehicleId, String id, DocumentDraft draft) async {
    await _repository.update(vehicleId, id, draft);
    _refresh(vehicleId);
    _ref.invalidate(documentProvider((vehicleId: vehicleId, documentId: id)));
  }

  Future<void> remove(String vehicleId, String id) async {
    await _repository.delete(vehicleId, id);
    _refresh(vehicleId);
  }

  void _refresh(String vehicleId) {
    _ref
      ..invalidate(documentListProvider(vehicleId))
      ..invalidate(expiringDocumentsProvider);
    // Document reminders follow each type's latest expiry date.
    refreshReminders(_ref.invalidate);
  }
}

final documentMutationsProvider = Provider<DocumentMutations>(
  DocumentMutations.new,
);
