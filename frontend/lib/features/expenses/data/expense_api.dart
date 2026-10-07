import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/monthly_amount.dart';
import '../../../core/models/paged.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/fixed_decimal.dart';
import '../domain/expense.dart';

FixedDecimal _money(Object? value) =>
    FixedDecimal.parse(value! as String, scale: FixedDecimal.moneyScale);

/// `ExpenseResponse` from the API.
Expense expenseFromJson(Map<String, dynamic> json) => Expense(
  id: json['id'] as String,
  vehicleId: json['vehicleId'] as String,
  category: ExpenseCategory.fromWire(json['category'] as String),
  amount: _money(json['amount']),
  date: ApiDate.parse(json['date'] as String),
  notes: json['notes'] as String?,
);

/// `SpendingSummaryResponse` from the API.
SpendingSummary spendingSummaryFromJson(Map<String, dynamic> json) =>
    SpendingSummary(
      total: _money(json['total']),
      categories: (json['categories'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(
            (item) => CategoryTotal(
              category: ExpenseCategory.fromWire(item['category'] as String),
              total: _money(item['total']),
              count: (item['count'] as num).toInt(),
            ),
          )
          .toList(),
    );

/// `ExpenseRequest` body; [id] only when creating.
Map<String, dynamic> expenseRequestJson(ExpenseDraft draft, {String? id}) {
  final notes = draft.notes?.trim();
  return {
    'id': ?id,
    'category': draft.category.wireValue,
    'amount': draft.amount.toPlainString(),
    'date': ApiDate.format(draft.date),
    'notes': notes == null || notes.isEmpty ? null : notes,
  };
}

/// HTTP calls for expenses and spending totals. Throws AppExceptions.
class ExpenseApi {
  ExpenseApi(this._dio);

  final Dio _dio;

  static String _vehicle(String vehicleId) => '/api/v1/vehicles/$vehicleId';

  /// Expenses, newest first.
  Future<Paged<Expense>> list(
    String vehicleId, {
    required int page,
    int size = 20,
  }) => guardApi(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '${_vehicle(vehicleId)}/expenses',
      queryParameters: {'page': page, 'size': size},
    );
    return Paged.fromJson(response.data!, expenseFromJson);
  });

  Future<Expense> get(String vehicleId, String id) => guardApi(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '${_vehicle(vehicleId)}/expenses/$id',
    );
    return expenseFromJson(response.data!);
  });

  Future<Expense> create(
    String vehicleId,
    ExpenseDraft draft, {
    required String id,
  }) => guardApi(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '${_vehicle(vehicleId)}/expenses',
      data: expenseRequestJson(draft, id: id),
    );
    return expenseFromJson(response.data!);
  });

  Future<Expense> update(String vehicleId, String id, ExpenseDraft draft) =>
      guardApi(() async {
        final response = await _dio.put<Map<String, dynamic>>(
          '${_vehicle(vehicleId)}/expenses/$id',
          data: expenseRequestJson(draft),
        );
        return expenseFromJson(response.data!);
      });

  Future<void> delete(String vehicleId, String id) =>
      guardApi(() => _dio.delete<void>('${_vehicle(vehicleId)}/expenses/$id'));

  /// Spend by category from [from] (open start when null) to today.
  Future<SpendingSummary> summary(String vehicleId, {DateTime? from}) =>
      guardApi(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          '${_vehicle(vehicleId)}/spending',
          queryParameters: {
            'from': ?(from == null ? null : ApiDate.format(from)),
          },
        );
        return spendingSummaryFromJson(response.data!);
      });

  /// Total spend for the last [months] months, oldest first.
  Future<List<MonthlyAmount>> monthly(
    String vehicleId, {
    required int months,
  }) => guardApi(() async {
    final response = await _dio.get<List<dynamic>>(
      '${_vehicle(vehicleId)}/spending/monthly',
      queryParameters: {'months': months},
    );
    return response.data!
        .cast<Map<String, dynamic>>()
        .map(MonthlyAmount.fromJson)
        .toList();
  });

  /// Each of the user's vehicles' total from [from] to today.
  Future<List<VehicleTotal>> byVehicle({DateTime? from}) => guardApi(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/spending/vehicles',
      queryParameters: {'from': ?(from == null ? null : ApiDate.format(from))},
    );
    return (response.data!['vehicles'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(
          (item) => VehicleTotal(
            vehicleId: item['vehicleId'] as String,
            make: item['make'] as String,
            model: item['model'] as String,
            registrationNumber: item['registrationNumber'] as String,
            total: _money(item['total']),
          ),
        )
        .toList();
  });
}

final expenseApiProvider = Provider<ExpenseApi>(
  (ref) => ExpenseApi(ref.watch(dioProvider)),
);
