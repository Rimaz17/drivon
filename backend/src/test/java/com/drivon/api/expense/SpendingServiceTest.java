package com.drivon.api.expense;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.drivon.api.common.stats.MonthlyAmount;
import com.drivon.api.common.stats.MonthlySum;
import com.drivon.api.common.stats.SpendTotal;
import com.drivon.api.common.time.BusinessCalendar;
import com.drivon.api.expense.SpendingSummaryResponse.CategoryTotal;
import com.drivon.api.fuel.FuelService;
import com.drivon.api.maintenance.MaintenanceService;
import com.drivon.api.vehicle.FuelType;
import com.drivon.api.vehicle.VehicleResponse;
import com.drivon.api.vehicle.VehicleService;
import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.YearMonth;
import java.time.ZoneOffset;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class SpendingServiceTest {

  private static final UUID USER = UUID.randomUUID();
  private static final UUID VEHICLE = UUID.randomUUID();
  private static final LocalDate FROM = LocalDate.of(2026, 1, 1);
  private static final LocalDate TO = LocalDate.of(2026, 10, 7);

  private final ExpenseRepository expenses = mock(ExpenseRepository.class);
  private final FuelService fuel = mock(FuelService.class);
  private final MaintenanceService maintenance = mock(MaintenanceService.class);
  private final VehicleService vehicles = mock(VehicleService.class);
  private final SpendingService service =
      new SpendingService(
          expenses,
          fuel,
          maintenance,
          vehicles,
          new BusinessCalendar(Clock.fixed(Instant.parse("2026-10-07T04:30:00Z"), ZoneOffset.UTC)));

  private static ExpenseRepository.CategorySum categorySum(
      ExpenseCategory category, String amount, long count) {
    return new ExpenseRepository.CategorySum() {
      @Override
      public ExpenseCategory getCategory() {
        return category;
      }

      @Override
      public BigDecimal getAmount() {
        return new BigDecimal(amount);
      }

      @Override
      public long getCount() {
        return count;
      }
    };
  }

  private static MonthlySum monthSum(int month, String total) {
    return new MonthlySum() {
      @Override
      public Integer getYear() {
        return 2026;
      }

      @Override
      public Integer getMonth() {
        return month;
      }

      @Override
      public BigDecimal getTotal() {
        return new BigDecimal(total);
      }
    };
  }

  @BeforeEach
  void setUp() {
    when(expenses.sumByCategory(any(), any(), any())).thenReturn(List.of());
    when(fuel.spendBetween(any(), any(), any())).thenReturn(new SpendTotal(BigDecimal.ZERO, 0));
    when(maintenance.spendBetween(any(), any(), any()))
        .thenReturn(new SpendTotal(BigDecimal.ZERO, 0));
  }

  @Test
  void fillUpsCountAsFuelAndServicesAsMaintenanceAlongsideExpenses() {
    when(expenses.sumByCategory(VEHICLE, FROM, TO))
        .thenReturn(
            List.of(
                categorySum(ExpenseCategory.INSURANCE, "45000.00", 1),
                categorySum(ExpenseCategory.FUEL, "1000.00", 1),
                categorySum(ExpenseCategory.PARKING, "350.50", 2)));
    when(fuel.spendBetween(VEHICLE, FROM, TO))
        .thenReturn(new SpendTotal(new BigDecimal("20075.00"), 3));
    when(maintenance.spendBetween(VEHICLE, FROM, TO))
        .thenReturn(new SpendTotal(new BigDecimal("9800.00"), 1));

    SpendingSummaryResponse summary = service.summary(USER, VEHICLE, FROM, TO);

    verify(vehicles).requireOwned(USER, VEHICLE);
    assertThat(summary.total().toPlainString()).isEqualTo("76225.50");
    assertThat(summary.categories()).hasSize(ExpenseCategory.values().length);
    assertThat(summary.categories())
        .extracting(CategoryTotal::category)
        .startsWith(
            ExpenseCategory.INSURANCE,
            ExpenseCategory.FUEL,
            ExpenseCategory.MAINTENANCE,
            ExpenseCategory.PARKING);
    CategoryTotal fuelTotal = summary.categories().get(1);
    assertThat(fuelTotal.total().toPlainString()).isEqualTo("21075.00");
    assertThat(fuelTotal.count()).isEqualTo(4);
    assertThat(summary.categories().get(7).total().toPlainString()).isEqualTo("0.00");
  }

  @Test
  void anEmptyPeriodHasZeroTotals() {
    SpendingSummaryResponse summary = service.summary(USER, VEHICLE, null, null);

    assertThat(summary.from()).isEqualTo(BusinessCalendar.EARLIEST);
    assertThat(summary.to()).isEqualTo(TO);
    assertThat(summary.total().toPlainString()).isEqualTo("0.00");
    assertThat(summary.categories()).allSatisfy(c -> assertThat(c.count()).isZero());
  }

  @Test
  void monthlyTotalsAddUpAllThreeSources() {
    LocalDate from = LocalDate.of(2026, 9, 1);
    LocalDate to = LocalDate.of(2026, 10, 31);
    when(expenses.sumByMonth(VEHICLE, from, to)).thenReturn(List.of(monthSum(10, "500.00")));
    when(fuel.spendByMonth(VEHICLE, from, to))
        .thenReturn(List.of(monthSum(9, "7300.00"), monthSum(10, "10950.00")));
    when(maintenance.spendByMonth(VEHICLE, from, to)).thenReturn(List.of(monthSum(10, "9800")));

    List<MonthlyAmount> months = service.monthly(USER, VEHICLE, 2);

    assertThat(months)
        .extracting(MonthlyAmount::month)
        .containsExactly(YearMonth.of(2026, 9), YearMonth.of(2026, 10));
    assertThat(months)
        .extracting(m -> m.total().toPlainString())
        .containsExactly("7300.00", "21250.00");
  }

  @Test
  void comparesEachOfTheUsersVehicles() {
    UUID second = UUID.randomUUID();
    Instant now = Instant.parse("2026-10-07T04:30:00Z");
    when(vehicles.list(USER))
        .thenReturn(
            List.of(
                new VehicleResponse(
                    VEHICLE, "Toyota", "Aqua", 2018, "CAB-1234", FuelType.HYBRID, 46_500, now, now),
                new VehicleResponse(
                    second, "Honda", "Dio", 2021, "BGH-4521", FuelType.PETROL, 12_000, now, now)));
    when(fuel.spendBetween(eq(VEHICLE), any(), any()))
        .thenReturn(new SpendTotal(new BigDecimal("20075.00"), 3));
    when(expenses.sumByCategory(eq(second), any(), any()))
        .thenReturn(List.of(categorySum(ExpenseCategory.WASHING, "500.00", 1)));

    VehicleSpendingResponse result = service.byVehicle(USER, null, null);

    assertThat(result.vehicles())
        .extracting(v -> v.total().toPlainString())
        .containsExactly("20075.00", "500.00");
    assertThat(result.vehicles().get(1).registrationNumber()).isEqualTo("BGH-4521");
    assertThat(result.total().toPlainString()).isEqualTo("20575.00");
  }
}
