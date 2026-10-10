import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/reminder.dart';
import '../reminder_text.dart';

/// A reminder's urgency as a small pill. The icon repeats what the color
/// says, so the status never depends on color alone.
class ReminderStatusChip extends StatelessWidget {
  const ReminderStatusChip({required this.status, super.key});

  final ReminderStatus status;

  static const double _iconSize = 14;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.drivonColors;
    final (icon, color) = switch (status) {
      ReminderStatus.overdue => (Icons.error_outline_rounded, colors.danger),
      ReminderStatus.dueSoon => (Icons.schedule_rounded, colors.warning),
      ReminderStatus.upcoming => (Icons.event_outlined, colors.textSecondary),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: DrivonRadii.pill,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DrivonSpacing.sm,
          vertical: DrivonSpacing.xxs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: _iconSize, color: color),
            const SizedBox(width: DrivonSpacing.xs),
            Text(
              reminderStatusLabel(l10n, status),
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// A reminder row on the paper sheet: what is due and its status, when it
/// is due beneath, and a chevron. The icon says where the reminder comes
/// from: a service, a document or the user.
class ReminderTile extends StatelessWidget {
  const ReminderTile({
    required this.reminder,
    required this.today,
    required this.onTap,
    super.key,
  });

  final Reminder reminder;
  final DateTime today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colors = context.drivonColors;
    final headline = reminderHeadline(context, l10n, reminder, today);
    final detail = reminderDetail(context, l10n, reminder);
    final source = switch (reminder.source) {
      ReminderSource.service => l10n.reminderFromService,
      ReminderSource.document => l10n.reminderFromDocument,
      ReminderSource.manual => l10n.reminderFromYou,
    };

    return Semantics(
      button: true,
      label: l10n.reminderRowSemantics(
        headline,
        reminderStatusLabel(l10n, reminder.status),
        detail,
        source,
      ),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: DrivonRadii.mdAll,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: DrivonSpacing.minTouchTarget,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: DrivonSpacing.md),
            child: Row(
              children: [
                Icon(switch (reminder.source) {
                  ReminderSource.service => Icons.build_outlined,
                  ReminderSource.document => Icons.description_outlined,
                  ReminderSource.manual => Icons.notifications_outlined,
                }, color: colors.textSecondary),
                const SizedBox(width: DrivonSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(headline, style: textTheme.titleMedium),
                      const SizedBox(height: DrivonSpacing.xxs),
                      Text(detail, style: textTheme.bodyMedium),
                      const SizedBox(height: DrivonSpacing.xs),
                      Wrap(
                        spacing: DrivonSpacing.sm,
                        runSpacing: DrivonSpacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ReminderStatusChip(status: reminder.status),
                          Text(source, style: textTheme.bodySmall),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: DrivonSpacing.xs),
                Icon(Icons.chevron_right_rounded, color: colors.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
