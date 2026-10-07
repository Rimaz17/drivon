import 'package:flutter/material.dart';

import '../../../../core/utils/number_format.dart';
import '../../../../design_system/design_system.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/vehicle.dart';

/// The selected vehicle at a glance: plate, name and odometer, set large
/// and light like the inspiration's main readout.
class VehicleHeroCard extends StatelessWidget {
  const VehicleHeroCard({
    required this.vehicle,
    required this.onEdit,
    super.key,
  });

  final Vehicle vehicle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final odometer = formatInteger(context, vehicle.currentOdometerKm);

    return DrivonCard(
      tone: DrivonCardTone.hero,
      padding: const EdgeInsets.fromLTRB(
        DrivonSpacing.xl,
        DrivonSpacing.lg,
        DrivonSpacing.sm,
        DrivonSpacing.xl,
      ),
      child: Builder(
        builder: (context) {
          final textTheme = Theme.of(context).textTheme;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Semantics(
                  label: l10n.vehicleSummary(
                    vehicle.displayName,
                    vehicle.registrationNumber,
                    odometer,
                  ),
                  excludeSemantics: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: DrivonSpacing.xs),
                      Text(
                        vehicle.registrationNumber,
                        style: textTheme.titleMedium,
                      ),
                      const SizedBox(height: DrivonSpacing.xxs),
                      Text(
                        vehicle.displayName,
                        style: textTheme.headlineSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: DrivonSpacing.xxxl),
                      Text(l10n.odometerLabel, style: textTheme.labelMedium),
                      const SizedBox(height: DrivonSpacing.xxs),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: odometer,
                                style: textTheme.displayLarge,
                              ),
                              TextSpan(
                                text: ' ${l10n.kmUnit}',
                                style: textTheme.titleMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: l10n.editVehicleTooltip,
                icon: const Icon(Icons.edit_outlined),
                onPressed: onEdit,
              ),
            ],
          );
        },
      ),
    );
  }
}
