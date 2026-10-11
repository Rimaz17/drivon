import 'package:flutter/material.dart';

import '../../../design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';

/// Shown while the saved session is checked. At launch the launch animation
/// covers it; this is the logo's resting frame, in the same place, for any
/// other time the session is being restored.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Semantics(
        label: AppLocalizations.of(context).loadingSession,
        child: const DrivonLogo(),
      ),
    );
  }
}
