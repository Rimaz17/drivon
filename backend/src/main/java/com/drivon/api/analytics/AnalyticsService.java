package com.drivon.api.analytics;

import com.drivon.api.analytics.VehicleComparisonResponse.VehicleCost;
import com.drivon.api.common.time.BusinessCalendar;
import com.drivon.api.common.time.DateRange;
import com.drivon.api.expense.MonthlyCategoryTotal;
import com.drivon.api.expense.SpendingService;
import com.drivon.api.expense.SpendingSummaryResponse;
import com.drivon.api.expense.SpendingSummaryResponse.CategoryTotal;
import com.drivon.api.fuel.EfficiencyPoint;
import com.drivon.api.fuel.FuelService;
import com.drivon.api.vehicle.MonthlyDistance;
import com.drivon.api.vehicle.OdometerService;
import com.drivon.api.vehicle.VehicleResponse;
import com.drivon.api.vehicle.VehicleService;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.ArrayList;
import java.util.EnumMap;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.jspecify.annotations.Nullable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Running-cost analytics built on the other features: spending totals (fill-ups, services and
 * expenses), the odometer timeline's distance and the full-tank efficiency calculator. It holds no
 * data of its own and repeats none of their rules. See docs/adr/0012-analytics-and-cost-per-km.md.
 */
@Service
public class AnalyticsService {

  private final SpendingService spending;
  private final FuelService fuel;
  private final OdometerService odometer;
  private final VehicleService vehicles;
  private final BusinessCalendar calendar;

  AnalyticsService(
      SpendingService spending,
      FuelService fuel,
      OdometerService odometer,
      VehicleService vehicles,
      BusinessCalendar calendar) {
    this.spending = spending;
    this.fuel = fuel;
    this.odometer = odometer;
    this.vehicles = vehicles;
    this.calendar = calendar;
  }

  /** Total cost per km of a vehicle in a range, split into fuel, maintenance and other. */
  @Transactional(readOnly = true)
  public CostPerKmResponse costPerKm(
      UUID userId, UUID vehicleId, @Nullable LocalDate from, @Nullable LocalDate to) {
    return costPerKm(vehicleId, spending.summary(userId, vehicleId, from, to));
  }

  /**
   * Each of the last {@code months} months up to this one, oldest first: cost by group, distance
   * and cost per km. Months without records are zero.
   */
  @Transactional(readOnly = true)
  public List<MonthlyCostResponse> monthlyCosts(UUID userId, UUID vehicleId, int months) {
    vehicles.requireOwned(userId, vehicleId);
    YearMonth last = calendar.currentMonth();
    YearMonth first = last.minusMonths(months - 1L);
    Map<YearMonth, Map<CostGroup, BigDecimal>> costs = new HashMap<>();
    for (MonthlyCategoryTotal total :
        spending.monthlyByCategory(vehicleId, first.atDay(1), last.atEndOfMonth())) {
      costs
          .computeIfAbsent(total.month(), month -> zeroByGroup())
          .merge(CostGroup.of(total.category()), total.total(), BigDecimal::add);
    }
    List<MonthlyCostResponse> result = new ArrayList<>(months);
    for (MonthlyDistance distance : odometer.distanceByMonth(vehicleId, last, months)) {
      Map<CostGroup, BigDecimal> month = costs.getOrDefault(distance.month(), zeroByGroup());
      BigDecimal total = sum(month);
      result.add(
          new MonthlyCostResponse(
              distance.month(),
              money(month.get(CostGroup.FUEL)),
              money(month.get(CostGroup.MAINTENANCE)),
              money(month.get(CostGroup.OTHER)),
              money(total),
              distance.distanceKm(),
              perKm(total, distance.distanceKm())));
    }
    return result;
  }

  /** km/L of every tank that ended in the range, oldest first. */
  @Transactional(readOnly = true)
  public List<EfficiencyPoint> efficiencyTrend(
      UUID userId, UUID vehicleId, @Nullable LocalDate from, @Nullable LocalDate to) {
    return fuel.efficiencyTrend(userId, vehicleId, from, to);
  }

  /** The user's vehicles side by side: cost per km, its parts and average km/L. */
  @Transactional(readOnly = true)
  public VehicleComparisonResponse compareVehicles(
      UUID userId, @Nullable LocalDate from, @Nullable LocalDate to) {
    DateRange range = calendar.range(from, to);
    List<VehicleCost> costs = new ArrayList<>();
    for (VehicleResponse vehicle : vehicles.list(userId)) {
      CostPerKmResponse cost =
          costPerKm(vehicle.id(), spending.summary(userId, vehicle.id(), range.from(), range.to()));
      costs.add(
          new VehicleCost(
              vehicle.id(),
              vehicle.make(),
              vehicle.model(),
              vehicle.registrationNumber(),
              cost.distanceKm(),
              cost.totalCost(),
              cost.costPerKm(),
              cost.breakdown(),
              fuel.stats(userId, vehicle.id(), range.from(), range.to()).averageKmPerLitre()));
    }
    return new VehicleComparisonResponse(range.from(), range.to(), costs);
  }

  private CostPerKmResponse costPerKm(UUID vehicleId, SpendingSummaryResponse summary) {
    int distance = odometer.distanceBetween(vehicleId, summary.from(), summary.to());
    Map<CostGroup, BigDecimal> totals = zeroByGroup();
    for (CategoryTotal category : summary.categories()) {
      totals.merge(CostGroup.of(category.category()), category.total(), BigDecimal::add);
    }
    List<GroupCost> breakdown =
        totals.entrySet().stream()
            .map(
                entry ->
                    new GroupCost(
                        entry.getKey(), money(entry.getValue()), perKm(entry.getValue(), distance)))
            .toList();
    BigDecimal total = sum(totals);
    return new CostPerKmResponse(
        summary.from(), summary.to(), distance, money(total), perKm(total, distance), breakdown);
  }

  /** Every group at zero, iterated in declaration order (fuel, maintenance, other). */
  private static Map<CostGroup, BigDecimal> zeroByGroup() {
    Map<CostGroup, BigDecimal> totals = new EnumMap<>(CostGroup.class);
    for (CostGroup group : CostGroup.values()) {
      totals.put(group, BigDecimal.ZERO);
    }
    return totals;
  }

  private static BigDecimal sum(Map<CostGroup, BigDecimal> totals) {
    return totals.values().stream().reduce(BigDecimal.ZERO, BigDecimal::add);
  }

  /** Rupees per km to the cent, or null without distance (a cost per zero km means nothing). */
  static @Nullable BigDecimal perKm(BigDecimal amount, int distanceKm) {
    if (distanceKm <= 0) {
      return null;
    }
    return amount.divide(BigDecimal.valueOf(distanceKm), 2, RoundingMode.HALF_UP);
  }

  private static BigDecimal money(BigDecimal value) {
    return value.setScale(2, RoundingMode.HALF_UP);
  }
}
