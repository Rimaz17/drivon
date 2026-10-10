import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/services/local_notifications.dart';
import '../../../core/services/push_messaging.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/session_controller.dart';
import '../../reminders/presentation/reminder_controllers.dart';
import '../../vehicles/presentation/vehicles_controller.dart';
import '../data/device_token_api.dart';
import 'reminder_schedule.dart';

/// How reminders reach the user outside the app.
enum NotificationStatus {
  /// Signed out, or still finding out.
  checking,

  /// Notifications aren't allowed yet; the app can ask.
  off,

  /// The user declined the prompt; only the system settings can change it.
  blocked,

  /// Allowed; date reminders are scheduled on the device.
  local,

  /// Allowed, and the server pushes reminders to this device (Android).
  push,
}

/// Notification text is written outside any widget, in the app's only
/// language.
AppLocalizations notificationStrings() =>
    lookupAppLocalizations(const Locale('en'));

/// Sets up local notifications and push once per app run, and routes taps on
/// notifications (including the one that launched the app) to
/// [notificationTapsProvider].
final notificationBootstrapProvider = FutureProvider<void>((ref) async {
  final l10n = notificationStrings();
  final taps = ref.read(notificationTapsProvider.notifier);
  final local = ref.read(localNotificationsProvider);
  await local.initialize(
    channelName: l10n.notificationChannelName,
    channelDescription: l10n.notificationChannelDescription,
    onTap: taps.open,
  );
  taps.open(await local.launchPayload());

  final push = ref.read(pushMessagingProvider);
  if (push.supported && await push.initialize()) {
    final opened = push.openedMessages.listen(
      (data) => taps.open(data[pushVehicleKey]),
    );
    ref.onDispose(opened.cancel);
    taps.open((await push.initialMessage())?[pushVehicleKey]);
  }
});

/// The data key of the vehicle in reminder pushes; set by the server.
const String pushVehicleKey = 'vehicleId';

/// The vehicle whose reminders a tapped notification should open, until the
/// app has shown them.
class NotificationTapsController extends Notifier<String?> {
  @override
  String? build() => null;

  void open(String? vehicleId) {
    if (vehicleId != null && vehicleId.isNotEmpty) state = vehicleId;
  }

  /// Returns the pending vehicle and forgets it.
  String? take() {
    final vehicleId = state;
    state = null;
    return vehicleId;
  }
}

final notificationTapsProvider =
    NotifierProvider<NotificationTapsController, String?>(
      NotificationTapsController.new,
    );

/// Whether and how reminders notify the signed-in user. Starts when someone
/// signs in and stops (cancelling scheduled notifications and the push
/// token) when they sign out.
class NotificationController extends Notifier<NotificationStatus> {
  /// ID of the test notification; scheduled reminders use 1 to 60 and
  /// pushes shown while the app is open use 1000 and up.
  static const int testNotificationId = 999;

  StreamSubscription<String>? _tokenRefreshes;
  StreamSubscription<PushNotice>? _foreground;
  String? _token;

  /// Bumped whenever the user changes, so late results of an earlier
  /// session are ignored.
  int _session = 0;

  @override
  NotificationStatus build() {
    ref.listen(currentUserProvider, (previous, next) {
      if (previous?.id == next?.id) return;
      // After the current build or update, never during it.
      if (previous != null) unawaited(Future.microtask(_stop));
      if (next != null) unawaited(Future.microtask(_start));
    }, fireImmediately: true);
    ref.onDispose(_cancelSubscriptions);
    return NotificationStatus.checking;
  }

  LocalNotifications get _local => ref.read(localNotificationsProvider);

  bool _isCurrent(int session) => ref.mounted && session == _session;

  Future<void> _start() async {
    final session = ++_session;
    try {
      await ref.read(notificationBootstrapProvider.future);
      final enabled = await _local.areEnabled();
      if (!_isCurrent(session)) return;
      if (!enabled) {
        state = NotificationStatus.off;
        return;
      }
      await _deliver(session);
    } on Object catch (error) {
      debugPrint('Notifications unavailable: $error');
      if (_isCurrent(session)) state = NotificationStatus.off;
    }
  }

  /// Asks for permission (the user tapped "Turn on notifications").
  Future<void> enable() async {
    final session = _session;
    bool granted;
    try {
      await ref.read(notificationBootstrapProvider.future);
      granted = await _local.requestPermission();
    } on Object catch (error) {
      debugPrint('Asking for notification permission failed: $error');
      granted = false;
    }
    if (!_isCurrent(session)) return;
    if (!granted) {
      state = NotificationStatus.blocked;
      return;
    }
    await _deliver(session);
  }

