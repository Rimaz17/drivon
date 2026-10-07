import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';

/// A row in a record history (service, expense): title and amount on the
/// first line, details beneath, optional notes, and a chevron. Screen readers
/// hear [semanticsLabel] as one button.
class RecordTile extends StatelessWidget {
  const RecordTile({
    required this.title,
    required this.amount,
    required this.details,
    required this.semanticsLabel,
    required this.onTap,
    this.notes,
    super.key,
  });

  final String title;
  final String amount;
  final String details;
  final String? notes;
  final String semanticsLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final note = notes;
    return Semantics(
      button: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: DrivonRadii.mdAll,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: DrivonSpacing.minTouchTarget,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: DrivonSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(title, style: textTheme.titleMedium),
                          ),
                          const SizedBox(width: DrivonSpacing.sm),
                          Text(amount, style: textTheme.titleMedium),
                        ],
                      ),
                      const SizedBox(height: DrivonSpacing.xxs),
                      Text(details, style: textTheme.bodyMedium),
                      if (note != null && note.isNotEmpty) ...[
                        const SizedBox(height: DrivonSpacing.xxs),
                        Text(
                          note,
                          style: textTheme.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: DrivonSpacing.xs),
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.drivonColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
