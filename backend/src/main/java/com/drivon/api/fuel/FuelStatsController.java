package com.drivon.api.fuel;

import com.drivon.api.common.security.CurrentUserId;
import com.drivon.api.common.stats.MonthlyAmount;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;
import org.jspecify.annotations.Nullable;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.format.annotation.DateTimeFormat.ISO;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/vehicles/{vehicleId}/fuel-stats")
@Tag(name = "Fuel")
class FuelStatsController {

  private final FuelService fuel;

  FuelStatsController(FuelService fuel) {
    this.fuel = fuel;
  }

  @GetMapping
  @Operation(
      summary = "Fuel spend and efficiency for a date range",
      description =
          "Total spend, litres and fill-ups, plus average, best and latest km/L and fuel cost per"
              + " km (full-tank method). Both dates are optional and inclusive.")
  @ApiResponse(responseCode = "200", description = "The figures; efficiency may be null")
  @ApiResponse(responseCode = "400", description = "INVALID_DATE_RANGE")
  @ApiResponse(responseCode = "404", description = "VEHICLE_NOT_FOUND")
  FuelStatsResponse stats(
      @CurrentUserId UUID userId,
      @PathVariable UUID vehicleId,
      @Parameter(description = "First day, e.g. 2026-09-01; default: the beginning")
          @RequestParam(required = false)
          @DateTimeFormat(iso = ISO.DATE)
          @Nullable LocalDate from,
      @Parameter(description = "Last day, e.g. 2026-09-30; default: today")
          @RequestParam(required = false)
          @DateTimeFormat(iso = ISO.DATE)
          @Nullable LocalDate to) {
    return fuel.stats(userId, vehicleId, from, to);
  }

  @GetMapping("/monthly")
  @Operation(
      summary = "Fuel spend per month",
      description = "One entry per month up to the current one, oldest first; empty months are 0.")
  @ApiResponse(responseCode = "200", description = "Monthly totals")
  @ApiResponse(responseCode = "400", description = "VALIDATION_FAILED (months outside 1–24)")
  @ApiResponse(responseCode = "404", description = "VEHICLE_NOT_FOUND")
  List<MonthlyAmount> monthly(
      @CurrentUserId UUID userId,
      @PathVariable UUID vehicleId,
      @Parameter(description = "How many months, 1 to 24")
          @RequestParam(defaultValue = "6")
          @Min(1) @Max(24) int months) {
    return fuel.monthlySpend(userId, vehicleId, months);
  }
}
