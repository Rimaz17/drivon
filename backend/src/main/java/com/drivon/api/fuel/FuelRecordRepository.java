package com.drivon.api.fuel;

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

/** Fill-ups are always looked up through a vehicle whose ownership was checked first. */
interface FuelRecordRepository extends JpaRepository<FuelRecord, UUID> {

  Page<FuelRecord> findByVehicleId(UUID vehicleId, Pageable pageable);

  Optional<FuelRecord> findByIdAndVehicleId(UUID id, UUID vehicleId);

  /** The efficiency inputs of every fill-up, in the order the full-tank method needs. */
  @Query(
      """
      select new com.drivon.api.fuel.FuelFill(
          f.id, f.date, f.odometerKm, f.litres, f.amount, f.fullTank)
      from FuelRecord f
      where f.vehicleId = :vehicleId
      order by f.odometerKm, f.date, f.createdAt
      """)
  List<FuelFill> findFillsInOdometerOrder(@Param("vehicleId") UUID vehicleId);

  @Query(
      """
      select coalesce(sum(f.amount), 0) as amount,
             coalesce(sum(f.litres), 0) as litres,
             count(f) as fillUps
      from FuelRecord f
      where f.vehicleId = :vehicleId and f.date between :from and :to
      """)
  Totals sumBetween(
      @Param("vehicleId") UUID vehicleId, @Param("from") LocalDate from, @Param("to") LocalDate to);

  @Query(
      """
      select year(f.date) as year, month(f.date) as month, sum(f.amount) as total
      from FuelRecord f
      where f.vehicleId = :vehicleId and f.date between :from and :to
      group by year(f.date), month(f.date)
      """)
  List<MonthlySum> sumByMonth(
      @Param("vehicleId") UUID vehicleId, @Param("from") LocalDate from, @Param("to") LocalDate to);

  /** Projection of {@link #sumBetween}. */
  interface Totals {
    BigDecimal getAmount();

    BigDecimal getLitres();

    long getFillUps();
  }
}
