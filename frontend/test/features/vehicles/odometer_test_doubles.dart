import 'package:drivon/core/errors/app_exception.dart';
import 'package:drivon/core/models/paged.dart';
import 'package:drivon/features/vehicles/data/odometer_api.dart';
import 'package:drivon/features/vehicles/domain/odometer_reading.dart';

OdometerReading odometerReading({
  String id = 'reading-1',
  int readingKm = 45000,
  DateTime? date,
  OdometerSource source = OdometerSource.initial,
  String? sourceId,
}) => OdometerReading(
  id: id,
  readingKm: readingKm,
  date: date ?? DateTime(2026, 10),
  source: source,
  sourceId: sourceId,
);

/// In-memory [OdometerApi] for tests; readings are kept newest first.
class FakeOdometerApi implements OdometerApi {
  FakeOdometerApi([List<OdometerReading>? readings])
    : readings = readings ?? [];

  final List<OdometerReading> readings;

  /// When set, the next call throws it once.
  AppException? nextError;
  int _ids = 100;

  @override
  Future<Paged<OdometerReading>> list(
    String vehicleId, {
    required int page,
    int size = 20,
  }) async {
    _throwIfScripted();
    return Paged(items: List.of(readings), hasMore: false);
  }

  @override
  Future<OdometerReading> add(
    String vehicleId,
    int readingKm,
    DateTime date,
  ) async {
    _throwIfScripted();
    final reading = odometerReading(
      id: 'reading-${_ids++}',
      readingKm: readingKm,
      date: date,
      source: OdometerSource.manual,
    );
    readings.insert(0, reading);
    return reading;
  }

  @override
  Future<OdometerReading> correct(
    String vehicleId,
    String id,
    int readingKm,
    DateTime date,
  ) async {
    _throwIfScripted();
    final index = readings.indexWhere((r) => r.id == id);
    final corrected = readings[index].copyWith(
      readingKm: readingKm,
      date: date,
    );
    readings[index] = corrected;
    return corrected;
  }

  @override
  Future<void> delete(String vehicleId, String id) async {
    _throwIfScripted();
    readings.removeWhere((r) => r.id == id);
  }

  void _throwIfScripted() {
    final error = nextError;
    if (error != null) {
      nextError = null;
      throw error;
    }
  }
}
