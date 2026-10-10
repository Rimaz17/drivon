package com.drivon.api.analytics;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.assertj.core.api.Assertions.tuple;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.drivon.api.common.error.DrivonException;
import com.drivon.api.common.error.ErrorCode;
import com.drivon.api.common.time.BusinessCalendar;
import com.drivon.api.expense.ExpenseCategory;
import com.drivon.api.expense.MonthlyCategoryTotal;
import com.drivon.api.expense.SpendingService;
import com.drivon.api.expense.SpendingSummaryResponse;
import com.drivon.api.expense.SpendingSummaryResponse.CategoryTotal;
import com.drivon.api.fuel.FuelService;
import com.drivon.api.fuel.FuelStatsResponse;
import com.drivon.api.vehicle.FuelType;
import com.drivon.api.vehicle.MonthlyDistance;
import com.drivon.api.vehicle.OdometerService;
import com.drivon.api.vehicle.VehicleResponse;
import com.drivon.api.vehicle.VehicleService;
import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.YearMonth;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;
import org.junit.jupiter.api.Test;

class AnalyticsServiceTest {

  private static final UUID USER = UUID.randomUUID();
  private static final UUID VEHICLE = UUID.randomUUID();
  private static final LocalDate FROM = LocalDate.of(2026, 1, 1);
  private static final LocalDate TO = LocalDate.of(2026, 10, 7);
  private static final Clock CLOCK =
      Clock.fixed(Instant.parse("2026-10-07T04:30:00Z"), ZoneOffset.UTC);

  private final SpendingService spending = mock(SpendingService.class);
  private final FuelService fuel = mock(FuelService.class);
  private final OdometerService odometer = mock(OdometerService.class);
  private final VehicleService vehicles = mock(VehicleService.class);
  private final AnalyticsService service =
      new AnalyticsService(spending, fuel, odometer, vehicles, new BusinessCalendar(CLOCK));

  /** A spending summary with the given amounts; every other category is zero. */
  private static SpendingSummaryResponse summary(Object... categoryAndAmount) {
    List<CategoryTotal> categories =
        Arrays.stream(ExpenseCategory.values())
            .map(category -> new CategoryTotal(category, new BigDecimal("0.00"), 0))
            .collect(Collectors.toCollection(ArrayList::new));
    for (int i = 0; i < categoryAndAmount.length; i += 2) {
      ExpenseCategory category = (ExpenseCategory) categoryAndAmount[i];
      categories.set(
          category.ordinal(),
          new CategoryTotal(category, new BigDecimal((String) categoryAndAmount[i + 1]), 1));
    }
    BigDecimal total =
        categories.stream().map(CategoryTotal::total).reduce(BigDecimal.ZERO, BigDecimal::add);
    return new SpendingSummaryResponse(FROM, TO, total, categories);
  }

  private static FuelStatsResponse fuelStats(String averageKmPerLitre) {
    return new FuelStatsResponse(
        FROM,
        TO,
        BigDecimal.ZERO,
        BigDecimal.ZERO,
        0,
        averageKmPerLitre == null ? null : new BigDecimal(averageKmPerLitre),
        null,
        null,
        null,
        0);
  }

  @Test
  void splitsCostPerKmIntoFuelMaintenanceAndOther() {
    when(spending.summary(USER, VEHICLE, FROM, TO))
        .thenReturn(
            summary(
                ExpenseCategory.FUEL, "18500.00",
                ExpenseCategory.MAINTENANCE, "9800.00",
                ExpenseCategory.REPAIRS, "2000.00",
                ExpenseCategory.INSURANCE, "45000.00",
                ExpenseCategory.PARKING, "200.00"));
    when(odometer.distanceBetween(VEHICLE, FROM, TO)).thenReturn(1_000);

    CostPerKmResponse cost = service.costPerKm(USER, VEHICLE, FROM, TO);

    assertThat(cost.distanceKm()).isEqualTo(1_000);
    assertThat(cost.totalCost().toPlainString()).isEqualTo("75500.00");
    assertThat(cost.costPerKm().toPlainString()).isEqualTo("75.50");
    assertThat(cost.breakdown())
        .containsExactly(
            new GroupCost(CostGroup.FUEL, new BigDecimal("18500.00"), new BigDecimal("18.50")),
            new GroupCost(
                CostGroup.MAINTENANCE, new BigDecimal("11800.00"), new BigDecimal("11.80")),
            new GroupCost(CostGroup.OTHER, new BigDecimal("45200.00"), new BigDecimal("45.20")));
  }

  @Test
  void costPerKmIsUnknownWithoutDistance() {
    when(spending.summary(USER, VEHICLE, FROM, TO))
        .thenReturn(summary(ExpenseCategory.INSURANCE, "45000.00"));
    when(odometer.distanceBetween(VEHICLE, FROM, TO)).thenReturn(0);

    CostPerKmResponse cost = service.costPerKm(USER, VEHICLE, FROM, TO);

    assertThat(cost.totalCost().toPlainString()).isEqualTo("45000.00");
    assertThat(cost.costPerKm()).isNull();
    assertThat(cost.breakdown()).allSatisfy(group -> assertThat(group.costPerKm()).isNull());
  }

