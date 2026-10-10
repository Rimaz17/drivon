package com.drivon.api.fuel;

import com.drivon.api.common.error.DrivonException;
import com.drivon.api.common.error.ErrorCode;
import com.drivon.api.common.stats.MonthlyAmount;
import com.drivon.api.common.stats.MonthlySeries;
import com.drivon.api.common.stats.MonthlySum;
import com.drivon.api.common.stats.SpendTotal;
import com.drivon.api.common.time.BusinessCalendar;
import com.drivon.api.common.time.DateRange;
import com.drivon.api.common.web.CreateResult;
import com.drivon.api.common.web.PageResponse;
import com.drivon.api.common.web.SortOptions;
import com.drivon.api.fuel.FuelRecord.FuelDetails;
import com.drivon.api.vehicle.OdometerService;
import com.drivon.api.vehicle.OdometerSource;
import com.drivon.api.vehicle.Vehicle;
import com.drivon.api.vehicle.VehicleService;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.stream.Collectors;
import org.jspecify.annotations.Nullable;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.domain.Sort.Direction;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Fill-ups for the signed-in user's vehicles. Every method checks that the vehicle belongs to the
 * user; a fill-up under someone else's vehicle is reported as not found.
 */
@Service
public class FuelService {

  static final SortOptions SORT =
      new SortOptions(
          Map.of(
              "date", "date",
              "odometerKm", "odometerKm",
              "amount", "amount",
              "litres", "litres"),
          Sort.by(Direction.DESC, "date").and(Sort.by(Direction.DESC, "odometerKm")),
          Sort.by(Direction.DESC, "createdAt"));

  /** Pumps round the amount, so litres × price may differ from it by up to 1% (at least Rs. 1). */
  private static final BigDecimal PRICE_TOLERANCE_RATE = new BigDecimal("0.01");

  private final FuelRecordRepository records;
  private final VehicleService vehicles;
  private final OdometerService odometer;
  private final BusinessCalendar calendar;

  FuelService(
      FuelRecordRepository records,
      VehicleService vehicles,
      OdometerService odometer,
      BusinessCalendar calendar) {
    this.records = records;
    this.vehicles = vehicles;
    this.odometer = odometer;
    this.calendar = calendar;
  }

  @Transactional(readOnly = true)
  public PageResponse<FuelRecordResponse> list(UUID userId, UUID vehicleId, Pageable pageable) {
    vehicles.requireOwned(userId, vehicleId);
    Map<UUID, BigDecimal> efficiency = efficiencyByRecord(vehicleId);
    return PageResponse.of(
        records.findByVehicleId(vehicleId, SORT.apply(pageable)),
        record -> FuelRecordMapper.toResponse(record, efficiency.get(record.getId())));
  }

  @Transactional(readOnly = true)
  public FuelRecordResponse get(UUID userId, UUID vehicleId, UUID recordId) {
    vehicles.requireOwned(userId, vehicleId);
    return withEfficiency(find(vehicleId, recordId));
  }

  /**
   * Logs a fill-up and puts its odometer on the vehicle's timeline. If the request carries an ID
   * that was already saved for this vehicle, that record is returned unchanged (an offline retry).
   */
  @Transactional
  public CreateResult<FuelRecordResponse> create(
      UUID userId, UUID vehicleId, FuelRecordRequest request) {
    Vehicle vehicle = odometer.lockVehicle(userId, vehicleId);
    Optional<FuelRecord> earlier =
        request.id() == null ? Optional.empty() : records.findById(request.id());
    if (earlier.isPresent()) {
      if (!earlier.get().getVehicleId().equals(vehicleId)) {
        throw new DrivonException(
            ErrorCode.RECORD_ID_CONFLICT, "This ID is already used by another record.");
      }
      return new CreateResult<>(withEfficiency(earlier.get()), false);
    }
    FuelDetails details = validate(request);
    FuelRecord record = new FuelRecord(request.id(), vehicleId, details);
    odometer.recordLinked(
        vehicle, OdometerSource.FUEL, record.getId(), details.date(), details.odometerKm());
    records.saveAndFlush(record);
    return new CreateResult<>(withEfficiency(record), true);
  }

  /** Replaces a fill-up's details; its odometer reading moves with it. */
  @Transactional
  public FuelRecordResponse update(
      UUID userId, UUID vehicleId, UUID recordId, FuelRecordRequest request) {
    Vehicle vehicle = odometer.lockVehicle(userId, vehicleId);
    FuelRecord record = find(vehicleId, recordId);
    FuelDetails details = validate(request);
    odometer.recordLinked(
        vehicle, OdometerSource.FUEL, record.getId(), details.date(), details.odometerKm());
    record.update(details);
    records.saveAndFlush(record);
    return withEfficiency(record);
  }

