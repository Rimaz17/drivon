import 'package:flutter/material.dart';

import '../../../../core/utils/date_format.dart';
import '../../../../core/utils/number_format.dart';
import '../../../../design_system/design_system.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/fuel_record.dart';

/// One fill-up in the history: amount first, then date, litres and
/// odometer, with its km/L (or a top-up tag). Tapping opens it for editing.
class FuelRecordTile extends StatelessWidget {
  const FuelRecordTile({required this.record, required this.onTap, super.key});

  final FuelRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colors = context.drivonColors;
    final amount = formatRupees(context, record.amount);
    final date = formatDate(context, record.date);
    final litres = formatDecimal(context, record.litres);
    final km = formatInteger(context, record.odometerKm);
    final kmPerLitre = record.kmPerLitre;
    final efficiency = kmPerLitre == null
        ? null
        : formatDecimal(context, kmPerLitre, trimZeros: false);
    final station = record.station;

    return Semantics(
      button: true,
      label: l10n.fillUpSemantics(
        amount,
        date,
        litres,
        km,
        efficiency != null
            ? l10n.fillUpEfficiencySemantics(efficiency)
            : (record.fullTank ? '' : l10n.topUpSemantics),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(amount, style: textTheme.titleMedium),
                      const SizedBox(height: DrivonSpacing.xxs),
                      Text(
                        l10n.fillUpDetails(date, litres, km),
                        style: textTheme.bodyMedium,
                      ),
                      if (station != null && station.isNotEmpty) ...[
                        const SizedBox(height: DrivonSpacing.xxs),
                        Text(
                          station,
                          style: textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: DrivonSpacing.sm),
                if (efficiency != null)
                  TagChip(
                    label: '$efficiency ${l10n.kmPerLitreUnit}',
                    tone: TagTone.mint,
                  )
                else if (!record.fullTank)
                  TagChip(label: l10n.topUpTag),
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
