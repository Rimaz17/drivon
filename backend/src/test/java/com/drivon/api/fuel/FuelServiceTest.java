package com.drivon.api.fuel;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.drivon.api.common.error.DrivonException;
import com.drivon.api.common.error.ErrorCode;
import com.drivon.api.common.time.BusinessCalendar;
import com.drivon.api.common.web.CreateResult;
import com.drivon.api.fuel.FuelRecord.FuelDetails;
import com.drivon.api.vehicle.OdometerService;
import com.drivon.api.vehicle.OdometerSource;
import com.drivon.api.vehicle.Vehicle;
import com.drivon.api.vehicle.VehicleService;
import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.YearMonth;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.mockito.InOrder;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;

class FuelServiceTest {

  private static final UUID USER = UUID.randomUUID();
  private static final UUID VEHICLE = UUID.randomUUID();
  private static final LocalDate TODAY = LocalDate.of(2026, 10, 7);

  private final FuelRecordRepository records = mock(FuelRecordRepository.class);
  private final VehicleService vehicles = mock(VehicleService.class);
  private final OdometerService odometer = mock(OdometerService.class);
  private final Vehicle vehicle = mock(Vehicle.class);
  private final FuelService service =
      new FuelService(
          records,
          vehicles,
          odometer,
          new BusinessCalendar(Clock.fixed(Instant.parse("2026-10-07T04:30:00Z"), ZoneOffset.UTC)));

  @BeforeEach
  void setUp() {
    when(odometer.lockVehicle(USER, VEHICLE)).thenReturn(vehicle);
    when(records.saveAndFlush(any())).thenAnswer(i -> i.getArgument(0));
    when(records.findById(any())).thenReturn(Optional.empty());
  }

  private static FuelRecordRequest request(
      UUID id, String litres, String amount, String price, LocalDate date) {
    return new FuelRecordRequest(
        id,
        date,
        new BigDecimal(litres),
        new BigDecimal(amount),
        price == null ? null : new BigDecimal(price),
        10_450,
        true,
        "  Ceypetco Kollupitiya  ");
  }

  private static FuelRecordRequest request(String litres, String amount, String price) {
    return request(null, litres, amount, price, TODAY);
  }

  private static FuelRecord stored(UUID vehicleId) {
    return new FuelRecord(
        null,
        vehicleId,
        new FuelDetails(
            TODAY,
            new BigDecimal("30.000"),
            new BigDecimal("10950.00"),
            new BigDecimal("365.00"),
            10_450,
            true,
            null));
  }

  private static ErrorCode codeOf(Throwable error) {
    return ((DrivonException) error).code();
  }

  @Test
  void derivesThePricePerLitreWhenItIsLeftOut() {
    FuelRecordResponse saved = service.create(USER, VEHICLE, request("30", "10950", null)).record();

    assertThat(saved.pricePerLitre()).isEqualByComparingTo("365.00");
    assertThat(saved.litres()).isEqualByComparingTo("30.000");
    assertThat(saved.station()).isEqualTo("Ceypetco Kollupitiya");
  }

  @Test
  void acceptsAPriceThatMatchesTheRoundedPumpAmount() {
    // 30.123 L × Rs. 365.00 = Rs. 10,994.90, rounded at the pump to Rs. 10,995.
    FuelRecordResponse saved =
        service.create(USER, VEHICLE, request("30.123", "10995", "365")).record();

    assertThat(saved.pricePerLitre()).isEqualByComparingTo("365.00");
    assertThat(saved.amount()).isEqualByComparingTo("10995.00");
  }

  @Test
  void rejectsAPriceThatDoesNotMatchTheAmountAndLitres() {
    assertThatThrownBy(() -> service.create(USER, VEHICLE, request("30", "12000", "365")))
        .isInstanceOfSatisfying(
            DrivonException.class,
            e -> {
              assertThat(e.code()).isEqualTo(ErrorCode.FUEL_PRICE_MISMATCH);
              assertThat(e.properties()).containsEntry("expectedAmount", "10950.00");
            });
    verify(records, never()).saveAndFlush(any());
  }

  @Test
  void theToleranceIsAtLeastOneRupeeForSmallAmounts() {
    // 0.2 L × Rs. 365.00 = Rs. 73.00; 1% of the amount is under a rupee, so Rs. 1 applies.
    assertThat(
            FuelService.resolvePricePerLitre(
                new BigDecimal("0.200"), new BigDecimal("74.00"), new BigDecimal("365.00")))
        .isEqualByComparingTo("365.00");
    assertThatThrownBy(
            () ->
                FuelService.resolvePricePerLitre(
                    new BigDecimal("0.200"), new BigDecimal("74.01"), new BigDecimal("365.00")))
        .extracting(FuelServiceTest::codeOf)
        .isEqualTo(ErrorCode.FUEL_PRICE_MISMATCH);
  }

