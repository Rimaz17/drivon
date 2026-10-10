import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Something the user created offline, waiting to be sent to the server.
@immutable
class StoredDraft {
  const StoredDraft({
    required this.id,
    required this.userId,
    required this.vehicleId,
    required this.json,
    required this.createdAt,
    this.error,
  });

  /// The record's own ID, generated on the phone; the server uses it to
  /// recognise a retry.
  final String id;
  final String userId;
  final String vehicleId;

  /// The request body.
  final String json;
  final DateTime createdAt;

  /// Why the server refused it, or null while it is just waiting.
  final String? error;

  StoredDraft withError(String? error) => StoredDraft(
    id: id,
    userId: userId,
    vehicleId: vehicleId,
    json: json,
    createdAt: createdAt,
    error: error,
  );
}

/// Data kept on the phone for offline use: copies of API responses and
/// drafts waiting to sync, always per user. Tokens never go here; they stay
/// in secure storage.
abstract interface class LocalStore {
  /// The saved copy of a response, or null.
  Future<String?> readCache(String userId, String key);

  Future<void> writeCache(String userId, String key, String json);

  /// The user's drafts, oldest first.
  Future<List<StoredDraft>> drafts(String userId);

  /// Adds a draft or replaces the one with the same ID.
  Future<void> saveDraft(StoredDraft draft);

  Future<void> deleteDraft(String id);

  /// Forgets everything kept for the user, e.g. when they sign out.
  Future<void> clearUser(String userId);
}

/// [LocalStore] in an SQLite database (sqflite) in the app's private files.
class SqliteLocalStore implements LocalStore {
  static const String _file = 'drivon.db';
  static const int _version = 1;

  Future<Database>? _database;

  Future<Database> get _db => _database ??= _open();

  Future<Database> _open() async => openDatabase(
    p.join(await getDatabasesPath(), _file),
    version: _version,
    onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE cache (
          user_id TEXT NOT NULL,
          key TEXT NOT NULL,
          json TEXT NOT NULL,
          saved_at INTEGER NOT NULL,
          PRIMARY KEY (user_id, key)
        )''');
      await db.execute('''
        CREATE TABLE drafts (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          vehicle_id TEXT NOT NULL,
          json TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          error TEXT
        )''');
      await db.execute('CREATE INDEX idx_drafts_user ON drafts (user_id)');
    },
  );

  @override
  Future<String?> readCache(String userId, String key) async {
    final rows = await (await _db).query(
      'cache',
      columns: ['json'],
      where: 'user_id = ? AND key = ?',
      whereArgs: [userId, key],
    );
    return rows.isEmpty ? null : rows.first['json'] as String?;
  }

  @override
  Future<void> writeCache(String userId, String key, String json) async {
    await (await _db).insert('cache', {
      'user_id': userId,
      'key': key,
      'json': json,
      'saved_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<List<StoredDraft>> drafts(String userId) async {
    final rows = await (await _db).query(
      'drafts',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at, id',
    );
    return [
      for (final row in rows)
        StoredDraft(
          id: row['id']! as String,
          userId: row['user_id']! as String,
          vehicleId: row['vehicle_id']! as String,
          json: row['json']! as String,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            row['created_at']! as int,
          ),
          error: row['error'] as String?,
        ),
    ];
  }

  @override
  Future<void> saveDraft(StoredDraft draft) async {
    await (await _db).insert('drafts', {
      'id': draft.id,
      'user_id': draft.userId,
      'vehicle_id': draft.vehicleId,
      'json': draft.json,
      'created_at': draft.createdAt.millisecondsSinceEpoch,
      'error': draft.error,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> deleteDraft(String id) async {
    await (await _db).delete('drafts', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> clearUser(String userId) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('cache', where: 'user_id = ?', whereArgs: [userId]);
      await txn.delete('drafts', where: 'user_id = ?', whereArgs: [userId]);
    });
  }
}

final localStoreProvider = Provider<LocalStore>((ref) => SqliteLocalStore());

/// The signed-in user's ID, so offline data is always kept per user. Set by
/// the session; null when signed out.
class ActiveUserController extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? userId) {
    if (state != userId) state = userId;
  }
}

final activeUserIdProvider = NotifierProvider<ActiveUserController, String?>(
  ActiveUserController.new,
);
