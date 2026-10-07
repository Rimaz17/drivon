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
}
