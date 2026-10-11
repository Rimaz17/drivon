import 'package:drivon/core/errors/app_exception.dart';
import 'package:drivon/core/network/session_events.dart';
import 'package:drivon/core/storage/token_store.dart';
import 'package:drivon/features/auth/data/auth_repository.dart';
import 'package:drivon/features/auth/presentation/session_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import 'auth_test_doubles.dart';

void main() {
  late FakeAuthApi api;
  late InMemoryTokenStore tokens;
  late ProviderContainer container;

  ProviderContainer createContainer() => ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(
        AuthRepository(
          api: api,
          tokens: tokens,
          userCache: InMemoryUserCache(),
        ),
      ),
    ],
  );

  setUp(() {
    api = FakeAuthApi();
    tokens = InMemoryTokenStore();
  });

  tearDown(() => container.dispose());

  Future<SessionState> settled() async {
    container.read(sessionControllerProvider);
    await pumpEventQueue();
    return container.read(sessionControllerProvider);
  }

  test('starts signed out when nothing is stored', () async {
    container = createContainer();

    expect(container.read(sessionControllerProvider), isA<SessionRestoring>());
    expect(await settled(), isA<SignedOut>());
  });

  test('restores a stored session', () async {
    tokens.tokens = const AuthTokens(accessToken: 'a', refreshToken: 'r');
    container = createContainer();

    final state = await settled();

    expect(state, isA<SignedIn>());
    expect(container.read(currentUserProvider)?.firstName, 'Rimaz');
  });

  test('signs in and out', () async {
    container = createContainer();
    await settled();
    final controller = container.read(sessionControllerProvider.notifier);

    await controller.signIn(email: 'rimaz@example.com', password: 'secret');
    expect(container.read(sessionControllerProvider), isA<SignedIn>());

    await controller.signOut();
    expect(container.read(sessionControllerProvider), isA<SignedOut>());
    expect(tokens.tokens, isNull);
  });

  test('an expired session signs the user out with a reason', () async {
    tokens.tokens = const AuthTokens(accessToken: 'a', refreshToken: 'r');
    container = createContainer();
    await settled();

    container.read(sessionEventsProvider).notifyExpired();
    await pumpEventQueue();

    final state = container.read(sessionControllerProvider);
    expect(state, isA<SignedOut>());
    expect((state as SignedOut).sessionExpired, isTrue);
  });

  test('a profile update keeps the same user for data providers', () async {
    tokens.tokens = const AuthTokens(accessToken: 'a', refreshToken: 'r');
    container = createContainer();
    await settled();
    var idChanges = 0;
    container.listen(currentUserIdProvider, (_, _) => idChanges++);

    await container
        .read(sessionControllerProvider.notifier)
        .updateProfile(name: 'Rimaz S', email: 'new@example.com');

    expect(container.read(currentUserProvider)?.name, 'Rimaz S');
    expect(container.read(currentUserProvider)?.email, 'new@example.com');
    expect(idChanges, 0);
  });

  test(
    'deleting the account signs out with a reason and clears the phone',
    () async {
      tokens.tokens = const AuthTokens(accessToken: 'a', refreshToken: 'r');
      container = createContainer();
      await settled();
      SessionState? stateWhenCleared;

      await container
          .read(sessionControllerProvider.notifier)
          .deleteAccount(
            'secret-pass',
            clearDeviceData: () async =>
                stateWhenCleared = container.read(sessionControllerProvider),
          );

      final state = container.read(sessionControllerProvider);
      expect(state, isA<SignedOut>());
      expect((state as SignedOut).accountDeleted, isTrue);
      expect(stateWhenCleared, isA<SignedOut>());
      expect(tokens.tokens, isNull);
    },
  );

  test('a refused deletion keeps the user signed in', () async {
    tokens.tokens = const AuthTokens(accessToken: 'a', refreshToken: 'r');
    container = createContainer();
    await settled();
    api.deleteAccountError = const ApiProblemException(
      statusCode: 422,
      code: ApiErrorCodes.passwordIncorrect,
    );
    var cleared = false;

    await expectLater(
      container
          .read(sessionControllerProvider.notifier)
          .deleteAccount(
            'wrong-pass',
            clearDeviceData: () async => cleared = true,
          ),
      throwsA(isA<ApiProblemException>()),
    );
    expect(container.read(sessionControllerProvider), isA<SignedIn>());
    expect(cleared, isFalse);
  });
}
