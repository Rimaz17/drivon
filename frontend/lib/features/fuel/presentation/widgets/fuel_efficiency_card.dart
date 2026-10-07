import 'package:flutter/material.dart';

import '../../../../core/utils/fixed_decimal.dart';
import '../../../../core/utils/number_format.dart';
import '../../../../design_system/design_system.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/fuel_record.dart';

/// The vehicle's km/L: the last tank on the gauge, measured against the best
/// tank, with the average and best beside it. Before two full fill-ups it
/// explains what is needed instead.
class FuelEfficiencyCard extends StatelessWidget {
  const FuelEfficiencyCard({required this.stats, super.key});

  final FuelStats stats;

  /// Gauge diameter; fits a 320 dp phone with the card's padding.
  static const double gaugeSize = 200;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final latest = stats.latestKmPerLitre;
    final best = stats.bestKmPerLitre;
    final average = stats.averageKmPerLitre;

    if (latest == null || best == null || average == null) {
      return DrivonCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.speed_rounded,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(width: DrivonSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.efficiencyPendingTitle,
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: DrivonSpacing.xs),
                  Text(
                    l10n.efficiencyPendingMessage,
                    style: textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    String figure(FixedDecimal value) =>
        formatDecimal(context, value, trimZeros: false);

    return DrivonCard(
      padding: const EdgeInsets.fromLTRB(
        DrivonSpacing.lg,
        DrivonSpacing.xl,
        DrivonSpacing.lg,
        DrivonSpacing.lg,
      ),
      child: Column(
        children: [
          ArcGauge(
            size: gaugeSize,
            // A display ratio only; both values share the same scale.
            progress: best.isZero ? 0 : latest.units / best.units,
            value: figure(latest),
            unit: l10n.kmPerLitreUnit,
            caption: l10n.lastTankCaption,
            semanticsLabel: l10n.efficiencySemantics(
              figure(latest),
              figure(average),
              figure(best),
            ),
          ),
          // The arc's open bottom already separates the gauge from the row.
          ExcludeSemantics(
            child: Row(
              children: [
                Expanded(
                  child: _Figure(
                    label: l10n.averageLabel,
                    value: figure(average),
                    unit: l10n.kmPerLitreUnit,
                  ),
                ),
                const SizedBox(width: DrivonSpacing.md),
                Expanded(
                  child: _Figure(
                    label: l10n.bestTankLabel,
                    value: figure(best),
                    unit: l10n.kmPerLitreUnit,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, required this.unit});

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        Text(label, style: textTheme.bodySmall, textAlign: TextAlign.center),
        const SizedBox(height: DrivonSpacing.xxs),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: value, style: textTheme.titleLarge),
              TextSpan(text: ' $unit', style: textTheme.bodySmall),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
