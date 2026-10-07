package com.drivon.api.expense;

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
class MaintenanceAndSpendingIntegrationTest {

  private static final LocalDate TODAY = LocalDate.now(BusinessCalendar.ZONE);

  @Autowired private MockMvcTester mvc;
  @Autowired private JdbcTemplate jdbc;
  private ApiClient api;

  @BeforeEach
  void setUp() {
    api = new ApiClient(mvc);
  }

  private static String services(String vehicleId) {
    return "/api/v1/vehicles/" + vehicleId + "/maintenance-records";
  }

  private static String expenses(String vehicleId) {
    return "/api/v1/vehicles/" + vehicleId + "/expenses";
  }

  private static String service(
      String type, Integer odometer, String cost, LocalDate nextDate, Integer nextKm) {
    return """
        {"serviceType": "%s", "date": "%s", "odometerKm": %s, "cost": "%s",
         "notes": "Lanka Auto Care", "nextServiceDate": %s, "nextServiceKm": %s}
        """
        .formatted(
            type,
            TODAY,
            odometer,
            cost,
            nextDate == null ? "null" : "\"" + nextDate + "\"",
            nextKm);
  }

  private static String expense(String category, String amount) {
    return """
        {"category": "%s", "amount": "%s", "date": "%s", "notes": "Annual policy"}
        """
        .formatted(category, amount, TODAY);
  }

  private String create(String path, String body, Session session) {
    MvcTestResult result = api.postJson(path, body, session.bearer());
    assertThat(result).hasStatus(HttpStatus.CREATED);
    return JsonPath.read(ApiClient.body(result), "$.id");
  }

  @Test
  void logsServicesAndListsWhatIsDueNext() {
    Session session = api.register();
    String vehicleId = api.createVehicle(session, "CAB-1234", 46_000);

    String oilChange =
        create(
            services(vehicleId),
            service("OIL_CHANGE", 46_500, "9800", TODAY.plusMonths(6), 51_500),
            session);
    create(services(vehicleId), service("BRAKE_SERVICE", null, "4500", null, null), session);
    assertThat(api.odometerOf(session, vehicleId)).isEqualTo(46_500);

    assertThat(api.get(services(vehicleId) + "/upcoming", session.bearer()))
        .hasStatusOk()
        .bodyJson()
        .satisfies(
            json -> {
              json.assertThat().extractingPath("$.length()").isEqualTo(1);
              json.assertThat().extractingPath("$[0].recordId").isEqualTo(oilChange);
              json.assertThat().extractingPath("$[0].kmRemaining").isEqualTo(5_000);
              json.assertThat().extractingPath("$[0].overdue").isEqualTo(false);
              json.assertThat()
                  .extractingPath("$[0].dueDate")
                  .isEqualTo(TODAY.plusMonths(6).toString());
            });
    assertThat(api.get(services(vehicleId) + "?serviceType=BRAKE_SERVICE", session.bearer()))
        .hasStatusOk()
        .bodyJson()
        .satisfies(
            json -> {
              json.assertThat().extractingPath("$.totalElements").isEqualTo(1);
              json.assertThat().extractingPath("$.content[0].cost").isEqualTo("4500.00");
              json.assertThat().extractingPath("$.content[0].odometerKm").isNull();
            });
  }

  @Test
  void rejectsNextServicesThatAreNotAhead() {
    Session session = api.register();
    String vehicleId = api.createVehicle(session, "CAB-1234", 46_000);

    assertThat(
            api.postJson(
                services(vehicleId),
                service("OIL_CHANGE", 46_500, "9800", null, 46_500),
                session.bearer()))
        .hasStatus(HttpStatus.UNPROCESSABLE_CONTENT)
        .bodyJson()
        .satisfies(
            json -> {
              json.assertThat().extractingPath("$.code").isEqualTo("NEXT_SERVICE_KM_INVALID");
              json.assertThat().extractingPath("$.minKm").isEqualTo(46_501);
            });
    assertThat(
            api.postJson(
                services(vehicleId),
                service("OIL_CHANGE", 46_500, "9800", TODAY, null),
                session.bearer()))
        .hasStatus(HttpStatus.UNPROCESSABLE_CONTENT)
        .bodyJson()
        .extractingPath("$.code")
        .isEqualTo("NEXT_SERVICE_DATE_INVALID");
    assertThat(api.odometerOf(session, vehicleId)).isEqualTo(46_000);
  }

