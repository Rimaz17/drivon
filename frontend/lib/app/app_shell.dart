import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design_system/design_system.dart';
import '../l10n/app_localizations.dart';

/// The signed-in app's frame: a bottom navigation bar on phones and a
/// navigation rail on wider windows, switching between the top-level tabs.
/// Each tab keeps its own navigation stack and scroll position.
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
            Expanded(child: navigationShell),
          ],
        ),
      );
    }
    return Scaffold(
      body: navigationShell,
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
