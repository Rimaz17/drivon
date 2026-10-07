package com.drivon.api.vehicle;

import com.drivon.api.common.security.CurrentUserId;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.net.URI;
import java.util.List;
import java.util.UUID;
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
@RequestMapping("/api/v1/vehicles")
@Tag(name = "Vehicles", description = "The signed-in user's vehicles (at most two)")
class VehicleController {

  private final VehicleService vehicles;

  VehicleController(VehicleService vehicles) {
    this.vehicles = vehicles;
  }

  /** Not paginated: the list is capped at two vehicles by a business rule. */
  @GetMapping
  @Operation(summary = "List vehicles, oldest first")
  List<VehicleResponse> list(@CurrentUserId UUID userId) {
    return vehicles.list(userId);
  }

  @GetMapping("/{vehicleId}")
  @Operation(summary = "Get one vehicle")
  @ApiResponse(responseCode = "200", description = "The vehicle")
  @ApiResponse(responseCode = "404", description = "VEHICLE_NOT_FOUND (also for others' vehicles)")
  VehicleResponse get(@CurrentUserId UUID userId, @PathVariable UUID vehicleId) {
    return vehicles.get(userId, vehicleId);
  }

  @PostMapping
  @Operation(summary = "Add a vehicle")
  @ApiResponse(responseCode = "201", description = "Created; Location points to the vehicle")
  @ApiResponse(responseCode = "400", description = "VALIDATION_FAILED")
  @ApiResponse(responseCode = "409", description = "REGISTRATION_NUMBER_IN_USE")
  @ApiResponse(responseCode = "422", description = "VEHICLE_LIMIT_REACHED, INVALID_MODEL_YEAR")
  ResponseEntity<VehicleResponse> create(
      @CurrentUserId UUID userId, @Valid @RequestBody VehicleRequest request) {
    VehicleResponse created = vehicles.create(userId, request);
    URI location =
        ServletUriComponentsBuilder.fromCurrentRequest()
            .path("/{id}")
            .buildAndExpand(created.id())
            .toUri();
    return ResponseEntity.created(location).body(created);
  }

  @PutMapping("/{vehicleId}")
  @Operation(summary = "Replace a vehicle's details")
  @ApiResponse(responseCode = "200", description = "Updated vehicle")
  @ApiResponse(responseCode = "404", description = "VEHICLE_NOT_FOUND")
  @ApiResponse(responseCode = "409", description = "REGISTRATION_NUMBER_IN_USE")
  @ApiResponse(responseCode = "422", description = "ODOMETER_DECREASE, INVALID_MODEL_YEAR")
  VehicleResponse update(
      @CurrentUserId UUID userId,
      @PathVariable UUID vehicleId,
      @Valid @RequestBody VehicleRequest request) {
    return vehicles.update(userId, vehicleId, request);
  }

  @DeleteMapping("/{vehicleId}")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  @Operation(summary = "Delete a vehicle")
  @ApiResponse(responseCode = "204", description = "Deleted")
  @ApiResponse(responseCode = "404", description = "VEHICLE_NOT_FOUND")
  void delete(@CurrentUserId UUID userId, @PathVariable UUID vehicleId) {
    vehicles.delete(userId, vehicleId);
  }
}
