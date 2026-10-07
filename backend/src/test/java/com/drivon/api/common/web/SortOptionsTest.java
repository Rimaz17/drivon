package com.drivon.api.common.web;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.drivon.api.common.error.DrivonException;
import com.drivon.api.common.error.ErrorCode;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.domain.Sort.Direction;

class SortOptionsTest {

  private final SortOptions options =
      new SortOptions(
          Map.of("date", "filledOn", "amount", "amount"),
          Sort.by(Direction.DESC, "filledOn"),
          Sort.by(Direction.DESC, "createdAt"));

  @Test
  void usesTheDefaultSortWhenNoneIsRequested() {
    Pageable pageable = options.apply(PageRequest.of(2, 20));

    assertThat(pageable.getPageNumber()).isEqualTo(2);
    assertThat(pageable.getSort())
        .isEqualTo(Sort.by(Direction.DESC, "filledOn").and(Sort.by(Direction.DESC, "createdAt")));
  }

  @Test
  void mapsApiFieldNamesToEntityAttributesAndKeepsTheDirection() {
    Pageable pageable = options.apply(PageRequest.of(0, 20, Sort.by(Direction.ASC, "date")));

    assertThat(pageable.getSort())
        .isEqualTo(Sort.by(Direction.ASC, "filledOn").and(Sort.by(Direction.DESC, "createdAt")));
  }

  @Test
  void rejectsFieldsThatAreNotWhitelisted() {
    assertThatThrownBy(
            () -> options.apply(PageRequest.of(0, 20, Sort.by(Direction.ASC, "vehicleId"))))
        .isInstanceOf(DrivonException.class)
        .hasMessageContaining("amount, date")
        .extracting(e -> ((DrivonException) e).code())
        .isEqualTo(ErrorCode.INVALID_SORT);
  }

  @Test
  void capsThePageSize() {
    assertThat(options.apply(PageRequest.of(0, 500)).getPageSize())
        .isEqualTo(SortOptions.MAX_PAGE_SIZE);
  }
}
