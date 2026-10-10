package com.drivon.api.assistant.tools;

import com.drivon.api.analytics.AnalyticsService;
import com.drivon.api.analytics.MonthlyCostResponse;
import com.drivon.api.analytics.VehicleComparisonResponse;
import com.drivon.api.analytics.VehicleComparisonResponse.VehicleCost;
import com.drivon.api.assistant.llm.ToolCall;
import com.drivon.api.assistant.llm.ToolSpec;
import com.drivon.api.assistant.tools.ToolChoices.ComparisonMetric;
import com.drivon.api.assistant.tools.ToolChoices.Period;
import com.drivon.api.assistant.tools.ToolChoices.TrendMetric;
import com.drivon.api.common.error.DrivonException;
import com.drivon.api.common.time.BusinessCalendar;
import com.drivon.api.common.time.DateRange;
import com.drivon.api.document.DocumentResponse;
import com.drivon.api.document.DocumentService;
import com.drivon.api.document.DocumentType;
import com.drivon.api.expense.ExpenseCategory;
import com.drivon.api.expense.ExpenseService;
import com.drivon.api.expense.SpendingService;
import com.drivon.api.expense.SpendingSummaryResponse;
import com.drivon.api.fuel.FuelRecordResponse;
import com.drivon.api.fuel.FuelService;
import com.drivon.api.fuel.FuelStatsResponse;
import com.drivon.api.maintenance.MaintenanceRecordResponse;
import com.drivon.api.maintenance.MaintenanceService;
import com.drivon.api.maintenance.ServiceType;
import com.drivon.api.reminder.ReminderResponse;
import com.drivon.api.reminder.ReminderRules;
import com.drivon.api.reminder.ReminderService;
import com.drivon.api.reminder.ReminderStatus;
import com.drivon.api.vehicle.OdometerService;
import com.drivon.api.vehicle.Vehicle;
import com.drivon.api.vehicle.VehicleResponse;
import com.drivon.api.vehicle.VehicleService;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Function;
import org.jspecify.annotations.Nullable;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.data.domain.Sort.Direction;
import org.springframework.stereotype.Component;
import tools.jackson.databind.json.JsonMapper;

/**
 * The read-only tools of Ask My Vehicle (see the product overview, section 6). Each one turns its
 * arguments into a call to an existing service; services check that vehicles belong to the user and
 * hold every calculation. Results are JSON; failures become {@code {"error": "..."}} so the model
 * can explain or correct them.
 */
@Component
public class AssistantTools {

  /** Longest list a tool returns, to keep answers within the model's input. */
  static final int MAX_ITEMS = 50;

  private static final Logger log = LoggerFactory.getLogger(AssistantTools.class);

  private final JsonMapper json;
  private final VehicleService vehicles;
  private final OdometerService odometer;
  private final FuelService fuel;
  private final MaintenanceService maintenance;
  private final ExpenseService expenses;
  private final SpendingService spending;
  private final AnalyticsService analytics;
  private final DocumentService documents;
  private final ReminderService reminders;
  private final BusinessCalendar calendar;
  private final Map<String, AssistantTool> tools = new LinkedHashMap<>();

  AssistantTools(
      JsonMapper json,
      VehicleService vehicles,
      OdometerService odometer,
      FuelService fuel,
      MaintenanceService maintenance,
      ExpenseService expenses,
      SpendingService spending,
      AnalyticsService analytics,
      DocumentService documents,
      ReminderService reminders,
      BusinessCalendar calendar) {
    this.json = json;
    this.vehicles = vehicles;
    this.odometer = odometer;
    this.fuel = fuel;
    this.maintenance = maintenance;
    this.expenses = expenses;
    this.spending = spending;
    this.analytics = analytics;
    this.documents = documents;
    this.reminders = reminders;
    this.calendar = calendar;
    registerVehicleTools();
    registerFuelTools();
    registerMaintenanceTools();
    registerSpendingTools();
    registerDocumentAndReminderTools();
  }

