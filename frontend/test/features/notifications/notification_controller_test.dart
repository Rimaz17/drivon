import 'package:drivon/core/errors/app_exception.dart';
import 'package:drivon/core/services/push_messaging.dart';
import 'package:drivon/core/storage/token_store.dart';
import 'package:drivon/features/auth/presentation/session_controller.dart';
import 'package:drivon/features/notifications/presentation/notification_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import '../../support/test_app.dart';
import '../reminders/reminder_test_doubles.dart';
import '../vehicles/vehicle_test_doubles.dart';

void main() {
  late FakeLocalNotifications local;
  late FakePushMessaging push;
  late FakeDeviceTokenApi devices;
  late FakeReminderApi reminders;

  setUp(() {
    local = FakeLocalNotifications();
    push = FakePushMessaging();
    devices = FakeDeviceTokenApi();
    reminders = FakeReminderApi();
  });

  tearDown(() => push.close());

  /// A signed-in app whose notification controller has settled.
  Future<ProviderContainer> start({bool signedIn = true}) async {
    final container = ProviderContainer(
      overrides: testOverrides(
        tokens: signedIn
            ? InMemoryTokenStore(
                const AuthTokens(accessToken: 'a', refreshToken: 'r'),
              )
            : InMemoryTokenStore(),
        vehicleApi: FakeVehicleApi([vehicleDto()]),
        reminderApi: reminders,
        deviceTokenApi: devices,
        localNotifications: local,
        pushMessaging: push,
      ),
    );
    addTearDown(container.dispose);
    container
      ..listen(notificationBootstrapProvider, (_, _) {})
      ..listen(notificationControllerProvider, (_, _) {})
      ..listen(reminderScheduleSyncProvider, (_, _) {});
    await settle(container);
    return container;
  }

  test('stays off until the user allows notifications', () async {
    final container = await start();

    expect(
      container.read(notificationControllerProvider),
      NotificationStatus.off,
    );
    expect(local.initialized, isTrue);
    expect(local.permissionRequests, 0);
    // Nothing is left scheduled from before.
    expect(local.schedules.last, isEmpty);
  });

  test('schedules date reminders on the device without push', () async {
    local.enabled = true;
    reminders.reminders.add(
      reminder(
        dueDate: DateTime.now().add(const Duration(days: 30)),
        remindFrom: DateTime.now().add(const Duration(days: 23)),
      ),
    );

    final container = await start();

    expect(
      container.read(notificationControllerProvider),
      NotificationStatus.local,
    );
    expect(local.schedules.last, hasLength(2));
    expect(local.schedules.last.first.body, startsWith('Toyota Aqua CAB-1234'));
    expect(devices.registered, isEmpty);
  });

  test('turning notifications on registers this phone for push', () async {
    push = FakePushMessaging(supported: true);
    final container = await start();

    await container.read(notificationControllerProvider.notifier).enable();
    await settle(container);

    expect(local.permissionRequests, 1);
    expect(
      container.read(notificationControllerProvider),
      NotificationStatus.push,
    );
    expect(devices.registered, ['push-token-1']);
    // Push replaces local scheduling.
    expect(local.schedules.last, isEmpty);
  });

  test('a declined prompt is remembered as blocked', () async {
    local.grantOnRequest = false;
    final container = await start();

    await container.read(notificationControllerProvider.notifier).enable();

    expect(
      container.read(notificationControllerProvider),
      NotificationStatus.blocked,
    );
    await container
        .read(notificationControllerProvider.notifier)
        .openSettings();
    expect(local.settingsOpened, 1);
  });

  test(
    'falls back to local reminders when the server is unreachable',
    () async {
      local.enabled = true;
      push = FakePushMessaging(supported: true);
      devices.registerError = const NoConnectionException();

      final container = await start();

      expect(
        container.read(notificationControllerProvider),
        NotificationStatus.local,
      );
    },
  );

  test('falls back to local reminders without Firebase in the build', () async {
    local.enabled = true;
    push = FakePushMessaging(supported: true, configured: false);

    final container = await start();

    expect(
      container.read(notificationControllerProvider),
      NotificationStatus.local,
    );
    expect(devices.registered, isEmpty);
  });

  test('a new push token is sent to the server', () async {
    local.enabled = true;
    push = FakePushMessaging(supported: true);
    await start();

    push.refreshes.add('push-token-2');
    await pumpEventQueue();

    expect(devices.registered, ['push-token-1', 'push-token-2']);
  });

  test('pushes arriving while the app is open are shown', () async {
    local.enabled = true;
    push = FakePushMessaging(supported: true);
    await start();

    push.foreground.add(
      const PushNotice(
        title: 'Oil change is due soon',
        body: 'Toyota Aqua CAB-1234: Due at 50,000 km.',
        data: {'vehicleId': 'vehicle-1', 'reminderId': 'reminder-1'},
      ),
    );
    await pumpEventQueue();

    expect(local.shown.single.title, 'Oil change is due soon');
    expect(local.shown.single.payload, 'vehicle-1');
    expect(local.shown.single.id, greaterThanOrEqualTo(1000));
  });

  test('signing out stops pushes and clears notifications', () async {
    local.enabled = true;
    push = FakePushMessaging(supported: true);
    final container = await start();

    await container
        .read(notificationControllerProvider.notifier)
        .prepareSignOut();
    await container.read(sessionControllerProvider.notifier).signOut();
    await settle(container);

    expect(devices.unregistered, ['push-token-1']);
    expect(push.deleteTokenCalls, 1);
    expect(local.cancelAllCalls, 1);
    expect(
      container.read(notificationControllerProvider),
      NotificationStatus.checking,
    );
  });

  test('the test notification shows right away', () async {
    local.enabled = true;
    final container = await start();

    await container.read(notificationControllerProvider.notifier).sendTest();

    expect(local.shown.single.title, 'Drivon reminders are on');
  });

  test('a tapped notification is kept until the app opens it', () async {
    local.launchPayloadValue = 'vehicle-1';
    final container = await start(signedIn: false);

    expect(container.read(notificationTapsProvider), 'vehicle-1');
    expect(
      container.read(notificationTapsProvider.notifier).take(),
      'vehicle-1',
    );
    expect(container.read(notificationTapsProvider), isNull);

    local.onTap!('vehicle-2');
    expect(container.read(notificationTapsProvider), 'vehicle-2');
  });
}

/// Lets the session restore and the controller's async start finish.
Future<void> settle(ProviderContainer container) async {
  for (var i = 0; i < 5; i++) {
    await pumpEventQueue();
  }
}
