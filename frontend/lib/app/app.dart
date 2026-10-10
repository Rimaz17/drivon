import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design_system/theme/drivon_theme.dart';
import '../features/notifications/presentation/notification_controller.dart';
import '../l10n/app_localizations.dart';
import 'notification_navigation.dart';
import 'router.dart';

class DrivonApp extends ConsumerWidget {
  const DrivonApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // App-wide notification work: setting up notifications at launch (so a
    // tap that opened the app is seen), scheduling local reminders and
    // opening a tapped reminder. Listening keeps them alive without
    // rebuilding here.
    ref
      ..listen(notificationBootstrapProvider, (_, _) {})
      ..listen(reminderScheduleSyncProvider, (_, _) {})
      ..listen(notificationNavigationProvider, (_, _) {});
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: DrivonTheme.dark(),
      themeMode: ThemeMode.dark,
      routerConfig: ref.watch(routerProvider),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
