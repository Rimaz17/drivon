import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../design_system/design_system.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/reminder.dart';
import '../reminder_controllers.dart';
import '../reminder_text.dart';

/// The selected vehicle's reminders on the Garage sheet: the most urgent
/// one, how many others need attention, or a calm all-clear. Opens the
/// Reminders screen.
class RemindersGarageTile extends ConsumerWidget {
  const RemindersGarageTile({required this.vehicleId, super.key});

  final String vehicleId;

  /// Reloads what the tile shows.
  static void refresh(WidgetRef ref, String vehicleId) =>
      ref.invalidate(vehicleRemindersProvider(vehicleId));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final now = today();
    final reminders = ref.watch(vehicleRemindersProvider(vehicleId));
    final list = reminders.value ?? const <Reminder>[];
    final attention = [
      for (final reminder in list)
        if (reminder.status != ReminderStatus.upcoming) reminder,
    ];
    final first = attention.firstOrNull;

    final String headline;
    String? detail;
    if (first != null) {
      headline = reminderHeadline(context, l10n, first, now);
      detail = attention.length > 1
          ? l10n.moreRemindersNotice(attention.length - 1)
          : reminderDetail(context, l10n, first);
    } else if (reminders.hasError) {
      headline = l10n.snapshotLoadFailed;
    } else if (!reminders.hasValue) {
      headline = l10n.notYetValue;
    } else if (list.isEmpty) {
      headline = l10n.remindersTilePrompt;
    } else {
      headline = l10n.remindersNothingDue;
      detail = l10n.nextReminderDetail(
        reminderHeadline(context, l10n, list.first, now),
      );
    }
    final urgent = first?.status == ReminderStatus.overdue;

    return Semantics(
      container: true,
      button: true,
      label: [l10n.remindersTitle, headline, ?detail].join(', '),
      excludeSemantics: true,
      child: DrivonCard(
        onTap: () => context.push(AppRoutes.remindersPath(vehicleId)),
        child: Builder(
          builder: (context) {
            final textTheme = Theme.of(context).textTheme;
            final colors = context.drivonColors;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    TagChip(label: l10n.remindersTitle, tone: TagTone.violet),
                    const Spacer(),
                    Icon(
                      first == null
                          ? Icons.chevron_right_rounded
                          : urgent
                          ? Icons.error_outline_rounded
                          : Icons.schedule_rounded,
                      color: first == null
                          ? colors.textTertiary
                          : urgent
                          ? colors.danger
                          : colors.warning,
                    ),
                  ],
                ),
                const SizedBox(height: DrivonSpacing.lg),
                Text(
                  headline,
                  style: first != null
                      ? textTheme.headlineSmall
                      : textTheme.titleMedium,
                ),
                if (detail != null) ...[
                  const SizedBox(height: DrivonSpacing.xs),
                  Text(detail, style: textTheme.bodyMedium),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
