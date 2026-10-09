import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/fixed_decimal.dart';
import '../domain/analytics.dart';

FixedDecimal _money(Object? value) =>
    FixedDecimal.parse(value! as String, scale: FixedDecimal.moneyScale);

FixedDecimal? _optionalMoney(Object? value) =>
    value == null ? null : _money(value);

List<GroupCost> _breakdown(Object? json) => (json! as List<dynamic>)
    .cast<Map<String, dynamic>>()
    .map(
      (item) => GroupCost(
        group: CostGroup.fromWire(item['group'] as String),
        total: _money(item['total']),
        costPerKm: _optionalMoney(item['costPerKm']),
      ),
    )
    .toList();

/// `CostPerKmResponse` from the API.
CostPerKm costPerKmFromJson(Map<String, dynamic> json) => CostPerKm(
  distanceKm: (json['distanceKm'] as num).toInt(),
  totalCost: _money(json['totalCost']),
  costPerKm: _optionalMoney(json['costPerKm']),
  breakdown: _breakdown(json['breakdown']),
);

/// `MonthlyCostResponse` from the API.
MonthlyCost monthlyCostFromJson(Map<String, dynamic> json) => MonthlyCost(
  month: ApiDate.parseMonth(json['month'] as String),
  fuel: _money(json['fuel']),
  maintenance: _money(json['maintenance']),
  other: _money(json['other']),
  total: _money(json['total']),
  distanceKm: (json['distanceKm'] as num).toInt(),
  costPerKm: _optionalMoney(json['costPerKm']),
);

/// `EfficiencyPoint` from the API.
EfficiencyPoint efficiencyPointFromJson(Map<String, dynamic> json) =>
    EfficiencyPoint(
      startDate: ApiDate.parse(json['startDate'] as String),
      endDate: ApiDate.parse(json['endDate'] as String),
      distanceKm: (json['distanceKm'] as num).toInt(),
      litres: FixedDecimal.parse(
        json['litres'] as String,
        scale: FixedDecimal.litresScale,
      ),
      kmPerLitre: FixedDecimal.parse(json['kmPerLitre'] as String, scale: 2),
      costPerKm: _money(json['costPerKm']),
    );

/// One entry of `VehicleComparisonResponse.vehicles`.
VehicleCost vehicleCostFromJson(Map<String, dynamic> json) {
  final average = json['averageKmPerLitre'] as String?;
  return VehicleCost(
    vehicleId: json['vehicleId'] as String,
    make: json['make'] as String,
    model: json['model'] as String,
    registrationNumber: json['registrationNumber'] as String,
    distanceKm: (json['distanceKm'] as num).toInt(),
    totalCost: _money(json['totalCost']),
    costPerKm: _optionalMoney(json['costPerKm']),
    breakdown: _breakdown(json['breakdown']),
    averageKmPerLitre: average == null
        ? null
        : FixedDecimal.parse(average, scale: 2),
  );
}

/// HTTP calls for running-cost analytics. Throws AppExceptions.
class AnalyticsApi {
  AnalyticsApi(this._dio);

  final Dio _dio;

  static String _vehicle(String vehicleId) =>
      '/api/v1/vehicles/$vehicleId/analytics';

  static Map<String, dynamic> _range(DateTime? from) => {
    'from': ?(from == null ? null : ApiDate.format(from)),
  };

  /// Cost per km from [from] (open start when null) to today.
  Future<CostPerKm> costPerKm(String vehicleId, {DateTime? from}) =>
      guardApi(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          '${_vehicle(vehicleId)}/cost-per-km',
          queryParameters: _range(from),
        );
        return costPerKmFromJson(response.data!);
      });

  /// The last [months] months up to this one, oldest first.
  Future<List<MonthlyCost>> monthlyCosts(
    String vehicleId, {
    required int months,
  }) => guardApi(() async {
    final response = await _dio.get<List<dynamic>>(
      '${_vehicle(vehicleId)}/monthly-costs',
      queryParameters: {'months': months},
    );
    return response.data!
        .cast<Map<String, dynamic>>()
        .map(monthlyCostFromJson)
        .toList();
  });

  /// Tanks that ended from [from] to today, oldest first.
  Future<List<EfficiencyPoint>> efficiencyTrend(
    String vehicleId, {
    DateTime? from,
  }) => guardApi(() async {
    final response = await _dio.get<List<dynamic>>(
      '${_vehicle(vehicleId)}/efficiency-trend',
      queryParameters: _range(from),
    );
    return response.data!
        .cast<Map<String, dynamic>>()
        .map(efficiencyPointFromJson)
        .toList();
  });

  /// Every vehicle of the user from [from] to today, oldest vehicle first.
  Future<List<VehicleCost>> compareVehicles({DateTime? from}) =>
      guardApi(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          '/api/v1/analytics/vehicle-comparison',
          queryParameters: _range(from),
        );
        return (response.data!['vehicles'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(vehicleCostFromJson)
            .toList();
      });
}

final analyticsApiProvider = Provider<AnalyticsApi>(
  (ref) => AnalyticsApi(ref.watch(dioProvider)),
);