  /** The tools, in the form sent to the model. */
  public List<ToolSpec> specs() {
    return tools.values().stream().map(AssistantTool::spec).toList();
  }

  /** Runs one tool call for the user in {@code context} and returns its result as JSON. */
  public String execute(ToolCall call, ToolContext context) {
    AssistantTool tool = tools.get(call.name());
    Object result;
    if (tool == null) {
      result = error("There is no tool called " + call.name() + ".");
    } else {
      try {
        result = tool.handler().run(context, new ToolArguments(call.arguments()));
      } catch (ToolArgumentException | DrivonException e) {
        result = error(e.getMessage());
      } catch (RuntimeException e) {
        log.warn("Assistant tool {} failed", call.name(), e);
        result = error("That lookup failed. Try again later.");
      }
    }
    return json.writeValueAsString(result);
  }

  private void register(
      String name, String description, Parameters parameters, AssistantTool.Handler handler) {
    tools.put(
        name, new AssistantTool(new ToolSpec(name, description, parameters.build()), handler));
  }

  private Parameters parameters() {
    return new Parameters(json);
  }

  private void registerVehicleTools() {
    register(
        "listVehicles",
        "The user's vehicles (at most two): make, model, year, registration number, fuel type and"
            + " current odometer, with each vehicle's ID for the other tools.",
        parameters(),
        (context, args) ->
            vehicles.list(context.userId()).stream()
                .map(vehicle -> vehicleSummary(vehicle, context))
                .toList());

    register(
        "getVehicleDetails",
        "One vehicle's details, such as its registration number, year, fuel type and current"
            + " odometer.",
        parameters().vehicleId(),
        (context, args) ->
            vehicleSummary(vehicles.get(context.userId(), context.vehicleId(args)), context));

    register(
        "getOdometerStats",
        "Kilometres driven in a period, from the odometer readings, and the current odometer."
            + " Example: how many km did I drive last month?",
        parameters().vehicleId().from("the first day of this month").to(),
        (context, args) -> {
          UUID vehicleId = context.vehicleId(args);
          Vehicle vehicle = vehicles.requireOwned(context.userId(), vehicleId);
          DateRange range = range(args, monthStart(context));
          return result(
              "from", range.from(),
              "to", range.to(),
              "distanceKm", odometer.distanceBetween(vehicleId, range.from(), range.to()),
              "currentOdometerKm", vehicle.getCurrentOdometerKm());
        });
  }

