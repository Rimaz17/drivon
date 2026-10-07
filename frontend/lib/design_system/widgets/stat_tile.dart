import 'package:flutter/material.dart';

import '../tokens/drivon_colors.dart';
import '../tokens/drivon_spacing.dart';
import 'drivon_card.dart';
import 'tag_chip.dart';

/// A single headline figure, e.g. monthly spend or average km/L.
///
/// [value] is pre-formatted by the caller (currency, decimals) so the tile
/// stays locale-agnostic. Screen readers hear one combined label.
class StatTile extends StatelessWidget {
  const StatTile({
    required this.label,
    required this.value,
    this.unit,
    this.caption,
    this.tagTone = TagTone.neutral,
    this.tone = DrivonCardTone.surface,
    this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final String? unit;
  final String? caption;
  final TagTone tagTone;
  final DrivonCardTone tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = context.drivonColors;
    final onHighlight = tone != DrivonCardTone.surface;
    final valueColor = onHighlight ? colors.onHighlight : colors.textPrimary;
    final captionColor = onHighlight
        ? colors.onHighlight
        : colors.textSecondary;
    final semanticsLabel = [
      label,
      [value, ?unit].join(' '),
      ?caption,
    ].join(', ');

    return Semantics(
      container: true,
      label: semanticsLabel,
      button: onTap != null,
      excludeSemantics: true,
      child: DrivonCard(
        tone: tone,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            TagChip(label: label, tone: tagTone),
            const SizedBox(height: DrivonSpacing.lg),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: textTheme.displaySmall?.copyWith(color: valueColor),
                  ),
                  if (unit != null)
                    TextSpan(
                      text: ' $unit',
                      style: textTheme.titleMedium?.copyWith(
                        color: captionColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (caption != null) ...[
              const SizedBox(height: DrivonSpacing.xs),
              Text(
                caption!,
                style: textTheme.bodySmall?.copyWith(color: captionColor),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
