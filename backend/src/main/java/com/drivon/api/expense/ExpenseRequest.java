package com.drivon.api.expense;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;
import org.jspecify.annotations.Nullable;

/**
 * Body for logging or replacing an expense.
 *
 * @param id optional app-generated ID; resending it returns the saved record. Ignored on update.
 */
public record ExpenseRequest(
    @Nullable UUID id,
    @NotNull ExpenseCategory category,
    @NotNull @DecimalMin("0.01") @DecimalMax("9999999.99") @Digits(integer = 7, fraction = 2) BigDecimal amount,
    @NotNull LocalDate date,
    @Size(max = 500) @Nullable String notes) {}
