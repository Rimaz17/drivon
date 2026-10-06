import 'package:flutter/material.dart';

import '../../../design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';

/// Temporary landing screen until authentication and vehicles exist (Phase 1).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: DrivonSpacing.screenGutter,
            vertical: DrivonSpacing.xxxl,
          ),
          children: [
            Text(l10n.appTitle, style: textTheme.displayMedium),
            const SizedBox(height: DrivonSpacing.md),
            Text(l10n.homeTagline, style: textTheme.bodyLarge),
            const SizedBox(height: DrivonSpacing.xxxl),
            DrivonCard(
              tone: DrivonCardTone.highlight,
              child: Builder(
                builder: (context) => Text(
                  l10n.homeComingSoon,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
