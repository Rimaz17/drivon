package com.drivon.api.vehicle;

import static org.assertj.core.api.Assertions.assertThat;

import com.drivon.api.common.time.BusinessCalendar;
import com.drivon.api.support.ApiClient;
import com.drivon.api.support.ApiClient.Session;
import com.drivon.api.support.IntegrationTest;
import com.jayway.jsonpath.JsonPath;
import java.time.LocalDate;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.test.web.servlet.assertj.MockMvcTester;
import org.springframework.test.web.servlet.assertj.MvcTestResult;

@IntegrationTest
class OdometerIntegrationTest {

  private static final LocalDate TODAY = LocalDate.now(BusinessCalendar.ZONE);

  @Autowired private MockMvcTester mvc;
  private ApiClient api;

  @BeforeEach
  void setUp() {
    api = new ApiClient(mvc);
  }

  private static String readingsPath(String vehicleId) {
    return "/api/v1/vehicles/" + vehicleId + "/odometer-readings";
  }

  private static String reading(int km, LocalDate date) {
    return """
        {"readingKm": %d, "date": "%s"}
        """
        .formatted(km, date);
  }

  private String addReading(Session session, String vehicleId, int km, LocalDate date) {
    MvcTestResult result =
        api.postJson(readingsPath(vehicleId), reading(km, date), session.bearer());
    assertThat(result).hasStatus(HttpStatus.CREATED);
    return JsonPath.read(ApiClient.body(result), "$.id");
  }

  private String initialReadingId(Session session, String vehicleId) {
    MvcTestResult list = api.get(readingsPath(vehicleId), session.bearer());
    assertThat(list).hasStatusOk();
    List<String> ids =
        JsonPath.read(ApiClient.body(list), "$.content[?(@.source == 'INITIAL')].id");
    assertThat(ids).hasSize(1);
    return ids.get(0);
  }

  @Test
  void aNewVehicleStartsItsTimelineWithAnInitialReadingForToday() {
    Session session = api.register();
    String vehicleId = api.createVehicle(session, "CAB-1234", 45_000);

    assertThat(api.get(readingsPath(vehicleId), session.bearer()))
        .hasStatusOk()
        .bodyJson()
        .satisfies(
            json -> {
              json.assertThat().extractingPath("$.totalElements").isEqualTo(1);
              json.assertThat().extractingPath("$.content[0].source").isEqualTo("INITIAL");
              json.assertThat().extractingPath("$.content[0].readingKm").isEqualTo(45_000);
              json.assertThat().extractingPath("$.content[0].date").isEqualTo(TODAY.toString());
            });
  }

  @Test
  void readingsMustNotGoBackwardsAcrossDates() {
    Session session = api.register();
    String vehicleId = api.createVehicle(session, "CAB-1234", 45_000);

    // A back-dated reading below today's is fine; one above it is not.
    addReading(session, vehicleId, 44_000, TODAY.minusDays(10));
    assertThat(
            api.postJson(
                readingsPath(vehicleId), reading(45_500, TODAY.minusDays(5)), session.bearer()))
        .hasStatus(HttpStatus.UNPROCESSABLE_CONTENT)
        .bodyJson()
        .satisfies(
            json -> {
              json.assertThat().extractingPath("$.code").isEqualTo("ODOMETER_OUT_OF_ORDER");
              json.assertThat().extractingPath("$.minKm").isEqualTo(44_000);
              json.assertThat().extractingPath("$.maxKm").isEqualTo(45_000);
            });

    // Today, below the earlier reading of 45,000 km is fine (same date), but tomorrow is not.
    assertThat(
            api.postJson(
                readingsPath(vehicleId), reading(46_000, TODAY.plusDays(1)), session.bearer()))
        .hasStatus(HttpStatus.UNPROCESSABLE_CONTENT)
        .bodyJson()
        .extractingPath("$.code")
        .isEqualTo("DATE_IN_FUTURE");
    assertThat(api.odometerOf(session, vehicleId)).isEqualTo(45_000);
  }

  @Test
  void correctingAMistypedInitialReadingLowersTheVehiclesOdometer() {
    Session session = api.register();
    String vehicleId = api.createVehicle(session, "CAB-1234", 450_000);

    // The vehicle form refuses to lower the odometer...
    assertThat(
            api.putJson(
                "/api/v1/vehicles/" + vehicleId,
                """
                {"make": "Toyota", "model": "Aqua", "year": 2018, "registrationNumber": "CAB-1234",
                 "fuelType": "HYBRID", "currentOdometerKm": 45000}
                """,
                session.bearer()))
        .hasStatus(HttpStatus.UNPROCESSABLE_CONTENT)
        .bodyJson()
        .extractingPath("$.code")
        .isEqualTo("ODOMETER_DECREASE");

    // ...the explicit correction does.
    String initialId = initialReadingId(session, vehicleId);
    assertThat(
            api.putJson(
                readingsPath(vehicleId) + "/" + initialId,
                reading(45_000, TODAY),
                session.bearer()))
        .hasStatusOk()
        .bodyJson()
        .extractingPath("$.readingKm")
        .isEqualTo(45_000);
    assertThat(api.odometerOf(session, vehicleId)).isEqualTo(45_000);
  }

