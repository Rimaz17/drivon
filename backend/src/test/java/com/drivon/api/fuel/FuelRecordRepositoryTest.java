package com.drivon.api.fuel;

import static org.assertj.core.api.Assertions.assertThat;

import com.drivon.api.common.stats.MonthlySum;
import com.drivon.api.fuel.FuelRecord.FuelDetails;
import com.drivon.api.support.ApiClient;
import com.drivon.api.support.ApiClient.Session;
import com.drivon.api.support.IntegrationTest;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.web.servlet.assertj.MockMvcTester;

/** Runs the hand-written queries against Postgres. */
@IntegrationTest
class FuelRecordRepositoryTest {

  @Autowired private MockMvcTester mvc;
  @Autowired private FuelRecordRepository repository;

  private UUID vehicleId;

  @BeforeEach
  void setUp() {
    ApiClient api = new ApiClient(mvc);
    Session session = api.register();
    vehicleId = UUID.fromString(api.createVehicle(session, "CAB-1234", 0));
  }

  private FuelRecord save(
      LocalDate date, int odometer, String litres, String amount, boolean full) {
    return repository.saveAndFlush(
        new FuelRecord(
            null,
            vehicleId,
            new FuelDetails(
                date,
                new BigDecimal(litres),
                new BigDecimal(amount),
                new BigDecimal("365.00"),
                odometer,
                full,
                null)));
  }

  @Test
  void loadsFillsInOdometerOrderWhateverTheEntryOrder() {
    FuelRecord later = save(LocalDate.of(2026, 9, 20), 10_450, "30.000", "10950.00", true);
    FuelRecord earlier = save(LocalDate.of(2026, 9, 1), 10_000, "35.500", "12957.50", true);

    List<FuelFill> fills = repository.findFillsInOdometerOrder(vehicleId);

    assertThat(fills).extracting(FuelFill::id).containsExactly(earlier.getId(), later.getId());
    assertThat(fills.get(0).litres()).isEqualByComparingTo("35.5");
    assertThat(fills.get(0).fullTank()).isTrue();
  }

  @Test
  void sumsAmountsLitresAndCountsWithinAnInclusiveRange() {
    save(LocalDate.of(2026, 8, 31), 9_000, "10.000", "3650.00", true);
    save(LocalDate.of(2026, 9, 1), 9_400, "20.000", "7300.00", true);
    save(LocalDate.of(2026, 9, 30), 9_800, "25.250", "9216.25", false);
    save(LocalDate.of(2026, 10, 1), 10_200, "5.000", "1825.00", true);

    FuelRecordRepository.Totals september =
        repository.sumBetween(vehicleId, LocalDate.of(2026, 9, 1), LocalDate.of(2026, 9, 30));

    assertThat(september.getAmount()).isEqualByComparingTo("16516.25");
    assertThat(september.getLitres()).isEqualByComparingTo("45.250");
    assertThat(september.getFillUps()).isEqualTo(2);
  }

  @Test
  void anEmptyRangeSumsToZero() {
    FuelRecordRepository.Totals none =
        repository.sumBetween(vehicleId, LocalDate.of(2026, 1, 1), LocalDate.of(2026, 1, 31));

    assertThat(none.getAmount()).isEqualByComparingTo(BigDecimal.ZERO);
    assertThat(none.getLitres()).isEqualByComparingTo(BigDecimal.ZERO);
    assertThat(none.getFillUps()).isZero();
  }

  @Test
  void groupsSpendByCalendarMonth() {
    save(LocalDate.of(2026, 9, 1), 9_400, "20.000", "7300.00", true);
    save(LocalDate.of(2026, 9, 30), 9_800, "25.250", "9216.25", false);
    save(LocalDate.of(2026, 10, 1), 10_200, "5.000", "1825.00", true);

    List<MonthlySum> months =
        repository.sumByMonth(vehicleId, LocalDate.of(2026, 1, 1), LocalDate.of(2026, 12, 31));

    assertThat(months)
        .extracting(MonthlySum::yearMonth)
        .containsExactlyInAnyOrder(YearMonth.of(2026, 9), YearMonth.of(2026, 10));
    assertThat(months)
        .filteredOn(m -> m.yearMonth().equals(YearMonth.of(2026, 9)))
        .singleElement()
        .satisfies(m -> assertThat(m.getTotal()).isEqualByComparingTo("16516.25"));
  }
}
