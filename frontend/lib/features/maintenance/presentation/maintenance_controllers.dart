import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/paged.dart';
import '../../../core/ui/paged_list_controller.dart';
import '../../auth/presentation/session_controller.dart';
import '../../expenses/presentation/expense_controllers.dart';
import '../../vehicles/presentation/odometer_controllers.dart';
import '../../vehicles/presentation/vehicles_controller.dart';
import '../data/maintenance_repository.dart';
import '../domain/maintenance_record.dart';

/// The service type the Service tab's history is filtered to; null for all.
class ServiceTypeFilterController extends Notifier<ServiceType?> {
  @override
  ServiceType? build() => null;

  void select(ServiceType? type) => state = type;
}

final serviceTypeFilterProvider =
    NotifierProvider<ServiceTypeFilterController, ServiceType?>(
      ServiceTypeFilterController.new,
    );

/// Which services to list: a vehicle's, optionally of one type.
typedef MaintenanceQuery = ({String vehicleId, ServiceType? type});

/// A vehicle's services, newest first, a page at a time.
class MaintenanceHistoryController
    extends PagedListController<MaintenanceRecord> {
  MaintenanceHistoryController(this.query);

  final MaintenanceQuery query;

  @override
  Future<Paged<MaintenanceRecord>> fetchPage(int page) => ref
      .read(maintenanceRepositoryProvider)
      .list(query.vehicleId, page: page, type: query.type);
}

final maintenanceHistoryProvider = AsyncNotifierProvider.autoDispose
    .family<
      MaintenanceHistoryController,
      PagedList<MaintenanceRecord>,
      MaintenanceQuery
    >(
      MaintenanceHistoryController.new,
      // Failures are shown with a retry button instead of retried silently.
      retry: (_, _) => null,
    );

/// What is due next for a vehicle, soonest first.
final upcomingServicesProvider = FutureProvider.autoDispose
    .family<List<UpcomingService>, String>((ref, vehicleId) {
      ref.watch(currentUserProvider);
      return ref.read(maintenanceRepositoryProvider).upcoming(vehicleId);
    }, retry: (_, _) => null);

/// A service to edit, from the loaded history when possible.
final maintenanceRecordProvider = FutureProvider.autoDispose
    .family<MaintenanceRecord, ({String vehicleId, String recordId})>((
      ref,
      key,
    ) {
      final type = ref.read(serviceTypeFilterProvider);
      final loaded = ref
          .read(
            maintenanceHistoryProvider((vehicleId: key.vehicleId, type: type)),
          )
          .value;
      for (final record in loaded?.items ?? const <MaintenanceRecord>[]) {
        if (record.id == key.recordId) return record;
      }
      return ref
          .read(maintenanceRepositoryProvider)
          .get(key.vehicleId, key.recordId);
    }, retry: (_, _) => null);

/// Logs, edits and deletes services, then refreshes what they affect: the
/// history, upcoming services, spending totals, and the odometer when the
/// service had one. Throws AppExceptions for forms to explain.
class MaintenanceMutations {
  MaintenanceMutations(this._ref);

  final Ref _ref;

  MaintenanceRepository get _repository =>
      _ref.read(maintenanceRepositoryProvider);

  Future<void> add(String vehicleId, MaintenanceDraft draft) async {
    await _repository.create(vehicleId, draft);
    _refresh(vehicleId);
  }

  Future<void> edit(String vehicleId, String id, MaintenanceDraft draft) async {
    await _repository.update(vehicleId, id, draft);
    _refresh(vehicleId);
  }

  Future<void> remove(String vehicleId, String id) async {
    await _repository.delete(vehicleId, id);
    _refresh(vehicleId);
  }

  void _refresh(String vehicleId) {
    _ref
      // Every type filter of the vehicle's history may include the change.
      ..invalidate(maintenanceHistoryProvider)
      ..invalidate(upcomingServicesProvider(vehicleId))
      ..invalidate(odometerHistoryProvider(vehicleId));
    refreshSpending(_ref);
    unawaited(_ref.read(vehiclesControllerProvider.notifier).reload());
  }
}

final maintenanceMutationsProvider = Provider<MaintenanceMutations>(
  MaintenanceMutations.new,
);
