import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/session_events.dart';
import '../../../core/storage/local_store.dart';
import '../data/auth_repository.dart';
import '../domain/user.dart';

/// Whether someone is signed in. Drives routing.
sealed class SessionState {
  const SessionState();
}

/// Checking stored credentials at startup.
final class SessionRestoring extends SessionState {
  const SessionRestoring();
}

final class SignedIn extends SessionState {
  const SignedIn(this.user);

  final User user;
}

final class SignedOut extends SessionState {
  const SignedOut({this.sessionExpired = false, this.accountDeleted = false});

  /// True when the server ended the session, so the UI can explain why.
  final bool sessionExpired;

  /// True right after the user deleted their account.
  final bool accountDeleted;
}

class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() {
    final subscription = ref
        .watch(sessionEventsProvider)
        .expired
        .listen((_) => unawaited(_expire()));
    ref.onDispose(subscription.cancel);
    // Offline copies and drafts are kept per user.
    listenSelf(
      (_, next) => ref
          .read(activeUserIdProvider.notifier)
          .set(next is SignedIn ? next.user.id : null),
    );
    unawaited(Future.microtask(_restore));
    return const SessionRestoring();
  }

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  /// Throws an AppException when sign-in fails; the screen explains it.
  Future<void> signIn({required String email, required String password}) async {
    final user = await _repository.signIn(email: email, password: password);
    if (ref.mounted) state = SignedIn(user);
  }

  /// Throws an AppException when registration fails.
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final user = await _repository.register(
      name: name,
      email: email,
      password: password,
    );
    if (ref.mounted) state = SignedIn(user);
  }

  /// Saves the signed-in user's new name and email. Throws an AppException
  /// when the server refuses them.
  Future<void> updateProfile({
    required String name,
    required String email,
  }) async {
    final user = await _repository.updateProfile(name: name, email: email);
    if (ref.mounted && state is SignedIn) state = SignedIn(user);
  }

  /// Deletes the account once the server has checked [password]. Throws an
  /// AppException, keeping the session, when it refuses. After the account
  /// is gone the user is signed out, then [clearDeviceData] removes what
  /// the phone kept for them; it must not depend on widgets, which are
  /// gone by then.
  Future<void> deleteAccount(
    String password, {
    required Future<void> Function() clearDeviceData,
  }) async {
    await _repository.deleteAccount(password);
    if (ref.mounted) state = const SignedOut(accountDeleted: true);
    try {
      await clearDeviceData();
    } on Object catch (error) {
      debugPrint('Clearing data of the deleted account failed: $error');
    }
  }

  Future<void> signOut() async {
    await _repository.signOut();
    if (ref.mounted) state = const SignedOut();
  }

  Future<void> _restore() async {
    User? user;
    try {
      user = await _repository.restore();
    } on Object {
      user = null;
    }
    if (!ref.mounted) return;
    state = user == null ? const SignedOut() : SignedIn(user);
  }

  Future<void> _expire() async {
    if (state is! SignedIn) return;
    await _repository.clearLocalSession();
    if (ref.mounted) state = const SignedOut(sessionExpired: true);
  }
}

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);

/// The signed-in user, or null.
final currentUserProvider = Provider<User?>((ref) {
  final session = ref.watch(sessionControllerProvider);
  return session is SignedIn ? session.user : null;
});

/// ID of the signed-in user, or null. Data providers watch this rather than
/// [currentUserProvider], so editing the profile doesn't reload them.
final currentUserIdProvider = Provider<String?>(
  (ref) => ref.watch(currentUserProvider.select((user) => user?.id)),
);
