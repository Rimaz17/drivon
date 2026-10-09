import 'package:flutter/material.dart';

import '../../../../core/utils/number_format.dart';
import '../../../../design_system/design_system.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/analytics.dart';
import 'insight_card.dart';

/// The tab's headline: what the vehicle costs per km driven in the period,
/// with what it spent over what distance, and the fuel / maintenance /
/// other split as one bar with its legend.
class RunningCostCard extends StatelessWidget {
  const RunningCostCard({required this.cost, super.key});

  final CostPerKm cost;

  /// Height reserved while the figure loads, so the screen doesn't jump.
  static const double placeholderHeight = 200;

  @override
  Widget build(BuildContext context) {
    return DrivonCard(child: Builder(builder: _content));
  }

  Widget _content(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colors = context.drivonColors;
    final perKm = cost.costPerKm;
    final total = formatRupees(context, cost.totalCost);
    final caption = perKm != null
        ? l10n.costOverDistance(total, formatInteger(context, cost.distanceKm))
        : cost.totalCost.isZero
        ? l10n.costNothingYetCaption
        : l10n.costNoDistanceCaption(total);
    String groupPerKm(GroupCost group) {
      final value = group.costPerKm;
      return value == null
          ? l10n.notYetValue
          : formatRupees(context, value, showCents: true);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TagChip(label: l10n.runningCostLabel, tone: TagTone.violet),
        ),
        const SizedBox(height: DrivonSpacing.lg),
        Semantics(
          label: perKm != null
              ? l10n.runningCostSemantics(
                  formatRupees(context, perKm, showCents: true),
                  caption,
                )
              : l10n.runningCostUnknownSemantics(caption),
          excludeSemantics: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      perKm == null
                          ? l10n.notYetValue
                          : formatRupees(context, perKm, showCents: true),
                      style: textTheme.displayMedium,
                    ),
                    if (perKm != null) ...[
                      const SizedBox(width: DrivonSpacing.xs),
                      Text(
                        l10n.perKmUnit,
                        style: textTheme.titleMedium?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: DrivonSpacing.xs),
              Text(caption, style: textTheme.bodyMedium),
            ],
          ),
        ),
        if (!cost.totalCost.isZero) ...[
          const SizedBox(height: DrivonSpacing.xl),
          SegmentedBar(
            semanticsLabel: l10n.breakdownSemantics(
              groupPerKm(cost.breakdown[0]),
              groupPerKm(cost.breakdown[1]),
              groupPerKm(cost.breakdown[2]),
            ),
            segments: [
              for (final group in cost.breakdown)
                BarSegment(
                  value: group.total.toDouble(),
                  color: group.group.color(context),
                ),
            ],
          ),
          const SizedBox(height: DrivonSpacing.md),
          ExcludeSemantics(
            child: ChartLegend(
              entries: [
                for (final group in cost.breakdown)
                  LegendEntry(
                    color: group.group.color(context),
                    label: group.group.label(l10n),
                    value: perKm == null
                        ? formatRupees(context, group.total)
                        : l10n.perKmValue(groupPerKm(group)),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
