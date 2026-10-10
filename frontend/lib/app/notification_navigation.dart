import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/presentation/session_controller.dart';
import '../features/notifications/presentation/notification_controller.dart';
import 'router.dart';

/// Opens a vehicle's reminders when the user taps a reminder notification.
/// A tap that launched the app waits until the session is restored. Watch it
/// for as long as the app runs.
final notificationNavigationProvider = Provider<void>((ref) {
  void openPending() {
    // After the frame, so the sign-in redirect has settled first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!ref.mounted) return;
      if (ref.read(sessionControllerProvider) is! SignedIn) return;
      final vehicleId = ref.read(notificationTapsProvider.notifier).take();
      if (vehicleId == null) return;
      ref.read(routerProvider).push(AppRoutes.remindersPath(vehicleId));
    });
  }

  ref
    ..listen(notificationTapsProvider, (_, vehicleId) {
      if (vehicleId != null) openPending();
    })
    ..listen(sessionControllerProvider, (_, session) {
      if (session is SignedIn) openPending();
    });
});