  @Test
  void theToleranceIsOnePercentForLargerAmounts() {
    // 30 L × Rs. 365.00 = Rs. 10,950.00; 1% of Rs. 11,059 is Rs. 110.59.
    assertThat(
            FuelService.resolvePricePerLitre(
                new BigDecimal("30.000"), new BigDecimal("11059.00"), new BigDecimal("365.00")))
        .isEqualByComparingTo("365.00");
    assertThatThrownBy(
            () ->
                FuelService.resolvePricePerLitre(
                    new BigDecimal("30.000"), new BigDecimal("11062.00"), new BigDecimal("365.00")))
        .extracting(FuelServiceTest::codeOf)
        .isEqualTo(ErrorCode.FUEL_PRICE_MISMATCH);
  }

  @Test
  void rejectsAnAmountTooSmallToGiveAPrice() {
    assertThatThrownBy(() -> service.create(USER, VEHICLE, request("999", "0.01", null)))
        .extracting(FuelServiceTest::codeOf)
        .isEqualTo(ErrorCode.FUEL_PRICE_MISMATCH);
  }

  @Test
  void putsTheOdometerOnTheTimelineBeforeSaving() {
    FuelRecordResponse saved = service.create(USER, VEHICLE, request("30", "10950", null)).record();

    InOrder order = inOrder(odometer, records);
    order.verify(odometer).lockVehicle(USER, VEHICLE);
    order.verify(odometer).recordLinked(vehicle, OdometerSource.FUEL, saved.id(), TODAY, 10_450);
    order.verify(records).saveAndFlush(any());
  }

  @Test
  void rejectsFutureFillUpsBeforeTouchingTheOdometer() {
    assertThatThrownBy(
            () ->
                service.create(
                    USER, VEHICLE, request(null, "30", "10950", null, TODAY.plusDays(1))))
        .extracting(FuelServiceTest::codeOf)
        .isEqualTo(ErrorCode.DATE_IN_FUTURE);
    verify(odometer, never()).recordLinked(any(), any(), any(), any(), anyInt());
  }

  @Test
  void keepsTheClientGeneratedId() {
    UUID clientId = UUID.randomUUID();

    CreateResult<FuelRecordResponse> saved =
        service.create(USER, VEHICLE, request(clientId, "30", "10950", null, TODAY));

    assertThat(saved.created()).isTrue();
    assertThat(saved.record().id()).isEqualTo(clientId);
  }

  @Test
  void aRetriedCreateReturnsTheRecordAlreadySaved() {
    FuelRecord existing = stored(VEHICLE);
    when(records.findById(existing.getId())).thenReturn(Optional.of(existing));

    CreateResult<FuelRecordResponse> retry =
        service.create(USER, VEHICLE, request(existing.getId(), "99", "1", null, TODAY));

    assertThat(retry.created()).isFalse();
    assertThat(retry.record().amount()).isEqualByComparingTo("10950.00");
    verify(records, never()).saveAndFlush(any());
    verify(odometer, never()).recordLinked(any(), any(), any(), any(), anyInt());
  }

  @Test
  void anIdUsedUnderAnotherVehicleIsAConflict() {
    FuelRecord elsewhere = stored(UUID.randomUUID());
    when(records.findById(elsewhere.getId())).thenReturn(Optional.of(elsewhere));

    assertThatThrownBy(
            () ->
                service.create(
                    USER, VEHICLE, request(elsewhere.getId(), "30", "10950", null, TODAY)))
        .extracting(FuelServiceTest::codeOf)
        .isEqualTo(ErrorCode.RECORD_ID_CONFLICT);
  }

  @Test
  void updateMovesTheOdometerReadingWithTheRecord() {
    FuelRecord existing = stored(VEHICLE);
    when(records.findByIdAndVehicleId(existing.getId(), VEHICLE)).thenReturn(Optional.of(existing));

    FuelRecordResponse updated =
        service.update(
            USER,
            VEHICLE,
            existing.getId(),
            new FuelRecordRequest(
                null,
                TODAY.minusDays(2),
                new BigDecimal("20"),
                new BigDecimal("7300"),
                null,
                10_300,
                false,
                ""));

    verify(odometer)
        .recordLinked(vehicle, OdometerSource.FUEL, existing.getId(), TODAY.minusDays(2), 10_300);
    assertThat(updated.fullTank()).isFalse();
    assertThat(updated.station()).isNull();
    assertThat(updated.odometerKm()).isEqualTo(10_300);
  }

