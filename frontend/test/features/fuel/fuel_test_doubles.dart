import 'package:drivon/core/errors/app_exception.dart';
import 'package:drivon/core/models/monthly_amount.dart';
import 'package:drivon/core/models/paged.dart';
import 'package:drivon/core/utils/date_format.dart';
import 'package:drivon/core/utils/fixed_decimal.dart';
import 'package:drivon/features/fuel/data/fuel_api.dart';
import 'package:drivon/features/fuel/data/fuel_dto.dart';
import 'package:drivon/features/fuel/domain/fuel_record.dart';

Map<String, dynamic> fuelRecordJson({
  String id = 'record-1',
  String date = '2026-10-07',
  String litres = '15.000',
  String amount = '5475.00',
  int odometerKm = 10500,
  bool fullTank = true,
  String? kmPerLitre,
}) => {
  'id': id,
  'vehicleId': 'vehicle-1',
  'date': date,
  'litres': litres,
  'amount': amount,
  'pricePerLitre': '365.00',
  'odometerKm': odometerKm,
  'fullTank': fullTank,
  'station': 'Ceypetco Kollupitiya',
  'kmPerLitre': kmPerLitre,
  'createdAt': '2026-10-07T04:30:00Z',
  'updatedAt': '2026-10-07T04:30:00Z',
};

FuelRecordDto fuelRecordDto({
  String id = 'record-1',
  String date = '2026-10-07',
  String litres = '15.000',
  String amount = '5475.00',
  int odometerKm = 10500,
  bool fullTank = true,
  String? kmPerLitre,
  String? station = 'Ceypetco Kollupitiya',
}) => FuelRecordDto(
  id: id,
  vehicleId: 'vehicle-1',
  date: date,
  litres: litres,
  amount: amount,
  pricePerLitre: '365.00',
  odometerKm: odometerKm,
  fullTank: fullTank,
  station: station,
  kmPerLitre: kmPerLitre,
);

FuelDraft fuelDraft({String? station = 'Ceypetco', int odometerKm = 10500}) =>
    FuelDraft(
      date: DateTime(2026, 10, 7),
      litres: FixedDecimal.parse('15', scale: 3),
      amount: FixedDecimal.parse('5475', scale: 2),
      pricePerLitre: FixedDecimal.parse('365', scale: 2),
      odometerKm: odometerKm,
      fullTank: true,
      station: station,
    );

FuelStatsDto fuelStatsDto({
  String totalSpend = '0.00',
  String totalLitres = '0.000',
  int fillUps = 0,
  int trackedDistanceKm = 0,
  String? averageKmPerLitre,
  String? bestKmPerLitre,
  String? latestKmPerLitre,
  String? costPerKm,
}) => FuelStatsDto(
  totalSpend: totalSpend,
  totalLitres: totalLitres,
  fillUps: fillUps,
  trackedDistanceKm: trackedDistanceKm,
  averageKmPerLitre: averageKmPerLitre,
  bestKmPerLitre: bestKmPerLitre,
  latestKmPerLitre: latestKmPerLitre,
  costPerKm: costPerKm,
);

/// In-memory [FuelApi] for tests. Stats and monthly spend are scripted;
/// records are kept newest first.
class FakeFuelApi implements FuelApi {
  FakeFuelApi({List<FuelRecordDto>? records, this.pageSize = 20})
    : records = records ?? [];

  final List<FuelRecordDto> records;
  final int pageSize;
  FuelStatsDto statsResponse = fuelStatsDto();
  List<MonthlyAmount> monthlyResponse = [
    for (var month = 5; month <= 10; month++)
      MonthlyAmount(
        month: DateTime(2026, month),
        total: const FixedDecimal(0, 2),
      ),
  ];

  /// When set, the next call throws it once.
  AppException? nextError;
  final List<String> createdIds = [];
  final List<FuelDraft> savedDrafts = [];
  int listCalls = 0;
  int statsCalls = 0;

  @override
  Future<Paged<FuelRecordDto>> list(
    String vehicleId, {
    required int page,
    int size = 20,
  }) async {
    listCalls++;
    _throwIfScripted();
    final start = page * pageSize;
    final end = (start + pageSize).clamp(0, records.length);
    return Paged(
      items: start >= records.length ? [] : records.sublist(start, end),
      hasMore: end < records.length,
    );
  }

  @override
  Future<FuelRecordDto> get(String vehicleId, String id) async {
    _throwIfScripted();
    return records.firstWhere(
      (r) => r.id == id,
      orElse: () => throw const ApiProblemException(
        statusCode: 404,
        code: 'FUEL_RECORD_NOT_FOUND',
      ),
    );
  }

  @override
  Future<FuelRecordDto> create(
    String vehicleId,
    FuelDraft draft, {
    required String id,
  }) async {
    _throwIfScripted();
    createdIds.add(id);
    savedDrafts.add(draft);
    final dto = _fromDraft(id, draft);
    records.insert(0, dto);
    return dto;
  }

  @override
  Future<FuelRecordDto> update(
    String vehicleId,
    String id,
    FuelDraft draft,
  ) async {
    _throwIfScripted();
    savedDrafts.add(draft);
    final dto = _fromDraft(id, draft);
    records[records.indexWhere((r) => r.id == id)] = dto;
    return dto;
  }

  @override
  Future<void> delete(String vehicleId, String id) async {
    _throwIfScripted();
    records.removeWhere((r) => r.id == id);
  }

  @override
  Future<FuelStatsDto> stats(String vehicleId) async {
    statsCalls++;
    _throwIfScripted();
    return statsResponse;
  }

  @override
  Future<List<MonthlyAmount>> monthly(
    String vehicleId, {
    required int months,
  }) async => monthlyResponse;

  void _throwIfScripted() {
    final error = nextError;
    if (error != null) {
      nextError = null;
      throw error;
    }
  }

  static FuelRecordDto _fromDraft(String id, FuelDraft draft) => FuelRecordDto(
    id: id,
    vehicleId: 'vehicle-1',
    date: ApiDate.format(draft.date),
    litres: draft.litres.toPlainString(),
    amount: draft.amount.toPlainString(),
    pricePerLitre: draft.pricePerLitre.toPlainString(),
    odometerKm: draft.odometerKm,
    fullTank: draft.fullTank,
    station: draft.station,
  );
}

MonthlyAmount fuelMonth(int year, int month, String total) => MonthlyAmount(
  month: DateTime(year, month),
  total: FixedDecimal.parse(total, scale: 2),
);
