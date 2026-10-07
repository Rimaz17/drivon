package com.drivon.api.fuel;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;
import org.jspecify.annotations.Nullable;

/**
 * @param kmPerLitre efficiency of the stretch this full fill closes (full-tank method); null for
 *     partial fills and for the first full fill
 */
public record FuelRecordResponse(
    UUID id,
    UUID vehicleId,
    LocalDate date,
    BigDecimal litres,
    BigDecimal amount,
    BigDecimal pricePerLitre,
    int odometerKm,
    boolean fullTank,
    @Nullable String station,
    @Nullable BigDecimal kmPerLitre,
    Instant createdAt,
    Instant updatedAt) {}
