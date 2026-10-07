import 'package:flutter/material.dart';

import '../tokens/drivon_colors.dart';
import '../tokens/drivon_spacing.dart';

/// Shared layout for full-area status messages (empty and error states).
class _StatusMessage extends StatelessWidget {
  const _StatusMessage({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(DrivonSpacing.xxl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: DrivonSpacing.formMaxWidth,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: iconColor),
              const SizedBox(height: DrivonSpacing.lg),
              Text(
                title,
                style: textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: DrivonSpacing.sm),
              Text(
                message,
                style: textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              if (action != null) ...[
                const SizedBox(height: DrivonSpacing.xxl),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown when a list or screen has no data yet. Tell the user what will
/// appear here and offer the action that creates it.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  }) : assert(
         (actionLabel == null) == (onAction == null),
         'Provide both actionLabel and onAction, or neither.',
       );

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return _StatusMessage(
      icon: icon,
      iconColor: Theme.of(context).colorScheme.primary,
      title: title,
      message: message,
      action: onAction == null
          ? null
          : FilledButton(onPressed: onAction, child: Text(actionLabel!)),
    );
  }
}

/// Shown when loading fails. [message] names the problem and the recovery.
class ErrorState extends StatelessWidget {
  const ErrorState({
    required this.title,
    required this.message,
    required this.retryLabel,
    required this.onRetry,
    super.key,
  });

  final String title;
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _StatusMessage(
      icon: Icons.error_outline_rounded,
      iconColor: context.drivonColors.danger,
      title: title,
      message: message,
      action: OutlinedButton(onPressed: onRetry, child: Text(retryLabel)),
    );
  }
}

/// Centered progress indicator with a spoken label for screen readers.
class LoadingState extends StatelessWidget {
  const LoadingState({required this.semanticsLabel, super.key});

  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(semanticsLabel: semanticsLabel),
    );
  }
}