  @Test
  void raisingTheOdometerInTheVehicleFormAddsAManualReading() {
    Session session = api.register();
    String vehicleId = api.createVehicle(session, "CAB-1234", 45_000);

    assertThat(
            api.putJson(
                "/api/v1/vehicles/" + vehicleId,
                """
                {"make": "Toyota", "model": "Aqua", "year": 2018, "registrationNumber": "CAB-1234",
                 "fuelType": "HYBRID", "currentOdometerKm": 45250}
                """,
                session.bearer()))
        .hasStatusOk();

    assertThat(api.get(readingsPath(vehicleId) + "?sort=readingKm,desc", session.bearer()))
        .hasStatusOk()
        .bodyJson()
        .satisfies(
            json -> {
              json.assertThat().extractingPath("$.totalElements").isEqualTo(2);
              json.assertThat().extractingPath("$.content[0].source").isEqualTo("MANUAL");
              json.assertThat().extractingPath("$.content[0].readingKm").isEqualTo(45_250);
            });
  }

  @Test
  void deletingTheHighestManualReadingRestoresThePreviousOdometer() {
    Session session = api.register();
    String vehicleId = api.createVehicle(session, "CAB-1234", 45_000);
    String manualId = addReading(session, vehicleId, 45_900, TODAY);
    assertThat(api.odometerOf(session, vehicleId)).isEqualTo(45_900);

    assertThat(api.delete(readingsPath(vehicleId) + "/" + manualId, session.bearer()))
        .hasStatus(HttpStatus.NO_CONTENT);
    assertThat(api.odometerOf(session, vehicleId)).isEqualTo(45_000);

    assertThat(
            api.delete(
                readingsPath(vehicleId) + "/" + initialReadingId(session, vehicleId),
                session.bearer()))
        .hasStatus(HttpStatus.UNPROCESSABLE_CONTENT)
        .bodyJson()
        .extractingPath("$.code")
        .isEqualTo("ODOMETER_READING_LOCKED");
  }

  @Test
  void listsArePagedAndOnlySortableByDocumentedFields() {
    Session session = api.register();
    String vehicleId = api.createVehicle(session, "CAB-1234", 45_000);
    addReading(session, vehicleId, 44_000, TODAY.minusDays(20));
    addReading(session, vehicleId, 44_500, TODAY.minusDays(10));

    assertThat(api.get(readingsPath(vehicleId) + "?size=2", session.bearer()))
        .hasStatusOk()
        .bodyJson()
        .satisfies(
            json -> {
              json.assertThat().extractingPath("$.content.length()").isEqualTo(2);
              json.assertThat().extractingPath("$.content[0].readingKm").isEqualTo(45_000);
              json.assertThat().extractingPath("$.totalElements").isEqualTo(3);
              json.assertThat().extractingPath("$.hasNext").isEqualTo(true);
            });
    assertThat(api.get(readingsPath(vehicleId) + "?sort=date,asc", session.bearer()))
        .hasStatusOk()
        .bodyJson()
        .extractingPath("$.content[0].readingKm")
        .isEqualTo(44_000);
    assertThat(api.get(readingsPath(vehicleId) + "?sort=vehicleId", session.bearer()))
        .hasStatus(HttpStatus.BAD_REQUEST)
        .bodyJson()
        .extractingPath("$.code")
        .isEqualTo("INVALID_SORT");
  }

  @Test
  void usersCanNeverSeeOrChangeAnotherUsersOdometer() {
    Session owner = api.register();
    Session intruder = api.register();
    String vehicleId = api.createVehicle(owner, "CAB-1234", 45_000);
    String initialId = initialReadingId(owner, vehicleId);

    assertThat(api.get(readingsPath(vehicleId), intruder.bearer()))
        .hasStatus(HttpStatus.NOT_FOUND)
        .bodyJson()
        .extractingPath("$.code")
        .isEqualTo("VEHICLE_NOT_FOUND");
    assertThat(api.postJson(readingsPath(vehicleId), reading(46_000, TODAY), intruder.bearer()))
        .hasStatus(HttpStatus.NOT_FOUND);
    assertThat(
            api.putJson(
                readingsPath(vehicleId) + "/" + initialId, reading(1, TODAY), intruder.bearer()))
        .hasStatus(HttpStatus.NOT_FOUND);
    assertThat(api.delete(readingsPath(vehicleId) + "/" + initialId, intruder.bearer()))
        .hasStatus(HttpStatus.NOT_FOUND);

    // A reading ID from another vehicle is not found under the intruder's own vehicle either.
    String intruderVehicle = api.createVehicle(intruder, "HACK-1", 10);
    assertThat(api.get(readingsPath(intruderVehicle) + "/" + initialId, intruder.bearer()))
        .hasStatus(HttpStatus.NOT_FOUND)
        .bodyJson()
        .extractingPath("$.code")
        .isEqualTo("ODOMETER_READING_NOT_FOUND");
    assertThat(api.odometerOf(owner, vehicleId)).isEqualTo(45_000);
  }

  @Test
  void requestsWithoutATokenAreRejected() {
    assertThat(
            mvc.get()
                .uri(readingsPath("00000000-0000-0000-0000-000000000000"))
                .header(HttpHeaders.ACCEPT, "application/json"))
        .hasStatus(HttpStatus.UNAUTHORIZED);
  }
}
