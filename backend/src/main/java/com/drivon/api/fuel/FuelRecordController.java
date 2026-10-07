package com.drivon.api.fuel;

import com.drivon.api.common.security.CurrentUserId;
import com.drivon.api.common.web.PageResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.net.URI;
import java.util.UUID;
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
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.support.ServletUriComponentsBuilder;

@RestController
@RequestMapping("/api/v1/vehicles/{vehicleId}/fuel-records")
@Tag(name = "Fuel", description = "Fill-ups, fuel efficiency and fuel spend")
class FuelRecordController {

  private final FuelService fuel;

  FuelRecordController(FuelService fuel) {
    this.fuel = fuel;
  }

  @GetMapping
  @Operation(
      summary = "List fill-ups, newest first",
      description =
          "Sortable by `date`, `odometerKm`, `amount` and `litres`. Full fills that close a"
              + " full-to-full stretch carry its `kmPerLitre`.")
  @ApiResponse(responseCode = "200", description = "A page of fill-ups")
  @ApiResponse(responseCode = "400", description = "INVALID_SORT")
  @ApiResponse(responseCode = "404", description = "VEHICLE_NOT_FOUND")
  PageResponse<FuelRecordResponse> list(
      @CurrentUserId UUID userId,
      @PathVariable UUID vehicleId,
      @ParameterObject Pageable pageable) {
    return fuel.list(userId, vehicleId, pageable);
  }

  @GetMapping("/{recordId}")
  @Operation(summary = "Get one fill-up")
  @ApiResponse(responseCode = "404", description = "VEHICLE_NOT_FOUND, FUEL_RECORD_NOT_FOUND")
  FuelRecordResponse get(
      @CurrentUserId UUID userId, @PathVariable UUID vehicleId, @PathVariable UUID recordId) {
    return fuel.get(userId, vehicleId, recordId);
  }

  @PostMapping
  @Operation(
      summary = "Log a fill-up",
      description =
          "Send an app-generated `id` to make retries safe: resending it returns the saved"
              + " record with 200 instead of creating a duplicate.")
  @ApiResponse(responseCode = "201", description = "Created; Location points to the fill-up")
  @ApiResponse(responseCode = "200", description = "Already saved earlier with this ID")
  @ApiResponse(responseCode = "400", description = "VALIDATION_FAILED")
  @ApiResponse(responseCode = "404", description = "VEHICLE_NOT_FOUND")
  @ApiResponse(responseCode = "409", description = "RECORD_ID_CONFLICT")
  @ApiResponse(
      responseCode = "422",
      description = "FUEL_PRICE_MISMATCH, ODOMETER_OUT_OF_ORDER (with minKm/maxKm), DATE_IN_FUTURE")
  ResponseEntity<FuelRecordResponse> create(
      @CurrentUserId UUID userId,
      @PathVariable UUID vehicleId,
      @Valid @RequestBody FuelRecordRequest request) {
    FuelService.Saved saved = fuel.create(userId, vehicleId, request);
    if (!saved.created()) {
      return ResponseEntity.ok(saved.record());
    }
    URI location =
        ServletUriComponentsBuilder.fromCurrentRequest()
            .path("/{id}")
            .buildAndExpand(saved.record().id())
            .toUri();
    return ResponseEntity.created(location).body(saved.record());
  }

  @PutMapping("/{recordId}")
  @Operation(summary = "Replace a fill-up's details")
  @ApiResponse(responseCode = "200", description = "Updated fill-up")
  @ApiResponse(responseCode = "404", description = "VEHICLE_NOT_FOUND, FUEL_RECORD_NOT_FOUND")
  @ApiResponse(
      responseCode = "422",
      description = "FUEL_PRICE_MISMATCH, ODOMETER_OUT_OF_ORDER, DATE_IN_FUTURE")
  FuelRecordResponse update(
      @CurrentUserId UUID userId,
      @PathVariable UUID vehicleId,
      @PathVariable UUID recordId,
      @Valid @RequestBody FuelRecordRequest request) {
    return fuel.update(userId, vehicleId, recordId, request);
  }

  @DeleteMapping("/{recordId}")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  @Operation(summary = "Delete a fill-up and its odometer reading")
  @ApiResponse(responseCode = "204", description = "Deleted")
  @ApiResponse(responseCode = "404", description = "VEHICLE_NOT_FOUND, FUEL_RECORD_NOT_FOUND")
  void delete(
      @CurrentUserId UUID userId, @PathVariable UUID vehicleId, @PathVariable UUID recordId) {
    fuel.delete(userId, vehicleId, recordId);
  }
}
