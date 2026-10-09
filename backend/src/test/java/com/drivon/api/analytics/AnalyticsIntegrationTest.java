package com.drivon.api.analytics;

import static org.assertj.core.api.Assertions.assertThat;

import com.drivon.api.common.time.BusinessCalendar;
import com.drivon.api.support.ApiClient;
import com.drivon.api.support.ApiClient.Session;
import com.drivon.api.support.IntegrationTest;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.test.web.servlet.assertj.MockMvcTester;
import org.springframework.test.web.servlet.assertj.MvcTestResult;

/** Analytics over real fill-ups, services, expenses and odometer readings in Postgres. */
@IntegrationTest
class AnalyticsIntegrationTest {

  private static final LocalDate TODAY = LocalDate.now(BusinessCalendar.ZONE);

  @Autowired private MockMvcTester mvc;
  private ApiClient api;

  @BeforeEach
  void setUp() {
    api = new ApiClient(mvc);
  }

  private void post(Session session, String path, String body) {
    assertThat(api.postJson(path, body, session.bearer())).hasStatus(HttpStatus.CREATED);
  }

  /**
   * A car added today at 46,000 km, driven to 46,800 km: two full fills (the second closes a 500 km
   * tank of 25 L), a service and an insurance payment, all today.
   */
  private String carWithAMonthOfRecords(Session session) {
    String car = api.createVehicle(session, "CAB-3001", 46_000);
    String vehicle = "/api/v1/vehicles/" + car;
    post(
        session,
        vehicle + "/fuel-records",
        """
        {"date": "%s", "litres": "30", "amount": "10950", "odometerKm": 46300, "fullTank": true}
        """
            .formatted(TODAY));
    post(
        session,
        vehicle + "/maintenance-records",
        """
        {"serviceType": "OIL_CHANGE", "date": "%s", "odometerKm": 46500, "cost": "9800"}
        """
            .formatted(TODAY));
    post(
        session,
        vehicle + "/expenses",
        """
        {"category": "INSURANCE", "amount": "45000", "date": "%s"}
        """
            .formatted(TODAY));
    post(
        session,
        vehicle + "/fuel-records",
        """
        {"date": "%s", "litres": "25", "amount": "9125", "odometerKm": 46800, "fullTank": true}
        """
            .formatted(TODAY));
    return car;
  }

  @Test
  void costPerKmDividesEverythingSpentByTheDistanceDriven() {
    Session session = api.register();
    String car = carWithAMonthOfRecords(session);

    MvcTestResult result =
        api.get(
            "/api/v1/vehicles/" + car + "/analytics/cost-per-km?from=" + TODAY.withDayOfMonth(1),
            session.bearer());

    // Rs. 20,075 fuel + 9,800 service + 45,000 insurance over 800 km.
    assertThat(result)
        .hasStatusOk()
        .bodyJson()
        .satisfies(
            json -> {
              json.assertThat().extractingPath("$.distanceKm").isEqualTo(800);
              json.assertThat().extractingPath("$.totalCost").isEqualTo("74875.00");
              json.assertThat().extractingPath("$.costPerKm").isEqualTo("93.59");
              json.assertThat()
                  .extractingPath("$.breakdown[*].group")
                  .isEqualTo(List.of("FUEL", "MAINTENANCE", "OTHER"));
              json.assertThat()
                  .extractingPath("$.breakdown[*].costPerKm")
                  .isEqualTo(List.of("25.09", "12.25", "56.25"));
            });
  }

  @Test
  void monthlyCostsAndTheEfficiencyTrendCoverTheCurrentMonth() {
    Session session = api.register();
    String car = carWithAMonthOfRecords(session);
    String analytics = "/api/v1/vehicles/" + car + "/analytics";

    assertThat(api.get(analytics + "/monthly-costs?months=2", session.bearer()))
        .hasStatusOk()
        .bodyJson()
        .satisfies(
            json -> {
              json.assertThat()
                  .extractingPath("$[*].month")
                  .isEqualTo(
                      List.of(
                          YearMonth.from(TODAY).minusMonths(1).toString(),
                          YearMonth.from(TODAY).toString()));
              json.assertThat().extractingPath("$[0].total").isEqualTo("0.00");
              json.assertThat().extractingPath("$[0].costPerKm").isNull();
              json.assertThat().extractingPath("$[1].fuel").isEqualTo("20075.00");
              json.assertThat().extractingPath("$[1].maintenance").isEqualTo("9800.00");
              json.assertThat().extractingPath("$[1].other").isEqualTo("45000.00");
              json.assertThat().extractingPath("$[1].distanceKm").isEqualTo(800);
              json.assertThat().extractingPath("$[1].costPerKm").isEqualTo("93.59");
            });

    assertThat(api.get(analytics + "/efficiency-trend", session.bearer()))
        .hasStatusOk()
        .bodyJson()
        .satisfies(
            json -> {
              json.assertThat().extractingPath("$.length()").isEqualTo(1);
              json.assertThat().extractingPath("$[0].distanceKm").isEqualTo(500);
              json.assertThat().extractingPath("$[0].kmPerLitre").isEqualTo("20.00");
              json.assertThat().extractingPath("$[0].costPerKm").isEqualTo("18.25");
            });
  }

  @Test
  void comparesTheUsersVehiclesSideBySide() {
    Session session = api.register();
    carWithAMonthOfRecords(session);
    api.createVehicle(session, "BCD-3002", 12_000);

    assertThat(api.get("/api/v1/analytics/vehicle-comparison", session.bearer()))
        .hasStatusOk()
        .bodyJson()
        .satisfies(
            json -> {
              json.assertThat()
                  .extractingPath("$.vehicles[*].registrationNumber")
                  .isEqualTo(List.of("CAB-3001", "BCD-3002"));
              json.assertThat().extractingPath("$.vehicles[0].costPerKm").isEqualTo("93.59");
              json.assertThat()
                  .extractingPath("$.vehicles[0].averageKmPerLitre")
                  .isEqualTo("20.00");
              // Nothing logged and no distance yet.
              json.assertThat().extractingPath("$.vehicles[1].totalCost").isEqualTo("0.00");
              json.assertThat().extractingPath("$.vehicles[1].costPerKm").isNull();
            });
  }

  @Test
  void anotherUsersVehicleAnalyticsAreNotFound() {
    Session owner = api.register();
    String car = carWithAMonthOfRecords(owner);
    Session intruder = api.register();
    String analytics = "/api/v1/vehicles/" + car + "/analytics";

    for (String path :
        List.of(
            analytics + "/cost-per-km",
            analytics + "/monthly-costs",
            analytics + "/efficiency-trend")) {
      assertThat(api.get(path, intruder.bearer()))
          .hasStatus(HttpStatus.NOT_FOUND)
          .bodyJson()
          .extractingPath("$.code")
          .isEqualTo("VEHICLE_NOT_FOUND");
    }
    assertThat(api.get("/api/v1/analytics/vehicle-comparison", intruder.bearer()))
        .hasStatusOk()
        .bodyJson()
        .extractingPath("$.vehicles.length()")
        .isEqualTo(0);
  }
}
