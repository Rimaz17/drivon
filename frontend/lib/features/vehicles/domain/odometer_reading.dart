import 'package:freezed_annotation/freezed_annotation.dart';

part 'odometer_reading.freezed.dart';

/// Where a reading came from. Wire values match the backend's enum.
enum OdometerSource {
  /// The odometer the vehicle was added with: can be corrected, not deleted.
  initial('INITIAL'),

  /// Entered by the user: can be corrected and deleted.
  manual('MANUAL'),

  /// Belongs to a fill-up; changes only through that fill-up.
  fuel('FUEL'),

  /// Belongs to a service record; changes only through that record.
  maintenance('MAINTENANCE');

  const OdometerSource(this.wireValue);

  final String wireValue;

  bool get canCorrect => this == initial || this == manual;

  bool get canDelete => this == manual;

  static OdometerSource fromWire(String value) => values.firstWhere(
    (source) => source.wireValue == value,
    orElse: () => throw FormatException('Unknown odometer source: $value'),
  );
}

/// One point on a vehicle's odometer timeline.
@freezed
abstract class OdometerReading with _$OdometerReading {
  const factory OdometerReading({
    required String id,
    required int readingKm,
    required DateTime date,
    required OdometerSource source,

    /// The fill-up or service the reading belongs to.
    String? sourceId,
  }) = _OdometerReading;
}
