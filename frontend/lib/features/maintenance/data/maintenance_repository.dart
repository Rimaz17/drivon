import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/paged.dart';
import '../../../core/utils/uuid.dart';
import '../domain/maintenance_record.dart';
import 'maintenance_api.dart';

/// A vehicle's services. The server validates next-service rules and
/// calculates what is due next.
class MaintenanceRepository {
  MaintenanceRepository(this._api, {this._newId = uuidV4});

  final MaintenanceApi _api;
  final String Function() _newId;

  Future<Paged<MaintenanceRecord>> list(
    String vehicleId, {
    required int page,
    ServiceType? type,
  }) => _api.list(vehicleId, page: page, type: type);

  Future<MaintenanceRecord> get(String vehicleId, String id) =>
      _api.get(vehicleId, id);

  Future<List<UpcomingService>> upcoming(String vehicleId) =>
      _api.upcoming(vehicleId);

  Future<MaintenanceRecord> create(String vehicleId, MaintenanceDraft draft) =>
      _api.create(vehicleId, draft, id: _newId());

  Future<MaintenanceRecord> update(
    String vehicleId,
    String id,
    MaintenanceDraft draft,
  ) => _api.update(vehicleId, id, draft);

  Future<void> delete(String vehicleId, String id) =>
      _api.delete(vehicleId, id);
}

final maintenanceRepositoryProvider = Provider<MaintenanceRepository>(
  (ref) => MaintenanceRepository(ref.watch(maintenanceApiProvider)),
);
