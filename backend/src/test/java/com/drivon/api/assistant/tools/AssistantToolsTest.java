package com.drivon.api.assistant.tools;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.drivon.api.analytics.AnalyticsService;
import com.drivon.api.analytics.MonthlyCostResponse;
import com.drivon.api.assistant.llm.ToolCall;
import com.drivon.api.assistant.llm.ToolSpec;
import com.drivon.api.common.error.DrivonException;
import com.drivon.api.common.error.ErrorCode;
import com.drivon.api.common.time.BusinessCalendar;
import com.drivon.api.common.web.PageResponse;
import com.drivon.api.document.DocumentResponse;
import com.drivon.api.document.DocumentService;
import com.drivon.api.document.DocumentStatus;
import com.drivon.api.document.DocumentType;
import com.drivon.api.expense.ExpenseService;
import com.drivon.api.expense.SpendingService;
import com.drivon.api.expense.SpendingSummaryResponse;
import com.drivon.api.fuel.FuelService;
import com.drivon.api.fuel.FuelStatsResponse;
import com.drivon.api.maintenance.MaintenanceService;
import com.drivon.api.reminder.ReminderService;
import com.drivon.api.reminder.ReminderStatus;
import com.drivon.api.vehicle.FuelType;
import com.drivon.api.vehicle.OdometerService;
import com.drivon.api.vehicle.VehicleResponse;
import com.drivon.api.vehicle.VehicleService;
import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.YearMonth;
import java.time.ZoneOffset;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.Pageable;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;

class AssistantToolsTest {

  private static final UUID USER = UUID.randomUUID();
  private static final UUID CAR = UUID.randomUUID();
  private static final UUID BIKE = UUID.randomUUID();
  private static final LocalDate TODAY = LocalDate.of(2026, 10, 10);
  private static final JsonMapper JSON = JsonMapper.builder().build();

  private final VehicleService vehicles = mock(VehicleService.class);
  private final FuelService fuel = mock(FuelService.class);
  private final SpendingService spending = mock(SpendingService.class);
  private final AnalyticsService analytics = mock(AnalyticsService.class);
  private final DocumentService documents = mock(DocumentService.class);
  private final ReminderService reminders = mock(ReminderService.class);
  private final AssistantTools tools =
      new AssistantTools(
          JSON,
          vehicles,
          mock(OdometerService.class),
          fuel,
          mock(MaintenanceService.class),
          mock(ExpenseService.class),
          spending,
          analytics,
          documents,
          reminders,
          new BusinessCalendar(Clock.fixed(Instant.parse("2026-10-10T04:30:00Z"), ZoneOffset.UTC)));

  private static final List<VehicleResponse> TWO_VEHICLES =
      List.of(vehicle(CAR, "Toyota", "Aqua"), vehicle(BIKE, "Honda", "Dio"));

  private static VehicleResponse vehicle(UUID id, String make, String model) {
    return new VehicleResponse(
        id, make, model, 2018, "CAB-1234", FuelType.PETROL, 45_000, Instant.EPOCH, Instant.EPOCH);
  }

  private static ToolContext context(UUID selected) {
    return new ToolContext(USER, selected, TWO_VEHICLES, TODAY);
  }

  private JsonNode run(String tool, String arguments, ToolContext context) {
    return JSON.readTree(
        tools.execute(new ToolCall("c1", tool, JSON.readTree(arguments)), context));
  }

  private static FuelStatsResponse stats() {
    return new FuelStatsResponse(
        LocalDate.of(2026, 9, 1),
        LocalDate.of(2026, 9, 30),
        new BigDecimal("18500.00"),
        new BigDecimal("42.000"),
        3,
        new BigDecimal("17.40"),
        null,
        null,
        null,
        0);
  }

