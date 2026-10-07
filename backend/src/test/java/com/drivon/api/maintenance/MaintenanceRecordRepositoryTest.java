package com.drivon.api.maintenance;

import static org.assertj.core.api.Assertions.assertThat;

import com.drivon.api.common.stats.MonthlySum;
import com.drivon.api.maintenance.MaintenanceRecord.ServiceDetails;
import com.drivon.api.support.ApiClient;
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
class MaintenanceRecordRepositoryTest {

  @Autowired private MockMvcTester mvc;
  @Autowired private MaintenanceRecordRepository repository;

  private UUID vehicleId;

  @BeforeEach
  void setUp() {
    ApiClient api = new ApiClient(mvc);
    vehicleId = UUID.fromString(api.createVehicle(api.register(), "CAB-1234", 0));
  }

  private MaintenanceRecord save(ServiceType type, LocalDate date, String cost, Integer nextKm) {
    return repository.saveAndFlush(
        new MaintenanceRecord(
            null,
            vehicleId,
            new ServiceDetails(type, date, null, new BigDecimal(cost), null, null, nextKm)));
  }

  @Test
  void findsTheLatestRecordOfEachServiceType() {
    save(ServiceType.OIL_CHANGE, LocalDate.of(2026, 3, 1), "9500.00", 40_000);
    MaintenanceRecord latestOil =
        save(ServiceType.OIL_CHANGE, LocalDate.of(2026, 9, 1), "9800.00", 45_000);
    MaintenanceRecord brakes =
        save(ServiceType.BRAKE_SERVICE, LocalDate.of(2026, 5, 1), "4500.00", null);

    List<MaintenanceRecord> latest = repository.findLatestOfEachType(vehicleId);

    assertThat(latest)
        .extracting(MaintenanceRecord::getId)
        .containsExactlyInAnyOrder(latestOil.getId(), brakes.getId());
  }

  @Test
  void sumsCostsWithinAnInclusiveRangeAndByMonth() {
    save(ServiceType.OIL_CHANGE, LocalDate.of(2026, 8, 31), "1000.00", null);
    save(ServiceType.OIL_CHANGE, LocalDate.of(2026, 9, 1), "9800.00", null);
    save(ServiceType.GENERAL_SERVICE, LocalDate.of(2026, 9, 30), "15250.50", null);

    MaintenanceRecordRepository.Totals september =
        repository.sumBetween(vehicleId, LocalDate.of(2026, 9, 1), LocalDate.of(2026, 9, 30));
    assertThat(september.getAmount()).isEqualByComparingTo("25050.50");
    assertThat(september.getCount()).isEqualTo(2);

    List<MonthlySum> months =
        repository.sumByMonth(vehicleId, LocalDate.of(2026, 1, 1), LocalDate.of(2026, 12, 31));
    assertThat(months)
        .extracting(MonthlySum::yearMonth)
        .containsExactlyInAnyOrder(YearMonth.of(2026, 8), YearMonth.of(2026, 9));
  }

  @Test
  void anEmptyRangeSumsToZero() {
    MaintenanceRecordRepository.Totals none =
        repository.sumBetween(vehicleId, LocalDate.of(2026, 1, 1), LocalDate.of(2026, 1, 31));

    assertThat(none.getAmount()).isEqualByComparingTo(BigDecimal.ZERO);
    assertThat(none.getCount()).isZero();
  }
}
