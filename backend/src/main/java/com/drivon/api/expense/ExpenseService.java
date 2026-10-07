package com.drivon.api.expense;

import com.drivon.api.common.error.DrivonException;
import com.drivon.api.common.error.ErrorCode;
import com.drivon.api.common.time.BusinessCalendar;
import com.drivon.api.common.web.CreateResult;
import com.drivon.api.common.web.PageResponse;
import com.drivon.api.common.web.SortOptions;
import com.drivon.api.expense.Expense.ExpenseDetails;
import com.drivon.api.vehicle.VehicleService;
import java.math.RoundingMode;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import org.jspecify.annotations.Nullable;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.domain.Sort.Direction;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Expenses for the signed-in user's vehicles. Every method checks that the vehicle belongs to the
 * user; an expense under someone else's vehicle is reported as not found.
 */
@Service
public class ExpenseService {

  static final SortOptions SORT =
      new SortOptions(
          Map.of("date", "date", "amount", "amount"),
          Sort.by(Direction.DESC, "date"),
          Sort.by(Direction.DESC, "createdAt"));

  private final ExpenseRepository expenses;
  private final VehicleService vehicles;
  private final BusinessCalendar calendar;

  ExpenseService(ExpenseRepository expenses, VehicleService vehicles, BusinessCalendar calendar) {
    this.expenses = expenses;
    this.vehicles = vehicles;
    this.calendar = calendar;
  }

  /** Newest first, optionally only one category. */
  @Transactional(readOnly = true)
  public PageResponse<ExpenseResponse> list(
      UUID userId, UUID vehicleId, @Nullable ExpenseCategory category, Pageable pageable) {
    vehicles.requireOwned(userId, vehicleId);
    Pageable page = SORT.apply(pageable);
    Page<Expense> found =
        category == null
            ? expenses.findByVehicleId(vehicleId, page)
            : expenses.findByVehicleIdAndCategory(vehicleId, category, page);
    return PageResponse.of(found, ExpenseResponse::from);
  }

  @Transactional(readOnly = true)
  public ExpenseResponse get(UUID userId, UUID vehicleId, UUID expenseId) {
    vehicles.requireOwned(userId, vehicleId);
    return ExpenseResponse.from(find(vehicleId, expenseId));
  }

  /** Logs an expense. Resending an ID already saved for this vehicle returns that expense. */
  @Transactional
  public CreateResult<ExpenseResponse> create(UUID userId, UUID vehicleId, ExpenseRequest request) {
    vehicles.requireOwned(userId, vehicleId);
    Optional<Expense> earlier =
        request.id() == null ? Optional.empty() : expenses.findById(request.id());
    if (earlier.isPresent()) {
      if (!earlier.get().getVehicleId().equals(vehicleId)) {
        throw new DrivonException(
            ErrorCode.RECORD_ID_CONFLICT, "This ID is already used by another record.");
      }
      return new CreateResult<>(ExpenseResponse.from(earlier.get()), false);
    }
    Expense expense = new Expense(request.id(), vehicleId, validate(request));
    return new CreateResult<>(ExpenseResponse.from(expenses.saveAndFlush(expense)), true);
  }

  @Transactional
  public ExpenseResponse update(
      UUID userId, UUID vehicleId, UUID expenseId, ExpenseRequest request) {
    vehicles.requireOwned(userId, vehicleId);
    Expense expense = find(vehicleId, expenseId);
    expense.update(validate(request));
    return ExpenseResponse.from(expenses.saveAndFlush(expense));
  }

  @Transactional
  public void delete(UUID userId, UUID vehicleId, UUID expenseId) {
    vehicles.requireOwned(userId, vehicleId);
    expenses.delete(find(vehicleId, expenseId));
  }

  private ExpenseDetails validate(ExpenseRequest request) {
    calendar.requireNotFuture(request.date());
    String notes = request.notes();
    return new ExpenseDetails(
        request.category(),
        request.amount().setScale(2, RoundingMode.HALF_UP),
        request.date(),
        notes == null || notes.isBlank() ? null : notes.strip());
  }

  private Expense find(UUID vehicleId, UUID expenseId) {
    return expenses
        .findByIdAndVehicleId(expenseId, vehicleId)
        .orElseThrow(() -> new DrivonException(ErrorCode.EXPENSE_NOT_FOUND));
  }
}