  @Test
  void deleteRemovesTheRecordAndItsReading() {
    FuelRecord existing = stored(VEHICLE);
    when(records.findByIdAndVehicleId(existing.getId(), VEHICLE)).thenReturn(Optional.of(existing));

    service.delete(USER, VEHICLE, existing.getId());

    verify(records).delete(existing);
    verify(odometer).removeLinked(vehicle, existing.getId());
  }

  @Test
  void aFillUpUnderAnotherVehicleIsNotFound() {
    UUID recordId = UUID.randomUUID();
    when(records.findByIdAndVehicleId(recordId, VEHICLE)).thenReturn(Optional.empty());

    assertThatThrownBy(() -> service.get(USER, VEHICLE, recordId))
        .extracting(FuelServiceTest::codeOf)
        .isEqualTo(ErrorCode.FUEL_RECORD_NOT_FOUND);
    assertThatThrownBy(() -> service.delete(USER, VEHICLE, recordId))
        .extracting(FuelServiceTest::codeOf)
        .isEqualTo(ErrorCode.FUEL_RECORD_NOT_FOUND);
  }

  @Test
  void listingChecksOwnershipAndShowsKmPerLitreOnClosingFullFills() {
    FuelRecord first = stored(VEHICLE);
    FuelRecord second = stored(VEHICLE);
    when(records.findByVehicleId(eq(VEHICLE), any()))
        .thenReturn(new PageImpl<>(List.of(second, first), PageRequest.of(0, 20), 2));
    when(records.findFillsInOdometerOrder(VEHICLE))
        .thenReturn(
            List.of(
                new FuelFill(
                    first.getId(),
                    TODAY.minusDays(9),
                    10_000,
                    new BigDecimal("30"),
                    new BigDecimal("10950"),
                    true),
                new FuelFill(
                    second.getId(),
                    TODAY,
                    10_450,
                    new BigDecimal("30"),
                    new BigDecimal("10950"),
                    true)));

    var page = service.list(USER, VEHICLE, PageRequest.of(0, 20));

    verify(vehicles).requireOwned(USER, VEHICLE);
    assertThat(page.content().get(0).kmPerLitre()).isEqualByComparingTo("15.00");
    assertThat(page.content().get(1).kmPerLitre()).isNull();
    ArgumentCaptor<org.springframework.data.domain.Pageable> pageable =
        ArgumentCaptor.forClass(org.springframework.data.domain.Pageable.class);
    verify(records).findByVehicleId(eq(VEHICLE), pageable.capture());
    assertThat(pageable.getValue().getSort().getOrderFor("date")).isNotNull();
  }

  private static FuelFill fill(LocalDate date, int odometer, String litres, boolean full) {
    BigDecimal quantity = new BigDecimal(litres);
    return new FuelFill(
        UUID.randomUUID(),
        date,
        odometer,
        quantity,
        quantity.multiply(new BigDecimal("365")),
        full);
  }

  @Test
  void statsUseOnlyTheStretchesThatEndedInTheRange() {
    FuelRecordRepository.Totals totals = mock(FuelRecordRepository.Totals.class);
    when(totals.getAmount()).thenReturn(new BigDecimal("18250"));
    when(totals.getLitres()).thenReturn(new BigDecimal("50"));
    when(totals.getFillUps()).thenReturn(2L);
    LocalDate from = LocalDate.of(2026, 9, 1);
    LocalDate to = LocalDate.of(2026, 9, 30);
    when(records.sumBetween(VEHICLE, from, to)).thenReturn(totals);
    when(records.findFillsInOdometerOrder(VEHICLE))
        .thenReturn(
            List.of(
                fill(LocalDate.of(2026, 8, 1), 10_000, "30", true),
                fill(LocalDate.of(2026, 8, 20), 10_600, "40", true), // 15 km/L, ends in August
                fill(LocalDate.of(2026, 9, 10), 10_900, "20", true), // 15 km/L
                fill(LocalDate.of(2026, 9, 25), 11_200, "30", true))); // 10 km/L

    FuelStatsResponse stats = service.stats(USER, VEHICLE, from, to);

    verify(vehicles).requireOwned(USER, VEHICLE);
    assertThat(stats.totalSpend().toPlainString()).isEqualTo("18250.00");
    assertThat(stats.totalLitres().toPlainString()).isEqualTo("50.000");
    assertThat(stats.fillUps()).isEqualTo(2);
    assertThat(stats.trackedDistanceKm()).isEqualTo(600);
    assertThat(stats.averageKmPerLitre()).isEqualByComparingTo("12.00"); // 600 km / 50 L
    assertThat(stats.bestKmPerLitre()).isEqualByComparingTo("15.00");
    assertThat(stats.latestKmPerLitre()).isEqualByComparingTo("10.00");
    assertThat(stats.costPerKm()).isEqualByComparingTo("30.42"); // Rs. 18,250 / 600 km
  }

