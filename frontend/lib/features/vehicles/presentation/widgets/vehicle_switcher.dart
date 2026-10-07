import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/vehicle.dart';

/// Switches between the user's vehicles (at most two, so a segmented
/// control fits). Labels use the model name, or the plate when both
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

    return Semantics(
      label: l10n.vehicleSwitcherLabel,
      container: true,
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [
            for (final vehicle in vehicles)
              ButtonSegment(
                value: vehicle.id,
                tooltip: vehicle.displayName,
                label: Text(
                  useModel ? vehicle.model : vehicle.registrationNumber,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          selected: {selectedId},
          onSelectionChanged: (selection) => onSelected(selection.first),
        ),
      ),
    );
  }
}