  private void registerFuelTools() {
    register(
        "getFuelExpenses",
        "Money spent on fuel in a period, with litres bought and the number of fill-ups.",
        parameters().vehicleId().from("the first day of this month").to(),
        (context, args) -> {
          FuelStatsResponse stats =
              fuel.stats(
                  context.userId(),
                  context.vehicleId(args),
                  orDefault(args.date("from"), monthStart(context)),
                  args.date("to"));
          return result(
              "from", stats.from(),
              "to", stats.to(),
              "totalSpend", stats.totalSpend(),
              "totalLitres", stats.totalLitres(),
              "fillUps", stats.fillUps());
        });

    register(
        "getFuelHistory",
        "Individual fill-ups, newest first: date, litres, amount, price per litre, odometer,"
            + " full or partial tank, station and km/L of full tanks.",
        parameters()
            .vehicleId()
            .from("the first fill-up")
            .to()
            .integer(
                "limit", "How many fill-ups to return, newest first. Default 10.", 1, MAX_ITEMS),
        (context, args) ->
            fuel
                .history(
                    context.userId(),
                    context.vehicleId(args),
                    args.date("from"),
                    args.date("to"),
                    args.integer("limit", 1, MAX_ITEMS, 10))
                .stream()
                .map(AssistantTools::fillUp)
                .toList());

    register(
        "getFuelEfficiency",
        "Fuel efficiency in km/L by the full-tank method: average, best and latest tank, fuel"
            + " cost per km and the distance those tanks cover. Null values mean there aren't two"
            + " full fill-ups yet.",
        parameters().vehicleId().from("the first fill-up").to(),
        (context, args) -> {
          FuelStatsResponse stats =
              fuel.stats(
                  context.userId(), context.vehicleId(args), args.date("from"), args.date("to"));
          return result(
              "from", stats.from(),
              "to", stats.to(),
              "averageKmPerLitre", stats.averageKmPerLitre(),
              "bestKmPerLitre", stats.bestKmPerLitre(),
              "latestKmPerLitre", stats.latestKmPerLitre(),
              "fuelCostPerKm", stats.costPerKm(),
              "trackedDistanceKm", stats.trackedDistanceKm());
        });

    register(
        "getFuelPriceTrend",
        "Price paid per litre, month by month: average, lowest and highest.",
        parameters().vehicleId().from("12 months ago").to(),
        (context, args) ->
            fuel.priceTrend(
                context.userId(),
                context.vehicleId(args),
                orDefault(args.date("from"), context.today().minusMonths(11).withDayOfMonth(1)),
                args.date("to")));

    register(
        "getFuelStationStats",
        "Fill-ups per fuel station, most visited first, with litres, spend and the average,"
            + " lowest and highest price per litre there.",
        parameters().vehicleId().from("the first fill-up").to(),
        (context, args) ->
            fuel.stationStats(
                context.userId(), context.vehicleId(args), args.date("from"), args.date("to")));
  }

  private void registerMaintenanceTools() {
    register(
        "getMaintenanceHistory",
        "Services done on the vehicle, newest first, optionally of one type: date, odometer,"
            + " cost, notes and the next service date or mileage set then.",
        parameters()
            .vehicleId()
            .choice("serviceType", "Only this kind of service.", ServiceType.values())
            .from("the first service")
            .to()
            .integer("limit", "How many services to return. Default 20.", 1, MAX_ITEMS),
        (context, args) ->
            maintenance
                .history(
                    context.userId(),
                    context.vehicleId(args),
                    args.choice("serviceType", ServiceType.class),
                    args.date("from"),
                    args.date("to"),
                    args.integer("limit", 1, MAX_ITEMS, 20))
                .stream()
                .map(AssistantTools::service)
                .toList());

    register(
        "getLastService",
        "The most recent service, optionally of one type. Example: when did I last change my oil?",
        parameters()
            .vehicleId()
            .choice("serviceType", "Only this kind of service.", ServiceType.values()),
        (context, args) -> {
          List<MaintenanceRecordResponse> latest =
              maintenance.history(
                  context.userId(),
                  context.vehicleId(args),
                  args.choice("serviceType", ServiceType.class),
                  null,
                  null,
                  1);
          return latest.isEmpty()
              ? result("found", false)
              : result("found", true, "service", service(latest.get(0)));
        });

    register(
        "getUpcomingMaintenance",
        "When each kind of service is next due, from the latest service of that kind: due date"
            + " and/or mileage, days and km remaining (negative when overdue), overdue first.",
        parameters().vehicleId(),
        (context, args) -> maintenance.upcoming(context.userId(), context.vehicleId(args)));
  }

