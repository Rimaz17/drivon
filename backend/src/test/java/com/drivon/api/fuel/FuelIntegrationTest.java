package com.drivon.api.fuel;

import static org.assertj.core.api.Assertions.assertThat;

import com.drivon.api.common.time.BusinessCalendar;
import com.drivon.api.support.ApiClient;
import com.drivon.api.support.ApiClient.Session;
import com.drivon.api.support.IntegrationTest;
import com.jayway.jsonpath.JsonPath;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.assertj.MockMvcTester;
import org.springframework.test.web.servlet.assertj.MvcTestResult;

@IntegrationTest
class FuelIntegrationTest {

  private static final LocalDate TODAY = LocalDate.now(BusinessCalendar.ZONE);

  @Autowired private MockMvcTester mvc;
  @Autowired private JdbcTemplate jdbc;
  private ApiClient api;

  @BeforeEach
  void setUp() {
    api = new ApiClient(mvc);
  }

  private static String path(String vehicleId) {
    return "/api/v1/vehicles/" + vehicleId + "/fuel-records";
  }

  private static String fillUp(
      String id, LocalDate date, int odometer, String litres, String amount, boolean full) {
    return """
        {%s"date": "%s", "litres": "%s", "amount": "%s", "odometerKm": %d,
         "fullTank": %b, "station": "Ceypetco Kollupitiya"}
        """
        .formatted(
            id == null ? "" : "\"id\": \"" + id + "\", ", date, litres, amount, odometer, full);
  }

  private String log(
      Session session, String vehicleId, int odometer, String litres, String amount, boolean full) {
    MvcTestResult result =
        api.postJson(
            path(vehicleId), fillUp(null, TODAY, odometer, litres, amount, full), session.bearer());
    assertThat(result).hasStatus(HttpStatus.CREATED);
    return JsonPath.read(ApiClient.body(result), "$.id");
  }

  @Test
  void logsFillUpsAndCalculatesEfficiencyCostPerKmAndSpend() {
    Session session = api.register();
    String vehicleId = api.createVehicle(session, "CAB-1234", 10_000);

    log(session, vehicleId, 10_000, "30", "10950", true);
    log(session, vehicleId, 10_200, "10", "3650", false);
    assertThat(
            api.postJson(
                path(vehicleId), fillUp(null, TODAY, 10_500, "15", "5475", true), session.bearer()))
        .hasStatus(HttpStatus.CREATED)
        .bodyJson()
        .satisfies(
            json -> {
              // 500 km over the 25 L added after the first full fill.
              json.assertThat().extractingPath("$.kmPerLitre").isEqualTo("20.00");
              json.assertThat().extractingPath("$.pricePerLitre").isEqualTo("365.00");
              json.assertThat().extractingPath("$.litres").isEqualTo("15.000");
            });

    assertThat(api.get(path(vehicleId), session.bearer()))
        .hasStatusOk()
        .bodyJson()
        .satisfies(
            json -> {
              json.assertThat().extractingPath("$.totalElements").isEqualTo(3);
              json.assertThat().extractingPath("$.content[0].odometerKm").isEqualTo(10_500);
              json.assertThat().extractingPath("$.content[0].kmPerLitre").isEqualTo("20.00");
              json.assertThat().extractingPath("$.content[1].kmPerLitre").isNull();
              json.assertThat().extractingPath("$.content[2].kmPerLitre").isNull();
            });

    assertThat(api.get("/api/v1/vehicles/" + vehicleId + "/fuel-stats", session.bearer()))
        .hasStatusOk()
        .bodyJson()
        .satisfies(
            json -> {
              json.assertThat().extractingPath("$.totalSpend").isEqualTo("20075.00");
              json.assertThat().extractingPath("$.totalLitres").isEqualTo("55.000");
              json.assertThat().extractingPath("$.fillUps").isEqualTo(3);
              json.assertThat().extractingPath("$.averageKmPerLitre").isEqualTo("20.00");
              json.assertThat().extractingPath("$.bestKmPerLitre").isEqualTo("20.00");
              json.assertThat().extractingPath("$.latestKmPerLitre").isEqualTo("20.00");
              // Rs. 9,125 of fuel burned over 500 km.
              json.assertThat().extractingPath("$.costPerKm").isEqualTo("18.25");
              json.assertThat().extractingPath("$.trackedDistanceKm").isEqualTo(500);
            });

    assertThat(
            api.get(
                "/api/v1/vehicles/" + vehicleId + "/fuel-stats/monthly?months=2", session.bearer()))
        .hasStatusOk()
        .bodyJson()
        .satisfies(
            json -> {
              json.assertThat().extractingPath("$.length()").isEqualTo(2);
              json.assertThat()
                  .extractingPath("$[1].month")
                  .isEqualTo(YearMonth.from(TODAY).toString());
              json.assertThat().extractingPath("$[1].total").isEqualTo("20075.00");
              json.assertThat().extractingPath("$[0].total").isEqualTo("0.00");
            });

    // Each fill-up is on the odometer timeline, and the vehicle shows the highest reading.
    assertThat(api.odometerOf(session, vehicleId)).isEqualTo(10_500);
    assertThat(
            api.get(
                "/api/v1/vehicles/" + vehicleId + "/odometer-readings?sort=readingKm,desc",
                session.bearer()))
        .bodyJson()
        .satisfies(
            json -> {
              json.assertThat().extractingPath("$.totalElements").isEqualTo(4);
              json.assertThat().extractingPath("$.content[0].source").isEqualTo("FUEL");
            });
  }

