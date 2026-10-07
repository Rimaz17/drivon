import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The signed-in session's tokens.
class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  factory AuthTokens.fromJson(Map<String, dynamic> json) => AuthTokens(
    accessToken: json['accessToken'] as String,
    refreshToken: json['refreshToken'] as String,
  );

  final String accessToken;
  final String refreshToken;

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
  };
}

/// Persists tokens. Tokens never go to SharedPreferences, SQLite or logs.
abstract interface class TokenStore {
  Future<AuthTokens?> read();
  Future<void> save(AuthTokens tokens);
  Future<void> clear();
}

/// Stores tokens in the iOS Keychain / Android Keystore-backed storage, with
/// an in-memory copy so each request doesn't hit the platform store.
class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            // Readable after the first unlock (for future background refresh),
            // never synced to other devices or included in backups.
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  static const String _key = 'drivon.auth.tokens';

  final FlutterSecureStorage _storage;
  AuthTokens? _cached;
  bool _loaded = false;

  @override
  Future<AuthTokens?> read() async {
    if (!_loaded) {
      final raw = await _storage.read(key: _key);
      _cached = raw == null
          ? null
          : AuthTokens.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      _loaded = true;
    }
    return _cached;
  }

  @override
  Future<void> save(AuthTokens tokens) async {
    _cached = tokens;
    _loaded = true;
    await _storage.write(key: _key, value: jsonEncode(tokens.toJson()));
  }

  @override
  Future<void> clear() async {
    _cached = null;
    _loaded = true;
    await _storage.delete(key: _key);
  }
}

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());