  private void registerSpendingTools() {
    register(
        "getVehicleExpenses",
        "Expenses logged in the app, newest first: insurance, repairs, parking, tolls, washing"
            + " and others. Fill-ups and services aren't listed here; use getFuelHistory and"
            + " getMaintenanceHistory, or getSpendingSummary for totals that include them.",
        parameters()
            .vehicleId()
            .choice("category", "Only this category.", ExpenseCategory.values())
            .from("the first day of this month")
            .to()
            .integer("limit", "How many expenses to return. Default 20.", 1, MAX_ITEMS),
        (context, args) ->
            expenses
                .history(
                    context.userId(),
                    context.vehicleId(args),
                    args.choice("category", ExpenseCategory.class),
                    orDefault(args.date("from"), monthStart(context)),
                    args.date("to"),
                    args.integer("limit", 1, MAX_ITEMS, 20))
                .stream()
                .map(
                    expense ->
                        result(
                            "date", expense.date(),
                            "category", expense.category(),
                            "amount", expense.amount(),
                            "notes", expense.notes()))
                .toList());

    register(
        "getExpensesByCategory",
        "Total spent per category in a period, or on one category. FUEL includes fill-ups and"
            + " MAINTENANCE includes services. Example: how much did I spend on parking this year?",
        parameters()
            .vehicleId()
            .choice("category", "Only this category.", ExpenseCategory.values())
            .from("the first day of this month")
            .to(),
        (context, args) -> {
          SpendingSummaryResponse summary =
              spending.summary(
                  context.userId(),
                  context.vehicleId(args),
                  orDefault(args.date("from"), monthStart(context)),
                  args.date("to"));
          ExpenseCategory category = args.choice("category", ExpenseCategory.class);
          if (category == null) {
            return summary;
          }
          return summary.categories().stream()
              .filter(total -> total.category() == category)
              .findFirst()
              .map(
                  total ->
                      result(
                          "from", summary.from(),
                          "to", summary.to(),
                          "category", total.category(),
                          "total", total.total(),
                          "count", total.count()))
              .orElseThrow();
        });

    register(
        "getSpendingSummary",
        "Total spending in a named period with the split by category (fill-ups count as FUEL,"
            + " services as MAINTENANCE).",
        parameters()
            .vehicleId()
            .choice("period", "Which period. Default THIS_MONTH.", Period.values()),
        (context, args) -> {
          Period period = args.choice("period", Period.class);
          DateRange range = periodRange(period == null ? Period.THIS_MONTH : period, context);
          return spending.summary(
              context.userId(), context.vehicleId(args), range.from(), range.to());
        });

    register(
        "getMonthlyTrend",
        "One value per month for the last months, oldest first, to see whether costs or"
            + " driving go up or down. Months without records are 0.",
        parameters()
            .vehicleId()
            .choice("metric", "What to follow. Default TOTAL (all costs).", TrendMetric.values())
            .integer("months", "How many months up to this one. Default 6.", 1, 24),
        (context, args) -> {
          TrendMetric chosen = args.choice("metric", TrendMetric.class);
          TrendMetric metric = chosen == null ? TrendMetric.TOTAL : chosen;
          Function<MonthlyCostResponse, @Nullable Object> value =
              switch (metric) {
                case TOTAL -> MonthlyCostResponse::total;
                case FUEL -> MonthlyCostResponse::fuel;
                case MAINTENANCE -> MonthlyCostResponse::maintenance;
                case OTHER -> MonthlyCostResponse::other;
                case DISTANCE -> MonthlyCostResponse::distanceKm;
                case COST_PER_KM -> MonthlyCostResponse::costPerKm;
              };
          return result(
              "metric",
              metric,
              "months",
              analytics
                  .monthlyCosts(
                      context.userId(), context.vehicleId(args), args.integer("months", 1, 24, 6))
                  .stream()
                  .map(month -> result("month", month.month(), "value", value.apply(month)))
                  .toList());
        });

    register(
        "getCostPerKilometre",
        "Running cost per km in a period: everything spent divided by the distance driven,"
            + " split into fuel, maintenance and other. Null when no distance was recorded.",
        parameters().vehicleId().from("the first record").to(),
        (context, args) ->
            analytics.costPerKm(
                context.userId(), context.vehicleId(args), args.date("from"), args.date("to")));

    register(
        "compareVehicles",
        "Compares the user's vehicles in a period: distance, total cost, cost per km with its"
            + " parts, and average km/L, best first by the chosen metric.",
        parameters()
            .choice("metric", "What to rank by. Default COST_PER_KM.", ComparisonMetric.values())
            .from("the first record")
            .to(),
        (context, args) -> {
          ComparisonMetric chosen = args.choice("metric", ComparisonMetric.class);
          ComparisonMetric metric = chosen == null ? ComparisonMetric.COST_PER_KM : chosen;
          VehicleComparisonResponse comparison =
              analytics.compareVehicles(context.userId(), args.date("from"), args.date("to"));
          return result(
              "from", comparison.from(),
              "to", comparison.to(),
              "rankedBy", metric,
              "vehicles", comparison.vehicles().stream().sorted(ranking(metric)).toList());
        });
  }

