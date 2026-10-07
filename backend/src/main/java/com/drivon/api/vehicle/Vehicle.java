package com.drivon.api.vehicle;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

/** A vehicle owned by one user. The owner never changes after creation. */
@Entity
@Table(name = "vehicles")
public class Vehicle {

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private UUID id;

  @Column(name = "user_id", nullable = false, updatable = false)
  private UUID userId;

  @Column(nullable = false, length = 50)
  private String make;

  @Column(nullable = false, length = 50)
  private String model;

  @Column(name = "model_year", nullable = false)
  private int year;

  @Column(name = "registration_number", nullable = false, length = 20)
  private String registrationNumber;

  @Enumerated(EnumType.STRING)
  @Column(name = "fuel_type", nullable = false, length = 20)
  private FuelType fuelType;

  @Column(name = "current_odometer_km", nullable = false)
  private int currentOdometerKm;

  @CreationTimestamp
  @Column(name = "created_at", nullable = false, updatable = false)
  private Instant createdAt;

  @UpdateTimestamp
  @Column(name = "updated_at", nullable = false)
  private Instant updatedAt;

  protected Vehicle() {}

  Vehicle(
      UUID userId,
      String make,
      String model,
      int year,
      String registrationNumber,
      FuelType fuelType,
      int currentOdometerKm) {
    this.userId = userId;
    update(make, model, year, registrationNumber, fuelType, currentOdometerKm);
  }

  /** Replaces the editable details. Business rules are checked by {@link VehicleService}. */
  void update(
      String make,
      String model,
      int year,
      String registrationNumber,
      FuelType fuelType,
      int currentOdometerKm) {
    this.make = make;
    this.model = model;
    this.year = year;
    this.registrationNumber = registrationNumber;
    this.fuelType = fuelType;
    this.currentOdometerKm = currentOdometerKm;
  }

  public UUID getId() {
    return id;
  }

  public UUID getUserId() {
    return userId;
  }

  public String getMake() {
    return make;
  }

  public String getModel() {
    return model;
  }

  public int getYear() {
    return year;
  }

  public String getRegistrationNumber() {
    return registrationNumber;
  }

  public FuelType getFuelType() {
    return fuelType;
  }

  public int getCurrentOdometerKm() {
    return currentOdometerKm;
  }

  public Instant getCreatedAt() {
    return createdAt;
  }

  public Instant getUpdatedAt() {
    return updatedAt;
  }
}
