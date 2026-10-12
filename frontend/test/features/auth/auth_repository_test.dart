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

  test('restore waits only briefly for the server', () async {
    tokens.tokens = const AuthTokens(accessToken: 'a', refreshToken: 'r');

    await repository.restore();

    expect(api.lastMeReceiveTimeout, AuthRepository.launchCheckTimeout);
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

  test(
    'a profile update keeps the saved profile and its offline copy current',
    () async {
      await repository.signIn(email: 'rimaz@example.com', password: 'x');

      final user = await repository.updateProfile(
        name: ' Rimaz S ',
        email: ' New@Example.com ',
      );

      expect(api.lastProfileUpdate, {
        'name': 'Rimaz S',
        'email': 'New@Example.com',
      });
      expect(user.email, 'new@example.com');
      expect(cache.user, user);
      // Read back so the offline cache of /users/me has the new details.
      expect(api.meCalls, 1);
    },
  );

  test('a refused profile update changes nothing', () async {
    final signedIn = await repository.signIn(
      email: 'rimaz@example.com',
      password: 'x',
    );
    api.updateProfileResult = const ApiProblemException(
      statusCode: 409,
      code: ApiErrorCodes.emailAlreadyRegistered,
    );

    await expectLater(
      repository.updateProfile(name: 'R', email: 'taken@example.com'),
      throwsA(isA<ApiProblemException>()),
    );
    expect(cache.user, signedIn);
  });

  test('deleting the account forgets the session on this phone', () async {
    await repository.signIn(email: 'rimaz@example.com', password: 'x');

    await repository.deleteAccount('secret-pass');

    expect(api.deletionPasswords, ['secret-pass']);
    expect(tokens.tokens, isNull);
    expect(cache.user, isNull);
  });

  test('a refused deletion keeps the session', () async {
    await repository.signIn(email: 'rimaz@example.com', password: 'x');
    api.deleteAccountError = const ApiProblemException(
      statusCode: 422,
      code: ApiErrorCodes.passwordIncorrect,
    );

    await expectLater(
      repository.deleteAccount('wrong-pass'),
      throwsA(isA<ApiProblemException>()),
    );
    expect(tokens.tokens, isNotNull);
    expect(cache.user, isNotNull);
  });
}
