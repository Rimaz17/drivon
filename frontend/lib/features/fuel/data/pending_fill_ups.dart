import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_store.dart';
import '../domain/fuel_record.dart';
import 'fuel_dto.dart';

/// Why the server refused a fill-up saved offline.
@immutable
class SyncRejection {
  const SyncRejection({required this.code, this.detail});

  /// The API's error code, e.g. `ODOMETER_OUT_OF_ORDER`.
  final String code;

  /// The server's explanation, shown when the app has no text of its own.
  final String? detail;
}

/// A fill-up logged without a connection, kept on the phone until the server
/// has it. Its [id] is the one the server will store, so sending it twice
/// can't create two fill-ups.
@immutable
class PendingFillUp {
  const PendingFillUp({
    required this.id,
    required this.vehicleId,
    required this.draft,
    required this.savedAt,
    this.rejection,
  });

  final String id;
  final String vehicleId;
  final FuelDraft draft;
  final DateTime savedAt;

  /// Set when the server refused it; such a fill-up isn't sent again until
  /// the user retries.
  final SyncRejection? rejection;

  bool get rejected => rejection != null;
}

/// Fill-ups waiting to sync, kept per user in the local database.
class PendingFillUpStore {
  PendingFillUpStore(this._store);

  final LocalStore _store;

  /// Oldest first, the order they are sent in.
  Future<List<PendingFillUp>> all(String userId) async => [
    for (final stored in await _store.drafts(userId)) _fromStored(stored),
  ];

  Future<void> save(String userId, PendingFillUp fillUp) => _store.saveDraft(
    StoredDraft(
      id: fillUp.id,
      userId: userId,
      vehicleId: fillUp.vehicleId,
      json: jsonEncode(fuelRequestJson(fillUp.draft)),
      createdAt: fillUp.savedAt,
      error: fillUp.rejection == null
          ? null
          : jsonEncode({
              'code': fillUp.rejection!.code,
              'detail': fillUp.rejection!.detail,
            }),
    ),
  );

  Future<void> remove(String id) => _store.deleteDraft(id);

  static PendingFillUp _fromStored(StoredDraft stored) {
    final error = stored.error;
    SyncRejection? rejection;
    if (error != null) {
      final json = jsonDecode(error) as Map<String, dynamic>;
      rejection = SyncRejection(
        code: json['code'] as String,
        detail: json['detail'] as String?,
      );
    }
    return PendingFillUp(
      id: stored.id,
      vehicleId: stored.vehicleId,
      draft: fuelDraftFromRequestJson(
        jsonDecode(stored.json) as Map<String, dynamic>,
      ),
      savedAt: stored.createdAt,
      rejection: rejection,
    );
  }
}

final pendingFillUpStoreProvider = Provider<PendingFillUpStore>(
  (ref) => PendingFillUpStore(ref.watch(localStoreProvider)),
);
