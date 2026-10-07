package com.drivon.api.fuel;

import com.drivon.api.common.persistence.AssignedIdEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;
import org.jspecify.annotations.Nullable;

/** A fill-up. Rules (price consistency, odometer order) are enforced by {@link FuelService}. */
@Entity
@Table(name = "fuel_records")
public class FuelRecord extends AssignedIdEntity {

  @Column(name = "vehicle_id", nullable = false, updatable = false)
  private UUID vehicleId;

  @Column(name = "filled_on", nullable = false)
  private LocalDate date;

  @Column(nullable = false, precision = 7, scale = 3)
  private BigDecimal litres;

  @Column(nullable = false, precision = 12, scale = 2)
  private BigDecimal amount;

  @Column(name = "price_per_litre", nullable = false, precision = 10, scale = 2)
  private BigDecimal pricePerLitre;

  @Column(name = "odometer_km", nullable = false)
  private int odometerKm;

  @Column(name = "full_tank", nullable = false)
  private boolean fullTank;

  @Column(length = 100)
  private @Nullable String station;

  protected FuelRecord() {}

  FuelRecord(@Nullable UUID id, UUID vehicleId, FuelDetails details) {
    super(id);
    this.vehicleId = vehicleId;
    update(details);
  }

  void update(FuelDetails details) {
    this.date = details.date();
    this.litres = details.litres();
    this.amount = details.amount();
    this.pricePerLitre = details.pricePerLitre();
    this.odometerKm = details.odometerKm();
    this.fullTank = details.fullTank();
    this.station = details.station();
  }

  public UUID getVehicleId() {
    return vehicleId;
  }

  public LocalDate getDate() {
    return date;
  }

  public BigDecimal getLitres() {
    return litres;
  }

  public BigDecimal getAmount() {
    return amount;
  }

  public BigDecimal getPricePerLitre() {
    return pricePerLitre;
  }

  public int getOdometerKm() {
    return odometerKm;
  }

  public boolean isFullTank() {
    return fullTank;
  }

  public @Nullable String getStation() {
    return station;
  }

  /** Normalized values of a fill-up, after validation and price calculation. */
  record FuelDetails(
      LocalDate date,
      BigDecimal litres,
      BigDecimal amount,
      BigDecimal pricePerLitre,
      int odometerKm,
      boolean fullTank,
      @Nullable String station) {}
}
