import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/dio_provider.dart';
import 'auth_dtos.dart';

/// HTTP calls for `/api/v1/auth` and `/api/v1/users`. Throws AppExceptions.
class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  Future<AuthResponseDto> register({
    required String name,
    required String email,
    required String password,
  }) => _post('/api/v1/auth/register', {
    'name': name,
    'email': email,
    'password': password,
  });

  Future<AuthResponseDto> login({
    required String email,
    required String password,
  }) => _post('/api/v1/auth/login', {'email': email, 'password': password});

  Future<void> logout(String refreshToken) => guardApi(
    () => _dio.post<void>(
      '/api/v1/auth/logout',
      data: {'refreshToken': refreshToken},
      options: publicRequest,
    ),
  );

  Future<UserDto> me() => guardApi(() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/users/me');
    return UserDto.fromJson(response.data!);
  });

  Future<AuthResponseDto> _post(String path, Map<String, String> body) =>
      guardApi(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          path,
          data: body,
          options: publicRequest,
        );
        return AuthResponseDto.fromJson(response.data!);
      });
}

final authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(ref.watch(dioProvider)),
);
