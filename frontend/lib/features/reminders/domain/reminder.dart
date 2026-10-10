import 'package:freezed_annotation/freezed_annotation.dart';

import '../../documents/domain/vehicle_document.dart';
import '../../maintenance/domain/maintenance_record.dart';

part 'reminder.freezed.dart';

/// Where a reminder comes from. Wire values match the backend's enum.
enum ReminderSource {
  /// Added by the user; the only kind the user edits directly.
  manual('MANUAL'),

  /// Follows the latest service of a type that sets a next date or mileage.
  service('SERVICE'),

  /// Follows the latest expiry date of a document type.
  document('DOCUMENT');

  const ReminderSource(this.wireValue);

  final String wireValue;

  static ReminderSource fromWire(String value) => values.firstWhere(
    (source) => source.wireValue == value,
    orElse: () => throw FormatException('Unknown reminder source: $value'),
  );
}

/// How urgent a reminder is today, as the server works it out.
enum ReminderStatus {
  overdue('OVERDUE'),

  /// Within a week (a month for documents) or 500 km, including today.
  dueSoon('DUE_SOON'),
  upcoming('UPCOMING');

  const ReminderStatus(this.wireValue);

  final String wireValue;

  static ReminderStatus fromWire(String value) => values.firstWhere(
    (status) => status.wireValue == value,
    orElse: () => throw FormatException('Unknown reminder status: $value'),
  );
}

/// Something due on a vehicle by date, by mileage or by whichever comes
/// first. The server calculates the remaining days and kilometres.
@freezed
abstract class Reminder with _$Reminder {
  const factory Reminder({
    required String id,
    required String vehicleId,
    required ReminderSource source,
    required ReminderStatus status,

    /// Set for service reminders.
    ServiceType? serviceType,

    /// Set for document reminders.
    DocumentType? documentType,

    /// The service record or document an automatic reminder follows.
    String? sourceId,

    /// Set for the user's own reminders.
    String? title,
    DateTime? dueDate,
    int? dueKm,

    /// First day the reminder counts as due soon (date-based reminders).
    DateTime? remindFrom,

    /// Negative when overdue.
    int? daysRemaining,

    /// Negative when overdue.
    int? kmRemaining,
  }) = _Reminder;

  const Reminder._();

  bool get isManual => source == ReminderSource.manual;

  ReminderDraft toDraft() =>
      ReminderDraft(title: title ?? '', dueDate: dueDate, dueKm: dueKm);
}

/// The details of a reminder the user enters: a due date, a mileage or both.
@freezed
abstract class ReminderDraft with _$ReminderDraft {
  const factory ReminderDraft({
    required String title,
    DateTime? dueDate,
    int? dueKm,
  }) = _ReminderDraft;
}
