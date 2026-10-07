package com.drivon.api.maintenance;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;
import org.jspecify.annotations.Nullable;

/**
 * Body for logging or replacing a service.
 *
 * @param id optional app-generated ID; resending it returns the saved record. Ignored on update.
 * @param odometerKm optional; when given it goes on the vehicle's odometer timeline
 * @param cost may be 0 for free or warranty work
 * @param nextServiceDate optional, after {@code date}
 * @param nextServiceKm optional, above {@code odometerKm} when that is given
 */
public record MaintenanceRecordRequest(
    @Nullable UUID id,
    @NotNull ServiceType serviceType,
    @NotNull LocalDate date,
    @Min(0) @Max(2_000_000) @Nullable Integer odometerKm,
    @NotNull @DecimalMin("0.00") @DecimalMax("9999999.99") @Digits(integer = 7, fraction = 2) BigDecimal cost,
    @Size(max = 500) @Nullable String notes,
    @Nullable LocalDate nextServiceDate,
    @Min(1) @Max(2_000_000) @Nullable Integer nextServiceKm) {}
