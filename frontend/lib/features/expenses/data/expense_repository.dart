import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/monthly_amount.dart';
import '../../../core/models/paged.dart';
import '../../../core/utils/uuid.dart';
import '../domain/expense.dart';
import 'expense_api.dart';

/// Periods the Expenses tab can total over.
enum SpendingPeriod {
  thisMonth,
  thisYear,
  allTime;

  /// First day of the period, or null for all time; the period ends today.
  DateTime? start(DateTime today) => switch (this) {
    SpendingPeriod.thisMonth => DateTime(today.year, today.month),
    SpendingPeriod.thisYear => DateTime(today.year),
    SpendingPeriod.allTime => null,
  };
}

/// Expenses and spending totals. The server adds fill-ups (as fuel) and
/// services (as maintenance) to expenses and calculates every total.
class ExpenseRepository {
  ExpenseRepository(this._api, {this._newId = uuidV4});

  final ExpenseApi _api;
  final String Function() _newId;

  Future<Paged<Expense>> list(String vehicleId, {required int page}) =>
      _api.list(vehicleId, page: page);

  Future<Expense> get(String vehicleId, String id) => _api.get(vehicleId, id);

  Future<Expense> create(String vehicleId, ExpenseDraft draft) =>
      _api.create(vehicleId, draft, id: _newId());

  Future<Expense> update(String vehicleId, String id, ExpenseDraft draft) =>
      _api.update(vehicleId, id, draft);

  Future<void> delete(String vehicleId, String id) =>
      _api.delete(vehicleId, id);

  Future<SpendingSummary> summary(
    String vehicleId,
    SpendingPeriod period,
    DateTime today,
  ) => _api.summary(vehicleId, from: period.start(today));

  Future<List<MonthlyAmount>> monthly(String vehicleId, {int months = 6}) =>
      _api.monthly(vehicleId, months: months);

  Future<List<VehicleTotal>> byVehicle(SpendingPeriod period, DateTime today) =>
      _api.byVehicle(from: period.start(today));
}

final expenseRepositoryProvider = Provider<ExpenseRepository>(
  (ref) => ExpenseRepository(ref.watch(expenseApiProvider)),
);
