import 'package:drivon/features/documents/domain/vehicle_document.dart';
import 'package:drivon/features/notifications/presentation/reminder_schedule.dart';
import 'package:drivon/features/reminders/domain/reminder.dart';
import 'package:drivon/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../reminders/reminder_test_doubles.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  final now = DateTime(2026, 10, 10, 12);
  const names = {'vehicle-1': 'Toyota Aqua CAB-1234'};

  test('notifies on the first due-soon day and on the due day at 9:00', () {
    final schedule = reminderSchedule(
      reminders: [
        reminder(
          dueDate: DateTime(2026, 10, 20),
          remindFrom: DateTime(2026, 10, 13),
        ),
      ],
      vehicleNames: names,
      l10n: l10n,
      now: now,
    );

    expect(schedule, hasLength(2));
    expect(schedule.first.at, DateTime(2026, 10, 13, 9));
    expect(schedule.first.title, 'Emission test is due soon');
    expect(schedule.first.body, 'Toyota Aqua CAB-1234: due 20 Oct 2026');
    expect(schedule.first.payload, 'vehicle-1');
    expect(schedule.last.at, DateTime(2026, 10, 20, 9));
    expect(schedule.last.title, 'Emission test is due today');
    expect(schedule.map((n) => n.id), [1, 2]);
  });

  test('documents talk about expiry', () {
    final schedule = reminderSchedule(
      reminders: [
        Reminder(
          id: 'reminder-2',
          vehicleId: 'vehicle-1',
          source: ReminderSource.document,
          status: ReminderStatus.upcoming,
          documentType: DocumentType.insurance,
          dueDate: DateTime(2026, 12, 31),
          remindFrom: DateTime(2026, 12),
        ),
      ],
      vehicleNames: names,
      l10n: l10n,
      now: now,
    );

    expect(schedule.map((n) => n.title), [
      'Insurance expires soon',
      'Insurance expires today',
    ]);
    expect(schedule.first.body, 'Toyota Aqua CAB-1234: expires 31 Dec 2026');
  });

  test('leaves out past times, mileage-only reminders, and keeps order', () {
    final schedule = reminderSchedule(
      reminders: [
        // Already due soon: only the due day is still ahead.
        reminder(
          id: 'a',
          dueDate: DateTime(2026, 10, 14),
          remindFrom: DateTime(2026, 10, 7),
        ),
        reminder(id: 'b', dueKm: 50000),
        // Due today at 9:00, which has passed.
        reminder(
          id: 'c',
          dueDate: DateTime(2026, 10, 10),
          remindFrom: DateTime(2026, 10, 3),
        ),
        reminder(
          id: 'd',
          dueDate: DateTime(2026, 10, 12),
          remindFrom: DateTime(2026, 10, 5),
        ),
      ],
      vehicleNames: names,
      l10n: l10n,
      now: now,
    );

    expect(schedule.map((n) => n.at), [
      DateTime(2026, 10, 12, 9),
      DateTime(2026, 10, 14, 9),
    ]);
  });

  test('keeps the soonest notifications within the iOS limit', () {
    final schedule = reminderSchedule(
      reminders: [
        for (var i = 0; i < 40; i++)
          reminder(
            id: 'r$i',
            dueDate: DateTime(2027).add(Duration(days: i)),
            remindFrom: DateTime(2026, 12, 25).add(Duration(days: i)),
          ),
      ],
      vehicleNames: names,
      l10n: l10n,
      now: now,
    );

    expect(schedule, hasLength(maxScheduledNotifications));
    expect(schedule.first.at, DateTime(2026, 12, 25, 9));
    expect(schedule.map((n) => n.id).toSet(), hasLength(60));
  });
}
