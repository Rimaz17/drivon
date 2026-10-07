import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/storage/secure_storage.dart';
import '../domain/user.dart';
import 'auth_dtos.dart';

/// Remembers the signed-in user's profile so the app can open while the
/// server is unreachable or still waking up. Stored next to the tokens in
/// secure storage because it contains the email address.
abstract interface class UserCache {
  Future<User?> read();
  Future<void> save(User user);
  Future<void> clear();
}

class SecureUserCache implements UserCache {
  SecureUserCache([FlutterSecureStorage? storage])
    : _storage = storage ?? drivonSecureStorage;

  static const String _key = 'drivon.auth.user';

  final FlutterSecureStorage _storage;

  @override
  Future<User?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    return UserDto.fromJson(jsonDecode(raw) as Map<String, dynamic>).toDomain();
  }

  @override
  Future<void> save(User user) =>
      _storage.write(key: _key, value: jsonEncode(UserDto.fromDomain(user)));

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

final userCacheProvider = Provider<UserCache>((ref) => SecureUserCache());
