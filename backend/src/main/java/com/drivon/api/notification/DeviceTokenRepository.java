package com.drivon.api.notification;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

interface DeviceTokenRepository extends JpaRepository<DeviceToken, UUID> {

  Optional<DeviceToken> findByToken(String token);

  /** The user's tokens, most recently registered first. */
  List<DeviceToken> findByUserIdOrderByRegisteredAtDesc(UUID userId);

  @Modifying
  @Query("delete from DeviceToken d where d.userId = :userId and d.token = :token")
  int deleteByUserIdAndToken(@Param("userId") UUID userId, @Param("token") String token);

  @Modifying
  @Query("delete from DeviceToken d where d.token in :tokens")
  int deleteByTokenIn(@Param("tokens") Collection<String> tokens);
}
