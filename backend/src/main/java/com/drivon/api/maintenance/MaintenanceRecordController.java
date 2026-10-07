package com.drivon.api.maintenance;

import com.drivon.api.common.security.CurrentUserId;
import com.drivon.api.common.web.CreateResult;
import com.drivon.api.common.web.PageResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import org.jspecify.annotations.Nullable;
import org.springdoc.core.annotations.ParameterObject;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/vehicles/{vehicleId}/maintenance-records")
@Tag(name = "Maintenance", description = "Service history and upcoming services")
class MaintenanceRecordController {

  private final MaintenanceService maintenance;

  MaintenanceRecordController(MaintenanceService maintenance) {
    this.maintenance = maintenance;
  }

  @GetMapping
  @Operation(
      summary = "List services, newest first",
      description = "Sortable by `date`, `cost` and `odometerKm`.")
  @ApiResponse(responseCode = "200", description = "A page of services")
  @ApiResponse(responseCode = "400", description = "INVALID_SORT, MALFORMED_REQUEST")
  @ApiResponse(responseCode = "404", description = "VEHICLE_NOT_FOUND")
  PageResponse<MaintenanceRecordResponse> list(
      @CurrentUserId UUID userId,
      @PathVariable UUID vehicleId,
      @Parameter(description = "Only this service type") @RequestParam(required = false)
          @Nullable ServiceType serviceType,
      @ParameterObject Pageable pageable) {
    return maintenance.list(userId, vehicleId, serviceType, pageable);
  }

  @GetMapping("/upcoming")
  @Operation(
      summary = "Upcoming services",
      description =
          "When each service type is next due, from its latest record: overdue first, then by"
              + " due date, then by mileage.")
  @ApiResponse(responseCode = "404", description = "VEHICLE_NOT_FOUND")
  List<UpcomingServiceResponse> upcoming(@CurrentUserId UUID userId, @PathVariable UUID vehicleId) {
    return maintenance.upcoming(userId, vehicleId);
  }

  @GetMapping("/{recordId}")
  @Operation(summary = "Get one service")
  @ApiResponse(
      responseCode = "404",
      description = "VEHICLE_NOT_FOUND, MAINTENANCE_RECORD_NOT_FOUND")
  MaintenanceRecordResponse get(
      @CurrentUserId UUID userId, @PathVariable UUID vehicleId, @PathVariable UUID recordId) {
    return maintenance.get(userId, vehicleId, recordId);
  }

  @PostMapping
  @Operation(
      summary = "Log a service",
      description = "Send an app-generated `id` to make retries return the saved record (200).")
  @ApiResponse(responseCode = "201", description = "Created; Location points to the service")
  @ApiResponse(responseCode = "200", description = "Already saved earlier with this ID")
  @ApiResponse(responseCode = "400", description = "VALIDATION_FAILED")
  @ApiResponse(responseCode = "404", description = "VEHICLE_NOT_FOUND")
  @ApiResponse(responseCode = "409", description = "RECORD_ID_CONFLICT")
  @ApiResponse(
      responseCode = "422",
      description =
          "NEXT_SERVICE_DATE_INVALID, NEXT_SERVICE_KM_INVALID (with minKm),"
              + " ODOMETER_OUT_OF_ORDER, DATE_IN_FUTURE")
  ResponseEntity<MaintenanceRecordResponse> create(
      @CurrentUserId UUID userId,
      @PathVariable UUID vehicleId,
      @Valid @RequestBody MaintenanceRecordRequest request) {
    CreateResult<MaintenanceRecordResponse> result = maintenance.create(userId, vehicleId, request);
    return result.toResponse(result.record().id());
  }

  @PutMapping("/{recordId}")
  @Operation(summary = "Replace a service's details")
  @ApiResponse(responseCode = "200", description = "Updated service")
  @ApiResponse(
      responseCode = "404",
      description = "VEHICLE_NOT_FOUND, MAINTENANCE_RECORD_NOT_FOUND")
  @ApiResponse(
      responseCode = "422",
      description =
          "NEXT_SERVICE_DATE_INVALID, NEXT_SERVICE_KM_INVALID, ODOMETER_OUT_OF_ORDER,"
              + " DATE_IN_FUTURE")
  MaintenanceRecordResponse update(
      @CurrentUserId UUID userId,
      @PathVariable UUID vehicleId,
      @PathVariable UUID recordId,
      @Valid @RequestBody MaintenanceRecordRequest request) {
    return maintenance.update(userId, vehicleId, recordId, request);
  }

  @DeleteMapping("/{recordId}")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  @Operation(summary = "Delete a service and its odometer reading")
  @ApiResponse(responseCode = "204", description = "Deleted")
  @ApiResponse(
      responseCode = "404",
      description = "VEHICLE_NOT_FOUND, MAINTENANCE_RECORD_NOT_FOUND")
  void delete(
      @CurrentUserId UUID userId, @PathVariable UUID vehicleId, @PathVariable UUID recordId) {
    maintenance.delete(userId, vehicleId, recordId);
  }
}
