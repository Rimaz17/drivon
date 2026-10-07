package com.drivon.api.expense;

import com.drivon.api.common.stats.MonthlyAmount;
import com.drivon.api.common.stats.MonthlySeries;
import com.drivon.api.common.stats.MonthlySum;
import com.drivon.api.common.stats.SpendTotal;
import com.drivon.api.common.time.BusinessCalendar;
import com.drivon.api.common.time.DateRange;
import com.drivon.api.expense.SpendingSummaryResponse.CategoryTotal;
import com.drivon.api.expense.VehicleSpendingResponse.VehicleTotal;
import com.drivon.api.fuel.FuelService;
import com.drivon.api.maintenance.MaintenanceService;
import com.drivon.api.vehicle.VehicleResponse;
import com.drivon.api.vehicle.VehicleService;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.jspecify.annotations.Nullable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Spending totals across all of a vehicle's costs: fill-ups count as {@code FUEL}, services as
 * {@code MAINTENANCE}, and expenses under their own category. Every total comes from database
 * aggregates. See docs/adr/0009-maintenance-expenses-and-spending.md.
 */
@Service
public class SpendingService {

  private final ExpenseRepository expenses;
  private final FuelService fuel;
  private final MaintenanceService maintenance;
  private final VehicleService vehicles;
  private final BusinessCalendar calendar;

  SpendingService(
      ExpenseRepository expenses,
      FuelService fuel,
      MaintenanceService maintenance,
      VehicleService vehicles,
      BusinessCalendar calendar) {
    this.expenses = expenses;
    this.fuel = fuel;
    this.maintenance = maintenance;
    this.vehicles = vehicles;
    this.calendar = calendar;
  }

  /** Total and per-category spend of a vehicle; open ends mean "from the beginning"/"today". */
  @Transactional(readOnly = true)
  public SpendingSummaryResponse summary(
      UUID userId, UUID vehicleId, @Nullable LocalDate from, @Nullable LocalDate to) {
    vehicles.requireOwned(userId, vehicleId);
    DateRange range = calendar.range(from, to);
    Map<ExpenseCategory, SpendTotal> byCategory = new EnumMap<>(ExpenseCategory.class);
    for (ExpenseCategory category : ExpenseCategory.values()) {
      byCategory.put(category, new SpendTotal(BigDecimal.ZERO, 0));
    }
    for (ExpenseRepository.CategorySum sum :
        expenses.sumByCategory(vehicleId, range.from(), range.to())) {
      byCategory.merge(
          sum.getCategory(), new SpendTotal(sum.getAmount(), sum.getCount()), SpendingService::add);
    }
    byCategory.merge(
        ExpenseCategory.FUEL,
        fuel.spendBetween(vehicleId, range.from(), range.to()),
        SpendingService::add);
    byCategory.merge(
        ExpenseCategory.MAINTENANCE,
        maintenance.spendBetween(vehicleId, range.from(), range.to()),
        SpendingService::add);

    List<CategoryTotal> categories =
        byCategory.entrySet().stream()
            .map(
                entry ->
                    new CategoryTotal(
                        entry.getKey(), money(entry.getValue().amount()), entry.getValue().count()))
            .sorted(
                Comparator.comparing(CategoryTotal::total)
                    .reversed()
                    .thenComparing(CategoryTotal::category))
            .toList();
    BigDecimal total =
        categories.stream().map(CategoryTotal::total).reduce(BigDecimal.ZERO, BigDecimal::add);
    return new SpendingSummaryResponse(range.from(), range.to(), money(total), categories);
  }

  /** Total spend of a vehicle for each of the last {@code months} months, oldest first. */
  @Transactional(readOnly = true)
  public List<MonthlyAmount> monthly(UUID userId, UUID vehicleId, int months) {
    vehicles.requireOwned(userId, vehicleId);
    YearMonth last = calendar.currentMonth();
    LocalDate from = MonthlySeries.firstMonth(last, months).atDay(1);
    LocalDate to = last.atEndOfMonth();
    List<MonthlySum> sums = new ArrayList<>();
    sums.addAll(expenses.sumByMonth(vehicleId, from, to));
    sums.addAll(fuel.spendByMonth(vehicleId, from, to));
    sums.addAll(maintenance.spendByMonth(vehicleId, from, to));
    return MonthlySeries.of(last, months, sums);
  }

  /** What each of the user's vehicles cost in the range, to compare them. */
  @Transactional(readOnly = true)
  public VehicleSpendingResponse byVehicle(
      UUID userId, @Nullable LocalDate from, @Nullable LocalDate to) {
    DateRange range = calendar.range(from, to);
    List<VehicleTotal> totals = new ArrayList<>();
    for (VehicleResponse vehicle : vehicles.list(userId)) {
      BigDecimal total =
          vehicleTotal(vehicle.id(), range.from(), range.to()).setScale(2, RoundingMode.HALF_UP);
      totals.add(
          new VehicleTotal(
              vehicle.id(), vehicle.make(), vehicle.model(), vehicle.registrationNumber(), total));
    }
    BigDecimal total =
        totals.stream().map(VehicleTotal::total).reduce(BigDecimal.ZERO, BigDecimal::add);
    return new VehicleSpendingResponse(range.from(), range.to(), money(total), totals);
  }

  private BigDecimal vehicleTotal(UUID vehicleId, LocalDate from, LocalDate to) {
    BigDecimal expenseTotal =
        expenses.sumByCategory(vehicleId, from, to).stream()
            .map(ExpenseRepository.CategorySum::getAmount)
            .reduce(BigDecimal.ZERO, BigDecimal::add);
    return expenseTotal
        .add(fuel.spendBetween(vehicleId, from, to).amount())
        .add(maintenance.spendBetween(vehicleId, from, to).amount());
  }

  private static SpendTotal add(SpendTotal a, SpendTotal b) {
    return new SpendTotal(a.amount().add(b.amount()), a.count() + b.count());
  }

  private static BigDecimal money(BigDecimal value) {
    return value.setScale(2, RoundingMode.HALF_UP);
  }
}