  @Test
  void editingAndDeletingAFillUpMovesTheOdometerWithIt() {
    Session session = api.register();
    String vehicleId = api.createVehicle(session, "CAB-1234", 10_000);
    String id = log(session, vehicleId, 10_600, "30", "10950", true);
    assertThat(api.odometerOf(session, vehicleId)).isEqualTo(10_600);

    assertThat(
            api.putJson(
                path(vehicleId) + "/" + id,
                fillUp(null, TODAY, 10_450, "30", "10950", false),
                session.bearer()))
        .hasStatusOk()
        .bodyJson()
        .extractingPath("$.fullTank")
        .isEqualTo(false);
    assertThat(api.odometerOf(session, vehicleId)).isEqualTo(10_450);

    assertThat(api.delete(path(vehicleId) + "/" + id, session.bearer()))
        .hasStatus(HttpStatus.NO_CONTENT);
    assertThat(api.odometerOf(session, vehicleId)).isEqualTo(10_000);
    assertThat(api.get(path(vehicleId) + "/" + id, session.bearer()))
        .hasStatus(HttpStatus.NOT_FOUND)
        .bodyJson()
        .extractingPath("$.code")
        .isEqualTo("FUEL_RECORD_NOT_FOUND");
  }

  @Test
  void aRetriedOfflineDraftIsSavedOnlyOnce() {
    Session session = api.register();
    String vehicleId = api.createVehicle(session, "CAB-1234", 10_000);
    String clientId = UUID.randomUUID().toString();
    String body = fillUp(clientId, TODAY, 10_300, "20", "7300", true);

    assertThat(api.postJson(path(vehicleId), body, session.bearer()))
        .hasStatus(HttpStatus.CREATED)
        .bodyJson()
        .extractingPath("$.id")
        .isEqualTo(clientId);
    assertThat(api.postJson(path(vehicleId), body, session.bearer()))
        .hasStatusOk()
        .bodyJson()
        .extractingPath("$.id")
        .isEqualTo(clientId);
    assertThat(api.get(path(vehicleId), session.bearer()))
        .bodyJson()
        .extractingPath("$.totalElements")
        .isEqualTo(1);
  }

