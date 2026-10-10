import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/utils/date_format.dart';
import '../../documents/domain/vehicle_document.dart';
import '../../maintenance/domain/maintenance_record.dart';
import '../domain/reminder.dart';

DateTime? _dateOrNull(Object? value) =>
    value is String ? ApiDate.parse(value) : null;

/// `ReminderResponse` from the API.
Reminder reminderFromJson(Map<String, dynamic> json) {
  final serviceType = json['serviceType'] as String?;
  final documentType = json['documentType'] as String?;
  return Reminder(
    id: json['id'] as String,
    vehicleId: json['vehicleId'] as String,
    source: ReminderSource.fromWire(json['source'] as String),
    status: ReminderStatus.fromWire(json['status'] as String),
    serviceType: serviceType == null ? null : ServiceType.fromWire(serviceType),
    documentType: documentType == null
        ? null
        : DocumentType.fromWire(documentType),
    sourceId: json['sourceId'] as String?,
    title: json['title'] as String?,
    dueDate: _dateOrNull(json['dueDate']),
    dueKm: (json['dueKm'] as num?)?.toInt(),
    remindFrom: _dateOrNull(json['remindFrom']),
    daysRemaining: (json['daysRemaining'] as num?)?.toInt(),
    kmRemaining: (json['kmRemaining'] as num?)?.toInt(),
  );
}

/// `ReminderRequest` body; [id] only when creating.
Map<String, dynamic> reminderRequestJson(ReminderDraft draft, {String? id}) {
  final dueDate = draft.dueDate;
  return {
    'id': ?id,
    'title': draft.title.trim(),
    'dueDate': dueDate == null ? null : ApiDate.format(dueDate),
    'dueKm': draft.dueKm,
  };
}

List<Reminder> _reminderList(List<dynamic>? data) =>
    data!.cast<Map<String, dynamic>>().map(reminderFromJson).toList();

/// HTTP calls for reminders. Throws AppExceptions.
class ReminderApi {
  ReminderApi(this._dio);

  final Dio _dio;

  static String _reminders(String vehicleId) =>
      '/api/v1/vehicles/$vehicleId/reminders';

  /// The user's reminders across vehicles, most urgent first.
  Future<List<Reminder>> listAll() => guardApi(() async {
    final response = await _dio.get<List<dynamic>>('/api/v1/reminders');
    return _reminderList(response.data);
  });

  /// A vehicle's reminders, most urgent first.
  Future<List<Reminder>> list(String vehicleId) => guardApi(() async {
    final response = await _dio.get<List<dynamic>>(_reminders(vehicleId));
    return _reminderList(response.data);
  });

  Future<Reminder> get(String vehicleId, String id) => guardApi(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '${_reminders(vehicleId)}/$id',
    );
    return reminderFromJson(response.data!);
  });

  /// Adds the user's own reminder; resending [id] returns the saved one.
  Future<Reminder> create(
    String vehicleId,
    ReminderDraft draft, {
    required String id,
  }) => guardApi(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      _reminders(vehicleId),
      data: reminderRequestJson(draft, id: id),
    );
    return reminderFromJson(response.data!);
  });

  Future<Reminder> update(String vehicleId, String id, ReminderDraft draft) =>
      guardApi(() async {
        final response = await _dio.put<Map<String, dynamic>>(
          '${_reminders(vehicleId)}/$id',
          data: reminderRequestJson(draft),
        );
        return reminderFromJson(response.data!);
      });

  Future<void> delete(String vehicleId, String id) =>
      guardApi(() => _dio.delete<void>('${_reminders(vehicleId)}/$id'));
}

final reminderApiProvider = Provider<ReminderApi>(
  (ref) => ReminderApi(ref.watch(dioProvider)),
);
