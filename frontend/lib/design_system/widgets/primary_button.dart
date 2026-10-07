import 'package:flutter/material.dart';

import '../tokens/drivon_spacing.dart';

/// Full-width primary action that shows progress while [busy]. It is
/// disabled while busy so a slow request can't be submitted twice.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.busyLabel,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  /// Spoken instead of [label] while busy, e.g. "Signing in".
  final String? busyLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        child: busy
            ? Semantics(
                label: busyLabel ?? label,
                child: const SizedBox.square(
                  dimension: DrivonSpacing.xl,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              )
            : Text(label),
      ),
    );
  }
}
