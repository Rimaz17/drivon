package com.drivon.api.expense;

import static org.assertj.core.api.Assertions.assertThat;

import com.drivon.api.common.stats.MonthlySum;
import com.drivon.api.expense.Expense.ExpenseDetails;
import com.drivon.api.support.ApiClient;
import com.drivon.api.support.IntegrationTest;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.web.servlet.assertj.MockMvcTester;

/** Runs the hand-written queries against Postgres. */
@IntegrationTest
class ExpenseRepositoryTest {

  @Autowired private MockMvcTester mvc;
  @Autowired private ExpenseRepository repository;

  private UUID vehicleId;

  @BeforeEach
  void setUp() {
    ApiClient api = new ApiClient(mvc);
    vehicleId = UUID.fromString(api.createVehicle(api.register(), "CAB-1234", 0));
  }

  private void save(ExpenseCategory category, LocalDate date, String amount) {
    repository.saveAndFlush(
        new Expense(
            null, vehicleId, new ExpenseDetails(category, new BigDecimal(amount), date, null)));
  }

  @Test
  void sumsByCategoryWithinAnInclusiveRange() {
    save(ExpenseCategory.PARKING, LocalDate.of(2026, 9, 1), "200.00");
    save(ExpenseCategory.PARKING, LocalDate.of(2026, 9, 30), "150.50");
    save(ExpenseCategory.INSURANCE, LocalDate.of(2026, 9, 15), "45000.00");
    save(ExpenseCategory.PARKING, LocalDate.of(2026, 10, 1), "999.00");

    List<ExpenseRepository.CategorySum> september =
        repository.sumByCategory(vehicleId, LocalDate.of(2026, 9, 1), LocalDate.of(2026, 9, 30));

    assertThat(september).hasSize(2);
    ExpenseRepository.CategorySum parking =
        september.stream()
            .filter(sum -> sum.getCategory() == ExpenseCategory.PARKING)
            .findFirst()
            .orElseThrow();
    assertThat(parking.getAmount()).isEqualByComparingTo("350.50");
    assertThat(parking.getCount()).isEqualTo(2);
  }

  @Test
  void groupsByCalendarMonth() {
    save(ExpenseCategory.TOLLS, LocalDate.of(2026, 9, 30), "300.00");
    save(ExpenseCategory.TOLLS, LocalDate.of(2026, 10, 1), "300.00");
    save(ExpenseCategory.WASHING, LocalDate.of(2026, 10, 5), "1500.00");

    List<MonthlySum> months =
        repository.sumByMonth(vehicleId, LocalDate.of(2026, 1, 1), LocalDate.of(2026, 12, 31));

    assertThat(months)
        .filteredOn(m -> m.yearMonth().equals(YearMonth.of(2026, 10)))
        .singleElement()
        .satisfies(m -> assertThat(m.getTotal()).isEqualByComparingTo("1800.00"));
  }
}
