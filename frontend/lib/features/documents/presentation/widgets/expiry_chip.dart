import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/vehicle_document.dart';
import '../document_labels.dart';

/// A document's expiry status as a small pill. The icon repeats what the
/// color says, so the status never depends on color alone. Nothing is shown
/// for documents without an expiry date.
class ExpiryChip extends StatelessWidget {
  const ExpiryChip({required this.state, super.key});

  final ExpiryState state;

  static const double _iconSize = 14;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = expiryStatusLabel(l10n, state);
    if (label == null) return const SizedBox.shrink();
    final colors = context.drivonColors;
    final (icon, color) = switch (state) {
      ExpiryState.expired => (Icons.error_outline_rounded, colors.danger),
      ExpiryState.expiringSoon => (Icons.schedule_rounded, colors.warning),
      _ => (Icons.check_circle_outline_rounded, colors.success),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: DrivonRadii.pill,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DrivonSpacing.sm,
          vertical: DrivonSpacing.xxs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: _iconSize, color: color),
            const SizedBox(width: DrivonSpacing.xs),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
