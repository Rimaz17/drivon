package com.drivon.api.fuel;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

/** The parts of a fill-up that fuel efficiency depends on. */
record FuelFill(
    UUID id,
    LocalDate date,
    int odometerKm,
    BigDecimal litres,
    BigDecimal amount,
    boolean fullTank) {}