  private void registerDocumentAndReminderTools() {
    register(
        "getDocumentStatus",
        "Stored documents of a vehicle (insurance, revenue licence, registration, invoices,"
            + " receipts), latest expiry first, with whether each is valid, expiring soon"
            + " (within 30 days) or expired. Example: is my insurance still valid?",
        parameters()
            .vehicleId()
            .choice("type", "Only this kind of document.", DocumentType.values()),
        (context, args) ->
            documents
                .list(
                    context.userId(),
                    context.vehicleId(args),
                    args.choice("type", DocumentType.class),
                    PageRequest.of(0, 20, Sort.by(Direction.DESC, "expiryDate")))
                .content()
                .stream()
                .map(document -> document(document, context))
                .toList());

    register(
        "getExpiringDocuments",
        "Documents across all the user's vehicles that expired or expire within the given"
            + " number of days, soonest first.",
        parameters().integer("withinDays", "Days from today. Default 30.", 0, 365),
        (context, args) ->
            documents.expiring(context.userId(), args.integer("withinDays", 0, 365, 30)).stream()
                .map(document -> document(document, context))
                .toList());

    register(
        "getReminders",
        "Reminders, most urgent first: services due by date or mileage, document expiry dates"
            + " and the user's own reminders, each OVERDUE, DUE_SOON or UPCOMING. Leave out"
            + " vehicleId for all vehicles.",
        parameters()
            .vehicleId()
            .choice("status", "Only reminders with this status.", ReminderStatus.values()),
        (context, args) ->
            reminders
                .list(
                    context.userId(),
                    args.uuid("vehicleId"),
                    args.choice("status", ReminderStatus.class))
                .stream()
                .map(reminder -> reminder(reminder, context))
                .toList());
  }

  private static Map<String, Object> vehicleSummary(VehicleResponse vehicle, ToolContext context) {
    return result(
        "vehicleId", vehicle.id(),
        "make", vehicle.make(),
        "model", vehicle.model(),
        "year", vehicle.year(),
        "registrationNumber", vehicle.registrationNumber(),
        "fuelType", vehicle.fuelType(),
        "currentOdometerKm", vehicle.currentOdometerKm(),
        "selectedInApp", vehicle.id().equals(context.selectedVehicleId()));
  }

  private static Map<String, Object> fillUp(FuelRecordResponse record) {
    return result(
        "date", record.date(),
        "litres", record.litres(),
        "amount", record.amount(),
        "pricePerLitre", record.pricePerLitre(),
        "odometerKm", record.odometerKm(),
        "fullTank", record.fullTank(),
        "station", record.station(),
        "kmPerLitre", record.kmPerLitre());
  }

  private static Map<String, Object> service(MaintenanceRecordResponse record) {
    return result(
        "serviceType", record.serviceType(),
        "date", record.date(),
        "odometerKm", record.odometerKm(),
        "cost", record.cost(),
        "notes", record.notes(),
        "nextServiceDate", record.nextServiceDate(),
        "nextServiceKm", record.nextServiceKm());
  }

