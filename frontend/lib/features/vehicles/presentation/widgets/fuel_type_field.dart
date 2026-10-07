import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/fuel_type.dart';
import '../fuel_type_label.dart';

/// Fuel type picker as a validated form field. Starts empty so the user
/// makes an explicit choice.
class FuelTypeField extends FormField<FuelType> {
  FuelTypeField({
    required ValueChanged<FuelType> onChanged,
    super.initialValue,
    super.validator,
    super.enabled,
    super.key,
  }) : super(
         builder: (state) {
           final context = state.context;
           final l10n = AppLocalizations.of(context);
           final textTheme = Theme.of(context).textTheme;
           return Semantics(
             label: l10n.fuelTypeLabel,
             container: true,
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 ExcludeSemantics(
                   child: Text(l10n.fuelTypeLabel, style: textTheme.labelLarge),
                 ),
                 const SizedBox(height: DrivonSpacing.sm),
                 SizedBox(
                   width: double.infinity,
                   child: SegmentedButton<FuelType>(
                     emptySelectionAllowed: true,
                     showSelectedIcon: false,
                     segments: [
                       for (final type in FuelType.values)
                         ButtonSegment(
                           value: type,
                           label: Text(type.label(l10n)),
                         ),
                     ],
                     selected: {?state.value},
                     onSelectionChanged: state.widget.enabled
                         ? (selection) {
                             if (selection.isEmpty) return;
                             state.didChange(selection.first);
                             onChanged(selection.first);
                           }
                         : null,
                   ),
                 ),
                 if (state.hasError) ...[
                   const SizedBox(height: DrivonSpacing.xs),
                   Padding(
                     padding: const EdgeInsets.symmetric(
                       horizontal: DrivonSpacing.lg,
                     ),
                     child: Text(
                       state.errorText!,
                       style: textTheme.bodySmall?.copyWith(
                         color: context.drivonColors.danger,
                       ),
                     ),
                   ),
                 ],
               ],
             ),
           );
         },
       );
}
