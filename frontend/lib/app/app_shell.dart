import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/network/connection_status.dart';
import '../design_system/design_system.dart';
import '../l10n/app_localizations.dart';

/// The signed-in app's frame: a bottom navigation bar on phones and a
/// navigation rail on wider windows, switching between the top-level tabs.
/// Each tab keeps its own navigation stack and scroll position. While the
/// server can't be reached, a line on top says that saved data is shown.
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _select(int index) => navigationShell.goBranch(
    index,
    // Tapping the current tab again returns to its first screen.
    initialLocation: index == navigationShell.currentIndex,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final destinations = [
      (Icons.directions_car_outlined, Icons.directions_car, l10n.navGarage),
      (Icons.local_gas_station_outlined, Icons.local_gas_station, l10n.navFuel),
      (Icons.build_outlined, Icons.build, l10n.navService),
      (Icons.receipt_long_outlined, Icons.receipt_long, l10n.navExpenses),
      (Icons.insights_outlined, Icons.insights, l10n.navInsights),
    ];
    final wide =
        MediaQuery.sizeOf(context).width >=
        DrivonSpacing.navigationRailMinWidth;

    final body = Column(
      children: [
        const _OfflineBanner(),
        Expanded(child: navigationShell),
      ],
    );

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            SafeArea(
              right: false,
              child: NavigationRail(
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected: _select,
                labelType: NavigationRailLabelType.all,
                destinations: [
                  for (final (icon, selectedIcon, label) in destinations)
                    NavigationRailDestination(
                      icon: Icon(icon),
                      selectedIcon: Icon(selectedIcon),
                      label: Text(label),
                    ),
                ],
              ),
            ),
            const VerticalDivider(),
            Expanded(child: body),
          ],
        ),
      );
    }
    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _select,
        destinations: [
          for (final (icon, selectedIcon, label) in destinations)
            NavigationDestination(
              icon: Icon(icon),
              selectedIcon: Icon(selectedIcon),
              label: label,
            ),
        ],
      ),
    );
  }
}

/// Says the app is offline and showing what it saved earlier; hidden online.
class _OfflineBanner extends ConsumerWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(connectionStatusProvider) is! Offline) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Material(
        color: scheme.surfaceContainerHigh,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DrivonSpacing.screenGutter,
              vertical: DrivonSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  size: DrivonSpacing.xl,
                  color: context.drivonColors.warning,
                ),
                const SizedBox(width: DrivonSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.offlineBanner,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
