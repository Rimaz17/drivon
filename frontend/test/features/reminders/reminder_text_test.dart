import 'package:drivon/features/documents/domain/vehicle_document.dart';
import 'package:drivon/features/reminders/domain/reminder.dart';
import 'package:drivon/features/reminders/presentation/reminder_text.dart';
import 'package:drivon/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_app.dart';
import 'reminder_test_doubles.dart';

void main() {
  final today = DateTime(2026, 10, 10);

  Future<(String, String)> describe(WidgetTester tester, Reminder r) async {
    late (String, String) text;
    await tester.pumpWidget(
      localizedApp(
        Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context);
            text = (
              reminderHeadline(context, l10n, r, today),
              reminderDetail(context, l10n, r),
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return text;
  }

  testWidgets('a date reminder counts the days', (tester) async {
    final (headline, detail) = await describe(
      tester,
      reminder(
        status: ReminderStatus.dueSoon,
        dueDate: DateTime(2026, 10, 15),
        daysRemaining: 5,
      ),
    );

    expect(headline, 'Emission test due in 5 days');
    expect(detail, 'Due 15 Oct 2026');
  });

  testWidgets('the mileage leads while the date is still far off', (
    tester,
  ) async {
    final (headline, detail) = await describe(
      tester,
      reminder(
        status: ReminderStatus.dueSoon,
        dueDate: DateTime(2027, 3),
        remindFrom: DateTime(2027, 2, 22),
        daysRemaining: 142,
        dueKm: 50000,
        kmRemaining: 300,
      ),
    );

    expect(headline, 'Emission test due in 300 km');
    expect(detail, 'Due 1 Mar 2027 or at 50,000 km, whichever comes first');
  });

  testWidgets('a reached mileage is due now, a passed one overdue', (
    tester,
  ) async {
    expect(
      (await describe(
        tester,
        reminder(status: ReminderStatus.dueSoon, dueKm: 50000, kmRemaining: 0),
      )).$1,
      'Emission test is due now',
    );
    expect(
      (await describe(
        tester,
        reminder(
          status: ReminderStatus.overdue,
          dueKm: 50000,
          kmRemaining: -20,
        ),
      )).$1,
      'Emission test is overdue',
    );
  });

  testWidgets('documents talk about expiry', (tester) async {
    final document = Reminder(
      id: 'r',
      vehicleId: 'vehicle-1',
      source: ReminderSource.document,
      status: ReminderStatus.overdue,
      documentType: DocumentType.revenueLicence,
      dueDate: DateTime(2026, 10),
      daysRemaining: -9,
    );

    final (headline, detail) = await describe(tester, document);

    expect(headline, 'Revenue licence has expired');
    expect(detail, 'Expired 1 Oct 2026');
  });
}