  @Test
  void statsHaveNoEfficiencyBeforeTwoFullFills() {
    FuelRecordRepository.Totals totals = mock(FuelRecordRepository.Totals.class);
    when(totals.getAmount()).thenReturn(BigDecimal.ZERO);
    when(totals.getLitres()).thenReturn(BigDecimal.ZERO);
    when(records.sumBetween(eq(VEHICLE), any(), any())).thenReturn(totals);
    when(records.findFillsInOdometerOrder(VEHICLE))
        .thenReturn(List.of(fill(TODAY, 10_000, "30", true)));

    FuelStatsResponse stats = service.stats(USER, VEHICLE, null, null);

    assertThat(stats.from()).isEqualTo(BusinessCalendar.EARLIEST);
    assertThat(stats.to()).isEqualTo(TODAY);
    assertThat(stats.totalSpend().toPlainString()).isEqualTo("0.00");
    assertThat(stats.averageKmPerLitre()).isNull();
    assertThat(stats.costPerKm()).isNull();
    assertThat(stats.trackedDistanceKm()).isZero();
  }

  @Test
  void monthlySpendCoversTheLastMonthsUpToThisOne() {
    when(records.sumByMonth(VEHICLE, LocalDate.of(2026, 5, 1), LocalDate.of(2026, 10, 31)))
        .thenReturn(List.of());

    var months = service.monthlySpend(USER, VEHICLE, 6);

    verify(vehicles).requireOwned(USER, VEHICLE);
    assertThat(months).hasSize(6);
    assertThat(months.get(0).month()).isEqualTo(YearMonth.of(2026, 5));
    assertThat(months.get(5).month()).isEqualTo(YearMonth.of(2026, 10));
    assertThat(months.get(5).total().toPlainString()).isEqualTo("0.00");
  }

  @Test
  void efficiencyTrendListsTheTanksThatEndedInTheRangeOldestFirst() {
    when(records.findFillsInOdometerOrder(VEHICLE))
        .thenReturn(
            List.of(
                fill(LocalDate.of(2026, 8, 1), 10_000, "30", true),
                fill(LocalDate.of(2026, 8, 20), 10_600, "40", true), // ends in August
                fill(LocalDate.of(2026, 9, 1), 10_750, "8", false),
                fill(LocalDate.of(2026, 9, 10), 10_900, "12", true), // partial + full: 20 L
                fill(LocalDate.of(2026, 9, 25), 11_200, "30", true)));

    List<EfficiencyPoint> trend =
        service.efficiencyTrend(USER, VEHICLE, LocalDate.of(2026, 9, 1), LocalDate.of(2026, 9, 30));

    verify(vehicles).requireOwned(USER, VEHICLE);
    assertThat(trend)
        .extracting(EfficiencyPoint::endDate)
        .containsExactly(LocalDate.of(2026, 9, 10), LocalDate.of(2026, 9, 25));
    EfficiencyPoint first = trend.get(0);
    assertThat(first.startDate()).isEqualTo(LocalDate.of(2026, 8, 20));
    assertThat(first.distanceKm()).isEqualTo(300);
    assertThat(first.litres().toPlainString()).isEqualTo("20.000");
    assertThat(first.kmPerLitre()).isEqualByComparingTo("15.00");
    assertThat(first.costPerKm()).isEqualByComparingTo("24.33"); // Rs. 7,300 / 300 km
    assertThat(trend.get(1).kmPerLitre()).isEqualByComparingTo("10.00");
  }

  @Test
  void efficiencyTrendIsEmptyUntilTheSecondFullFill() {
    when(records.findFillsInOdometerOrder(VEHICLE))
        .thenReturn(List.of(fill(TODAY, 10_000, "30", true)));

    assertThat(service.efficiencyTrend(USER, VEHICLE, null, null)).isEmpty();
  }
}
