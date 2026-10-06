import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// Temporary landing screen until authentication and vehicles exist (Phase 1).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.appTitle,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              Text(l10n.homeTagline, textAlign: TextAlign.center),
              Text(l10n.homeComingSoon, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
