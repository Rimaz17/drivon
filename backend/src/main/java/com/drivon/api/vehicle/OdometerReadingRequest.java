package com.drivon.api.vehicle;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import java.time.LocalDate;

/** Body for adding a manual reading or correcting an initial or manual one. */
public record OdometerReadingRequest(
    @NotNull @Min(0) @Max(2_000_000) Integer readingKm, @NotNull LocalDate date) {}
