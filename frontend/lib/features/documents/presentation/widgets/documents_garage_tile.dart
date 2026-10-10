import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../design_system/design_system.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/vehicle_document.dart';
import '../document_controllers.dart';
import '../document_labels.dart';

/// The selected vehicle's documents on the Garage sheet: what expires next,
/// a prompt when nothing is stored yet, or a calm all-clear. Opens the
/// Documents screen.
class DocumentsGarageTile extends ConsumerWidget {
  const DocumentsGarageTile({required this.vehicleId, super.key});

  final String vehicleId;

  /// Reloads what the tile shows.
  static void refresh(WidgetRef ref, String vehicleId) => ref
    ..invalidate(expiringDocumentsProvider)
    ..invalidate(documentListProvider(vehicleId));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final now = today();
    final expiring = ref.watch(expiringDocumentsProvider);
    final stored = ref.watch(documentListProvider(vehicleId));
    final attention = [
      for (final document in expiring.value ?? const <VehicleDocument>[])
        if (document.vehicleId == vehicleId) document,
    ];
    final first = attention.firstOrNull;
    final empty = stored.value?.items.isEmpty ?? false;

    final String headline;
    String? detail;
    if (first != null) {
      headline = expiryHeadline(l10n, first, now);
      detail = expiryDetail(context, l10n, first, now);
    } else if (expiring.hasError || stored.hasError) {
      headline = l10n.snapshotLoadFailed;
    } else if (!expiring.hasValue || !stored.hasValue) {
      headline = l10n.notYetValue;
    } else if (empty) {
      headline = l10n.documentsTilePrompt;
    } else {
      headline = l10n.documentsAllCurrent;
    }
    final urgent = first?.expiryState(now) == ExpiryState.expired;

    return Semantics(
      container: true,
      button: true,
      label: [l10n.documentsTileLabel, headline, ?detail].join(', '),
      excludeSemantics: true,
      child: DrivonCard(
        onTap: () => context.push(
          empty
              ? AppRoutes.addDocumentPath(vehicleId)
              : AppRoutes.documentsPath(vehicleId),
        ),
        child: Builder(
          builder: (context) {
            final textTheme = Theme.of(context).textTheme;
            final colors = context.drivonColors;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    TagChip(label: l10n.documentsTileLabel, tone: TagTone.sky),
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
