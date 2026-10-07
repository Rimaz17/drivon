package com.drivon.api.vehicle;

import static org.assertj.core.api.Assertions.assertThat;

import com.drivon.api.support.IntegrationTest;
import java.time.LocalDate;
import java.util.Map;
import javax.sql.DataSource;
import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;

/** Runs the migrations in a separate schema to check V3's backfill of existing vehicles. */
@IntegrationTest
class OdometerBackfillMigrationTest {

  private static final String SCHEMA = "v3_backfill_check";

  @Autowired private DataSource dataSource;

  private Flyway flyway(String target) {
    return Flyway.configure()
        .dataSource(dataSource)
        .schemas(SCHEMA)
        .locations("classpath:db/migration")
        .cleanDisabled(false)
        .target(target)
        .load();
  }

  @Test
  void existingVehiclesGetAnInitialReadingDatedInSriLanka() {
    flyway("latest").clean();
    flyway("2").migrate();
    JdbcTemplate jdbc = new JdbcTemplate(dataSource);
    jdbc.update(
        "insert into "
            + SCHEMA
            + ".users values ('00000000-0000-0000-0000-000000000001', 'A', 'a@example.com',"
            + " 'hash', now(), now())");
    // 20:00 UTC on 31 Oct is already 1 Nov in Colombo.
    jdbc.update(
        "insert into "
            + SCHEMA
            + ".vehicles values ('00000000-0000-0000-0000-0000000000a1',"
            + " '00000000-0000-0000-0000-000000000001', 'Toyota', 'Aqua', 2018, 'CAB-1234',"
            + " 'HYBRID', 45000, '2026-10-01T08:00:00Z', '2026-10-31T20:00:00Z')");

    flyway("3").migrate();

    Map<String, Object> reading =
        jdbc.queryForMap(
            "select vehicle_id::text as vehicle, reading_km, recorded_on, source, source_id from "
                + SCHEMA
                + ".odometer_readings");
    assertThat(reading)
        .containsEntry("vehicle", "00000000-0000-0000-0000-0000000000a1")
        .containsEntry("reading_km", 45000)
        .containsEntry("source", "INITIAL")
        .containsEntry("source_id", null);
    assertThat(((java.sql.Date) reading.get("recorded_on")).toLocalDate())
        .isEqualTo(LocalDate.of(2026, 11, 1));
    flyway("latest").clean();
  }
}