  @Test
  void roundsCostPerKmHalfUpToTheCent() {
    assertThat(AnalyticsService.perKm(new BigDecimal("100.00"), 3).toPlainString())
        .isEqualTo("33.33");
    assertThat(AnalyticsService.perKm(new BigDecimal("0.05"), 2).toPlainString()).isEqualTo("0.03");
    assertThat(AnalyticsService.perKm(BigDecimal.ONE, 0)).isNull();
  }

  @Test
  void monthlyCostsCombineGroupsWithEachMonthsDistance() {
    YearMonth october = YearMonth.of(2026, 10);
    YearMonth september = YearMonth.of(2026, 9);
    YearMonth august = YearMonth.of(2026, 8);
    when(spending.monthlyByCategory(VEHICLE, august.atDay(1), october.atEndOfMonth()))
        .thenReturn(
            List.of(
                new MonthlyCategoryTotal(september, ExpenseCategory.FUEL, new BigDecimal("10000")),
                new MonthlyCategoryTotal(september, ExpenseCategory.REPAIRS, new BigDecimal("500")),
                new MonthlyCategoryTotal(
                    september, ExpenseCategory.MAINTENANCE, new BigDecimal("1500")),
                new MonthlyCategoryTotal(
                    october, ExpenseCategory.INSURANCE, new BigDecimal("45000"))));
    when(odometer.distanceByMonth(VEHICLE, october, 3))
        .thenReturn(
            List.of(
                new MonthlyDistance(august, 0),
                new MonthlyDistance(september, 1_000),
                new MonthlyDistance(october, 0)));

    List<MonthlyCostResponse> months = service.monthlyCosts(USER, VEHICLE, 3);

    assertThat(months)
        .containsExactly(
            new MonthlyCostResponse(
                august,
                new BigDecimal("0.00"),
                new BigDecimal("0.00"),
                new BigDecimal("0.00"),
                new BigDecimal("0.00"),
                0,
                null),
            new MonthlyCostResponse(
                september,
                new BigDecimal("10000.00"),
                new BigDecimal("2000.00"),
                new BigDecimal("0.00"),
                new BigDecimal("12000.00"),
                1_000,
                new BigDecimal("12.00")),
            new MonthlyCostResponse(
                october,
                new BigDecimal("0.00"),
                new BigDecimal("0.00"),
                new BigDecimal("45000.00"),
                new BigDecimal("45000.00"),
                0,
                null));
  }

  @Test
  void monthlyCostsOfAnotherUsersVehicleAreNotFound() {
    when(vehicles.requireOwned(USER, VEHICLE))
        .thenThrow(new DrivonException(ErrorCode.VEHICLE_NOT_FOUND));

    assertThatThrownBy(() -> service.monthlyCosts(USER, VEHICLE, 6))
        .extracting(e -> ((DrivonException) e).code())
        .isEqualTo(ErrorCode.VEHICLE_NOT_FOUND);
    verifyNoInteractions(spending, odometer);
  }

  @Test
  void comparesEveryVehicleOverTheSameRange() {
    UUID bike = UUID.randomUUID();
    LocalDate start = LocalDate.of(2026, 1, 1);
    when(vehicles.list(USER))
        .thenReturn(
            List.of(
                vehicle(VEHICLE, "Toyota", "Aqua", "CAB-1234"),
                vehicle(bike, "Honda", "Dio", "BCD-5678")));
    when(spending.summary(USER, VEHICLE, start, TO))
        .thenReturn(summary(ExpenseCategory.FUEL, "32000.00"));
    when(spending.summary(USER, bike, start, TO))
        .thenReturn(summary(ExpenseCategory.FUEL, "8000.00"));
    when(odometer.distanceBetween(VEHICLE, start, TO)).thenReturn(1_000);
    when(odometer.distanceBetween(bike, start, TO)).thenReturn(1_000);
    when(fuel.stats(USER, VEHICLE, start, TO)).thenReturn(fuelStats("18.40"));
    when(fuel.stats(USER, bike, start, TO)).thenReturn(fuelStats(null));

    VehicleComparisonResponse comparison = service.compareVehicles(USER, start, null);

    assertThat(comparison.to()).isEqualTo(TO);
    assertThat(comparison.vehicles())
        .extracting(
            VehicleComparisonResponse.VehicleCost::make,
            cost -> cost.costPerKm().toPlainString(),
            VehicleComparisonResponse.VehicleCost::averageKmPerLitre)
        .containsExactly(
            tuple("Toyota", "32.00", new BigDecimal("18.40")), tuple("Honda", "8.00", null));
  }

  @Test
  void groupsEveryCategory() {
    assertThat(Arrays.stream(ExpenseCategory.values()).map(CostGroup::of))
        .containsExactly(
            CostGroup.FUEL,
            CostGroup.MAINTENANCE,
            CostGroup.MAINTENANCE,
            CostGroup.OTHER,
            CostGroup.OTHER,
            CostGroup.OTHER,
            CostGroup.OTHER,
            CostGroup.OTHER);
  }

  private static VehicleResponse vehicle(UUID id, String make, String model, String plate) {
    Instant now = Instant.parse("2026-01-01T00:00:00Z");
    return new VehicleResponse(id, make, model, 2018, plate, FuelType.PETROL, 46_000, now, now);
  }
}
