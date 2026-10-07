package com.drivon.api.expense;

import com.drivon.api.common.security.CurrentUserId;
import com.drivon.api.common.web.CreateResult;
import com.drivon.api.common.web.PageResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
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
@RequestMapping("/api/v1/vehicles/{vehicleId}/expenses")
@Tag(name = "Expenses", description = "Running costs other than fill-ups and services")
class ExpenseController {

  private final ExpenseService expenses;

  ExpenseController(ExpenseService expenses) {
    this.expenses = expenses;
  }

  @GetMapping
  @Operation(
      summary = "List expenses, newest first",
      description = "Sortable by `date` and `amount`.")
  @ApiResponse(responseCode = "200", description = "A page of expenses")
  @ApiResponse(responseCode = "400", description = "INVALID_SORT, MALFORMED_REQUEST")
  @ApiResponse(responseCode = "404", description = "VEHICLE_NOT_FOUND")
  PageResponse<ExpenseResponse> list(
      @CurrentUserId UUID userId,
      @PathVariable UUID vehicleId,
      @Parameter(description = "Only this category") @RequestParam(required = false)
          @Nullable ExpenseCategory category,
      @ParameterObject Pageable pageable) {
    return expenses.list(userId, vehicleId, category, pageable);
  }

  @GetMapping("/{expenseId}")
  @Operation(summary = "Get one expense")
  @ApiResponse(responseCode = "404", description = "VEHICLE_NOT_FOUND, EXPENSE_NOT_FOUND")
  ExpenseResponse get(
      @CurrentUserId UUID userId, @PathVariable UUID vehicleId, @PathVariable UUID expenseId) {
    return expenses.get(userId, vehicleId, expenseId);
  }

  @PostMapping
  @Operation(
      summary = "Log an expense",
      description = "Send an app-generated `id` to make retries return the saved record (200).")
  @ApiResponse(responseCode = "201", description = "Created; Location points to the expense")
  @ApiResponse(responseCode = "200", description = "Already saved earlier with this ID")
  @ApiResponse(responseCode = "400", description = "VALIDATION_FAILED")
  @ApiResponse(responseCode = "404", description = "VEHICLE_NOT_FOUND")
  @ApiResponse(responseCode = "409", description = "RECORD_ID_CONFLICT")
  @ApiResponse(responseCode = "422", description = "DATE_IN_FUTURE")
  ResponseEntity<ExpenseResponse> create(
      @CurrentUserId UUID userId,
      @PathVariable UUID vehicleId,
      @Valid @RequestBody ExpenseRequest request) {
    CreateResult<ExpenseResponse> result = expenses.create(userId, vehicleId, request);
    return result.toResponse(result.record().id());
  }

  @PutMapping("/{expenseId}")
  @Operation(summary = "Replace an expense")
  @ApiResponse(responseCode = "200", description = "Updated expense")
  @ApiResponse(responseCode = "404", description = "VEHICLE_NOT_FOUND, EXPENSE_NOT_FOUND")
  @ApiResponse(responseCode = "422", description = "DATE_IN_FUTURE")
  ExpenseResponse update(
      @CurrentUserId UUID userId,
      @PathVariable UUID vehicleId,
      @PathVariable UUID expenseId,
      @Valid @RequestBody ExpenseRequest request) {
    return expenses.update(userId, vehicleId, expenseId, request);
  }

  @DeleteMapping("/{expenseId}")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  @Operation(summary = "Delete an expense")
  @ApiResponse(responseCode = "204", description = "Deleted")
  @ApiResponse(responseCode = "404", description = "VEHICLE_NOT_FOUND, EXPENSE_NOT_FOUND")
  void delete(
      @CurrentUserId UUID userId, @PathVariable UUID vehicleId, @PathVariable UUID expenseId) {
    expenses.delete(userId, vehicleId, expenseId);
  }
}
