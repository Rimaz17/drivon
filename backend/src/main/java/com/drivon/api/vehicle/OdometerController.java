package com.drivon.api.vehicle;

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
@RequestMapping("/api/v1/vehicles/{vehicleId}/odometer-readings")
@Tag(name = "Odometer", description = "A vehicle's odometer history and corrections")
class OdometerController {

  private final OdometerService odometer;

  OdometerController(OdometerService odometer) {
    this.odometer = odometer;
  }

  @GetMapping
  @Operation(
      summary = "List readings, newest first",
      description = "Sortable by `date` and `readingKm`. Includes fill-up and service readings.")
  @ApiResponse(responseCode = "200", description = "A page of readings")
  @ApiResponse(responseCode = "400", description = "INVALID_SORT")
  @ApiResponse(responseCode = "404", description = "VEHICLE_NOT_FOUND")
  PageResponse<OdometerReadingResponse> list(
      @CurrentUserId UUID userId,
      @PathVariable UUID vehicleId,
      @ParameterObject Pageable pageable) {
    return odometer.list(userId, vehicleId, pageable);
  }

  @GetMapping("/{readingId}")
  @Operation(summary = "Get one reading")
  @ApiResponse(responseCode = "404", description = "VEHICLE_NOT_FOUND, ODOMETER_READING_NOT_FOUND")
  OdometerReadingResponse get(
      @CurrentUserId UUID userId, @PathVariable UUID vehicleId, @PathVariable UUID readingId) {
    return odometer.get(userId, vehicleId, readingId);
  }

  @PostMapping
  @Operation(summary = "Add a manual reading")
  @ApiResponse(responseCode = "201", description = "Created; Location points to the reading")
  @ApiResponse(responseCode = "404", description = "VEHICLE_NOT_FOUND")
  @ApiResponse(
      responseCode = "422",
      description = "ODOMETER_OUT_OF_ORDER (with minKm/maxKm), DATE_IN_FUTURE")
  ResponseEntity<OdometerReadingResponse> add(
      @CurrentUserId UUID userId,
      @PathVariable UUID vehicleId,
      @Valid @RequestBody OdometerReadingRequest request) {
    OdometerReadingResponse created = odometer.add(userId, vehicleId, request);
    URI location =
        ServletUriComponentsBuilder.fromCurrentRequest()
            .path("/{id}")
            .buildAndExpand(created.id())
            .toUri();
    return ResponseEntity.created(location).body(created);
  }

  @PutMapping("/{readingId}")
  @Operation(
      summary = "Correct an initial or manual reading",
      description =
          "The explicit way to fix a mistyped odometer; may lower the vehicle's current odometer."
              + " Fill-up and service readings change through their records.")
  @ApiResponse(responseCode = "200", description = "The corrected reading")
  @ApiResponse(responseCode = "404", description = "VEHICLE_NOT_FOUND, ODOMETER_READING_NOT_FOUND")
  @ApiResponse(
      responseCode = "422",
      description = "ODOMETER_OUT_OF_ORDER, ODOMETER_READING_LOCKED, DATE_IN_FUTURE")
  OdometerReadingResponse correct(
      @CurrentUserId UUID userId,
      @PathVariable UUID vehicleId,
      @PathVariable UUID readingId,
      @Valid @RequestBody OdometerReadingRequest request) {
    return odometer.correct(userId, vehicleId, readingId, request);
  }

  @DeleteMapping("/{readingId}")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  @Operation(summary = "Delete a manual reading")
  @ApiResponse(responseCode = "204", description = "Deleted")
  @ApiResponse(responseCode = "404", description = "VEHICLE_NOT_FOUND, ODOMETER_READING_NOT_FOUND")
  @ApiResponse(responseCode = "422", description = "ODOMETER_READING_LOCKED")
  void delete(
      @CurrentUserId UUID userId, @PathVariable UUID vehicleId, @PathVariable UUID readingId) {
    odometer.delete(userId, vehicleId, readingId);
  }
}
