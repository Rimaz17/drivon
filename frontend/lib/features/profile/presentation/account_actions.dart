import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_store.dart';
import '../../../core/ui/confirm_dialog.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/session_controller.dart';
import '../../fuel/presentation/fuel_sync_controller.dart';
import '../../notifications/presentation/notification_controller.dart';
import '../../vehicles/data/selected_vehicle_store.dart';

/// Signs out after warning about fill-ups that haven't synced, and removes
/// everything kept on the phone for this user.
Future<void> signOut(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final unsynced = ref.read(fuelSyncProvider).pending.length;
  if (unsynced > 0) {
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.signOutPendingTitle,
      message: l10n.signOutPendingMessage(unsynced),
      confirmLabel: l10n.signOutAction,
      cancelLabel: l10n.cancelAction,
      destructive: true,
    );
    if (!confirmed) return;
  }
  // While still signed in, so the server stops pushing reminders to this
  // phone.
  await ref.read(notificationControllerProvider.notifier).prepareSignOut();
  final userId = ref.read(activeUserIdProvider);
  if (userId != null) await ref.read(localStoreProvider).clearUser(userId);
  await ref.read(selectedVehicleStoreProvider).clear();
  await ref.read(sessionControllerProvider.notifier).signOut();
}

/// Removes what the phone kept for the signed-in user, for
/// [SessionController.deleteAccount]. Reads everything it needs now, while
/// the screen is still there: the cleanup runs after the sign-out has
/// replaced it. Scheduled notifications and the push token are dropped by
/// the notification controller when the user signs out; the server deleted
/// its device tokens with the account.
Future<void> Function() deviceDataCleaner(WidgetRef ref) {
  final userId = ref.read(activeUserIdProvider);
  final localStore = ref.read(localStoreProvider);
  final selectedVehicles = ref.read(selectedVehicleStoreProvider);
  return () async {
    if (userId != null) await localStore.clearUser(userId);
    await selectedVehicles.clear();
  };
}
