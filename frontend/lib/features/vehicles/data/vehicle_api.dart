import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/vehicle.dart';
import 'vehicle_dto.dart';

/// HTTP calls for `/api/v1/vehicles`. Throws AppExceptions.
class VehicleApi {
  VehicleApi(this._dio);

  static const String _path = '/api/v1/vehicles';

  final Dio _dio;

  Future<List<VehicleDto>> list() => guardApi(() async {
    final response = await _dio.get<List<dynamic>>(_path);
    return response.data!
        .cast<Map<String, dynamic>>()
        .map(VehicleDto.fromJson)
        .toList();
  });

  Future<VehicleDto> create(VehicleDraft draft) => guardApi(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      _path,
      data: vehicleRequestJson(draft),
    );
    return VehicleDto.fromJson(response.data!);
  });

  Future<VehicleDto> update(String id, VehicleDraft draft) =>
      guardApi(() async {
        final response = await _dio.put<Map<String, dynamic>>(
          '$_path/$id',
          data: vehicleRequestJson(draft),
        );
        return VehicleDto.fromJson(response.data!);
      });

  Future<void> delete(String id) =>
      guardApi(() => _dio.delete<void>('$_path/$id'));
}

final vehicleApiProvider = Provider<VehicleApi>(
  (ref) => VehicleApi(ref.watch(dioProvider)),
);
