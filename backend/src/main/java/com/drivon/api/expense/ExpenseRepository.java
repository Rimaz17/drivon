package com.drivon.api.expense;

import com.drivon.api.common.stats.MonthlySum;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

/** Expenses are always looked up through a vehicle whose ownership was checked first. */
interface ExpenseRepository extends JpaRepository<Expense, UUID> {

  Page<Expense> findByVehicleId(UUID vehicleId, Pageable pageable);

  Page<Expense> findByVehicleIdAndCategory(
      UUID vehicleId, ExpenseCategory category, Pageable pageable);

  Optional<Expense> findByIdAndVehicleId(UUID id, UUID vehicleId);

  @Query(
      """
      select e.category as category, sum(e.amount) as amount, count(e) as count
      from Expense e
      where e.vehicleId = :vehicleId and e.date between :from and :to
      group by e.category
      """)
  List<CategorySum> sumByCategory(
      @Param("vehicleId") UUID vehicleId, @Param("from") LocalDate from, @Param("to") LocalDate to);

  @Query(
      """
      select year(e.date) as year, month(e.date) as month, sum(e.amount) as total
      from Expense e
      where e.vehicleId = :vehicleId and e.date between :from and :to
      group by year(e.date), month(e.date)
      """)
  List<MonthlySum> sumByMonth(
      @Param("vehicleId") UUID vehicleId, @Param("from") LocalDate from, @Param("to") LocalDate to);

  /** Projection of {@link #sumByCategory}. */
  interface CategorySum {
    ExpenseCategory getCategory();

    BigDecimal getAmount();

    long getCount();
  }
}
