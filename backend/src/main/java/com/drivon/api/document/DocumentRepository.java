package com.drivon.api.document;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.jspecify.annotations.Nullable;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

/**
 * Documents are looked up through a vehicle whose ownership was checked first, except {@link
 * #findExpiring}, which joins the vehicles of one user itself.
 */
interface DocumentRepository extends JpaRepository<Document, UUID> {

  @Query(
      """
      select d from Document d
      where d.vehicleId = :vehicleId and d.status = com.drivon.api.document.DocumentStatus.ACTIVE
        and (:type is null or d.type = :type)
      """)
  Page<Document> findActive(
      @Param("vehicleId") UUID vehicleId,
      @Param("type") @Nullable DocumentType type,
      Pageable pageable);

  Optional<Document> findByIdAndVehicleId(UUID id, UUID vehicleId);

  long countByVehicleId(UUID vehicleId);

  /** Uploads that were started before {@code cutoff} and never confirmed. */
  List<Document> findByVehicleIdAndStatusAndCreatedAtBefore(
      UUID vehicleId, DocumentStatus status, Instant cutoff);

  @Query("select d.fileKey from Document d where d.vehicleId = :vehicleId")
  List<String> findFileKeysByVehicleId(@Param("vehicleId") UUID vehicleId);

  /** For each type, the active document with the latest expiry date. */
  @Query(
      nativeQuery = true,
      value =
          """
          SELECT DISTINCT ON (type) *
          FROM documents
          WHERE vehicle_id = :vehicleId AND status = 'ACTIVE' AND expires_on IS NOT NULL
          ORDER BY type, expires_on DESC, created_at DESC
          """)
  List<Document> findLatestExpiryOfEachType(@Param("vehicleId") UUID vehicleId);

  /** The user's active documents expiring on or before {@code until}, soonest first. */
  @Query(
      """
      select d from Document d, Vehicle v
      where v.id = d.vehicleId and v.userId = :userId
        and d.status = com.drivon.api.document.DocumentStatus.ACTIVE and d.expiryDate <= :until
      order by d.expiryDate asc, d.createdAt asc
      """)
  List<Document> findExpiring(@Param("userId") UUID userId, @Param("until") LocalDate until);
}
