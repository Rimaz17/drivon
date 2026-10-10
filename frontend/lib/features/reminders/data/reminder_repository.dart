import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/uuid.dart';
import '../domain/reminder.dart';
import 'reminder_api.dart';

/// Reminders of the user's vehicles. Service and document reminders appear
/// and change with their records on the server; the user manages only their
/// own.
class ReminderRepository {
  ReminderRepository(this._api, {this._newId = uuidV4});

  final ReminderApi _api;
  final String Function() _newId;

  /// An ID for a new reminder. Keep it for the whole add attempt: retrying
  /// [create] with it can't add the reminder twice.
  String newReminderId() => _newId();

  Future<List<Reminder>> listAll() => _api.listAll();

  Future<List<Reminder>> list(String vehicleId) => _api.list(vehicleId);

  Future<Reminder> get(String vehicleId, String id) => _api.get(vehicleId, id);

  Future<Reminder> create(
    String vehicleId,
    ReminderDraft draft, {
    required String id,
  }) => _api.create(vehicleId, draft, id: id);

  Future<Reminder> update(String vehicleId, String id, ReminderDraft draft) =>
      _api.update(vehicleId, id, draft);

  Future<void> delete(String vehicleId, String id) =>
      _api.delete(vehicleId, id);
}

final reminderRepositoryProvider = Provider<ReminderRepository>(
  (ref) => ReminderRepository(ref.watch(reminderApiProvider)),
);
