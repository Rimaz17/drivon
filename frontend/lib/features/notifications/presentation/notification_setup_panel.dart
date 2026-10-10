import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import 'notification_controller.dart';

/// Whether reminders notify the user, with the one action that matters:
/// turn notifications on, open the settings after a refusal, or send a test.
/// Place it on a paper sheet.
class NotificationSetupPanel extends ConsumerWidget {
  const NotificationSetupPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final status = ref.watch(notificationControllerProvider);
    final controller = ref.read(notificationControllerProvider.notifier);

    switch (status) {
      case NotificationStatus.checking:
        return const SizedBox.shrink();
      case NotificationStatus.off || NotificationStatus.blocked:
        final blocked = status == NotificationStatus.blocked;
        return DrivonCard(
          child: Builder(
            builder: (context) {
              final textTheme = Theme.of(context).textTheme;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.notifications_off_outlined),
                      const SizedBox(width: DrivonSpacing.sm),
                      Expanded(
                        child: Text(
                          l10n.notificationsOffTitle,
                          style: textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: DrivonSpacing.xs),
                  Text(
                    blocked
                        ? l10n.notificationsBlockedMessage
                        : l10n.notificationsOffMessage,
                    style: textTheme.bodyMedium,
                  ),
                  const SizedBox(height: DrivonSpacing.md),
                  FilledButton.icon(
                    icon: Icon(
                      blocked
                          ? Icons.settings_outlined
                          : Icons.notifications_active_outlined,
                    ),
                    label: Text(
                      blocked
                          ? l10n.notificationsOpenSettingsAction
                          : l10n.notificationsTurnOnAction,
                    ),
                    onPressed: blocked
                        ? controller.openSettings
                        : controller.enable,
                  ),
                ],
              );
            },
          ),
        );
      case NotificationStatus.local || NotificationStatus.push:
        final textTheme = Theme.of(context).textTheme;
        final colors = context.drivonColors;
        return Row(
          children: [
            Icon(Icons.notifications_active_outlined, color: colors.success),
            const SizedBox(width: DrivonSpacing.sm),
            Expanded(
              child: Text(
                status == NotificationStatus.push
                    ? l10n.notificationsOnPush
                    : l10n.notificationsOnLocal,
                style: textTheme.bodyMedium,
              ),
            ),
            TextButton(
              onPressed: controller.sendTest,
              child: Text(l10n.sendTestNotificationAction),
            ),
          ],
        );
    }
  }
}
