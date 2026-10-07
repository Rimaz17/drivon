import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../core/errors/error_text.dart';
import '../../../../design_system/design_system.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/vehicle.dart';
import '../vehicles_controller.dart';
import 'vehicle_switcher.dart';

/// Body of a tab that works on the selected vehicle (Fuel, Service,
/// Expenses). Handles loading, errors and having no vehicle, and passes the
/// selected vehicle to [builder] with a [VehicleSwitcher] to place at the top
/// of the content when the user has two vehicles (null otherwise).
class SelectedVehicleView extends ConsumerWidget {
  const SelectedVehicleView({required this.builder, super.key});

  final Widget Function(BuildContext context, Vehicle vehicle, Widget? switcher)
  builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return ref
        .watch(vehiclesControllerProvider)
        .when(
          loading: () => LoadingState(semanticsLabel: l10n.loadingVehicles),
          error: (error, _) => ErrorState(
            title: l10n.vehiclesLoadErrorTitle,
            message: errorText(l10n, error),
            retryLabel: l10n.retryAction,
            onRetry: () => ref.invalidate(vehiclesControllerProvider),
          ),
          data: (vehicles) {
            final selected = ref.watch(selectedVehicleProvider);
            if (vehicles.isEmpty || selected == null) {
              return EmptyState(
                icon: Icons.directions_car_outlined,
                title: l10n.noVehicleTitle,
                message: l10n.noVehicleMessage,
                actionLabel: l10n.addVehicleAction,
                onAction: () => context.push(AppRoutes.addVehicle),
              );
            }
            final switcher = vehicles.length > 1
                ? VehicleSwitcher(
                    vehicles: vehicles,
                    selectedId: selected.id,
                    onSelected: (id) =>
                        ref.read(selectedVehicleIdProvider.notifier).select(id),
                  )
                : null;
            return builder(context, selected, switcher);
          },
        );
  }
}
