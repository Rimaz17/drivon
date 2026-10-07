import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/storage/token_store.dart';
import '../domain/user.dart';
import 'auth_api.dart';
import 'auth_dtos.dart';
import 'user_cache.dart';

/// Signs users in and out and keeps the session's tokens and profile.
class AuthRepository {
  AuthRepository({
    required this._api,
    required this._tokens,
    required this._userCache,
  });

  final AuthApi _api;
  final TokenStore _tokens;
  final UserCache _userCache;

  Future<User> signIn({
    required String email,
    required String password,
  }) async =>
      _startSession(await _api.login(email: email.trim(), password: password));

  Future<User> register({
    required String name,
    required String email,
    required String password,
  }) async => _startSession(
    await _api.register(
      name: name.trim(),
      email: email.trim(),
      password: password,
    ),
  );

  /// The user from a previous session, or null if they must sign in.
  ///
  /// Confirms the session with the server when possible. If the server can't
  /// be reached, the cached profile keeps the user signed in.
  Future<User?> restore() async {
    if (await _tokens.read() == null) return null;
    try {
      final user = (await _api.me()).toDomain();
      await _userCache.save(user);
      return user;
    } on SessionExpiredException {
      await clearLocalSession();
      return null;
    } on ApiProblemException catch (error) {
      if (error.statusCode == 401) {
        await clearLocalSession();
        return null;
      }
      return _userCache.read();
    } on AppException {
      return _userCache.read();
    }
  }

  /// Revokes the session on the server (best effort) and forgets it locally.
  Future<void> signOut() async {
    final tokens = await _tokens.read();
    if (tokens != null) {
      try {
        await _api.logout(tokens.refreshToken);
      } on AppException {
        // Offline or already expired: the local session is cleared anyway.
      }
    }
    await clearLocalSession();
  }

  Future<void> clearLocalSession() async {
    await _tokens.clear();
    await _userCache.clear();
  }

  Future<User> _startSession(AuthResponseDto response) async {
    await _tokens.save(
      AuthTokens(
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
      ),
    );
    final user = response.user.toDomain();
    await _userCache.save(user);
    return user;
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    api: ref.watch(authApiProvider),
    tokens: ref.watch(tokenStoreProvider),
    userCache: ref.watch(userCacheProvider),
  ),
);
