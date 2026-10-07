package com.drivon.api.expense;

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

/** A running cost of a vehicle. Rules are enforced by {@link ExpenseService}. */
@Entity
@Table(name = "expenses")
public class Expense extends AssignedIdEntity {

  @Column(name = "vehicle_id", nullable = false, updatable = false)
  private UUID vehicleId;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false, length = 20)
  private ExpenseCategory category;

  @Column(nullable = false, precision = 12, scale = 2)
  private BigDecimal amount;

  @Column(name = "spent_on", nullable = false)
  private LocalDate date;

  @Column(length = 500)
  private @Nullable String notes;

  protected Expense() {}

  Expense(@Nullable UUID id, UUID vehicleId, ExpenseDetails details) {
    super(id);
    this.vehicleId = vehicleId;
    update(details);
  }

  void update(ExpenseDetails details) {
    this.category = details.category();
    this.amount = details.amount();
    this.date = details.date();
    this.notes = details.notes();
  }

  public UUID getVehicleId() {
    return vehicleId;
  }

  public ExpenseCategory getCategory() {
    return category;
  }

  public BigDecimal getAmount() {
    return amount;
  }

  public LocalDate getDate() {
    return date;
  }

  public @Nullable String getNotes() {
    return notes;
  }

  /** Normalized values of an expense, after validation. */
  record ExpenseDetails(
      ExpenseCategory category, BigDecimal amount, LocalDate date, @Nullable String notes) {}
}