  @Test
  void aServicesOdometerFollowsItThroughEditsAndDeletion() {
    Session session = api.register();
    String vehicleId = api.createVehicle(session, "CAB-1234", 46_000);
    String id =
        create(
            services(vehicleId), service("GENERAL_SERVICE", 47_000, "15000", null, null), session);
    assertThat(api.odometerOf(session, vehicleId)).isEqualTo(47_000);

    assertThat(
            api.putJson(
                services(vehicleId) + "/" + id,
                service("GENERAL_SERVICE", null, "15000", null, null),
                session.bearer()))
        .hasStatusOk();
    assertThat(api.odometerOf(session, vehicleId)).isEqualTo(46_000);

    assertThat(
            api.putJson(
                services(vehicleId) + "/" + id,
                service("GENERAL_SERVICE", 46_800, "15000", null, null),
                session.bearer()))
        .hasStatusOk();
    assertThat(api.odometerOf(session, vehicleId)).isEqualTo(46_800);

    assertThat(api.delete(services(vehicleId) + "/" + id, session.bearer()))
        .hasStatus(HttpStatus.NO_CONTENT);
    assertThat(api.odometerOf(session, vehicleId)).isEqualTo(46_000);
  }

  @Test
  void expensesCanBeLoggedFilteredEditedAndDeleted() {
    Session session = api.register();
    String vehicleId = api.createVehicle(session, "CAB-1234", 46_000);
    String insurance = create(expenses(vehicleId), expense("INSURANCE", "45000"), session);
    create(expenses(vehicleId), expense("PARKING", "200"), session);

    assertThat(api.get(expenses(vehicleId) + "?category=PARKING", session.bearer()))
        .hasStatusOk()
        .bodyJson()
        .extractingPath("$.totalElements")
        .isEqualTo(1);
    assertThat(
            api.putJson(
                expenses(vehicleId) + "/" + insurance,
                expense("INSURANCE", "47500.50"),
                session.bearer()))
        .hasStatusOk()
        .bodyJson()
        .extractingPath("$.amount")
        .isEqualTo("47500.50");
    assertThat(api.delete(expenses(vehicleId) + "/" + insurance, session.bearer()))
        .hasStatus(HttpStatus.NO_CONTENT);
    assertThat(api.get(expenses(vehicleId) + "/" + insurance, session.bearer()))
        .hasStatus(HttpStatus.NOT_FOUND)
        .bodyJson()
        .extractingPath("$.code")
        .isEqualTo("EXPENSE_NOT_FOUND");
  }

  @Test
  void spendingAddsFillUpsServicesAndExpenses() {
    Session session = api.register();
    String car = api.createVehicle(session, "CAB-1234", 46_000);
    String bike = api.createVehicle(session, "BGH-4521", 12_000);
    create(
        "/api/v1/vehicles/" + car + "/fuel-records",
        """
        {"date": "%s", "litres": "30", "amount": "10950", "odometerKm": 46200, "fullTank": true}
        """
            .formatted(TODAY),
        session);
    create(services(car), service("OIL_CHANGE", 46_300, "9800", null, null), session);
    create(expenses(car), expense("INSURANCE", "45000"), session);
    create(expenses(car), expense("FUEL", "1000"), session);
    create(expenses(bike), expense("WASHING", "500"), session);

    assertThat(api.get("/api/v1/vehicles/" + car + "/spending", session.bearer()))
        .hasStatusOk()
        .bodyJson()
        .satisfies(
            json -> {
              json.assertThat().extractingPath("$.total").isEqualTo("66750.00");
              json.assertThat().extractingPath("$.categories.length()").isEqualTo(8);
              json.assertThat().extractingPath("$.categories[0].category").isEqualTo("INSURANCE");
              json.assertThat().extractingPath("$.categories[1].category").isEqualTo("FUEL");
              json.assertThat().extractingPath("$.categories[1].total").isEqualTo("11950.00");
              json.assertThat().extractingPath("$.categories[1].count").isEqualTo(2);
              json.assertThat().extractingPath("$.categories[2].category").isEqualTo("MAINTENANCE");
              json.assertThat().extractingPath("$.categories[2].total").isEqualTo("9800.00");
            });
    String lastYear = TODAY.minusYears(1).withDayOfYear(1).toString();
    assertThat(
            api.get(
                "/api/v1/vehicles/" + car + "/spending?from=" + lastYear + "&to=" + lastYear,
                session.bearer()))
        .hasStatusOk()
        .bodyJson()
        .extractingPath("$.total")
        .isEqualTo("0.00");

    assertThat(api.get("/api/v1/vehicles/" + car + "/spending/monthly?months=1", session.bearer()))
        .hasStatusOk()
        .bodyJson()
        .satisfies(
            json -> {
              json.assertThat()
                  .extractingPath("$[0].month")
                  .isEqualTo(YearMonth.from(TODAY).toString());
              json.assertThat().extractingPath("$[0].total").isEqualTo("66750.00");
            });

    assertThat(api.get("/api/v1/spending/vehicles", session.bearer()))
        .hasStatusOk()
        .bodyJson()
        .satisfies(
            json -> {
              json.assertThat().extractingPath("$.total").isEqualTo("67250.00");
              json.assertThat().extractingPath("$.vehicles[0].vehicleId").isEqualTo(car);
              json.assertThat().extractingPath("$.vehicles[0].total").isEqualTo("66750.00");
              json.assertThat().extractingPath("$.vehicles[1].total").isEqualTo("500.00");
            });
  }

