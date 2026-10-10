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

  /** Fill-ups in an inclusive date range, sorted and limited by {@code pageable}. */
  @Query(
      "select f from FuelRecord f where f.vehicleId = :vehicleId and f.date between :from and :to")
  List<FuelRecord> findBetween(
      @Param("vehicleId") UUID vehicleId,
      @Param("from") LocalDate from,
      @Param("to") LocalDate to,
      Pageable pageable);

  /** What was paid per litre, month by month. */
  @Query(
      """
      select year(f.date) as year, month(f.date) as month,
             sum(f.amount) as amount, sum(f.litres) as litres,
             min(f.pricePerLitre) as lowestPrice, max(f.pricePerLitre) as highestPrice,
             count(f) as fillUps
      from FuelRecord f
      where f.vehicleId = :vehicleId and f.date between :from and :to
      group by year(f.date), month(f.date)
      order by year(f.date), month(f.date)
      """)
  List<MonthlyPrice> priceByMonth(
      @Param("vehicleId") UUID vehicleId, @Param("from") LocalDate from, @Param("to") LocalDate to);

  /**
   * Fill-ups per station, most visited first. Names are compared ignoring case and surrounding
   * spaces, since they are typed by hand.
   */
  @Query(
      """
      select min(trim(f.station)) as station, count(f) as fillUps,
             sum(f.litres) as litres, sum(f.amount) as amount,
             min(f.pricePerLitre) as lowestPrice, max(f.pricePerLitre) as highestPrice,
             max(f.date) as lastVisit
      from FuelRecord f
      where f.vehicleId = :vehicleId and f.date between :from and :to and f.station is not null
      group by lower(trim(f.station))
      order by count(f) desc, max(f.date) desc
      """)
  List<StationSum> sumByStation(
      @Param("vehicleId") UUID vehicleId, @Param("from") LocalDate from, @Param("to") LocalDate to);

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

  /** Projection of {@link #priceByMonth}. */
  interface MonthlyPrice {
    Integer getYear();

    Integer getMonth();

    BigDecimal getAmount();

    BigDecimal getLitres();

    BigDecimal getLowestPrice();

    BigDecimal getHighestPrice();

    long getFillUps();
  }

  /** Projection of {@link #sumByStation}. */
  interface StationSum {
    String getStation();

    long getFillUps();

    BigDecimal getLitres();

    BigDecimal getAmount();

    BigDecimal getLowestPrice();

    BigDecimal getHighestPrice();

    LocalDate getLastVisit();
  }

  /** Projection of {@link #sumBetween}. */
  interface Totals {
    BigDecimal getAmount();

    BigDecimal getLitres();

    long getFillUps();
  }
}
