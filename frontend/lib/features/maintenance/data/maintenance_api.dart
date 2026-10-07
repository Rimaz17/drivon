import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/paged.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/fixed_decimal.dart';
import '../domain/maintenance_record.dart';

DateTime? _dateOrNull(Object? value) =>
    value is String ? ApiDate.parse(value) : null;

/// `MaintenanceRecordResponse` from the API.
MaintenanceRecord maintenanceRecordFromJson(Map<String, dynamic> json) =>
    MaintenanceRecord(
      id: json['id'] as String,
      vehicleId: json['vehicleId'] as String,
      serviceType: ServiceType.fromWire(json['serviceType'] as String),
      date: ApiDate.parse(json['date'] as String),
      cost: FixedDecimal.parse(
        json['cost'] as String,
        scale: FixedDecimal.moneyScale,
      ),
      odometerKm: (json['odometerKm'] as num?)?.toInt(),
      notes: json['notes'] as String?,
      nextServiceDate: _dateOrNull(json['nextServiceDate']),
      nextServiceKm: (json['nextServiceKm'] as num?)?.toInt(),
    );

/// `UpcomingServiceResponse` from the API.
UpcomingService upcomingServiceFromJson(Map<String, dynamic> json) =>
    UpcomingService(
      serviceType: ServiceType.fromWire(json['serviceType'] as String),
      recordId: json['recordId'] as String,
      lastServicedOn: ApiDate.parse(json['lastServicedOn'] as String),
      overdue: json['overdue'] as bool,
      dueDate: _dateOrNull(json['dueDate']),
      dueKm: (json['dueKm'] as num?)?.toInt(),
      daysRemaining: (json['daysRemaining'] as num?)?.toInt(),
      kmRemaining: (json['kmRemaining'] as num?)?.toInt(),
    );

/// `MaintenanceRecordRequest` body; [id] only when creating.
Map<String, dynamic> maintenanceRequestJson(
  MaintenanceDraft draft, {
  String? id,
}) {
  final notes = draft.notes?.trim();
  final nextDate = draft.nextServiceDate;
  return {
    'id': ?id,
    'serviceType': draft.serviceType.wireValue,
    'date': ApiDate.format(draft.date),
    'odometerKm': draft.odometerKm,
    'cost': draft.cost.toPlainString(),
    'notes': notes == null || notes.isEmpty ? null : notes,
    'nextServiceDate': nextDate == null ? null : ApiDate.format(nextDate),
    'nextServiceKm': draft.nextServiceKm,
  };
}

/// HTTP calls for a vehicle's services. Throws AppExceptions.
class MaintenanceApi {
  MaintenanceApi(this._dio);

  final Dio _dio;

  static String _path(String vehicleId) =>
      '/api/v1/vehicles/$vehicleId/maintenance-records';

  /// Services, newest first, optionally of one [type].
  Future<Paged<MaintenanceRecord>> list(
    String vehicleId, {
    required int page,
    ServiceType? type,
    int size = 20,
  }) => guardApi(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      _path(vehicleId),
      queryParameters: {
        'page': page,
        'size': size,
        'serviceType': ?type?.wireValue,
      },
    );
    return Paged.fromJson(response.data!, maintenanceRecordFromJson);
  });

  Future<MaintenanceRecord> get(String vehicleId, String id) =>
      guardApi(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          '${_path(vehicleId)}/$id',
        );
        return maintenanceRecordFromJson(response.data!);
      });

  Future<List<UpcomingService>> upcoming(String vehicleId) =>
      guardApi(() async {
        final response = await _dio.get<List<dynamic>>(
          '${_path(vehicleId)}/upcoming',
        );
        return response.data!
            .cast<Map<String, dynamic>>()
            .map(upcomingServiceFromJson)
            .toList();
      });

  Future<MaintenanceRecord> create(
    String vehicleId,
    MaintenanceDraft draft, {
    required String id,
  }) => guardApi(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      _path(vehicleId),
      data: maintenanceRequestJson(draft, id: id),
    );
    return maintenanceRecordFromJson(response.data!);
  });

  Future<MaintenanceRecord> update(
    String vehicleId,
    String id,
    MaintenanceDraft draft,
  ) => guardApi(() async {
    final response = await _dio.put<Map<String, dynamic>>(
      '${_path(vehicleId)}/$id',
      data: maintenanceRequestJson(draft),
    );
    return maintenanceRecordFromJson(response.data!);
  });

  Future<void> delete(String vehicleId, String id) =>
      guardApi(() => _dio.delete<void>('${_path(vehicleId)}/$id'));
}

final maintenanceApiProvider = Provider<MaintenanceApi>(
  (ref) => MaintenanceApi(ref.watch(dioProvider)),
);