  @Test
  void offersTheTwentyToolsFromTheOverview() {
    List<ToolSpec> specs = tools.specs();

    assertThat(specs)
        .extracting(ToolSpec::name)
        .containsExactly(
            "listVehicles",
            "getVehicleDetails",
            "getOdometerStats",
            "getFuelExpenses",
            "getFuelHistory",
            "getFuelEfficiency",
            "getFuelPriceTrend",
            "getFuelStationStats",
            "getMaintenanceHistory",
            "getLastService",
            "getUpcomingMaintenance",
            "getVehicleExpenses",
            "getExpensesByCategory",
            "getSpendingSummary",
            "getMonthlyTrend",
            "getCostPerKilometre",
            "compareVehicles",
            "getDocumentStatus",
            "getExpiringDocuments",
            "getReminders");
    for (ToolSpec spec : specs) {
      assertThat(spec.description()).isNotBlank();
      assertThat(spec.parameters().path("type").asString()).isEqualTo("object");
      // The user is never a parameter: the server sets it.
      assertThat(spec.parameters().path("properties").has("userId")).isFalse();
    }
  }

  @Test
  void usesTheVehicleSelectedInTheAppAndTheSignedInUser() {
    when(fuel.stats(eq(USER), eq(BIKE), any(), any())).thenReturn(stats());

    JsonNode result =
        run(
            "getFuelExpenses",
            "{\"from\": \"2026-09-01\", \"to\": \"2026-09-30\", \"userId\": \"x\"}",
            context(BIKE));

    // The app's mapper writes decimals as strings; this plain one writes numbers.
    assertThat(result.path("totalSpend").decimalValue()).isEqualByComparingTo("18500");
    verify(fuel).stats(USER, BIKE, LocalDate.of(2026, 9, 1), LocalDate.of(2026, 9, 30));
  }

  @Test
  void spendDefaultsToThisMonth() {
    when(fuel.stats(eq(USER), eq(CAR), any(), any())).thenReturn(stats());

    run("getFuelExpenses", "{}", context(CAR));

    verify(fuel).stats(USER, CAR, LocalDate.of(2026, 10, 1), null);
  }

  @Test
  void withSeveralVehiclesAndNoneChosenTheModelIsToldToPickOne() {
    JsonNode result = run("getFuelExpenses", "{}", context(null));

    assertThat(result.path("error").asString()).contains("several vehicles");
  }

  @Test
  void badArgumentsAreExplainedToTheModel() {
    assertThat(
            run("getFuelExpenses", "{\"from\": \"September\"}", context(CAR))
                .path("error")
                .asString())
        .contains("YYYY-MM-DD");
    assertThat(
            run("getFuelExpenses", "{\"vehicleId\": \"car\"}", context(CAR))
                .path("error")
                .asString())
        .contains("listVehicles");
    assertThat(run("getFuelHistory", "{\"limit\": 500}", context(CAR)).path("error").asString())
        .contains("1 to 50");
    assertThat(
            run("getSpendingSummary", "{\"period\": \"FOREVER\"}", context(CAR))
                .path("error")
                .asString())
        .contains("THIS_MONTH");
    assertThat(run("noSuchTool", "{}", context(CAR)).path("error").asString())
        .contains("noSuchTool");
  }

  @Test
  void someoneElsesVehicleIsNotFound() {
    UUID stranger = UUID.randomUUID();
    when(fuel.stats(eq(USER), eq(stranger), any(), any()))
        .thenThrow(new DrivonException(ErrorCode.VEHICLE_NOT_FOUND));

    JsonNode result = run("getFuelExpenses", "{\"vehicleId\": \"" + stranger + "\"}", context(CAR));

    assertThat(result.path("error").asString()).isEqualTo("Vehicle not found");
  }

  @Test
  void anUnexpectedFailureIsAGenericError() {
    when(fuel.stats(any(), any(), any(), any())).thenThrow(new IllegalStateException("db"));

    assertThat(run("getFuelEfficiency", "{}", context(CAR)).path("error").asString())
        .isEqualTo("That lookup failed. Try again later.");
  }

