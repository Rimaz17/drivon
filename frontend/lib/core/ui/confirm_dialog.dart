import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';

/// Asks the user to confirm an action, using the platform's native dialog
/// (Cupertino alert on iOS, Material dialog elsewhere). Returns true only
/// when the user confirms.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
  bool destructive = false,
}) async {
  final confirmed = await showAdaptiveDialog<bool>(
    context: context,
    builder: (context) => AlertDialog.adaptive(
      title: Text(title),
      content: Text(message),
      actions: [
        _DialogAction(
          label: cancelLabel,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        _DialogAction(
          label: confirmLabel,
          destructive: destructive,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

class _DialogAction extends StatelessWidget {
  const _DialogAction({
    required this.label,
    required this.onPressed,
    this.destructive = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    switch (Theme.of(context).platform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return CupertinoDialogAction(
          isDestructiveAction: destructive,
          onPressed: onPressed,
          child: Text(label),
        );
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return TextButton(
          onPressed: onPressed,
          style: destructive
              ? TextButton.styleFrom(
                  foregroundColor: context.drivonColors.danger,
                )
              : null,
          child: Text(label),
        );
    }
  }
}