  /// Checks again after the user may have changed the system settings.
  Future<void> recheck() async {
    if (state == NotificationStatus.off ||
        state == NotificationStatus.blocked) {
      await _start();
    }
  }

  Future<void> openSettings() => _local.openSettings();

  /// Shows a notification right away, so the user can see what reminders
  /// look like.
  Future<void> sendTest() {
    final l10n = notificationStrings();
    return _local.show(
      id: testNotificationId,
      title: l10n.testNotificationTitle,
      body: l10n.testNotificationBody,
    );
  }

  /// Call while still signed in: stops pushes to this phone on the server.
  /// Best effort; when offline, the token is invalidated on sign-out anyway.
  Future<void> prepareSignOut() async {
    final token = _token;
    if (token == null) return;
    try {
      await ref.read(deviceTokenApiProvider).unregister(token);
    } on AppException catch (error) {
      debugPrint('Could not unregister the push token: $error');
    }
  }

  /// Push on Android when Firebase is set up in this build and the server
  /// accepts the token; local notifications otherwise.
  Future<void> _deliver(int session) async {
    final push = ref.read(pushMessagingProvider);
    try {
      if (push.supported && await push.initialize()) {
        final token = await push.token();
        if (token != null) {
          await ref.read(deviceTokenApiProvider).register(token);
          if (!_isCurrent(session)) return;
          _token = token;
          _listenToPush(push);
          state = NotificationStatus.push;
          return;
        }
      }
    } on Object catch (error) {
      // Offline or Firebase unavailable: reminders still come locally.
      debugPrint('Push registration failed: $error');
    }
    if (_isCurrent(session)) state = NotificationStatus.local;
  }

  void _listenToPush(PushMessaging push) {
    _cancelSubscriptions();
    _tokenRefreshes = push.tokenRefreshes.listen((token) async {
      _token = token;
      try {
        await ref.read(deviceTokenApiProvider).register(token);
      } on AppException catch (error) {
        debugPrint('Could not register the new push token: $error');
      }
    });
    // Android shows pushes itself only while the app is in the background.
    _foreground = push.foregroundMessages.listen((notice) {
      final reminderId = notice.data['reminderId'] ?? notice.title;
      unawaited(
        _local.show(
          id: 1000 + (reminderId.hashCode & 0xfffff),
          title: notice.title,
          body: notice.body,
          payload: notice.data[pushVehicleKey],
        ),
      );
      refreshReminders(ref.invalidate);
    });
  }

  Future<void> _stop() async {
    _session++;
    _cancelSubscriptions();
    final hadToken = _token != null;
    _token = null;
    if (ref.mounted) state = NotificationStatus.checking;
    try {
      await _local.cancelAll();
      if (hadToken) await ref.read(pushMessagingProvider).deleteToken();
    } on Object catch (error) {
      debugPrint('Clearing notifications failed: $error');
    }
  }

  void _cancelSubscriptions() {
    unawaited(_tokenRefreshes?.cancel());
    unawaited(_foreground?.cancel());
    _tokenRefreshes = null;
    _foreground = null;
  }
}

final notificationControllerProvider =
    NotifierProvider<NotificationController, NotificationStatus>(
      NotificationController.new,
    );

/// Keeps the device's scheduled reminder notifications in step with the
/// reminders, when they are delivered locally. Watch it for as long as the
/// app runs.
final reminderScheduleSyncProvider = Provider<void>((ref) {
  final status = ref.watch(notificationControllerProvider);
  final local = ref.read(localNotificationsProvider);

  void replace(List<ScheduledNotification> notifications) => unawaited(
    local
        .replaceScheduled(notifications)
        .catchError(
          (Object error) => debugPrint('Scheduling reminders failed: $error'),
        ),
  );

  switch (status) {
    case NotificationStatus.checking:
      return;
    case NotificationStatus.off ||
        NotificationStatus.blocked ||
        NotificationStatus.push:
      replace(const []);
    case NotificationStatus.local:
      final reminders = ref.watch(allRemindersProvider).value;
      final vehicles = ref.watch(vehiclesControllerProvider).value;
      if (reminders == null || vehicles == null) return;
      replace(
        reminderSchedule(
          reminders: reminders,
          vehicleNames: {
            for (final vehicle in vehicles)
              vehicle.id:
                  '${vehicle.displayName} ${vehicle.registrationNumber}',
          },
          l10n: notificationStrings(),
          now: DateTime.now(),
        ),
      );
  }
});
