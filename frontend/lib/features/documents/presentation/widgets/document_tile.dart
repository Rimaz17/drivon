import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/vehicle_document.dart';
import '../document_labels.dart';
import 'expiry_chip.dart';

/// A document row on the paper sheet: type and status on the first line,
/// expiry and file kind beneath, optional notes, and a chevron.
class DocumentTile extends StatelessWidget {
  const DocumentTile({
    required this.document,
    required this.today,
    required this.onTap,
    super.key,
  });

  final VehicleDocument document;
  final DateTime today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colors = context.drivonColors;
    final title = document.type.label(l10n);
    final state = document.expiryState(today);
    final kind = document.isPdf ? l10n.fileKindPdf : l10n.fileKindPhoto;
    final details = '${expiryDetail(context, l10n, document, today)} · $kind';
    final notes = document.notes;

    return Semantics(
      button: true,
      label: l10n.documentRowSemantics(
        title,
        expiryStatusLabel(l10n, state) ?? l10n.noExpiryDetail,
        details,
      ),
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
                Icon(
                  document.isPdf
                      ? Icons.picture_as_pdf_outlined
                      : Icons.image_outlined,
                  color: colors.textSecondary,
                ),
                const SizedBox(width: DrivonSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: DrivonSpacing.sm,
                        runSpacing: DrivonSpacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(title, style: textTheme.titleMedium),
                          ExpiryChip(state: state),
                        ],
                      ),
                      const SizedBox(height: DrivonSpacing.xxs),
                      Text(details, style: textTheme.bodyMedium),
                      if (notes != null && notes.isNotEmpty) ...[
                        const SizedBox(height: DrivonSpacing.xxs),
                        Text(
                          notes,
                          style: textTheme.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: DrivonSpacing.xs),
                Icon(Icons.chevron_right_rounded, color: colors.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
