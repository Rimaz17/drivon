import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/errors/error_text.dart';
import '../../../core/ui/load_more_footer.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/number_format.dart';
import '../../../design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/odometer_reading.dart';
import 'odometer_controllers.dart';

/// A vehicle's odometer readings, newest first. Initial and manual readings
/// open for correction; a fill-up's reading opens that fill-up.
class OdometerHistoryScreen extends ConsumerWidget {
  const OdometerHistoryScreen({required this.vehicleId, super.key});

  final String vehicleId;

  /// Space below the list so the last row clears the floating button.
  static const double _fabClearance = 96;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final history = ref.watch(odometerHistoryProvider(vehicleId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.odometerHistoryTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            context.push(AppRoutes.addOdometerReadingPath(vehicleId)),
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.addReadingAction),
      ),
      body: SafeArea(
        child: history.when(
          loading: () => LoadingState(semanticsLabel: l10n.loadingReadings),
          error: (error, _) => ErrorState(
            title: l10n.readingsLoadErrorTitle,
            message: errorText(l10n, error),
            retryLabel: l10n.retryAction,
            onRetry: () => ref.invalidate(odometerHistoryProvider(vehicleId)),
          ),
          data: (list) => RefreshIndicator.adaptive(
            onRefresh: () async {
              ref.invalidate(odometerHistoryProvider(vehicleId));
              await ref.read(odometerHistoryProvider(vehicleId).future);
            },
            child: ContentWidth(
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  DrivonSpacing.screenGutter,
                  DrivonSpacing.sm,
                  DrivonSpacing.screenGutter,
                  _fabClearance,
                ),
                children: [
                  Text(
                    l10n.odometerHistoryExplainer,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: DrivonSpacing.md),
                  for (final (index, reading) in list.items.indexed) ...[
                    if (index > 0) const Divider(),
                    _ReadingTile(vehicleId: vehicleId, reading: reading),
                  ],
                  LoadMoreFooter(
                    list: list,
                    failedMessage: l10n.readingsLoadMoreFailed,
                    onLoadMore: () => ref
                        .read(odometerHistoryProvider(vehicleId).notifier)
                        .loadMore(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReadingTile extends StatelessWidget {
  const _ReadingTile({required this.vehicleId, required this.reading});

  final String vehicleId;
  final OdometerReading reading;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final km = formatInteger(context, reading.readingKm);
    final date = formatDate(context, reading.date);
    final source = switch (reading.source) {
      OdometerSource.initial => l10n.sourceInitial,
      OdometerSource.manual => l10n.sourceManual,
      OdometerSource.fuel => l10n.sourceFuel,
      OdometerSource.maintenance => l10n.sourceMaintenance,
    };
    final sourceId = reading.sourceId;
    final VoidCallback? onTap = reading.source.canCorrect
        ? () => context.push(
            AppRoutes.editOdometerReadingPath(vehicleId, reading.id),
          )
        : reading.source == OdometerSource.fuel && sourceId != null
        ? () => context.push(AppRoutes.editFuelRecordPath(vehicleId, sourceId))
        : null;
    final note = switch (reading.source) {
      OdometerSource.fuel => l10n.linkedReadingFuelHint,
      OdometerSource.maintenance => l10n.linkedReadingServiceNote,
      OdometerSource.initial || OdometerSource.manual => null,
    };

    return Semantics(
      button: onTap != null,
      label: l10n.readingSemantics(km, date, source),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$km ${l10n.kmUnit}', style: textTheme.titleMedium),
                      const SizedBox(height: DrivonSpacing.xxs),
                      Text('$date · $source', style: textTheme.bodyMedium),
                      if (note != null) ...[
                        const SizedBox(height: DrivonSpacing.xxs),
                        Text(note, style: textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
                if (onTap != null)
                  Icon(
                    Icons.chevron_right_rounded,
                    color: context.drivonColors.textTertiary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
