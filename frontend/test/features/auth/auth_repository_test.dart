import 'package:drivon/core/errors/app_exception.dart';
import 'package:drivon/core/storage/token_store.dart';
import 'package:drivon/features/auth/data/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import 'auth_test_doubles.dart';

void main() {
  late FakeAuthApi api;
  late InMemoryTokenStore tokens;
  late InMemoryUserCache cache;
  late AuthRepository repository;

  setUp(() {
    api = FakeAuthApi();
    tokens = InMemoryTokenStore();
    cache = InMemoryUserCache();
    repository = AuthRepository(api: api, tokens: tokens, userCache: cache);
  });

  test('signing in stores tokens and the profile', () async {
    final user = await repository.signIn(
      email: '  rimaz@example.com ',
      password: 'secret-pass',
    );

    expect(user.firstName, 'Rimaz');
    expect(api.lastLogin?['email'], 'rimaz@example.com');
    expect(tokens.tokens?.refreshToken, 'refresh-1');
    expect(cache.user, user);
  });

  test('a failed sign-in stores nothing', () async {
    api.loginResult = const ApiProblemException(
      statusCode: 401,
      code: ApiErrorCodes.invalidCredentials,
    );

    await expectLater(
      repository.signIn(email: 'a@b.c', password: 'nope-nope'),
      throwsA(isA<ApiProblemException>()),
    );
    expect(tokens.tokens, isNull);
  });

  test('restore returns null without stored tokens', () async {
    expect(await repository.restore(), isNull);
  });

  test('restore confirms the session with the server', () async {
    tokens.tokens = const AuthTokens(accessToken: 'a', refreshToken: 'r');

    final user = await repository.restore();

    expect(user?.email, 'rimaz@example.com');
  });

  test(
    'restore keeps the cached user when the server is unreachable',
    () async {
      tokens.tokens = const AuthTokens(accessToken: 'a', refreshToken: 'r');
      await repository.signIn(email: 'rimaz@example.com', password: 'x');
      api.meResult = const ServerTimeoutException();

      final user = await repository.restore();

      expect(user?.name, 'Rimaz Saththar');
      expect(tokens.tokens, isNotNull);
    },
  );

  test('restore clears everything when the session has ended', () async {
    await repository.signIn(email: 'rimaz@example.com', password: 'x');
    api.meResult = const SessionExpiredException();

    expect(await repository.restore(), isNull);
    expect(tokens.tokens, isNull);
    expect(cache.user, isNull);
  });

  test('sign out revokes the refresh token and clears local data', () async {
    await repository.signIn(email: 'rimaz@example.com', password: 'x');

    await repository.signOut();

    expect(api.loggedOutTokens, ['refresh-1']);
    expect(tokens.tokens, isNull);
    expect(cache.user, isNull);
  });
}
