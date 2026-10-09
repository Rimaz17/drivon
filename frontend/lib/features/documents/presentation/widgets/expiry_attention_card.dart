import 'package:flutter/material.dart';

import '../../../../core/utils/date_format.dart';
import '../../../../design_system/design_system.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/vehicle_document.dart';
import '../document_labels.dart';

/// The screen's one highlight card: the document that needs attention first
/// (expired, or expiring soonest), with a count of the others.
class ExpiryAttentionCard extends StatelessWidget {
  const ExpiryAttentionCard({
    required this.documents,
    required this.today,
    required this.onOpen,
    super.key,
  });

  /// Soonest expiry first, as the API sorts them; must not be empty.
  final List<VehicleDocument> documents;
  final DateTime today;
  final ValueChanged<VehicleDocument> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final first = documents.first;
    final expired = first.expiryState(today) == ExpiryState.expired;
    final headline = expiryHeadline(l10n, first, today);
    final date = formatDate(context, first.expiryDate!);
    final detail = expired
        ? l10n.expiredOnDetail(date)
        : l10n.expiresOnDetail(date);
    final more = documents.length - 1;

    return Semantics(
      button: true,
      label: [
        headline,
        detail,
        if (more > 0) l10n.moreExpiringNotice(more),
      ].join(', '),
      excludeSemantics: true,
      child: DrivonCard(
        tone: DrivonCardTone.highlight,
        onTap: () => onOpen(first),
        child: Builder(
          builder: (context) {
            final textTheme = Theme.of(context).textTheme;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  expired
                      ? Icons.error_outline_rounded
                      : Icons.event_busy_outlined,
                ),
                const SizedBox(width: DrivonSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(headline, style: textTheme.titleLarge),
                      const SizedBox(height: DrivonSpacing.xs),
                      Text(detail, style: textTheme.bodyMedium),
                      if (more > 0) ...[
                        const SizedBox(height: DrivonSpacing.sm),
                        Text(
                          l10n.moreExpiringNotice(more),
                          style: textTheme.labelLarge,
                        ),
                      ],
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
