import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/paged.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/utils/date_format.dart';
import '../domain/odometer_reading.dart';

/// `OdometerReadingResponse` from the API.
OdometerReading odometerReadingFromJson(Map<String, dynamic> json) =>
    OdometerReading(
      id: json['id'] as String,
      readingKm: (json['readingKm'] as num).toInt(),
      date: ApiDate.parse(json['date'] as String),
      source: OdometerSource.fromWire(json['source'] as String),
      sourceId: json['sourceId'] as String?,
    );

/// HTTP calls for a vehicle's odometer history. Throws AppExceptions.
class OdometerApi {
  OdometerApi(this._dio);

  final Dio _dio;

  static String _path(String vehicleId) =>
      '/api/v1/vehicles/$vehicleId/odometer-readings';

  /// Readings, newest first.
  Future<Paged<OdometerReading>> list(
    String vehicleId, {
    required int page,
    int size = 20,
  }) => guardApi(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      _path(vehicleId),
      queryParameters: {'page': page, 'size': size},
    );
    return Paged.fromJson(response.data!, odometerReadingFromJson);
  });

  Future<OdometerReading> add(String vehicleId, int readingKm, DateTime date) =>
      guardApi(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          _path(vehicleId),
          data: _body(readingKm, date),
        );
        return odometerReadingFromJson(response.data!);
      });

  Future<OdometerReading> correct(
    String vehicleId,
    String id,
    int readingKm,
    DateTime date,
  ) => guardApi(() async {
    final response = await _dio.put<Map<String, dynamic>>(
      '${_path(vehicleId)}/$id',
      data: _body(readingKm, date),
    );
    return odometerReadingFromJson(response.data!);
  });

  Future<void> delete(String vehicleId, String id) =>
      guardApi(() => _dio.delete<void>('${_path(vehicleId)}/$id'));

  static Map<String, dynamic> _body(int readingKm, DateTime date) => {
    'readingKm': readingKm,
    'date': ApiDate.format(date),
  };
}

final odometerApiProvider = Provider<OdometerApi>(
  (ref) => OdometerApi(ref.watch(dioProvider)),
);
