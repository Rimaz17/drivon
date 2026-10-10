import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/session_controller.dart';
import '../../reminders/presentation/reminder_controllers.dart';
import '../data/selected_vehicle_store.dart';
import '../data/vehicle_repository.dart';
import '../domain/vehicle.dart';

/// The signed-in user's vehicles, oldest first. Mutations throw
/// AppExceptions so forms can show field-level errors.
class VehiclesController extends AsyncNotifier<List<Vehicle>> {
  @override
  Future<List<Vehicle>> build() async {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const [];
    return ref.read(vehicleRepositoryProvider).list();
  }

  /// Reloads from the server, keeping the current list visible meanwhile.
  Future<void> reload() async {
    final result = await AsyncValue.guard(
      () => ref.read(vehicleRepositoryProvider).list(),
    );
    if (ref.mounted) state = result;
  }

  Future<Vehicle> add(VehicleDraft draft) async {
    final created = await ref.read(vehicleRepositoryProvider).create(draft);
    _replaceList([..._current, created]);
    return created;
  }

  Future<Vehicle> edit(String id, VehicleDraft draft) async {
    final updated = await ref.read(vehicleRepositoryProvider).update(id, draft);
    // A higher odometer moves mileage reminders.
    refreshReminders(ref.invalidate);
    _replaceList([
      for (final vehicle in _current) vehicle.id == id ? updated : vehicle,
    ]);
    return updated;
  }

  Future<void> remove(String id) async {
    await ref.read(vehicleRepositoryProvider).delete(id);
    _replaceList([
      for (final vehicle in _current)
        if (vehicle.id != id) vehicle,
    ]);
  }

  List<Vehicle> get _current => state.value ?? const [];

  void _replaceList(List<Vehicle> vehicles) {
    if (ref.mounted) state = AsyncData(vehicles);
  }
}

final vehiclesControllerProvider =
    AsyncNotifierProvider<VehiclesController, List<Vehicle>>(
      VehiclesController.new,
      // Failures are shown with a retry button instead of retried silently.
      retry: (_, _) => null,
    );

/// ID of the vehicle the user chose, remembered on this device per user.
class SelectedVehicleIdController extends Notifier<String?> {
  @override
  String? build() {
    final user = ref.watch(currentUserProvider);
    if (user != null) {
      unawaited(_restore(user.id));
    }
    return null;
  }

  Future<void> _restore(String userId) async {
    final stored = await ref.read(selectedVehicleStoreProvider).read(userId);
    if (ref.mounted && state == null && stored != null) state = stored;
  }

  Future<void> select(String vehicleId) async {
    state = vehicleId;
    final user = ref.read(currentUserProvider);
    if (user != null) {
      await ref.read(selectedVehicleStoreProvider).write(user.id, vehicleId);
    }
  }
}

final selectedVehicleIdProvider =
    NotifierProvider<SelectedVehicleIdController, String?>(
      SelectedVehicleIdController.new,
    );

/// The vehicle to show: the chosen one if it still exists, else the first.
final selectedVehicleProvider = Provider<Vehicle?>((ref) {
  final vehicles = ref.watch(vehiclesControllerProvider).value ?? const [];
  if (vehicles.isEmpty) return null;
  final selectedId = ref.watch(selectedVehicleIdProvider);
  return vehicles.firstWhere(
    (vehicle) => vehicle.id == selectedId,
    orElse: () => vehicles.first,
  );
});