  /** Deletes a fill-up and its odometer reading. */
  @Transactional
  public void delete(UUID userId, UUID vehicleId, UUID recordId) {
    Vehicle vehicle = odometer.lockVehicle(userId, vehicleId);
    FuelRecord record = find(vehicleId, recordId);
    records.delete(record);
    odometer.removeLinked(vehicle, record.getId());
  }

  /**
   * Spend, litres and efficiency for a date range (open ends mean "from the beginning" and "up to
   * today"). Efficiency uses the full-to-full stretches that ended inside the range.
   */
  @Transactional(readOnly = true)
  public FuelStatsResponse stats(
      UUID userId, UUID vehicleId, @Nullable LocalDate from, @Nullable LocalDate to) {
    vehicles.requireOwned(userId, vehicleId);
    DateRange range = calendar.range(from, to);
    FuelRecordRepository.Totals totals = records.sumBetween(vehicleId, range.from(), range.to());
    List<FuelInterval> intervals =
        FuelEfficiencyCalculator.intervals(records.findFillsInOdometerOrder(vehicleId)).stream()
            .filter(interval -> range.contains(interval.endDate()))
            .toList();
    FuelEfficiencyCalculator.Summary efficiency = FuelEfficiencyCalculator.summarize(intervals);
    return new FuelStatsResponse(
        range.from(),
        range.to(),
        totals.getAmount().setScale(2, RoundingMode.HALF_UP),
        totals.getLitres().setScale(3, RoundingMode.HALF_UP),
        totals.getFillUps(),
        efficiency.averageKmPerLitre(),
        efficiency.bestKmPerLitre(),
        efficiency.latestKmPerLitre(),
        efficiency.costPerKm(),
        efficiency.distanceKm());
  }

  /**
   * Every full-to-full stretch that ended in the range (open ends mean "from the beginning" and "up
   * to today"), oldest first, to chart efficiency over time.
   */
  @Transactional(readOnly = true)
  public List<EfficiencyPoint> efficiencyTrend(
      UUID userId, UUID vehicleId, @Nullable LocalDate from, @Nullable LocalDate to) {
    vehicles.requireOwned(userId, vehicleId);
    DateRange range = calendar.range(from, to);
    return FuelEfficiencyCalculator.intervals(records.findFillsInOdometerOrder(vehicleId)).stream()
        .filter(interval -> range.contains(interval.endDate()))
        .map(EfficiencyPoint::from)
        .toList();
  }

  /**
   * Up to {@code limit} fill-ups in a date range, newest first (open ends mean "from the beginning"
   * and "up to today").
   */
  @Transactional(readOnly = true)
  public List<FuelRecordResponse> history(
      UUID userId, UUID vehicleId, @Nullable LocalDate from, @Nullable LocalDate to, int limit) {
    vehicles.requireOwned(userId, vehicleId);
    DateRange range = calendar.range(from, to);
    Map<UUID, BigDecimal> efficiency = efficiencyByRecord(vehicleId);
    PageRequest newestFirst =
        PageRequest.of(
            0,
            limit,
            Sort.by(Direction.DESC, "date")
                .and(Sort.by(Direction.DESC, "odometerKm"))
                .and(Sort.by(Direction.DESC, "createdAt")));
    return records.findBetween(vehicleId, range.from(), range.to(), newestFirst).stream()
        .map(record -> FuelRecordMapper.toResponse(record, efficiency.get(record.getId())))
        .toList();
  }

  /** Price paid per litre in each month of a range that has fill-ups, oldest first. */
  @Transactional(readOnly = true)
  public List<FuelPriceMonth> priceTrend(
      UUID userId, UUID vehicleId, @Nullable LocalDate from, @Nullable LocalDate to) {
    vehicles.requireOwned(userId, vehicleId);
    DateRange range = calendar.range(from, to);
    return records.priceByMonth(vehicleId, range.from(), range.to()).stream()
        .map(
            month ->
                new FuelPriceMonth(
                    YearMonth.of(month.getYear(), month.getMonth()),
                    pricePerLitre(month.getAmount(), month.getLitres()),
                    month.getLowestPrice(),
                    month.getHighestPrice(),
                    month.getFillUps()))
        .toList();
  }

  /**
   * Fill-ups per station in a range, most visited first; fill-ups without a station are left out.
   */
  @Transactional(readOnly = true)
  public List<FuelStationStats> stationStats(
      UUID userId, UUID vehicleId, @Nullable LocalDate from, @Nullable LocalDate to) {
    vehicles.requireOwned(userId, vehicleId);
    DateRange range = calendar.range(from, to);
    return records.sumByStation(vehicleId, range.from(), range.to()).stream()
        .map(
            station ->
                new FuelStationStats(
                    station.getStation(),
                    station.getFillUps(),
                    station.getLitres().setScale(3, RoundingMode.HALF_UP),
                    station.getAmount().setScale(2, RoundingMode.HALF_UP),
                    pricePerLitre(station.getAmount(), station.getLitres()),
                    station.getLowestPrice(),
                    station.getHighestPrice(),
                    station.getLastVisit()))
        .toList();
  }

