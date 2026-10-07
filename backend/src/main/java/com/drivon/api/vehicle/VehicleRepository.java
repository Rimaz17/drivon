package com.drivon.api.vehicle;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

/** Every query takes the owner's ID, so one user can never load another user's vehicle. */
interface VehicleRepository extends JpaRepository<Vehicle, UUID> {

  List<Vehicle> findAllByUserIdOrderByCreatedAtAsc(UUID userId);

  Optional<Vehicle> findByIdAndUserId(UUID id, UUID userId);

  long countByUserId(UUID userId);

  boolean existsByUserIdAndRegistrationNumber(UUID userId, String registrationNumber);

  boolean existsByUserIdAndRegistrationNumberAndIdNot(
      UUID userId, String registrationNumber, UUID id);
}
