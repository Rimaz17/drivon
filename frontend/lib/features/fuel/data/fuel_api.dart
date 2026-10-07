import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/monthly_amount.dart';
import '../../../core/models/paged.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/fuel_record.dart';
import 'fuel_dto.dart';

/// HTTP calls for a vehicle's fill-ups and fuel stats. Throws AppExceptions.
class FuelApi {
  FuelApi(this._dio);

  final Dio _dio;

  static String _records(String vehicleId) =>
      '/api/v1/vehicles/$vehicleId/fuel-records';

  static String _stats(String vehicleId) =>
      '/api/v1/vehicles/$vehicleId/fuel-stats';

  /// Fill-ups, newest first.
  Future<Paged<FuelRecordDto>> list(
    String vehicleId, {
    required int page,
    int size = 20,
  }) => guardApi(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      _records(vehicleId),
      queryParameters: {'page': page, 'size': size},
    );
    return Paged.fromJson(response.data!, FuelRecordDto.fromJson);
  });

  Future<FuelRecordDto> get(String vehicleId, String id) => guardApi(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '${_records(vehicleId)}/$id',
    );
    return FuelRecordDto.fromJson(response.data!);
  });

  /// Logs a fill-up under the app-generated [id]; retrying with the same ID
  /// returns the record already saved.
  Future<FuelRecordDto> create(
    String vehicleId,
    FuelDraft draft, {
    required String id,
  }) => guardApi(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      _records(vehicleId),
      data: fuelRequestJson(draft, id: id),
    );
    return FuelRecordDto.fromJson(response.data!);
  });

  Future<FuelRecordDto> update(String vehicleId, String id, FuelDraft draft) =>
      guardApi(() async {
        final response = await _dio.put<Map<String, dynamic>>(
          '${_records(vehicleId)}/$id',
          data: fuelRequestJson(draft),
        );
        return FuelRecordDto.fromJson(response.data!);
      });

  Future<void> delete(String vehicleId, String id) =>
      guardApi(() => _dio.delete<void>('${_records(vehicleId)}/$id'));

  /// All-time figures.
  Future<FuelStatsDto> stats(String vehicleId) => guardApi(() async {
    final response = await _dio.get<Map<String, dynamic>>(_stats(vehicleId));
    return FuelStatsDto.fromJson(response.data!);
  });

  /// Fuel spend for the last [months] months, oldest first.
  Future<List<MonthlyAmount>> monthly(
    String vehicleId, {
    required int months,
  }) => guardApi(() async {
    final response = await _dio.get<List<dynamic>>(
      '${_stats(vehicleId)}/monthly',
      queryParameters: {'months': months},
    );
    return response.data!
        .cast<Map<String, dynamic>>()
        .map(MonthlyAmount.fromJson)
        .toList();
  });
}

final fuelApiProvider = Provider<FuelApi>(
  (ref) => FuelApi(ref.watch(dioProvider)),
);
