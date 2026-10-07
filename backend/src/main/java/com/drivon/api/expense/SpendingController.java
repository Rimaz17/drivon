package com.drivon.api.expense;

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
@RequestMapping("/api/v1")
@Tag(
    name = "Spending",
    description = "Totals across fill-ups (FUEL), services (MAINTENANCE) and expenses")
class SpendingController {

  private final SpendingService spending;

  SpendingController(SpendingService spending) {
    this.spending = spending;
  }

  @GetMapping("/vehicles/{vehicleId}/spending")
  @Operation(
      summary = "A vehicle's spend by category for a date range",
      description = "Both dates are optional and inclusive; every category is listed.")
  @ApiResponse(responseCode = "400", description = "INVALID_DATE_RANGE")
  @ApiResponse(responseCode = "404", description = "VEHICLE_NOT_FOUND")
  SpendingSummaryResponse summary(
      @CurrentUserId UUID userId,
      @PathVariable UUID vehicleId,
      @Parameter(description = "First day, e.g. 2026-01-01; default: the beginning")
          @RequestParam(required = false)
          @DateTimeFormat(iso = ISO.DATE)
          @Nullable LocalDate from,
      @Parameter(description = "Last day, e.g. 2026-12-31; default: today")
          @RequestParam(required = false)
          @DateTimeFormat(iso = ISO.DATE)
          @Nullable LocalDate to) {
    return spending.summary(userId, vehicleId, from, to);
  }

  @GetMapping("/vehicles/{vehicleId}/spending/monthly")
  @Operation(
      summary = "A vehicle's total spend per month",
      description = "One entry per month up to the current one, oldest first; empty months are 0.")
  @ApiResponse(responseCode = "400", description = "VALIDATION_FAILED (months outside 1–24)")
  @ApiResponse(responseCode = "404", description = "VEHICLE_NOT_FOUND")
  List<MonthlyAmount> monthly(
      @CurrentUserId UUID userId,
      @PathVariable UUID vehicleId,
      @Parameter(description = "How many months, 1 to 24")
          @RequestParam(defaultValue = "6")
          @Min(1) @Max(24) int months) {
    return spending.monthly(userId, vehicleId, months);
  }

  @GetMapping("/spending/vehicles")
  @Operation(
      summary = "Total spend of each of the user's vehicles",
      description = "For comparing vehicles; both dates are optional and inclusive.")
  @ApiResponse(responseCode = "400", description = "INVALID_DATE_RANGE")
  VehicleSpendingResponse byVehicle(
      @CurrentUserId UUID userId,
      @RequestParam(required = false) @DateTimeFormat(iso = ISO.DATE) @Nullable LocalDate from,
      @RequestParam(required = false) @DateTimeFormat(iso = ISO.DATE) @Nullable LocalDate to) {
    return spending.byVehicle(userId, from, to);
  }
}
