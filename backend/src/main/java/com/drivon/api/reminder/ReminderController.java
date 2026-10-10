package com.drivon.api.reminder;

import com.drivon.api.common.security.CurrentUserId;
import com.drivon.api.common.web.CreateResult;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import org.jspecify.annotations.Nullable;
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
@RequestMapping("/api/v1")
@Tag(
    name = "Reminders",
    description =
        "Date and mileage reminders: from service records (next service), documents (expiry) and"
            + " the user's own")
class ReminderController {

  private static final String REMINDERS = "/vehicles/{vehicleId}/reminders";

  private final ReminderService reminders;

  ReminderController(ReminderService reminders) {
    this.reminders = reminders;
  }

  @GetMapping("/reminders")
  @Operation(
      summary = "The user's reminders across vehicles, most urgent first",
      description =
          "Overdue first, then due soon, then upcoming. Not paginated: a vehicle has at most one"
              + " reminder per service and document type plus 50 of the user's own.")
  @ApiResponse(responseCode = "200", description = "The reminders")
  @ApiResponse(responseCode = "400", description = "MALFORMED_REQUEST (unknown status)")
  List<ReminderResponse> listAll(
      @CurrentUserId UUID userId,
      @Parameter(description = "Only reminders with this status") @RequestParam(required = false)
          @Nullable ReminderStatus status) {
    return reminders.list(userId, null, status);
  }

  @GetMapping(REMINDERS)
  @Operation(summary = "A vehicle's reminders, most urgent first")
  @ApiResponse(responseCode = "200", description = "The reminders")
  @ApiResponse(responseCode = "404", description = "VEHICLE_NOT_FOUND")
  List<ReminderResponse> list(
      @CurrentUserId UUID userId,
      @PathVariable UUID vehicleId,
      @Parameter(description = "Only reminders with this status") @RequestParam(required = false)
          @Nullable ReminderStatus status) {
    return reminders.list(userId, vehicleId, status);
  }

  @GetMapping(REMINDERS + "/{reminderId}")
  @Operation(summary = "Get one reminder")
  @ApiResponse(responseCode = "404", description = "VEHICLE_NOT_FOUND, REMINDER_NOT_FOUND")
  ReminderResponse get(
      @CurrentUserId UUID userId, @PathVariable UUID vehicleId, @PathVariable UUID reminderId) {
    return reminders.get(userId, vehicleId, reminderId);
  }

  @PostMapping(REMINDERS)
  @Operation(
      summary = "Add your own reminder",
      description =
          "Due on a date, at a mileage or at whichever comes first. Send an app-generated `id` to"
              + " make retries return the saved reminder (200).")
  @ApiResponse(responseCode = "201", description = "Created; Location points to the reminder")
  @ApiResponse(responseCode = "200", description = "Already saved earlier with this ID")
  @ApiResponse(responseCode = "400", description = "VALIDATION_FAILED")
  @ApiResponse(responseCode = "404", description = "VEHICLE_NOT_FOUND")
  @ApiResponse(responseCode = "409", description = "RECORD_ID_CONFLICT")
  @ApiResponse(
      responseCode = "422",
      description =
          "REMINDER_DUE_MISSING, REMINDER_DATE_PAST, REMINDER_KM_PAST (with minKm),"
              + " REMINDER_LIMIT_REACHED")
  ResponseEntity<ReminderResponse> create(
      @CurrentUserId UUID userId,
      @PathVariable UUID vehicleId,
      @Valid @RequestBody ReminderRequest request) {
    CreateResult<ReminderResponse> result = reminders.create(userId, vehicleId, request);
    return result.toResponse(result.record().id());
  }

  @PutMapping(REMINDERS + "/{reminderId}")
  @Operation(
      summary = "Replace one of your own reminders",
      description = "Service and document reminders change with their records instead.")
  @ApiResponse(responseCode = "200", description = "Updated reminder")
  @ApiResponse(responseCode = "404", description = "VEHICLE_NOT_FOUND, REMINDER_NOT_FOUND")
  @ApiResponse(
      responseCode = "422",
      description =
          "REMINDER_READ_ONLY, REMINDER_DUE_MISSING, REMINDER_DATE_PAST, REMINDER_KM_PAST")
  ReminderResponse update(
      @CurrentUserId UUID userId,
      @PathVariable UUID vehicleId,
      @PathVariable UUID reminderId,
      @Valid @RequestBody ReminderRequest request) {
    return reminders.update(userId, vehicleId, reminderId, request);
  }

  @DeleteMapping(REMINDERS + "/{reminderId}")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  @Operation(summary = "Delete one of your own reminders")
  @ApiResponse(responseCode = "204", description = "Deleted")
  @ApiResponse(responseCode = "404", description = "VEHICLE_NOT_FOUND, REMINDER_NOT_FOUND")
  @ApiResponse(responseCode = "422", description = "REMINDER_READ_ONLY")
  void delete(
      @CurrentUserId UUID userId, @PathVariable UUID vehicleId, @PathVariable UUID reminderId) {
    reminders.delete(userId, vehicleId, reminderId);
  }
}
