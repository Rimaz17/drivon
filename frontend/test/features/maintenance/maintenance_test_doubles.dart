import 'package:drivon/core/errors/app_exception.dart';
import 'package:drivon/core/models/paged.dart';
import 'package:drivon/core/utils/fixed_decimal.dart';
import 'package:drivon/features/maintenance/data/maintenance_api.dart';
import 'package:drivon/features/maintenance/domain/maintenance_record.dart';

MaintenanceRecord maintenanceRecord({
  String id = 'service-1',
  ServiceType serviceType = ServiceType.oilChange,
  DateTime? date,
  String cost = '9800.00',
  int? odometerKm = 46500,
  String? notes,
  DateTime? nextServiceDate,
  int? nextServiceKm,
}) => MaintenanceRecord(
  id: id,
  vehicleId: 'vehicle-1',
  serviceType: serviceType,
  date: date ?? DateTime(2026, 10, 7),
  cost: FixedDecimal.parse(cost, scale: 2),
  odometerKm: odometerKm,
  notes: notes,
  nextServiceDate: nextServiceDate,
  nextServiceKm: nextServiceKm,
);

/// In-memory [MaintenanceApi] for tests; records are kept newest first and
/// upcoming services are scripted.
class FakeMaintenanceApi implements MaintenanceApi {
  FakeMaintenanceApi([List<MaintenanceRecord>? records])
    : records = records ?? [];

  final List<MaintenanceRecord> records;
  List<UpcomingService> upcomingResponse = [];

  /// When set, the next call throws it once.
  AppException? nextError;
  final List<MaintenanceDraft> savedDrafts = [];
  final List<ServiceType?> listedTypes = [];

  @override
  Future<Paged<MaintenanceRecord>> list(
    String vehicleId, {
    required int page,
    ServiceType? type,
    int size = 20,
  }) async {
    _throwIfScripted();
    listedTypes.add(type);
    return Paged(
      items: [
        for (final record in records)
          if (type == null || record.serviceType == type) record,
      ],
      hasMore: false,
    );
  }

  @override
  Future<MaintenanceRecord> get(String vehicleId, String id) async {
    _throwIfScripted();
    return records.firstWhere((r) => r.id == id);
  }

  @override
  Future<List<UpcomingService>> upcoming(String vehicleId) async {
    _throwIfScripted();
    return upcomingResponse;
  }

  @override
  Future<MaintenanceRecord> create(
    String vehicleId,
    MaintenanceDraft draft, {
    required String id,
  }) async {
    _throwIfScripted();
    savedDrafts.add(draft);
    final record = _fromDraft(id, draft);
    records.insert(0, record);
    return record;
  }

  @override
  Future<MaintenanceRecord> update(
    String vehicleId,
    String id,
    MaintenanceDraft draft,
  ) async {
    _throwIfScripted();
    savedDrafts.add(draft);
    final record = _fromDraft(id, draft);
    records[records.indexWhere((r) => r.id == id)] = record;
    return record;
  }

  @override
  Future<void> delete(String vehicleId, String id) async {
    _throwIfScripted();
    records.removeWhere((r) => r.id == id);
  }

  void _throwIfScripted() {
    final error = nextError;
    if (error != null) {
      nextError = null;
      throw error;
    }
  }

  static MaintenanceRecord _fromDraft(String id, MaintenanceDraft draft) =>
      MaintenanceRecord(
        id: id,
        vehicleId: 'vehicle-1',
        serviceType: draft.serviceType,
        date: draft.date,
        cost: draft.cost,
        odometerKm: draft.odometerKm,
        notes: draft.notes,
        nextServiceDate: draft.nextServiceDate,
        nextServiceKm: draft.nextServiceKm,
      );
}
