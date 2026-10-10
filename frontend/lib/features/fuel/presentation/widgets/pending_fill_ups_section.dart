import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/ui/confirm_dialog.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/utils/number_format.dart';
import '../../../../design_system/design_system.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/pending_fill_ups.dart';
import '../fuel_sync_controller.dart';

/// Fill-ups logged without a connection, on the Fuel sheet above the
/// history. They show what was entered, not figures: km/L and totals come
/// from the server once they sync.
class PendingFillUpsSection extends ConsumerWidget {
  const PendingFillUpsSection({required this.vehicleId, super.key});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(fuelSyncProvider);
    final pending = sync.forVehicle(vehicleId);
    if (pending.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final controller = ref.read(fuelSyncProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: SectionTitle(l10n.pendingFillUpsTitle)),
            if (sync.syncing)
              Text(l10n.syncingNotice, style: textTheme.bodySmall)
            else if (pending.any((fillUp) => !fillUp.rejected))
              TextButton(
                onPressed: controller.syncNow,
                child: Text(l10n.syncNowAction),
              ),
          ],
        ),
        Text(l10n.pendingFillUpsExplainer, style: textTheme.bodySmall),
        const SizedBox(height: DrivonSpacing.xs),
        for (final (index, fillUp) in pending.indexed) ...[
          if (index > 0) const Divider(),
          _PendingTile(fillUp: fillUp, busy: sync.syncing),
        ],
        const SizedBox(height: DrivonSpacing.xxl),
      ],
    );
  }
}

class _PendingTile extends ConsumerWidget {
  const _PendingTile({required this.fillUp, required this.busy});

  final PendingFillUp fillUp;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colors = context.drivonColors;
    final draft = fillUp.draft;
    final title =
        '${formatDecimal(context, draft.litres)} ${l10n.litresUnit} · '
        '${formatRupees(context, draft.amount)}';
    final details =
        '${formatDate(context, draft.date)} · '
        '${formatInteger(context, draft.odometerKm)} ${l10n.kmUnit}';
    final rejection = fillUp.rejection;
    final status = rejection == null
        ? l10n.pendingFillUpWaiting
        : l10n.pendingFillUpRejected(rejectionText(l10n, rejection));

    Future<void> discard() async {
      final confirmed = await showConfirmDialog(
        context,
        title: l10n.discardFillUpTitle,
        message: l10n.discardFillUpMessage,
        confirmLabel: l10n.discardAction,
        cancelLabel: l10n.cancelAction,
        destructive: true,
      );
      if (confirmed) {
        await ref.read(fuelSyncProvider.notifier).discard(fillUp.id);
      }
    }

    return Semantics(
      container: true,
      label: '$title, $details, $status',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: DrivonSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              rejection == null
                  ? Icons.cloud_upload_outlined
                  : Icons.error_outline_rounded,
              color: rejection == null ? colors.textSecondary : colors.danger,
            ),
            const SizedBox(width: DrivonSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Text(title, style: textTheme.titleMedium),
                  ),
                  const SizedBox(height: DrivonSpacing.xxs),
                  ExcludeSemantics(
                    child: Text(details, style: textTheme.bodyMedium),
                  ),
                  const SizedBox(height: DrivonSpacing.xxs),
                  ExcludeSemantics(
                    child: Text(status, style: textTheme.bodySmall),
                  ),
                  Wrap(
                    spacing: DrivonSpacing.sm,
                    children: [
                      if (rejection != null)
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => ref
                                    .read(fuelSyncProvider.notifier)
                                    .retry(fillUp.id),
                          child: Text(l10n.retryAction),
                        ),
                      TextButton(
                        onPressed: busy ? null : discard,
                        child: Text(l10n.discardAction),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Why the server refused a fill-up, in the app's words when it has them.
String rejectionText(AppLocalizations l10n, SyncRejection rejection) =>
    switch (rejection.code) {
      ApiErrorCodes.odometerOutOfOrder => l10n.pendingRejectedOdometer,
      ApiErrorCodes.dateInFuture => l10n.errorDateInFuture,
      ApiErrorCodes.fuelPriceMismatch => l10n.pendingRejectedPrice,
      ApiErrorCodes.vehicleNotFound => l10n.errorVehicleNotFound,
      _ => rejection.detail ?? l10n.errorGeneric,
    };
