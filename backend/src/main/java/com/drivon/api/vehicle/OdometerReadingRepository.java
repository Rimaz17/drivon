package com.drivon.api.vehicle;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

/** Readings are always looked up through a vehicle whose ownership was checked first. */
interface OdometerReadingRepository extends JpaRepository<OdometerReading, UUID> {

  Page<OdometerReading> findByVehicleId(UUID vehicleId, Pageable pageable);

  Optional<OdometerReading> findByIdAndVehicleId(UUID id, UUID vehicleId);

  Optional<OdometerReading> findBySourceId(UUID sourceId);

  /** Highest reading dated before {@code date}, ignoring the reading being moved. */
  @Query(
      """
      select max(r.readingKm) from OdometerReading r
      where r.vehicleId = :vehicleId and r.date < :date and r.id <> :excludeId
      """)
  Optional<Integer> findMaxBefore(
      @Param("vehicleId") UUID vehicleId,
      @Param("date") LocalDate date,
      @Param("excludeId") UUID excludeId);

  /** Lowest reading dated after {@code date}, ignoring the reading being moved. */
  @Query(
      """
      select min(r.readingKm) from OdometerReading r
      where r.vehicleId = :vehicleId and r.date > :date and r.id <> :excludeId
      """)
  Optional<Integer> findMinAfter(
      @Param("vehicleId") UUID vehicleId,
      @Param("date") LocalDate date,
      @Param("excludeId") UUID excludeId);

  @Query("select max(r.readingKm) from OdometerReading r where r.vehicleId = :vehicleId")
  Optional<Integer> findMaxReading(@Param("vehicleId") UUID vehicleId);

  /** The odometer at the end of {@code date}: the highest reading dated on or before it. */
  @Query(
      """
      select max(r.readingKm) from OdometerReading r
      where r.vehicleId = :vehicleId and r.date <= :date
      """)
  Optional<Integer> findMaxOnOrBefore(
      @Param("vehicleId") UUID vehicleId, @Param("date") LocalDate date);

  /** The lowest reading dated in an inclusive range. */
  @Query(
      """
      select min(r.readingKm) from OdometerReading r
      where r.vehicleId = :vehicleId and r.date between :from and :to
      """)
  Optional<Integer> findMinBetween(
      @Param("vehicleId") UUID vehicleId, @Param("from") LocalDate from, @Param("to") LocalDate to);

  /** Lowest and highest reading of each month in an inclusive range that has readings. */
  @Query(
      """
      select year(r.date) as year, month(r.date) as month,
             min(r.readingKm) as minKm, max(r.readingKm) as maxKm
      from OdometerReading r
      where r.vehicleId = :vehicleId and r.date between :from and :to
      group by year(r.date), month(r.date)
      """)
  List<MonthReadings> findMonthReadings(
      @Param("vehicleId") UUID vehicleId, @Param("from") LocalDate from, @Param("to") LocalDate to);

  /** Projection of {@link #findMonthReadings}. */
  interface MonthReadings {
    Integer getYear();

    Integer getMonth();

    Integer getMinKm();

    Integer getMaxKm();
  }
}
