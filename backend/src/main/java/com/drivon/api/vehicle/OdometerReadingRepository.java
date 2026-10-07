package com.drivon.api.vehicle;

import java.time.LocalDate;
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
}
