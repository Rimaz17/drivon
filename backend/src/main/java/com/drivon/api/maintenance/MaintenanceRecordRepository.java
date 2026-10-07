package com.drivon.api.maintenance;

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

/** Services are always looked up through a vehicle whose ownership was checked first. */
interface MaintenanceRecordRepository extends JpaRepository<MaintenanceRecord, UUID> {

  Page<MaintenanceRecord> findByVehicleId(UUID vehicleId, Pageable pageable);

  Page<MaintenanceRecord> findByVehicleIdAndServiceType(
      UUID vehicleId, ServiceType serviceType, Pageable pageable);

  Optional<MaintenanceRecord> findByIdAndVehicleId(UUID id, UUID vehicleId);

  /** The most recent record of each service type: the one that says when it's next due. */
  @Query(
      nativeQuery = true,
      value =
          """
          SELECT DISTINCT ON (service_type) *
          FROM maintenance_records
          WHERE vehicle_id = :vehicleId
          ORDER BY service_type, serviced_on DESC, created_at DESC
          """)
  List<MaintenanceRecord> findLatestOfEachType(@Param("vehicleId") UUID vehicleId);

  @Query(
      """
      select coalesce(sum(m.cost), 0) as amount, count(m) as count
      from MaintenanceRecord m
      where m.vehicleId = :vehicleId and m.date between :from and :to
      """)
  Totals sumBetween(
      @Param("vehicleId") UUID vehicleId, @Param("from") LocalDate from, @Param("to") LocalDate to);

  @Query(
      """
      select year(m.date) as year, month(m.date) as month, sum(m.cost) as total
      from MaintenanceRecord m
      where m.vehicleId = :vehicleId and m.date between :from and :to
      group by year(m.date), month(m.date)
      """)
  List<MonthlySum> sumByMonth(
      @Param("vehicleId") UUID vehicleId, @Param("from") LocalDate from, @Param("to") LocalDate to);

  /** Projection of {@link #sumBetween}. */
  interface Totals {
    BigDecimal getAmount();

    long getCount();
  }
}
