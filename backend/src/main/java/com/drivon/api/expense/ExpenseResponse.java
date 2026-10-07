package com.drivon.api.expense;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;
import org.jspecify.annotations.Nullable;

public record ExpenseResponse(
    UUID id,
    UUID vehicleId,
    ExpenseCategory category,
    BigDecimal amount,
    LocalDate date,
    @Nullable String notes,
    Instant createdAt,
    Instant updatedAt) {

  static ExpenseResponse from(Expense expense) {
    return new ExpenseResponse(
        expense.getId(),
        expense.getVehicleId(),
        expense.getCategory(),
        expense.getAmount(),
        expense.getDate(),
        expense.getNotes(),
        expense.getCreatedAt(),
        expense.getUpdatedAt());
  }
}
