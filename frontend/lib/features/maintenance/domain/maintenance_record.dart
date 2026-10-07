import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/utils/fixed_decimal.dart';

part 'maintenance_record.freezed.dart';

/// Kinds of service work. Wire values match the backend's enum.
enum ServiceType {
  oilChange('OIL_CHANGE'),
  generalService('GENERAL_SERVICE'),
  tyreRotation('TYRE_ROTATION'),
  tyreReplacement('TYRE_REPLACEMENT'),
  brakeService('BRAKE_SERVICE'),
  batteryReplacement('BATTERY_REPLACEMENT'),
  wheelAlignment('WHEEL_ALIGNMENT'),
  airConditioning('AIR_CONDITIONING'),
  other('OTHER');

  const ServiceType(this.wireValue);

  final String wireValue;

  static ServiceType fromWire(String value) => values.firstWhere(
    (type) => type.wireValue == value,
    orElse: () => throw FormatException('Unknown service type: $value'),
  );
}

/// A service done on a vehicle.
@freezed
abstract class MaintenanceRecord with _$MaintenanceRecord {
  const factory MaintenanceRecord({
    required String id,
    required String vehicleId,
    required ServiceType serviceType,
    required DateTime date,
    required FixedDecimal cost,
    int? odometerKm,
    String? notes,
    DateTime? nextServiceDate,
    int? nextServiceKm,
  }) = _MaintenanceRecord;

  const MaintenanceRecord._();

  MaintenanceDraft toDraft() => MaintenanceDraft(
    serviceType: serviceType,
    date: date,
    cost: cost,
    odometerKm: odometerKm,
    notes: notes,
    nextServiceDate: nextServiceDate,
    nextServiceKm: nextServiceKm,
  );
}

/// The details of a service the user enters.
@freezed
abstract class MaintenanceDraft with _$MaintenanceDraft {
  const factory MaintenanceDraft({
    required ServiceType serviceType,
    required DateTime date,
    required FixedDecimal cost,
    int? odometerKm,
    String? notes,
    DateTime? nextServiceDate,
    int? nextServiceKm,
  }) = _MaintenanceDraft;
}

/// When a service type is next due, calculated by the server from the
/// latest record of that type.
@freezed
abstract class UpcomingService with _$UpcomingService {
  const factory UpcomingService({
    required ServiceType serviceType,
    required String recordId,
    required DateTime lastServicedOn,
    required bool overdue,
    DateTime? dueDate,
    int? dueKm,

    /// Negative when overdue.
    int? daysRemaining,

    /// Negative when overdue.
    int? kmRemaining,
  }) = _UpcomingService;
}
