package com.drivon.api.common.persistence;

import jakarta.persistence.Column;
import jakarta.persistence.Id;
import jakarta.persistence.MappedSuperclass;
import jakarta.persistence.PostLoad;
import jakarta.persistence.PostPersist;
import jakarta.persistence.Transient;
import java.time.Instant;
import java.util.UUID;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;
import org.jspecify.annotations.Nullable;
import org.springframework.data.domain.Persistable;

/**
 * Base for records whose UUID is assigned by the application: either one the client generated (so
 * an offline draft can be retried without creating a duplicate) or a random one.
 *
 * <p>It implements {@link Persistable} so saving a new instance always inserts. Without it, Spring
 * Data would merge, and a client-supplied ID that already exists would update that row instead of
 * failing with a key violation.
 */
@MappedSuperclass
public abstract class AssignedIdEntity implements Persistable<UUID> {

  @Id private UUID id;

  @Transient private boolean isNew = true;

  @CreationTimestamp
  @Column(name = "created_at", nullable = false, updatable = false)
  private Instant createdAt;

  @UpdateTimestamp
  @Column(name = "updated_at", nullable = false)
  private Instant updatedAt;

  protected AssignedIdEntity() {}

  protected AssignedIdEntity(@Nullable UUID id) {
    this.id = id != null ? id : UUID.randomUUID();
  }

  @Override
  public UUID getId() {
    return id;
  }

  @Override
  public boolean isNew() {
    return isNew;
  }

  @PostLoad
  @PostPersist
  void markNotNew() {
    isNew = false;
  }

  public Instant getCreatedAt() {
    return createdAt;
  }

  public Instant getUpdatedAt() {
    return updatedAt;
  }
}
