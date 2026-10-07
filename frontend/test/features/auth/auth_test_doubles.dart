import 'package:drivon/core/errors/app_exception.dart';
import 'package:drivon/features/auth/data/auth_api.dart';
import 'package:drivon/features/auth/data/auth_dtos.dart';
import 'package:drivon/features/auth/data/user_cache.dart';
import 'package:drivon/features/auth/domain/user.dart';

const testUserDto = UserDto(
  id: 'user-1',
  name: 'Rimaz Saththar',
  email: 'rimaz@example.com',
);

const testAuthResponse = AuthResponseDto(
  accessToken: 'access-1',
  refreshToken: 'refresh-1',
  user: testUserDto,
);

/// Scriptable [AuthApi]: each call returns its configured result or throws.
class FakeAuthApi implements AuthApi {
  Object? loginResult = testAuthResponse;
  Object? registerResult = testAuthResponse;
  Object? meResult = testUserDto;
  final List<String> loggedOutTokens = [];
  Map<String, String>? lastLogin;

  @override
  Future<AuthResponseDto> login({
    required String email,
    required String password,
  }) async {
    lastLogin = {'email': email, 'password': password};
    return _resolve(loginResult);
  }

  @override
  Future<AuthResponseDto> register({
    required String name,
    required String email,
    required String password,
  }) async => _resolve(registerResult);

  @override
  Future<UserDto> me() async => _resolve(meResult);

  @override
  Future<void> logout(String refreshToken) async =>
      loggedOutTokens.add(refreshToken);

  T _resolve<T>(Object? result) {
    if (result is AppException) throw result;
    return result as T;
  }
}

class InMemoryUserCache implements UserCache {
  User? user;

  @override
  Future<User?> read() async => user;

  @override
  Future<void> save(User user) async => this.user = user;

  @override
  Future<void> clear() async => user = null;
}