  @Test
  void rejectsInconsistentPricesAndOdometersThatGoBackwards() {
    Session session = api.register();
    String vehicleId = api.createVehicle(session, "CAB-1234", 10_000);

    assertThat(
            api.postJson(
                path(vehicleId),
                """
                {"date": "%s", "litres": "30", "amount": "12000", "pricePerLitre": "365",
                 "odometerKm": 10300, "fullTank": true}
                """
                    .formatted(TODAY),
                session.bearer()))
        .hasStatus(HttpStatus.UNPROCESSABLE_CONTENT)
        .bodyJson()
        .satisfies(
            json -> {
              json.assertThat().extractingPath("$.code").isEqualTo("FUEL_PRICE_MISMATCH");
              json.assertThat().extractingPath("$.expectedAmount").isEqualTo("10950.00");
            });

    // Yesterday's fill-up can't show more than today's 10,000 km.
    assertThat(
            api.postJson(
                path(vehicleId),
                fillUp(null, TODAY.minusDays(1), 10_600, "30", "10950", true),
                session.bearer()))
        .hasStatus(HttpStatus.UNPROCESSABLE_CONTENT)
        .bodyJson()
        .satisfies(
            json -> {
              json.assertThat().extractingPath("$.code").isEqualTo("ODOMETER_OUT_OF_ORDER");
              json.assertThat().extractingPath("$.maxKm").isEqualTo(10_000);
            });
    assertThat(api.get(path(vehicleId), session.bearer()))
        .bodyJson()
        .extractingPath("$.totalElements")
        .isEqualTo(0);
    assertThat(api.odometerOf(session, vehicleId)).isEqualTo(10_000);
  }

  @Test
  void deletingAVehicleDeletesItsFillUpsAndReadings() {
    Session session = api.register();
    String vehicleId = api.createVehicle(session, "CAB-1234", 10_000);
    log(session, vehicleId, 10_300, "20", "7300", true);

    assertThat(api.delete("/api/v1/vehicles/" + vehicleId, session.bearer()))
        .hasStatus(HttpStatus.NO_CONTENT);

    UUID id = UUID.fromString(vehicleId);
    assertThat(
            jdbc.queryForObject(
                "select count(*) from fuel_records where vehicle_id = ?", Integer.class, id))
        .isZero();
    assertThat(
            jdbc.queryForObject(
                "select count(*) from odometer_readings where vehicle_id = ?", Integer.class, id))
        .isZero();
  }

  @Test
  void usersCanNeverSeeOrChangeAnotherUsersFillUps() {
    Session owner = api.register();
    Session intruder = api.register();
    String vehicleId = api.createVehicle(owner, "CAB-1234", 10_000);
    String recordId = log(owner, vehicleId, 10_300, "20", "7300", true);
    String intruderVehicle = api.createVehicle(intruder, "HACK-1", 10_000);

    assertThat(api.get(path(vehicleId), intruder.bearer())).hasStatus(HttpStatus.NOT_FOUND);
    assertThat(api.get(path(vehicleId) + "/" + recordId, intruder.bearer()))
        .hasStatus(HttpStatus.NOT_FOUND);
    assertThat(
            api.putJson(
                path(vehicleId) + "/" + recordId,
                fillUp(null, TODAY, 10_400, "1", "365", true),
                intruder.bearer()))
        .hasStatus(HttpStatus.NOT_FOUND);
    assertThat(api.delete(path(vehicleId) + "/" + recordId, intruder.bearer()))
        .hasStatus(HttpStatus.NOT_FOUND);
    assertThat(api.get("/api/v1/vehicles/" + vehicleId + "/fuel-stats", intruder.bearer()))
        .hasStatus(HttpStatus.NOT_FOUND);
    assertThat(api.get("/api/v1/vehicles/" + vehicleId + "/fuel-stats/monthly", intruder.bearer()))
        .hasStatus(HttpStatus.NOT_FOUND);

    // The record ID can't be read or claimed through the intruder's own vehicle either.
    assertThat(api.get(path(intruderVehicle) + "/" + recordId, intruder.bearer()))
        .hasStatus(HttpStatus.NOT_FOUND)
        .bodyJson()
        .extractingPath("$.code")
        .isEqualTo("FUEL_RECORD_NOT_FOUND");
    assertThat(
            api.postJson(
                path(intruderVehicle),
                fillUp(recordId, TODAY, 10_100, "1", "365", true),
                intruder.bearer()))
        .hasStatus(HttpStatus.CONFLICT)
        .bodyJson()
        .extractingPath("$.code")
        .isEqualTo("RECORD_ID_CONFLICT");

    assertThat(api.get(path(vehicleId) + "/" + recordId, owner.bearer()))
        .hasStatusOk()
        .bodyJson()
        .extractingPath("$.odometerKm")
        .isEqualTo(10_300);
  }
}
