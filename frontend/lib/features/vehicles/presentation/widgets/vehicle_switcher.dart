import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/vehicle.dart';

/// Switches between the user's vehicles (at most two, so pills fit). Each
/// shows the model with the plate beside it, or the plate first when both
/// vehicles share a model.
class VehicleSwitcher extends StatelessWidget {
  const VehicleSwitcher({
    required this.vehicles,
    required this.selectedId,
    required this.onSelected,
    super.key,
  });

  final List<Vehicle> vehicles;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final models = vehicles.map((v) => v.model.toLowerCase()).toSet();
    final useModel = models.length == vehicles.length;

    return PillSegmentedControl<String>(
      semanticsLabel: l10n.vehicleSwitcherLabel,
      segments: [
        for (final vehicle in vehicles)
          PillSegment(
            value: vehicle.id,
            label: useModel ? vehicle.model : vehicle.registrationNumber,
            detail: useModel ? vehicle.registrationNumber : vehicle.model,
            tooltip: vehicle.displayName,
          ),
      ],
      selected: selectedId,
      onSelected: onSelected,
    );
  }
}
