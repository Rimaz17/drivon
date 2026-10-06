import 'package:flutter/material.dart';

import '../tokens/drivon_colors.dart';
import '../tokens/drivon_radii.dart';
import '../tokens/drivon_spacing.dart';

/// Color family of a [TagChip].
enum TagTone { neutral, violet, mint, sky }

/// Small pill label that names a metric or status, e.g. "This month".
///
/// Non-interactive; use Material [FilterChip]/[ChoiceChip] for selection.
class TagChip extends StatelessWidget {
  const TagChip({required this.label, this.tone = TagTone.neutral, super.key});

  final String label;
  final TagTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.drivonColors;
    final (background, foreground) = switch (tone) {
      TagTone.neutral => (scheme.surfaceContainerHigh, colors.textPrimary),
      TagTone.violet => (colors.highlight, colors.onHighlight),
      TagTone.mint => (scheme.secondary, scheme.onSecondary),
      TagTone.sky => (colors.accentSoft, colors.onAccentSoft),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: DrivonRadii.pill,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DrivonSpacing.md - 2,
          vertical: DrivonSpacing.xs,
        ),
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: foreground),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
