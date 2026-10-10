import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A push notification that arrived while the app was open. Android only
/// shows pushes itself when the app is in the background.
@immutable
class PushNotice {
  const PushNotice({
    required this.title,
    required this.body,
    this.data = const {},
  });

  final String title;
  final String body;
  final Map<String, String> data;
}

/// Push notifications from the server (Firebase Cloud Messaging). Android
/// only: iOS push needs a paid Apple developer account, so iPhones use local
/// notifications instead.
abstract interface class PushMessaging {
  /// Whether this platform receives pushes at all.
  bool get supported;

  /// Connects to Firebase. False when it isn't configured in this build
  /// (no google-services.json), in which case nothing else may be called.
  Future<bool> initialize();

  /// This installation's token for the server, or null if there is none yet.
  Future<String?> token();

  /// New tokens; Firebase rotates them now and then.
  Stream<String> get tokenRefreshes;

  Stream<PushNotice> get foregroundMessages;

  /// Data of pushes the user tapped while the app was in the background.
  Stream<Map<String, String>> get openedMessages;

  /// Data of the push whose tap launched the app, if any.
  Future<Map<String, String>?> initialMessage();

  /// Invalidates this installation's token, so the server can't reach it.
  Future<void> deleteToken();
}

/// [PushMessaging] with Firebase.
class FirebasePushMessaging implements PushMessaging {
  Future<bool>? _initialized;

  @override
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<bool> initialize() => _initialized ??= _initialize();

  Future<bool> _initialize() async {
    if (!supported) return false;
    try {
      // Reads android/app/google-services.json, compiled in by the Gradle
      // plugin when the file is present.
      await Firebase.initializeApp();
      return true;
    } on Object catch (error) {
      debugPrint('Push notifications are off: $error');
      return false;
    }
  }

  @override
  Future<String?> token() => FirebaseMessaging.instance.getToken();

  @override
  Stream<String> get tokenRefreshes =>
      FirebaseMessaging.instance.onTokenRefresh;

  @override
  Stream<PushNotice> get foregroundMessages => FirebaseMessaging.onMessage
      .where((message) => message.notification != null)
      .map(
        (message) => PushNotice(
          title: message.notification?.title ?? '',
          body: message.notification?.body ?? '',
          data: _strings(message.data),
        ),
      );

  @override
  Stream<Map<String, String>> get openedMessages => FirebaseMessaging
      .onMessageOpenedApp
      .map((message) => _strings(message.data));

  @override
  Future<Map<String, String>?> initialMessage() async {
    final message = await FirebaseMessaging.instance.getInitialMessage();
    return message == null ? null : _strings(message.data);
  }

  @override
  Future<void> deleteToken() => FirebaseMessaging.instance.deleteToken();

  static Map<String, String> _strings(Map<String, dynamic> data) => {
    for (final entry in data.entries) entry.key: '${entry.value}',
  };
}

final pushMessagingProvider = Provider<PushMessaging>(
  (ref) => FirebasePushMessaging(),
);
