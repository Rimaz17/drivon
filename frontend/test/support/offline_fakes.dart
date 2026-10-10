import 'dart:async';

import 'package:drivon/core/network/connection_status.dart';
import 'package:drivon/core/storage/local_store.dart';

/// [LocalStore] in memory, since SQLite doesn't run in widget tests.
class InMemoryLocalStore implements LocalStore {
  final Map<String, String> cache = {};
  final Map<String, StoredDraft> storedDrafts = {};

  static String _key(String userId, String key) => '$userId|$key';

  @override
  Future<String?> readCache(String userId, String key) async =>
      cache[_key(userId, key)];

  @override
  Future<void> writeCache(String userId, String key, String json) async =>
      cache[_key(userId, key)] = json;

  @override
  Future<List<StoredDraft>> drafts(String userId) async {
    final list = [
      for (final draft in storedDrafts.values)
        if (draft.userId == userId) draft,
    ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  @override
  Future<void> saveDraft(StoredDraft draft) async =>
      storedDrafts[draft.id] = draft;

  @override
  Future<void> deleteDraft(String id) async => storedDrafts.remove(id);

  @override
  Future<void> clearUser(String userId) async {
    cache.removeWhere((key, _) => key.startsWith('$userId|'));
    storedDrafts.removeWhere((_, draft) => draft.userId == userId);
  }
}

/// A network monitor tests switch on and off.
class FakeNetworkMonitor implements NetworkMonitor {
  final StreamController<bool> _changes = StreamController.broadcast();

  @override
  Stream<bool> get changes => _changes.stream;

  void connect() => _changes.add(true);

  void disconnect() => _changes.add(false);
}
