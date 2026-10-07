package com.drivon.api.vehicle;

final class OdometerReadingMapper {

  private OdometerReadingMapper() {}

  static OdometerReadingResponse toResponse(OdometerReading reading) {
    return new OdometerReadingResponse(
        reading.getId(),
        reading.getReadingKm(),
        reading.getDate(),
        reading.getSource(),
        reading.getSourceId(),
        reading.getCreatedAt());
  }
}
