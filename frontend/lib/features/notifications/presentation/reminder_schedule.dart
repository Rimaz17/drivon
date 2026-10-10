import 'package:intl/intl.dart';

import '../../../core/services/local_notifications.dart';
import '../../../l10n/app_localizations.dart';
import '../../reminders/domain/reminder.dart';
import '../../reminders/presentation/reminder_text.dart';

/// Hour of the day (Sri Lanka time) local reminder notifications appear.
const int reminderNotificationHour = 9;

/// iOS keeps at most 64 pending notifications per app; stay below that.
const int maxScheduledNotifications = 60;

/// The local notifications for [reminders]: one on the first due-soon day
/// and one on the due day, at 9:00, for every date-based reminder. Mileage
/// can't be known ahead, so mileage-only reminders get none. Times already
/// past are left out; the soonest [maxScheduledNotifications] are kept.
///
/// [vehicleNames] maps vehicle IDs to the name shown in the notification.
/// Each notification's payload is the vehicle ID, so a tap opens that
/// vehicle's reminders.
List<ScheduledNotification> reminderSchedule({
  required List<Reminder> reminders,
  required Map<String, String> vehicleNames,
  required AppLocalizations l10n,
  required DateTime now,
}) {
  // en_US date symbols ship with intl, so no locale data has to be loaded.
  final dateFormat = DateFormat('d MMM y', 'en_US');
  final pending =
      <({DateTime at, String title, String body, String vehicle})>[];

  DateTime atNine(DateTime day) =>
      DateTime(day.year, day.month, day.day, reminderNotificationHour);

  for (final reminder in reminders) {
    final dueDate = reminder.dueDate;
    if (dueDate == null) continue;
    final name = reminderName(l10n, reminder);
    final vehicle = vehicleNames[reminder.vehicleId] ?? '';
    final date = dateFormat.format(dueDate);
    final isDocument = reminder.source == ReminderSource.document;
    final body = isDocument
        ? l10n.notificationExpiresBody(vehicle, date)
        : l10n.notificationDueBody(vehicle, date);

    final remindFrom = reminder.remindFrom;
    if (remindFrom != null && remindFrom.isBefore(dueDate)) {
      pending.add((
        at: atNine(remindFrom),
        title: isDocument
            ? l10n.notificationExpiresSoonTitle(name)
            : l10n.notificationDueSoonTitle(name),
        body: body,
        vehicle: reminder.vehicleId,
      ));
    }
    pending.add((
      at: atNine(dueDate),
      title: isDocument
          ? l10n.notificationExpiresTodayTitle(name)
          : l10n.notificationDueTodayTitle(name),
      body: body,
      vehicle: reminder.vehicleId,
    ));
  }

  final upcoming = pending.where((n) => n.at.isAfter(now)).toList()
    ..sort((a, b) => a.at.compareTo(b.at));
  return [
    for (final (index, notification)
        in upcoming.take(maxScheduledNotifications).indexed)
      ScheduledNotification(
        // Every schedule replaces the previous one, so IDs only need to be
        // unique within it.
        id: index + 1,
        at: notification.at,
        title: notification.title,
        body: notification.body,
        payload: notification.vehicle,
      ),
  ];
}
