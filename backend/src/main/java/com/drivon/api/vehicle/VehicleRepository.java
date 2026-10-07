package com.drivon.api.vehicle;

import jakarta.persistence.LockModeType;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

/** Every query takes the owner's ID, so one user can never load another user's vehicle. */
interface VehicleRepository extends JpaRepository<Vehicle, UUID> {

  List<Vehicle> findAllByUserIdOrderByCreatedAtAsc(UUID userId);

  Optional<Vehicle> findByIdAndUserId(UUID id, UUID userId);

  /** Locks the row until the transaction ends; serializes odometer changes for the vehicle. */
  @Lock(LockModeType.PESSIMISTIC_WRITE)
  @Query("select v from Vehicle v where v.id = :id and v.userId = :userId")
  Optional<Vehicle> findByIdAndUserIdForUpdate(@Param("id") UUID id, @Param("userId") UUID userId);

  long countByUserId(UUID userId);

  boolean existsByUserIdAndRegistrationNumber(UUID userId, String registrationNumber);

  boolean existsByUserIdAndRegistrationNumberAndIdNot(
      UUID userId, String registrationNumber, UUID id);
}
