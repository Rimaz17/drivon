import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/dio_provider.dart';

/// Registers this installation for push notifications. Throws AppExceptions.
class DeviceTokenApi {
  DeviceTokenApi(this._dio);

  final Dio _dio;

  static const String _path = '/api/v1/device-tokens';

  /// Idempotent; also moves a token another account registered on this
  /// phone to the signed-in user.
  Future<void> register(String token) => guardApi(
    () => _dio.put<void>(_path, data: {'token': token, 'platform': 'ANDROID'}),
  );

  Future<void> unregister(String token) =>
      guardApi(() => _dio.delete<void>('$_path/${Uri.encodeComponent(token)}'));
}

final deviceTokenApiProvider = Provider<DeviceTokenApi>(
  (ref) => DeviceTokenApi(ref.watch(dioProvider)),
);