  /** Fuel spend for each of the last {@code months} months up to this one, oldest first. */
  @Transactional(readOnly = true)
  public List<MonthlyAmount> monthlySpend(UUID userId, UUID vehicleId, int months) {
    vehicles.requireOwned(userId, vehicleId);
    YearMonth last = calendar.currentMonth();
    YearMonth first = MonthlySeries.firstMonth(last, months);
    return MonthlySeries.of(
        last, months, records.sumByMonth(vehicleId, first.atDay(1), last.atEndOfMonth()));
  }

  /**
   * Fuel spend of a vehicle in an inclusive date range, for spending totals. The caller must have
   * checked that the vehicle belongs to the user.
   */
  @Transactional(readOnly = true)
  public SpendTotal spendBetween(UUID vehicleId, LocalDate from, LocalDate to) {
    FuelRecordRepository.Totals totals = records.sumBetween(vehicleId, from, to);
    return new SpendTotal(totals.getAmount(), totals.getFillUps());
  }

  /** Fuel spend of a vehicle per month in a range; the caller checked ownership. */
  @Transactional(readOnly = true)
  public List<MonthlySum> spendByMonth(UUID vehicleId, LocalDate from, LocalDate to) {
    return records.sumByMonth(vehicleId, from, to);
  }

  private FuelDetails validate(FuelRecordRequest request) {
    calendar.requireNotFuture(request.date());
    BigDecimal litres = request.litres().setScale(3, RoundingMode.HALF_UP);
    BigDecimal amount = request.amount().setScale(2, RoundingMode.HALF_UP);
    return new FuelDetails(
        request.date(),
        litres,
        amount,
        resolvePricePerLitre(litres, amount, request.pricePerLitre()),
        request.odometerKm(),
        request.fullTank(),
        blankToNull(request.station()));
  }

  /** The price per litre sent by the client if it agrees with amount and litres, else derived. */
  static BigDecimal resolvePricePerLitre(
      BigDecimal litres, BigDecimal amount, @Nullable BigDecimal pricePerLitre) {
    if (pricePerLitre == null) {
      BigDecimal derived = amount.divide(litres, 2, RoundingMode.HALF_UP);
      if (derived.signum() <= 0) {
        throw new DrivonException(
            ErrorCode.FUEL_PRICE_MISMATCH,
            "The amount is too small for that many litres. Check both values.");
      }
      return derived;
    }
    BigDecimal price = pricePerLitre.setScale(2, RoundingMode.HALF_UP);
    BigDecimal expectedAmount = litres.multiply(price).setScale(2, RoundingMode.HALF_UP);
    BigDecimal tolerance = amount.multiply(PRICE_TOLERANCE_RATE).max(BigDecimal.ONE);
    if (expectedAmount.subtract(amount).abs().compareTo(tolerance) > 0) {
      throw new DrivonException(
              ErrorCode.FUEL_PRICE_MISMATCH,
              "Litres × price per litre comes to Rs. "
                  + expectedAmount.toPlainString()
                  + ", which doesn't match the amount. Check the three values.")
          .with("expectedAmount", expectedAmount.toPlainString());
    }
    return price;
  }

  private FuelRecord find(UUID vehicleId, UUID recordId) {
    return records
        .findByIdAndVehicleId(recordId, vehicleId)
        .orElseThrow(() -> new DrivonException(ErrorCode.FUEL_RECORD_NOT_FOUND));
  }

  private FuelRecordResponse withEfficiency(FuelRecord record) {
    return FuelRecordMapper.toResponse(
        record, efficiencyByRecord(record.getVehicleId()).get(record.getId()));
  }

  /** km/L of every full fill that closes a stretch, keyed by record ID. */
  private Map<UUID, BigDecimal> efficiencyByRecord(UUID vehicleId) {
    return FuelEfficiencyCalculator.intervals(records.findFillsInOdometerOrder(vehicleId)).stream()
        .collect(
            Collectors.toMap(FuelInterval::closingFillId, FuelInterval::kmPerLitre, (a, b) -> a));
  }

  /** Amount ÷ litres in rupees; litres are always positive for saved fill-ups. */
  private static BigDecimal pricePerLitre(BigDecimal amount, BigDecimal litres) {
    return amount.divide(litres, 2, RoundingMode.HALF_UP);
  }

  private static @Nullable String blankToNull(@Nullable String value) {
    if (value == null || value.isBlank()) {
      return null;
    }
    return value.strip();
  }
}
