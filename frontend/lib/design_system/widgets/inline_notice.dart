import 'package:flutter/material.dart';

import '../tokens/drivon_colors.dart';
import '../tokens/drivon_radii.dart';
import '../tokens/drivon_spacing.dart';

enum InlineNoticeTone { info, error }

/// A short message inside a form or screen, e.g. why sign-in failed. Screen
/// readers announce it when it appears.
class InlineNotice extends StatelessWidget {
  const InlineNotice({
    required this.message,
    this.tone = InlineNoticeTone.error,
    super.key,
  });

  final String message;
  final InlineNoticeTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.drivonColors;
    final isError = tone == InlineNoticeTone.error;
    final accent = isError ? colors.danger : colors.info;

    return Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: DrivonRadii.mdAll,
        ),
        child: Padding(
          padding: const EdgeInsets.all(DrivonSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Icon(
                  isError
                      ? Icons.error_outline_rounded
                      : Icons.info_outline_rounded,
                  color: accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: DrivonSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: colors.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