  @Test
  void deletingAVehicleDeletesItsServicesAndExpenses() {
    Session session = api.register();
    String vehicleId = api.createVehicle(session, "CAB-1234", 46_000);
    create(services(vehicleId), service("OIL_CHANGE", 46_500, "9800", null, null), session);
    create(expenses(vehicleId), expense("TOLLS", "300"), session);

    assertThat(api.delete("/api/v1/vehicles/" + vehicleId, session.bearer()))
        .hasStatus(HttpStatus.NO_CONTENT);

    UUID id = UUID.fromString(vehicleId);
    assertThat(
            jdbc.queryForObject(
                "select count(*) from maintenance_records where vehicle_id = ?", Integer.class, id))
        .isZero();
    assertThat(
            jdbc.queryForObject(
                "select count(*) from expenses where vehicle_id = ?", Integer.class, id))
        .isZero();
  }

  @Test
  void usersCanNeverSeeOrChangeAnotherUsersServicesExpensesOrSpending() {
    Session owner = api.register();
    Session intruder = api.register();
    String vehicleId = api.createVehicle(owner, "CAB-1234", 46_000);
    String serviceId =
        create(services(vehicleId), service("OIL_CHANGE", 46_500, "9800", null, null), owner);
    String expenseId = create(expenses(vehicleId), expense("INSURANCE", "45000"), owner);
    api.createVehicle(intruder, "HACK-1", 10);

    for (String path :
        new String[] {
          services(vehicleId),
          services(vehicleId) + "/upcoming",
          services(vehicleId) + "/" + serviceId,
          expenses(vehicleId),
          expenses(vehicleId) + "/" + expenseId,
          "/api/v1/vehicles/" + vehicleId + "/spending",
          "/api/v1/vehicles/" + vehicleId + "/spending/monthly"
        }) {
      assertThat(api.get(path, intruder.bearer())).as(path).hasStatus(HttpStatus.NOT_FOUND);
    }
    assertThat(
            api.putJson(
                services(vehicleId) + "/" + serviceId,
                service("OTHER", null, "1", null, null),
                intruder.bearer()))
        .hasStatus(HttpStatus.NOT_FOUND);
    assertThat(api.delete(expenses(vehicleId) + "/" + expenseId, intruder.bearer()))
        .hasStatus(HttpStatus.NOT_FOUND);
    assertThat(api.get("/api/v1/spending/vehicles", intruder.bearer()))
        .hasStatusOk()
        .bodyJson()
        .satisfies(
            json -> {
              json.assertThat().extractingPath("$.vehicles.length()").isEqualTo(1);
              json.assertThat().extractingPath("$.total").isEqualTo("0.00");
            });

    assertThat(api.get(expenses(vehicleId) + "/" + expenseId, owner.bearer()))
        .hasStatusOk()
        .bodyJson()
        .extractingPath("$.amount")
        .isEqualTo("45000.00");
  }
}
