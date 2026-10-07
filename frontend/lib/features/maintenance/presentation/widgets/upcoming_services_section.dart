import 'package:flutter/material.dart';

import '../../../../core/utils/date_format.dart';
import '../../../../design_system/design_system.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/maintenance_record.dart';
import 'upcoming_service_text.dart';

/// What is due next: the soonest service on the screen's one highlight card,
/// the rest as rows beneath. Each opens the record that set the due date.
class UpcomingServicesSection extends StatelessWidget {
  const UpcomingServicesSection({
    required this.upcoming,
    required this.onOpen,
    super.key,
  });

  /// Soonest first, as the server sorts them; must not be empty.
  final List<UpcomingService> upcoming;
  final ValueChanged<UpcomingService> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final next = upcoming.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.upcomingTitle, style: textTheme.titleLarge),
        ),
        const SizedBox(height: DrivonSpacing.md),
        Semantics(
          button: true,
          child: DrivonCard(
            tone: DrivonCardTone.highlight,
            onTap: () => onOpen(next),
            child: Builder(
              builder: (context) {
                final onCard = Theme.of(context).textTheme;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      next.overdue
                          ? Icons.warning_amber_rounded
                          : Icons.event_available_rounded,
                    ),
                    const SizedBox(width: DrivonSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            upcomingHeadline(context, l10n, next),
                            style: onCard.titleLarge,
                          ),
                          const SizedBox(height: DrivonSpacing.xs),
                          Text(
                            upcomingDetail(context, l10n, next),
                            style: onCard.bodyMedium,
                          ),
                          const SizedBox(height: DrivonSpacing.xxs),
                          Text(
                            l10n.lastDoneDetail(
                              formatDate(context, next.lastServicedOn),
                            ),
                            style: onCard.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        for (final item in upcoming.skip(1)) ...[
          const SizedBox(height: DrivonSpacing.xs),
          Semantics(
            button: true,
            child: InkWell(
              onTap: () => onOpen(item),
              borderRadius: DrivonRadii.mdAll,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: DrivonSpacing.minTouchTarget,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: DrivonSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        item.overdue
                            ? Icons.warning_amber_rounded
                            : Icons.event_outlined,
                        color: item.overdue
                            ? context.drivonColors.warning
                            : context.drivonColors.textSecondary,
                      ),
                      const SizedBox(width: DrivonSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              upcomingHeadline(context, l10n, item),
                              style: textTheme.titleSmall,
                            ),
                            Text(
                              upcomingDetail(context, l10n, item),
                              style: textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
