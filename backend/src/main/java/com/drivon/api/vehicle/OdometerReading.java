package com.drivon.api.vehicle;

import com.drivon.api.common.persistence.AssignedIdEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Table;
import java.time.LocalDate;
import java.util.UUID;
import org.jspecify.annotations.Nullable;

/** One point on a vehicle's odometer timeline. Rules are enforced by {@link OdometerService}. */
@Entity
@Table(name = "odometer_readings")
public class OdometerReading extends AssignedIdEntity {

  @Column(name = "vehicle_id", nullable = false, updatable = false)
  private UUID vehicleId;

  @Column(name = "reading_km", nullable = false)
  private int readingKm;

  @Column(name = "recorded_on", nullable = false)
  private LocalDate date;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false, length = 20, updatable = false)
  private OdometerSource source;

  @Column(name = "source_id", updatable = false)
  private @Nullable UUID sourceId;

  protected OdometerReading() {}

  OdometerReading(
      UUID vehicleId,
      OdometerSource source,
      @Nullable UUID sourceId,
      LocalDate date,
      int readingKm) {
    super(null);
    this.vehicleId = vehicleId;
    this.source = source;
    this.sourceId = sourceId;
    this.date = date;
    this.readingKm = readingKm;
  }

  void moveTo(LocalDate date, int readingKm) {
    this.date = date;
    this.readingKm = readingKm;
  }

  public UUID getVehicleId() {
    return vehicleId;
  }

  public int getReadingKm() {
    return readingKm;
  }

  public LocalDate getDate() {
    return date;
  }

  public OdometerSource getSource() {
    return source;
  }

  public @Nullable UUID getSourceId() {
    return sourceId;
  }
}
