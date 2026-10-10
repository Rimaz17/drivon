import 'dart:async';

import 'package:drivon/app/app.dart';
import 'package:drivon/app/router.dart';
import 'package:drivon/core/errors/app_exception.dart';
import 'package:drivon/core/storage/token_store.dart';
import 'package:drivon/core/utils/date_format.dart';
import 'package:drivon/features/maintenance/domain/maintenance_record.dart';
import 'package:drivon/features/notifications/presentation/notification_controller.dart';
import 'package:drivon/features/reminders/domain/reminder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import '../../support/test_app.dart';
import '../vehicles/vehicle_test_doubles.dart';
import 'reminder_test_doubles.dart';

void main() {
  late FakeReminderApi reminders;
  late FakeLocalNotifications local;
  late ProviderContainer container;
  final now = today();

  Future<void> pumpApp(WidgetTester tester, {String? path}) async {
    tester.view.physicalSize = const Size(1236, 2745);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    container = ProviderContainer(
      overrides: testOverrides(
        tokens: InMemoryTokenStore(
          const AuthTokens(accessToken: 'a', refreshToken: 'r'),
        ),
        vehicleApi: FakeVehicleApi([vehicleDto()]),
        reminderApi: reminders,
        localNotifications: local,
      ),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const DrivonApp()),
    );
    await tester.pumpAndSettle();
    if (path != null) {
      unawaited(container.read(routerProvider).push(path));
      await tester.pumpAndSettle();
    }
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        200,
        scrollable: find.byType(Scrollable).last,
      );
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  setUp(() {
    reminders = FakeReminderApi();
    local = FakeLocalNotifications();
  });

  testWidgets('explains where reminders come from when there are none', (
    tester,
  ) async {
    await pumpApp(tester, path: AppRoutes.remindersPath('vehicle-1'));

    expect(find.text('No reminders yet'), findsOneWidget);
    expect(find.text('Add reminder'), findsOneWidget);
  });

  testWidgets('groups reminders by urgency with the most urgent on top', (
    tester,
  ) async {
    reminders.reminders.addAll([
      const Reminder(
        id: 'r1',
        vehicleId: 'vehicle-1',
        source: ReminderSource.service,
        status: ReminderStatus.overdue,
        serviceType: ServiceType.oilChange,
        sourceId: 'service-1',
        dueKm: 44000,
        kmRemaining: -1000,
      ),
      reminder(
        id: 'r2',
        dueDate: now.add(const Duration(days: 40)),
        remindFrom: now.add(const Duration(days: 33)),
        daysRemaining: 40,
      ),
    ]);

    await pumpApp(tester, path: AppRoutes.remindersPath('vehicle-1'));

    // The highlight card and the row both name the overdue service.
    expect(find.text('Oil change is overdue'), findsNWidgets(2));
    expect(find.text('Overdue'), findsWidgets);
    expect(find.text('Upcoming'), findsWidgets);
    expect(find.text('Emission test due in 40 days'), findsOneWidget);
    expect(find.text('From your services'), findsOneWidget);
  });

  testWidgets('asks to turn notifications on and confirms they are on', (
    tester,
  ) async {
    reminders.reminders.add(
      reminder(dueDate: now.add(const Duration(days: 3)), daysRemaining: 3),
    );
    await pumpApp(tester, path: AppRoutes.remindersPath('vehicle-1'));

    expect(find.text('Get reminder notifications'), findsOneWidget);
    await tapAndSettle(tester, find.text('Turn on notifications'));

    expect(local.permissionRequests, 1);
    expect(
      container.read(notificationControllerProvider),
      NotificationStatus.local,
    );
    expect(find.text('Get reminder notifications'), findsNothing);
    await tapAndSettle(tester, find.text('Send a test'));
    expect(local.shown.single.title, 'Drivon reminders are on');
  });

  testWidgets('a declined prompt points to the settings', (tester) async {
    local.grantOnRequest = false;
    reminders.reminders.add(
      reminder(dueDate: now.add(const Duration(days: 3)), daysRemaining: 3),
    );
    await pumpApp(tester, path: AppRoutes.remindersPath('vehicle-1'));

    await tapAndSettle(tester, find.text('Turn on notifications'));
    await tapAndSettle(tester, find.text('Open settings'));

    expect(local.settingsOpened, 1);
  });

  testWidgets('adds a reminder due by date or mileage', (tester) async {
    await pumpApp(tester, path: AppRoutes.remindersPath('vehicle-1'));
    await tapAndSettle(tester, find.text('Add reminder'));

    // Neither a date nor a mileage yet.
    await tapAndSettle(
      tester,
      find.widgetWithText(FilledButton, 'Add reminder'),
    );
    expect(find.text('Enter what the reminder is for.'), findsOneWidget);
    expect(find.text('Set a due date or an odometer reading.'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, "What's due"),
      'Emission test',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Due at odometer (optional)'),
      '44000',
    );
    await tapAndSettle(
      tester,
      find.widgetWithText(FilledButton, 'Add reminder'),
    );
    expect(find.text('Enter more than the current 45,000 km.'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Due at odometer (optional)'),
      '50000',
    );
    await tapAndSettle(
      tester,
      find.widgetWithText(FilledButton, 'Add reminder'),
    );

    expect(reminders.created.single.draft.title, 'Emission test');
    expect(reminders.created.single.draft.dueKm, 50000);
    expect(find.text('Reminder added'), findsOneWidget);
    expect(find.text('Emission test due in 5,000 km'), findsNothing);
  });

  testWidgets('a retry after a lost response keeps the same ID', (
    tester,
  ) async {
    await pumpApp(tester, path: AppRoutes.addReminderPath('vehicle-1'));
    await tester.enterText(
      find.widgetWithText(TextFormField, "What's due"),
      'Emission test',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Due at odometer (optional)'),
      '50000',
    );
    reminders.nextError = const ServerTimeoutException();
    await tapAndSettle(
      tester,
      find.widgetWithText(FilledButton, 'Add reminder'),
    );
    await tapAndSettle(
      tester,
      find.widgetWithText(FilledButton, 'Add reminder'),
    );

    expect(reminders.created, hasLength(1));
    expect(reminders.attemptedIds, hasLength(2));
    expect(reminders.attemptedIds.toSet(), hasLength(1));
  });

  testWidgets('marks the users own reminder as done', (tester) async {
    reminders.reminders.add(
      reminder(dueDate: now.add(const Duration(days: 3)), daysRemaining: 3),
    );
    await pumpApp(tester, path: AppRoutes.remindersPath('vehicle-1'));

    await tapAndSettle(tester, find.text('Emission test due in 3 days').last);
    expect(find.text('Edit reminder'), findsOneWidget);
    await tapAndSettle(tester, find.text('Mark as done'));
    await tapAndSettle(tester, find.text('Mark as done').last);

    expect(reminders.deleted, ['reminder-1']);
    expect(find.text('Reminder done'), findsOneWidget);
  });

  testWidgets('the garage shows the most urgent reminder', (tester) async {
    reminders.reminders.addAll([
      reminder(
        id: 'r1',
        status: ReminderStatus.dueSoon,
        dueDate: now.add(const Duration(days: 2)),
        daysRemaining: 2,
      ),
      reminder(
        id: 'r2',
        title: 'Wash',
        status: ReminderStatus.dueSoon,
        dueDate: now.add(const Duration(days: 4)),
        daysRemaining: 4,
      ),
    ]);
    await pumpApp(tester);
    await tester.scrollUntilVisible(
      find.text('1 more reminder needs attention'),
      200,
      scrollable: find.byType(Scrollable).last,
    );

    expect(find.text('Emission test due in 2 days'), findsOneWidget);
    expect(find.text('1 more reminder needs attention'), findsOneWidget);
    await tapAndSettle(tester, find.text('Emission test due in 2 days'));
    expect(find.text('Reminders'), findsWidgets);
  });

  testWidgets('a tapped notification opens that vehicles reminders', (
    tester,
  ) async {
    await pumpApp(tester);

    local.onTap!('vehicle-1');
    await tester.pumpAndSettle();

    expect(find.text('No reminders yet'), findsOneWidget);
  });
}