  @Test
  void namedPeriodsBecomeDateRanges() {
    when(spending.summary(any(), any(), any(), any()))
        .thenReturn(new SpendingSummaryResponse(TODAY, TODAY, BigDecimal.ZERO, List.of()));

    run("getSpendingSummary", "{\"period\": \"last_month\"}", context(CAR));
    run("getSpendingSummary", "{\"period\": \"LAST_YEAR\"}", context(CAR));
    run("getSpendingSummary", "{}", context(CAR));

    verify(spending).summary(USER, CAR, LocalDate.of(2026, 9, 1), LocalDate.of(2026, 9, 30));
    verify(spending).summary(USER, CAR, LocalDate.of(2025, 1, 1), LocalDate.of(2025, 12, 31));
    verify(spending).summary(USER, CAR, LocalDate.of(2026, 10, 1), TODAY);
  }

  @Test
  void aMonthlyTrendFollowsOneMetric() {
    when(analytics.monthlyCosts(USER, CAR, 3))
        .thenReturn(
            List.of(
                new MonthlyCostResponse(
                    YearMonth.of(2026, 10),
                    new BigDecimal("9000.00"),
                    BigDecimal.ZERO,
                    BigDecimal.ZERO,
                    new BigDecimal("9000.00"),
                    600,
                    new BigDecimal("15.00"))));

    JsonNode result =
        run("getMonthlyTrend", "{\"metric\": \"DISTANCE\", \"months\": 3}", context(CAR));

    assertThat(result.path("metric").asString()).isEqualTo("DISTANCE");
    assertThat(result.path("months").get(0).path("month").asString()).isEqualTo("2026-10");
    assertThat(result.path("months").get(0).path("value").asInt()).isEqualTo(600);
  }

  @Test
  void documentsSayWhetherTheyAreStillValid() {
    when(documents.list(eq(USER), eq(CAR), eq(DocumentType.INSURANCE), any(Pageable.class)))
        .thenReturn(
            new PageResponse<>(
                List.of(
                    document(LocalDate.of(2026, 10, 25)),
                    document(LocalDate.of(2026, 3, 1)),
                    document(null)),
                0,
                20,
                3,
                1,
                false));

    JsonNode result = run("getDocumentStatus", "{\"type\": \"INSURANCE\"}", context(CAR));

    assertThat(result.get(0).path("status").asString()).isEqualTo("EXPIRING_SOON");
    assertThat(result.get(0).path("daysUntilExpiry").asInt()).isEqualTo(15);
    assertThat(result.get(0).path("vehicle").asString()).isEqualTo("Toyota Aqua CAB-1234");
    assertThat(result.get(1).path("status").asString()).isEqualTo("EXPIRED");
    assertThat(result.get(2).path("status").asString()).isEqualTo("NO_EXPIRY_DATE");
  }

  @Test
  void remindersCoverEveryVehicleUnlessOneIsNamed() {
    when(reminders.list(any(), any(), any())).thenReturn(List.of());

    run("getReminders", "{\"status\": \"OVERDUE\"}", context(CAR));
    run("getReminders", "{\"vehicleId\": \"" + BIKE + "\"}", context(CAR));

    verify(reminders).list(USER, null, ReminderStatus.OVERDUE);
    verify(reminders).list(USER, BIKE, null);
  }

  @Test
  void listsTheUsersVehiclesWithTheSelectedOneMarked() {
    when(vehicles.list(USER)).thenReturn(TWO_VEHICLES);

    JsonNode result = run("listVehicles", "{}", context(BIKE));

    assertThat(result).hasSize(2);
    assertThat(result.get(1).path("selectedInApp").asBoolean()).isTrue();
    assertThat(result.get(0).path("vehicleId").asString()).isEqualTo(CAR.toString());
  }

  @Test
  void historyLimitsDefaultSensibly() {
    when(fuel.history(any(), any(), any(), any(), anyInt())).thenReturn(List.of());

    run("getFuelHistory", "{}", context(CAR));

    verify(fuel).history(USER, CAR, null, null, 10);
  }

  private static DocumentResponse document(LocalDate expiry) {
    return new DocumentResponse(
        UUID.randomUUID(),
        CAR,
        DocumentType.INSURANCE,
        null,
        expiry,
        null,
        "application/pdf",
        100,
        DocumentStatus.ACTIVE,
        Instant.EPOCH,
        Instant.EPOCH);
  }
}
