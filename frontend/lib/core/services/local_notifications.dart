import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// A notification to show later, at [at] in Sri Lanka's time zone.
@immutable
class ScheduledNotification {
  const ScheduledNotification({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
    this.payload,
  });

  final int id;

  /// Wall-clock time in Asia/Colombo; only the date, hour and minute count.
  final DateTime at;
  final String title;
  final String body;

  /// Handed back when the notification is tapped.
  final String? payload;

  @override
  bool operator ==(Object other) =>
      other is ScheduledNotification &&
      other.id == id &&
      other.at == at &&
      other.title == title &&
      other.body == body &&
      other.payload == payload;

  @override
  int get hashCode => Object.hash(id, at, title, body, payload);

  @override
  String toString() => 'ScheduledNotification($id, $at, $title)';
}

/// Notifications shown by the device itself, on Android and iOS. Works without
/// a server and without push; iPhones get reminders only this way.
abstract interface class LocalNotifications {
  /// Sets up the plugin, the Android channel and the time zone. Safe to call
  /// more than once; [onTap] receives the payload of a tapped notification.
  Future<void> initialize({
    required String channelName,
    required String channelDescription,
    required void Function(String? payload) onTap,
  });

  /// The payload of the notification that launched the app, if any.
  Future<String?> launchPayload();

  /// Whether the user allows this app's notifications.
  Future<bool> areEnabled();

  /// Asks the user to allow notifications (Android 13+ and iOS show a
  /// prompt). Returns whether they are allowed now.
  Future<bool> requestPermission();

  /// Opens the system settings for this app's notifications, for users who
  /// declined the prompt earlier.
  Future<void> openSettings();

  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  });

  /// Replaces every scheduled notification with [notifications]. Ones in the
  /// past are skipped; notifications already showing stay.
  Future<void> replaceScheduled(List<ScheduledNotification> notifications);

  /// Removes scheduled and showing notifications, e.g. on sign-out.
  Future<void> cancelAll();
}

/// [LocalNotifications] with the flutter_local_notifications plugin.
class PluginLocalNotifications implements LocalNotifications {
  PluginLocalNotifications([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// Shared with the server, which sends pushes to the same channel.
  static const String channelId = 'drivon_reminders';

  /// Small monochrome icon in android/app/src/main/res/drawable.
  static const String _androidIcon = '@drawable/ic_stat_drivon';

  /// Reminder dates are Sri Lankan calendar dates, like everything else.
  static const String _zoneName = 'Asia/Colombo';

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _initialized;
  Future<void> _replacing = Future.value();
  late tz.Location _zone;
  late NotificationDetails _details;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  @override
  Future<void> initialize({
    required String channelName,
    required String channelDescription,
    required void Function(String? payload) onTap,
  }) => _initialized ??= _initialize(
    channelName: channelName,
    channelDescription: channelDescription,
    onTap: onTap,
  );

  Future<void> _initialize({
    required String channelName,
    required String channelDescription,
    required void Function(String? payload) onTap,
  }) async {
    tz_data.initializeTimeZones();
    _zone = tz.getLocation(_zoneName);
    _details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(_androidIcon),
        // Permission is asked for when the user turns reminders on, not at
        // launch.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) => onTap(response.payload),
    );
    await _android?.createNotificationChannel(
      AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: Importance.high,
      ),
    );
  }

  @override
  Future<String?> launchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return details.notificationResponse?.payload;
  }

  @override
  Future<bool> areEnabled() async {
    final android = _android;
    if (android != null) {
      return await android.areNotificationsEnabled() ?? false;
    }
    final ios = _ios;
    if (ios != null) {
      return (await ios.checkPermissions())?.isEnabled ?? false;
    }
    return false;
  }

  @override
  Future<bool> requestPermission() async {
    final android = _android;
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _ios;
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return false;
  }

  @override
  Future<void> openSettings() async {
    await (_android?.openAppNotificationSettings() ??
        _ios?.openAppNotificationSettings());
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await _ready();
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: _details,
      payload: payload,
    );
  }

  @override
  Future<void> replaceScheduled(List<ScheduledNotification> notifications) {
    // One replacement at a time, so two can't interleave their cancels and
    // schedules.
    final next = _replacing.then((_) => _replace(notifications));
    _replacing = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }

  Future<void> _replace(List<ScheduledNotification> notifications) async {
    await _ready();
    await _plugin.cancelAllPendingNotifications();
    final now = tz.TZDateTime.now(_zone);
    for (final notification in notifications) {
      final at = notification.at;
      final when = tz.TZDateTime(
        _zone,
        at.year,
        at.month,
        at.day,
        at.hour,
        at.minute,
      );
      // The plugin rejects times in the past.
      if (!when.isAfter(now)) continue;
      await _plugin.zonedSchedule(
        id: notification.id,
        scheduledDate: when,
        notificationDetails: _details,
        // Inexact needs no exact-alarm permission; a few minutes' delay is
        // fine for a reminder.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: notification.title,
        body: notification.body,
        payload: notification.payload,
      );
    }
  }

  @override
  Future<void> cancelAll() => _plugin.cancelAll();

  Future<void> _ready() {
    final initialized = _initialized;
    if (initialized == null) {
      throw StateError('Call initialize() before showing notifications');
    }
    return initialized;
  }
}

final localNotificationsProvider = Provider<LocalNotifications>(
  (ref) => PluginLocalNotifications(),
);
