package com.drivon.api.expense;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.drivon.api.common.error.DrivonException;
import com.drivon.api.common.error.ErrorCode;
import com.drivon.api.common.time.BusinessCalendar;
import com.drivon.api.common.web.CreateResult;
import com.drivon.api.expense.Expense.ExpenseDetails;
import com.drivon.api.vehicle.VehicleService;
import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;

class ExpenseServiceTest {

  private static final UUID USER = UUID.randomUUID();
  private static final UUID VEHICLE = UUID.randomUUID();
  private static final LocalDate TODAY = LocalDate.of(2026, 10, 7);

  private final ExpenseRepository expenses = mock(ExpenseRepository.class);
  private final VehicleService vehicles = mock(VehicleService.class);
  private final ExpenseService service =
      new ExpenseService(
          expenses,
          vehicles,
          new BusinessCalendar(Clock.fixed(Instant.parse("2026-10-07T04:30:00Z"), ZoneOffset.UTC)));

  @BeforeEach
  void setUp() {
    when(expenses.saveAndFlush(any())).thenAnswer(i -> i.getArgument(0));
    when(expenses.findById(any())).thenReturn(Optional.empty());
  }

  private static ExpenseRequest request(UUID id, LocalDate date) {
    return new ExpenseRequest(
        id, ExpenseCategory.PARKING, new BigDecimal("200"), date, "  Majestic City  ");
  }

  private static Expense stored(UUID vehicleId) {
    return new Expense(
        null,
        vehicleId,
        new ExpenseDetails(ExpenseCategory.TOLLS, new BigDecimal("300.00"), TODAY, null));
  }

  private static ErrorCode codeOf(Throwable error) {
    return ((DrivonException) error).code();
  }

  @Test
  void logsAnExpenseForTheUsersVehicle() {
    CreateResult<ExpenseResponse> result = service.create(USER, VEHICLE, request(null, TODAY));

    verify(vehicles).requireOwned(USER, VEHICLE);
    assertThat(result.created()).isTrue();
    assertThat(result.record().amount().toPlainString()).isEqualTo("200.00");
    assertThat(result.record().notes()).isEqualTo("Majestic City");
  }

  @Test
  void rejectsFutureExpenses() {
    assertThatThrownBy(() -> service.create(USER, VEHICLE, request(null, TODAY.plusDays(1))))
        .extracting(ExpenseServiceTest::codeOf)
        .isEqualTo(ErrorCode.DATE_IN_FUTURE);
    verify(expenses, never()).saveAndFlush(any());
  }

  @Test
  void aRetriedCreateReturnsTheSavedExpense() {
    Expense existing = stored(VEHICLE);
    when(expenses.findById(existing.getId())).thenReturn(Optional.of(existing));

    CreateResult<ExpenseResponse> retry =
        service.create(USER, VEHICLE, request(existing.getId(), TODAY));

    assertThat(retry.created()).isFalse();
    assertThat(retry.record().category()).isEqualTo(ExpenseCategory.TOLLS);
  }

  @Test
  void anIdUsedUnderAnotherVehicleIsAConflict() {
    Expense elsewhere = stored(UUID.randomUUID());
    when(expenses.findById(elsewhere.getId())).thenReturn(Optional.of(elsewhere));

    assertThatThrownBy(() -> service.create(USER, VEHICLE, request(elsewhere.getId(), TODAY)))
        .extracting(ExpenseServiceTest::codeOf)
        .isEqualTo(ErrorCode.RECORD_ID_CONFLICT);
  }

  @Test
  void updatesAndDeletesOnlyTheVehiclesExpenses() {
    Expense existing = stored(VEHICLE);
    when(expenses.findByIdAndVehicleId(existing.getId(), VEHICLE))
        .thenReturn(Optional.of(existing));

    ExpenseResponse updated =
        service.update(
            USER,
            VEHICLE,
            existing.getId(),
            new ExpenseRequest(null, ExpenseCategory.WASHING, new BigDecimal("1500"), TODAY, ""));
    assertThat(updated.category()).isEqualTo(ExpenseCategory.WASHING);
    assertThat(updated.notes()).isNull();

    service.delete(USER, VEHICLE, existing.getId());
    verify(expenses).delete(existing);

    UUID missing = UUID.randomUUID();
    when(expenses.findByIdAndVehicleId(missing, VEHICLE)).thenReturn(Optional.empty());
    assertThatThrownBy(() -> service.delete(USER, VEHICLE, missing))
        .extracting(ExpenseServiceTest::codeOf)
        .isEqualTo(ErrorCode.EXPENSE_NOT_FOUND);
  }

  @Test
  void listsOneCategoryWhenAsked() {
    when(expenses.findByVehicleIdAndCategory(eq(VEHICLE), eq(ExpenseCategory.PARKING), any()))
        .thenReturn(new PageImpl<>(List.of(), PageRequest.of(0, 20), 0));

    service.list(USER, VEHICLE, ExpenseCategory.PARKING, PageRequest.of(0, 20));

    verify(expenses).findByVehicleIdAndCategory(eq(VEHICLE), eq(ExpenseCategory.PARKING), any());
  }
}
