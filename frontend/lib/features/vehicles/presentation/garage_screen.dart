import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/errors/error_text.dart';
import '../../../design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/domain/user.dart';
import '../../auth/presentation/session_controller.dart';
import '../data/selected_vehicle_store.dart';
import '../domain/vehicle.dart';
import 'fuel_type_label.dart';
import 'vehicles_controller.dart';
import 'widgets/vehicle_hero_card.dart';
import 'widgets/vehicle_snapshot.dart';
import 'widgets/vehicle_switcher.dart';

/// Home screen: the user's vehicles, with the selected one in focus.
class GarageScreen extends ConsumerWidget {
  const GarageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final vehicles = ref.watch(vehiclesControllerProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          if (user != null)
            IconButton(
              tooltip: l10n.accountTooltip,
              icon: const Icon(Icons.account_circle_outlined),
              onPressed: () => _showAccount(context, ref, user),
            ),
        ],
      ),
      body: SafeArea(
        child: vehicles.when(
          loading: () => LoadingState(semanticsLabel: l10n.loadingVehicles),
          error: (error, _) => ErrorState(
            title: l10n.vehiclesLoadErrorTitle,
            message: errorText(l10n, error),
            retryLabel: l10n.retryAction,
            onRetry: () => ref.invalidate(vehiclesControllerProvider),
          ),
          data: (list) => list.isEmpty
              ? EmptyState(
                  icon: Icons.directions_car_outlined,
                  title: l10n.emptyGarageTitle,
                  message: l10n.emptyGarageMessage,
                  actionLabel: l10n.addVehicleAction,
                  onAction: () => context.push(AppRoutes.addVehicle),
                )
              : _Garage(vehicles: list, firstName: user?.firstName ?? ''),
        ),
      ),
    );
  }

  Future<void> _showAccount(BuildContext context, WidgetRef ref, User user) {
    return showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        final l10n = AppLocalizations.of(sheetContext);
        final textTheme = Theme.of(sheetContext).textTheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              DrivonSpacing.screenGutter,
              0,
              DrivonSpacing.screenGutter,
              DrivonSpacing.xxl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(user.name, style: textTheme.titleLarge),
                const SizedBox(height: DrivonSpacing.xs),
                Text(user.email, style: textTheme.bodyMedium),
                const SizedBox(height: DrivonSpacing.xxl),
                OutlinedButton.icon(
                  icon: const Icon(Icons.logout_rounded),
                  label: Text(l10n.signOutAction),
                  onPressed: () async {
                    Navigator.of(sheetContext).pop();
                    await ref.read(selectedVehicleStoreProvider).clear();
                    await ref
                        .read(sessionControllerProvider.notifier)
                        .signOut();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Garage extends ConsumerWidget {
  const _Garage({required this.vehicles, required this.firstName});

  final List<Vehicle> vehicles;
  final String firstName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final selected = ref.watch(selectedVehicleProvider) ?? vehicles.first;
    final canAddMore = vehicles.length < maxVehiclesPerUser;

    return RefreshIndicator.adaptive(
      onRefresh: () {
        VehicleSnapshot.refresh(ref, selected.id);
        return ref.read(vehiclesControllerProvider.notifier).reload();
      },
      child: ContentWidth(
        child: SheetScrollView(
          header: [
            Semantics(
              header: true,
              child: Text(
                l10n.greeting(firstName),
                style: textTheme.headlineLarge,
              ),
            ),
            const SizedBox(height: DrivonSpacing.xl),
            if (vehicles.length > 1) ...[
              VehicleSwitcher(
                vehicles: vehicles,
                selectedId: selected.id,
                onSelected: (id) =>
                    ref.read(selectedVehicleIdProvider.notifier).select(id),
              ),
              const SizedBox(height: DrivonSpacing.lg),
            ],
            VehicleHeroCard(
              vehicle: selected,
              onEdit: () =>
                  context.push(AppRoutes.editVehiclePath(selected.id)),
            ),
            const SizedBox(height: DrivonSpacing.xs),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                icon: const Icon(Icons.history_rounded),
                label: Text(l10n.odometerHistoryTitle),
                onPressed: () =>
                    context.push(AppRoutes.odometerHistoryPath(selected.id)),
              ),
            ),
          ],
          sheet: [
            VehicleSnapshot(vehicle: selected),
            const SizedBox(height: DrivonSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: StatTile(
                    label: l10n.fuelTypeLabel,
                    value: selected.fuelType.label(l10n),
                    tagTone: TagTone.mint,
                  ),
                ),
                const SizedBox(width: DrivonSpacing.md),
                Expanded(
                  child: StatTile(
                    label: l10n.yearLabel,
                    value: '${selected.year}',
                    tagTone: TagTone.sky,
                  ),
                ),
              ],
            ),
            const SizedBox(height: DrivonSpacing.xxl),
            if (canAddMore)
              OutlinedButton.icon(
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.addAnotherVehicleAction),
                onPressed: () => context.push(AppRoutes.addVehicle),
              )
            else
              Builder(
                // Reads the sheet's paper theme, not the screen's.
                builder: (context) => Text(
                  l10n.vehicleLimitNote,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
