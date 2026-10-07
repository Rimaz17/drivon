package com.drivon.api.common.web;

import java.util.List;
import java.util.function.Function;
import org.springframework.data.domain.Page;

/**
 * One page of a list endpoint. Used instead of serializing Spring's {@link Page}, so the JSON shape
 * is explicit and stable.
 *
 * @param page zero-based page index
 */
public record PageResponse<T>(
    List<T> content, int page, int size, long totalElements, int totalPages, boolean hasNext) {

  public static <E, T> PageResponse<T> of(Page<E> page, Function<E, T> mapper) {
    return new PageResponse<>(
        page.getContent().stream().map(mapper).toList(),
        page.getNumber(),
        page.getSize(),
        page.getTotalElements(),
        page.getTotalPages(),
        page.hasNext());
  }
}