  private static Map<String, Object> document(DocumentResponse document, ToolContext context) {
    LocalDate expiry = document.expiryDate();
    Long days = expiry == null ? null : ChronoUnit.DAYS.between(context.today(), expiry);
    String status;
    if (days == null) {
      status = "NO_EXPIRY_DATE";
    } else if (days < 0) {
      status = "EXPIRED";
    } else if (days <= ReminderRules.DOCUMENT_LEAD_DAYS) {
      status = "EXPIRING_SOON";
    } else {
      status = "VALID";
    }
    return result(
        "vehicle", vehicleName(document.vehicleId(), context),
        "type", document.type(),
        "issueDate", document.issueDate(),
        "expiryDate", expiry,
        "daysUntilExpiry", days,
        "status", status,
        "notes", document.notes());
  }

  private static Map<String, Object> reminder(ReminderResponse reminder, ToolContext context) {
    Object what =
        switch (reminder.source()) {
          case MANUAL -> reminder.title();
          case SERVICE -> reminder.serviceType();
          case DOCUMENT -> reminder.documentType();
        };
    return result(
        "vehicle", vehicleName(reminder.vehicleId(), context),
        "source", reminder.source(),
        "what", what,
        "dueDate", reminder.dueDate(),
        "dueKm", reminder.dueKm(),
        "daysRemaining", reminder.daysRemaining(),
        "kmRemaining", reminder.kmRemaining(),
        "status", reminder.status());
  }

  private static String vehicleName(UUID vehicleId, ToolContext context) {
    return context.vehicles().stream()
        .filter(vehicle -> vehicle.id().equals(vehicleId))
        .map(v -> v.make() + " " + v.model() + " " + v.registrationNumber())
        .findFirst()
        .orElse("");
  }

  private static Comparator<VehicleCost> ranking(ComparisonMetric metric) {
    return switch (metric) {
      case COST_PER_KM ->
          Comparator.comparing(
              VehicleCost::costPerKm, Comparator.nullsLast(Comparator.naturalOrder()));
      case TOTAL_COST -> Comparator.comparing(VehicleCost::totalCost);
      case DISTANCE -> Comparator.comparing(VehicleCost::distanceKm).reversed();
      case KM_PER_LITRE ->
          Comparator.comparing(
              VehicleCost::averageKmPerLitre, Comparator.nullsLast(Comparator.reverseOrder()));
    };
  }

  private DateRange range(ToolArguments args, LocalDate defaultFrom) {
    return calendar.range(orDefault(args.date("from"), defaultFrom), args.date("to"));
  }

  private static DateRange periodRange(Period period, ToolContext context) {
    LocalDate today = context.today();
    return switch (period) {
      case THIS_MONTH -> new DateRange(today.withDayOfMonth(1), today);
      case LAST_MONTH -> {
        LocalDate start = today.minusMonths(1).withDayOfMonth(1);
        yield new DateRange(start, start.withDayOfMonth(start.lengthOfMonth()));
      }
      case THIS_YEAR -> new DateRange(today.withDayOfYear(1), today);
      case LAST_YEAR -> {
        LocalDate start = today.minusYears(1).withDayOfYear(1);
        yield new DateRange(start, start.withDayOfYear(start.lengthOfYear()));
      }
      case LAST_12_MONTHS -> new DateRange(today.minusMonths(11).withDayOfMonth(1), today);
      case ALL_TIME -> new DateRange(BusinessCalendar.EARLIEST, today);
    };
  }

  private static LocalDate monthStart(ToolContext context) {
    return context.today().withDayOfMonth(1);
  }

  private static LocalDate orDefault(@Nullable LocalDate value, LocalDate fallback) {
    return value != null ? value : fallback;
  }

  /** An ordered JSON object from name-value pairs; null values are kept as JSON null. */
  static Map<String, Object> result(Object... namesAndValues) {
    Map<String, Object> result = new LinkedHashMap<>();
    for (int i = 0; i < namesAndValues.length; i += 2) {
      result.put((String) namesAndValues[i], namesAndValues[i + 1]);
    }
    return result;
  }

  private static Map<String, Object> error(@Nullable String message) {
    return result("error", message == null ? "That lookup failed." : message);
  }
}
