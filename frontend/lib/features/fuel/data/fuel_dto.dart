import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/utils/date_format.dart';
import '../../../core/utils/fixed_decimal.dart';
import '../domain/fuel_record.dart';

part 'fuel_dto.freezed.dart';
part 'fuel_dto.g.dart';

FixedDecimal _money(String value) =>
    FixedDecimal.parse(value, scale: FixedDecimal.moneyScale);

FixedDecimal? _moneyOrNull(String? value) =>
    value == null ? null : _money(value);

/// `FuelRecordResponse` from the API. Decimals arrive as strings.
@freezed
abstract class FuelRecordDto with _$FuelRecordDto {
  const factory FuelRecordDto({
    required String id,
    required String vehicleId,
    required String date,
    required String litres,
    required String amount,
    required String pricePerLitre,
    required int odometerKm,
    required bool fullTank,
    String? station,
    String? kmPerLitre,
  }) = _FuelRecordDto;

  const FuelRecordDto._();

  factory FuelRecordDto.fromJson(Map<String, dynamic> json) =>
      _$FuelRecordDtoFromJson(json);

  FuelRecord toDomain() => FuelRecord(
    id: id,
    vehicleId: vehicleId,
    date: ApiDate.parse(date),
    litres: FixedDecimal.parse(litres, scale: FixedDecimal.litresScale),
    amount: _money(amount),
    pricePerLitre: _money(pricePerLitre),
    odometerKm: odometerKm,
    fullTank: fullTank,
    station: station,
    kmPerLitre: _moneyOrNull(kmPerLitre),
  );
}

/// `FuelStatsResponse` from the API.
@freezed
abstract class FuelStatsDto with _$FuelStatsDto {
  const factory FuelStatsDto({
    required String totalSpend,
    required String totalLitres,
    required int fillUps,
    required int trackedDistanceKm,
    String? averageKmPerLitre,
    String? bestKmPerLitre,
    String? latestKmPerLitre,
    String? costPerKm,
  }) = _FuelStatsDto;

  const FuelStatsDto._();

  factory FuelStatsDto.fromJson(Map<String, dynamic> json) =>
      _$FuelStatsDtoFromJson(json);

  FuelStats toDomain() => FuelStats(
    totalSpend: _money(totalSpend),
    totalLitres: FixedDecimal.parse(
      totalLitres,
      scale: FixedDecimal.litresScale,
    ),
    fillUps: fillUps,
    trackedDistanceKm: trackedDistanceKm,
    averageKmPerLitre: _moneyOrNull(averageKmPerLitre),
    bestKmPerLitre: _moneyOrNull(bestKmPerLitre),
    latestKmPerLitre: _moneyOrNull(latestKmPerLitre),
    costPerKm: _moneyOrNull(costPerKm),
  );
}

/// `FuelRecordRequest` body. [id] is set only when creating, so a retried
/// request returns the saved record instead of a duplicate.
Map<String, dynamic> fuelRequestJson(FuelDraft draft, {String? id}) => {
  'id': ?id,
  'date': ApiDate.format(draft.date),
  'litres': draft.litres.toPlainString(),
  'amount': draft.amount.toPlainString(),
  'pricePerLitre': draft.pricePerLitre.toPlainString(),
  'odometerKm': draft.odometerKm,
  'fullTank': draft.fullTank,
  'station': ?_trimmedOrNull(draft.station),
};

/// A [FuelDraft] from a body written by [fuelRequestJson], as kept for
/// fill-ups saved offline.
FuelDraft fuelDraftFromRequestJson(Map<String, dynamic> json) => FuelDraft(
  date: ApiDate.parse(json['date'] as String),
  litres: FixedDecimal.parse(
    json['litres'] as String,
    scale: FixedDecimal.litresScale,
  ),
  amount: FixedDecimal.parse(
    json['amount'] as String,
    scale: FixedDecimal.moneyScale,
  ),
  pricePerLitre: FixedDecimal.parse(
    json['pricePerLitre'] as String,
    scale: FixedDecimal.moneyScale,
  ),
  odometerKm: (json['odometerKm'] as num).toInt(),
  fullTank: json['fullTank'] as bool,
  station: json['station'] as String?,
);

String? _trimmedOrNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
