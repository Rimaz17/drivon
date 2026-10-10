import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/errors/error_text.dart';
import '../../../core/utils/date_format.dart';
import '../../../design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../../notifications/presentation/notification_controller.dart';
import '../../notifications/presentation/notification_setup_panel.dart';
import '../domain/reminder.dart';
import 'reminder_controllers.dart';
import 'reminder_text.dart';
import 'widgets/reminder_tile.dart';

/// A vehicle's reminders: the most urgent one on the canvas, every reminder
/// grouped by urgency on the sheet, and whether they notify the user.
class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({required this.vehicleId, super.key});

  final String vehicleId;

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> {
  /// Space below the list so the last row clears the floating button.
  static const double _fabClearance = 96;

  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Coming back from the system settings may have turned notifications on.
    _lifecycle = AppLifecycleListener(
      onResume: () =>
          ref.read(notificationControllerProvider.notifier).recheck(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _open(Reminder reminder) {
    final vehicleId = widget.vehicleId;
    final sourceId = reminder.sourceId;
    switch (reminder.source) {
      case ReminderSource.manual:
        context.push(AppRoutes.editReminderPath(vehicleId, reminder.id));
      case ReminderSource.service when sourceId != null:
        context.push(AppRoutes.editServicePath(vehicleId, sourceId));
      case ReminderSource.document when sourceId != null:
        context.push(AppRoutes.documentPath(vehicleId, sourceId));
      case ReminderSource.service || ReminderSource.document:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final vehicleId = widget.vehicleId;
    final reminders = ref.watch(vehicleRemindersProvider(vehicleId));
    final now = today();

    void add() => context.push(AppRoutes.addReminderPath(vehicleId));
    void retry() => ref.invalidate(vehicleRemindersProvider(vehicleId));

    final hasReminders = reminders.value?.isNotEmpty ?? false;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.remindersTitle)),
      floatingActionButton: hasReminders
          ? FloatingActionButton.extended(
              onPressed: add,
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.addReminderAction),
            )
          : null,
      body: SafeArea(
        child: reminders.when(
          loading: () => LoadingState(semanticsLabel: l10n.loadingReminders),
          error: (error, _) => ErrorState(
            title: l10n.remindersLoadErrorTitle,
            message: errorText(l10n, error),
            retryLabel: l10n.retryAction,
            onRetry: retry,
          ),
          data: (list) {
            if (list.isEmpty) {
              return EmptyState(
                icon: Icons.notifications_none_rounded,
                title: l10n.remindersEmptyTitle,
                message: l10n.remindersEmptyMessage,
                actionLabel: l10n.addReminderAction,
                onAction: add,
              );
            }
            final urgent = list.first.status == ReminderStatus.upcoming
                ? null
                : list.first;
            return RefreshIndicator.adaptive(
              onRefresh: () async {
                retry();
                await ref.read(vehicleRemindersProvider(vehicleId).future);
              },
              child: ContentWidth(
                child: SheetScrollView(
                  bottomPadding: _fabClearance,
                  header: [
                    if (urgent != null)
                      _AttentionCard(
                        reminder: urgent,
                        today: now,
                        onOpen: () => _open(urgent),
                      )
                    else
                      const _NothingDue(),
                  ],
                  sheet: [
                    const NotificationSetupPanel(),
                    for (final status in ReminderStatus.values)
                      ..._section(status, [
                        for (final reminder in list)
                          if (reminder.status == status) reminder,
                      ], now),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _section(
    ReminderStatus status,
    List<Reminder> reminders,
    DateTime now,
  ) {
    if (reminders.isEmpty) return const [];
    final l10n = AppLocalizations.of(context);
    return [
      const SizedBox(height: DrivonSpacing.xl),
      SectionTitle(reminderStatusLabel(l10n, status)),
      const SizedBox(height: DrivonSpacing.xs),
      for (final (index, reminder) in reminders.indexed) ...[
        if (index > 0) const Divider(),
        ReminderTile(
          reminder: reminder,
          today: now,
          onTap: () => _open(reminder),
        ),
      ],
    ];
  }
}

/// The screen's one highlight card: the most urgent reminder.
class _AttentionCard extends StatelessWidget {
  const _AttentionCard({
    required this.reminder,
    required this.today,
    required this.onOpen,
  });

  final Reminder reminder;
  final DateTime today;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final headline = reminderHeadline(context, l10n, reminder, today);
    final detail = reminderDetail(context, l10n, reminder);
    final overdue = reminder.status == ReminderStatus.overdue;
    return Semantics(
      button: true,
      label: '$headline, $detail',
      excludeSemantics: true,
      child: DrivonCard(
        tone: DrivonCardTone.highlight,
        onTap: onOpen,
        child: Builder(
          builder: (context) {
            final textTheme = Theme.of(context).textTheme;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  overdue
                      ? Icons.error_outline_rounded
                      : Icons.notifications_active_outlined,
                ),
                const SizedBox(width: DrivonSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(headline, style: textTheme.titleLarge),
                      const SizedBox(height: DrivonSpacing.xs),
                      Text(detail, style: textTheme.bodyMedium),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A calm line on the canvas when nothing is due soon.
class _NothingDue extends StatelessWidget {
  const _NothingDue();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.drivonColors;
    return Semantics(
      label: l10n.remindersNothingDue,
      excludeSemantics: true,
      child: Row(
        children: [
          Icon(Icons.verified_outlined, color: colors.success),
          const SizedBox(width: DrivonSpacing.sm),
          Expanded(
            child: Text(
              l10n.remindersNothingDue,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}
