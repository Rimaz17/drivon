package com.drivon.api.maintenance;

import com.drivon.api.common.persistence.AssignedIdEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;
import org.jspecify.annotations.Nullable;

/** A service on a vehicle. Rules are enforced by {@link MaintenanceService}. */
@Entity
@Table(name = "maintenance_records")
public class MaintenanceRecord extends AssignedIdEntity {

  @Column(name = "vehicle_id", nullable = false, updatable = false)
  private UUID vehicleId;

  @Enumerated(EnumType.STRING)
  @Column(name = "service_type", nullable = false, length = 30)
  private ServiceType serviceType;

  @Column(name = "serviced_on", nullable = false)
  private LocalDate date;

  @Column(name = "odometer_km")
  private @Nullable Integer odometerKm;

  @Column(nullable = false, precision = 12, scale = 2)
  private BigDecimal cost;

  @Column(length = 500)
  private @Nullable String notes;

  @Column(name = "next_service_on")
  private @Nullable LocalDate nextServiceDate;

  @Column(name = "next_service_km")
  private @Nullable Integer nextServiceKm;

  protected MaintenanceRecord() {}

  MaintenanceRecord(@Nullable UUID id, UUID vehicleId, ServiceDetails details) {
    super(id);
    this.vehicleId = vehicleId;
    update(details);
  }

  void update(ServiceDetails details) {
    this.serviceType = details.serviceType();
    this.date = details.date();
    this.odometerKm = details.odometerKm();
    this.cost = details.cost();
    this.notes = details.notes();
    this.nextServiceDate = details.nextServiceDate();
    this.nextServiceKm = details.nextServiceKm();
  }

  public UUID getVehicleId() {
    return vehicleId;
  }

  public ServiceType getServiceType() {
    return serviceType;
  }

  public LocalDate getDate() {
    return date;
  }

  public @Nullable Integer getOdometerKm() {
    return odometerKm;
  }

  public BigDecimal getCost() {
    return cost;
  }

  public @Nullable String getNotes() {
    return notes;
  }

  public @Nullable LocalDate getNextServiceDate() {
    return nextServiceDate;
  }

  public @Nullable Integer getNextServiceKm() {
    return nextServiceKm;
  }

  /** True when the record says when this service is next due. */
  boolean hasNextService() {
    return nextServiceDate != null || nextServiceKm != null;
  }

  /** Normalized values of a service, after validation. */
  record ServiceDetails(
      ServiceType serviceType,
      LocalDate date,
      @Nullable Integer odometerKm,
      BigDecimal cost,
      @Nullable String notes,
      @Nullable LocalDate nextServiceDate,
      @Nullable Integer nextServiceKm) {}
}
