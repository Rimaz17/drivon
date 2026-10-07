package com.drivon.api.common.web;

import com.drivon.api.common.error.DrivonException;
import com.drivon.api.common.error.ErrorCode;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;

/**
 * The sort fields a list endpoint accepts. Clients sort by API field names (e.g. {@code date}),
 * which are mapped to entity attributes here, so unknown or internal attributes are rejected with
 * {@code 400 INVALID_SORT} instead of reaching the database layer.
 *
 * @param fields API field name to entity attribute
 * @param defaultSort used when the request has no {@code sort} parameter
 * @param tieBreaker appended to every sort so paging is deterministic for equal values
 */
public record SortOptions(Map<String, String> fields, Sort defaultSort, Sort tieBreaker) {

  /** Largest page a client can request; bigger sizes are capped to it. */
  public static final int MAX_PAGE_SIZE = 100;

  /** The requested page with its sort translated to entity attributes. */
  public Pageable apply(Pageable requested) {
    List<Sort.Order> orders = new ArrayList<>();
    Sort sort = requested.getSort().isSorted() ? requested.getSort() : null;
    if (sort == null) {
      defaultSort.forEach(orders::add);
    } else {
      for (Sort.Order order : sort) {
        String attribute = fields.get(order.getProperty());
        if (attribute == null) {
          throw new DrivonException(
              ErrorCode.INVALID_SORT,
              "Can't sort by '"
                  + order.getProperty()
                  + "'. Use one of: "
                  + String.join(", ", fields.keySet().stream().sorted().toList())
                  + ".");
        }
        orders.add(order.withProperty(attribute));
      }
    }
    tieBreaker.forEach(orders::add);
    int size = Math.min(requested.getPageSize(), MAX_PAGE_SIZE);
    return PageRequest.of(requested.getPageNumber(), size, Sort.by(orders));
  }
}
