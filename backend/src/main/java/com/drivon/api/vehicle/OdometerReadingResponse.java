package com.drivon.api.vehicle;

import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;
import org.jspecify.annotations.Nullable;

/**
 * @param sourceId the fill-up or service the reading belongs to; null for initial and manual
 *     readings
 */
public record OdometerReadingResponse(
    UUID id,
    int readingKm,
    LocalDate date,
    OdometerSource source,
    @Nullable UUID sourceId,
    Instant createdAt) {}
