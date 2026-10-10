import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';

/// The way into Ask My Vehicle from the Garage sheet, with an example
/// question so it's clear what it is for.
class AssistantGarageTile extends StatelessWidget {
  const AssistantGarageTile({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      container: true,
      button: true,
      label: '${l10n.assistantTitle}, ${l10n.assistantTileHint}',
      excludeSemantics: true,
      child: DrivonCard(
        onTap: () => context.push(AppRoutes.assistant),
        child: Builder(
          builder: (context) {
            final textTheme = Theme.of(context).textTheme;
            final colors = context.drivonColors;
            return Row(
              children: [
                Icon(Icons.auto_awesome_outlined, color: colors.accentText),
                const SizedBox(width: DrivonSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.assistantTitle, style: textTheme.titleMedium),
                      const SizedBox(height: DrivonSpacing.xxs),
                      Text(l10n.assistantTileHint, style: textTheme.bodyMedium),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: colors.textTertiary),
              ],
            );
          },
        ),
      ),
    );
  }
}
