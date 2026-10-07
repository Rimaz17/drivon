package com.drivon.api.common.web;

import java.net.URI;
import org.springframework.http.ResponseEntity;
import org.springframework.web.servlet.support.ServletUriComponentsBuilder;

/**
 * The outcome of a create that accepts a client-generated ID: the record, and whether it was new or
 * had already been saved by an earlier attempt (an offline retry).
 */
public record CreateResult<T>(T record, boolean created) {

  /**
   * 201 with a {@code Location} of {@code <request URL>/<id>} for a new record, or 200 with the
   * record already saved.
   */
  public ResponseEntity<T> toResponse(Object id) {
    if (!created) {
      return ResponseEntity.ok(record);
    }
    URI location =
        ServletUriComponentsBuilder.fromCurrentRequest().path("/{id}").buildAndExpand(id).toUri();
    return ResponseEntity.created(location).body(record);
  }
}
