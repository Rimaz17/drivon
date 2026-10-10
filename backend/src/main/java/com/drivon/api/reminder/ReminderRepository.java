package com.drivon.api.reminder;

import jakarta.persistence.LockModeType;
import java.time.LocalDate;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

/**
 * Reminders are looked up through vehicles whose ownership was checked first, except the pending
 * queries, which serve the notification job and act for each vehicle's owner.
 */
interface ReminderRepository extends JpaRepository<Reminder, UUID> {

  List<Reminder> findByVehicleIdIn(Collection<UUID> vehicleIds);

  List<Reminder> findByVehicleIdAndSource(UUID vehicleId, ReminderSource source);

  Optional<Reminder> findByIdAndVehicleId(UUID id, UUID vehicleId);

  long countByVehicleIdAndSource(UUID vehicleId, ReminderSource source);

  /** Locks the row until the transaction ends, so one stage is never pushed twice. */
  @Lock(LockModeType.PESSIMISTIC_WRITE)
  @Query("select r from Reminder r where r.id = :id")
  Optional<Reminder> findByIdForUpdate(@Param("id") UUID id);

  /**
   * Reminders that may have reached a stage that wasn't pushed yet: due by {@code dateHorizon}, or
   * within {@code kmLead} km of the vehicle's odometer. The caller checks each one exactly.
   */
  @Query(
      """
      select r.id from Reminder r, Vehicle v
      where v.id = r.vehicleId
        and r.notifiedStage <> com.drivon.api.reminder.NotificationStage.DUE
        and (r.dueDate <= :dateHorizon or r.dueKm - v.currentOdometerKm <= :kmLead)
      order by r.createdAt
      """)
  List<UUID> findPendingIds(
      @Param("dateHorizon") LocalDate dateHorizon, @Param("kmLead") int kmLead);

  /** {@link #findPendingIds} for one vehicle. */
  @Query(
      """
      select r.id from Reminder r, Vehicle v
      where v.id = r.vehicleId and v.id = :vehicleId
        and r.notifiedStage <> com.drivon.api.reminder.NotificationStage.DUE
        and (r.dueDate <= :dateHorizon or r.dueKm - v.currentOdometerKm <= :kmLead)
      order by r.createdAt
      """)
  List<UUID> findPendingIdsForVehicle(
      @Param("vehicleId") UUID vehicleId,
      @Param("dateHorizon") LocalDate dateHorizon,
      @Param("kmLead") int kmLead);
}
