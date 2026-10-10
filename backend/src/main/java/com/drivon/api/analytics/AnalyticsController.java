package com.drivon.api.analytics;

import com.drivon.api.common.security.CurrentUserId;
import com.drivon.api.fuel.EfficiencyPoint;
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
    name = "Analytics",
    description = "Cost per km, monthly cost trends, efficiency trends and vehicle comparison")
class AnalyticsController {

  private static final String VEHICLE = "/vehicles/{vehicleId}/analytics";

  private final AnalyticsService analytics;

  AnalyticsController(AnalyticsService analytics) {
    this.analytics = analytics;
  }

  @GetMapping(VEHICLE + "/cost-per-km")
  @Operation(
      summary = "Running cost per km for a date range",
      description =
          "Everything spent in the range (fill-ups, services, expenses) over the distance the"
              + " odometer advanced in it, split into FUEL, MAINTENANCE (services, maintenance and"
              + " repairs) and OTHER. Both dates are optional and inclusive.")
  @ApiResponse(
      responseCode = "200",
      description = "The figures; costPerKm is null without distance")
  @ApiResponse(responseCode = "400", description = "INVALID_DATE_RANGE")
  @ApiResponse(responseCode = "404", description = "VEHICLE_NOT_FOUND")
  CostPerKmResponse costPerKm(
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
    return analytics.costPerKm(userId, vehicleId, from, to);
  }

  @GetMapping(VEHICLE + "/monthly-costs")
  @Operation(
      summary = "Cost, distance and cost per km for each month",
      description = "One entry per month up to the current one, oldest first; empty months are 0.")
  @ApiResponse(responseCode = "200", description = "Monthly figures")
  @ApiResponse(responseCode = "400", description = "VALIDATION_FAILED (months outside 1–24)")
  @ApiResponse(responseCode = "404", description = "VEHICLE_NOT_FOUND")
  List<MonthlyCostResponse> monthlyCosts(
      @CurrentUserId UUID userId,
      @PathVariable UUID vehicleId,
      @Parameter(description = "How many months, 1 to 24")
          @RequestParam(defaultValue = "6")
          @Min(1) @Max(24) int months) {
    return analytics.monthlyCosts(userId, vehicleId, months);
  }

  @GetMapping(VEHICLE + "/efficiency-trend")
  @Operation(
      summary = "km/L of each tank over time",
      description =
          "Every full-to-full stretch that ended in the range, oldest first, with its distance,"
              + " litres, km/L and fuel cost per km. Both dates are optional and inclusive.")
  @ApiResponse(responseCode = "200", description = "Points; empty until two full fills")
  @ApiResponse(responseCode = "400", description = "INVALID_DATE_RANGE")
  @ApiResponse(responseCode = "404", description = "VEHICLE_NOT_FOUND")
  List<EfficiencyPoint> efficiencyTrend(
      @CurrentUserId UUID userId,
      @PathVariable UUID vehicleId,
      @RequestParam(required = false) @DateTimeFormat(iso = ISO.DATE) @Nullable LocalDate from,
      @RequestParam(required = false) @DateTimeFormat(iso = ISO.DATE) @Nullable LocalDate to) {
    return analytics.efficiencyTrend(userId, vehicleId, from, to);
  }

  @GetMapping("/analytics/vehicle-comparison")
  @Operation(
      summary = "Compare the user's vehicles",
      description =
          "Cost per km with its parts, distance, total cost and average km/L of each vehicle for"
              + " the same range. Both dates are optional and inclusive.")
  @ApiResponse(responseCode = "200", description = "One entry per vehicle, oldest first")
  @ApiResponse(responseCode = "400", description = "INVALID_DATE_RANGE")
  VehicleComparisonResponse compareVehicles(
      @CurrentUserId UUID userId,
      @RequestParam(required = false) @DateTimeFormat(iso = ISO.DATE) @Nullable LocalDate from,
      @RequestParam(required = false) @DateTimeFormat(iso = ISO.DATE) @Nullable LocalDate to) {
    return analytics.compareVehicles(userId, from, to);
  }
}
