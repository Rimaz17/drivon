package com.drivon.api.assistant.tools;

import com.drivon.api.vehicle.VehicleResponse;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;
import org.jspecify.annotations.Nullable;

/**
 * Who a tool call acts for, set by the server for each question. The user ID comes from the access
 * token, never from the model; every service the tools call checks that the vehicle belongs to this
 * user.
 *
 * @param selectedVehicleId the vehicle selected in the app, already checked to be the user's
 * @param vehicles the user's vehicles
 * @param today today in Sri Lanka
 */
public record ToolContext(
    UUID userId,
    @Nullable UUID selectedVehicleId,
    List<VehicleResponse> vehicles,
    LocalDate today) {

  public ToolContext {
    vehicles = List.copyOf(vehicles);
  }

  /**
   * The vehicle a call is about: the one the model named, else the one selected in the app, else
   * the only one.
   */
  public UUID vehicleId(ToolArguments arguments) {
    UUID named = arguments.uuid("vehicleId");
    if (named != null) {
      return named;
    }
    if (selectedVehicleId != null) {
      return selectedVehicleId;
    }
    if (vehicles.size() == 1) {
      return vehicles.get(0).id();
    }
    throw new ToolArgumentException(
        vehicles.isEmpty()
            ? "The user hasn't added a vehicle yet."
            : "The user has several vehicles; pass vehicleId (from listVehicles).");
  }
}
