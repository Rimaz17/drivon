import 'dart:async';

import 'package:drivon/core/errors/app_exception.dart';
import 'package:drivon/core/services/local_notifications.dart';
import 'package:drivon/core/services/push_messaging.dart';
import 'package:drivon/features/notifications/data/device_token_api.dart';
import 'package:drivon/features/reminders/data/reminder_api.dart';
import 'package:drivon/features/reminders/domain/reminder.dart';

Reminder reminder({
  String id = 'reminder-1',
  String vehicleId = 'vehicle-1',
  ReminderSource source = ReminderSource.manual,
  ReminderStatus status = ReminderStatus.upcoming,
  String? title = 'Emission test',
  DateTime? dueDate,
  int? dueKm,
  DateTime? remindFrom,
  int? daysRemaining,
  int? kmRemaining,
  String? sourceId,
}) => Reminder(
  id: id,
  vehicleId: vehicleId,
  source: source,
  status: status,
  title: source == ReminderSource.manual ? title : null,
  dueDate: dueDate,
  dueKm: dueKm,
  remindFrom: remindFrom,
  daysRemaining: daysRemaining,
  kmRemaining: kmRemaining,
  sourceId: sourceId,
);

/// In-memory [ReminderApi] for tests; reminders are returned in list order.
class FakeReminderApi implements ReminderApi {
  FakeReminderApi([List<Reminder>? reminders]) : reminders = reminders ?? [];

  final List<Reminder> reminders;
  final List<({String id, ReminderDraft draft})> created = [];
  final List<String> deleted = [];

  /// The ID of every create call, including failed ones.
  final List<String> attemptedIds = [];

  /// When set, the next call throws it once.
  AppException? nextError;

  @override
  Future<List<Reminder>> listAll() async {
    _throwIfScripted();
    return List.of(reminders);
  }

  @override
  Future<List<Reminder>> list(String vehicleId) async {
    _throwIfScripted();
    return [
      for (final reminder in reminders)
        if (reminder.vehicleId == vehicleId) reminder,
    ];
  }

  @override
  Future<Reminder> get(String vehicleId, String id) async {
    _throwIfScripted();
    return reminders.firstWhere((r) => r.id == id);
  }

  @override
  Future<Reminder> create(
    String vehicleId,
    ReminderDraft draft, {
    required String id,
  }) async {
    attemptedIds.add(id);
    _throwIfScripted();
    created.add((id: id, draft: draft));
    final saved = Reminder(
      id: id,
      vehicleId: vehicleId,
      source: ReminderSource.manual,
      status: ReminderStatus.upcoming,
      title: draft.title,
      dueDate: draft.dueDate,
      dueKm: draft.dueKm,
    );
    reminders.add(saved);
    return saved;
  }

  @override
  Future<Reminder> update(
    String vehicleId,
    String id,
    ReminderDraft draft,
  ) async {
    _throwIfScripted();
    final index = reminders.indexWhere((r) => r.id == id);
    final updated = reminders[index].copyWith(
      title: draft.title,
      dueDate: draft.dueDate,
      dueKm: draft.dueKm,
    );
    reminders[index] = updated;
    return updated;
  }

  @override
  Future<void> delete(String vehicleId, String id) async {
    _throwIfScripted();
    deleted.add(id);
    reminders.removeWhere((r) => r.id == id);
  }

  void _throwIfScripted() {
    final error = nextError;
    if (error != null) {
      nextError = null;
      throw error;
    }
  }
}

/// Records device registrations instead of calling the API.
class FakeDeviceTokenApi implements DeviceTokenApi {
  final List<String> registered = [];
  final List<String> unregistered = [];

  /// When set, every registration throws it.
  AppException? registerError;

  @override
  Future<void> register(String token) async {
    final error = registerError;
    if (error != null) throw error;
    registered.add(token);
  }

  @override
  Future<void> unregister(String token) async => unregistered.add(token);
}

/// Records notifications instead of showing them.
class FakeLocalNotifications implements LocalNotifications {
  FakeLocalNotifications({this.enabled = false, this.grantOnRequest = true});

  bool enabled;
  bool grantOnRequest;
  bool initialized = false;
  int permissionRequests = 0;
  int settingsOpened = 0;
  int cancelAllCalls = 0;
  String? launchPayloadValue;
  void Function(String? payload)? onTap;
  final List<({int id, String title, String body, String? payload})> shown = [];

  /// Every list passed to [replaceScheduled], oldest first.
  final List<List<ScheduledNotification>> schedules = [];

  @override
  Future<void> initialize({
    required String channelName,
    required String channelDescription,
    required void Function(String? payload) onTap,
  }) async {
    initialized = true;
    this.onTap = onTap;
  }

  @override
  Future<String?> launchPayload() async => launchPayloadValue;

  @override
  Future<bool> areEnabled() async => enabled;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    enabled = grantOnRequest;
    return grantOnRequest;
  }

  @override
  Future<void> openSettings() async => settingsOpened++;

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async => shown.add((id: id, title: title, body: body, payload: payload));

  @override
  Future<void> replaceScheduled(
    List<ScheduledNotification> notifications,
  ) async => schedules.add(notifications);

  @override
  Future<void> cancelAll() async => cancelAllCalls++;
}

/// Firebase stand-in: [supported] and [configured] decide whether push is
/// used at all; streams can be fed by tests.
class FakePushMessaging implements PushMessaging {
  FakePushMessaging({
    this.supported = false,
    this.configured = true,
    this.currentToken = 'push-token-1',
  });

  @override
  final bool supported;
  final bool configured;
  String? currentToken;
  int deleteTokenCalls = 0;
  Map<String, String>? initialData;

  final StreamController<String> refreshes = StreamController.broadcast();
  final StreamController<PushNotice> foreground = StreamController.broadcast();
  final StreamController<Map<String, String>> opened =
      StreamController.broadcast();

  @override
  Future<bool> initialize() async => supported && configured;

  @override
  Future<String?> token() async => currentToken;

  @override
  Stream<String> get tokenRefreshes => refreshes.stream;

  @override
  Stream<PushNotice> get foregroundMessages => foreground.stream;

  @override
  Stream<Map<String, String>> get openedMessages => opened.stream;

  @override
  Future<Map<String, String>?> initialMessage() async => initialData;

  @override
  Future<void> deleteToken() async {
    deleteTokenCalls++;
    currentToken = null;
  }

  Future<void> close() async {
    await refreshes.close();
    await foreground.close();
    await opened.close();
  }
}
