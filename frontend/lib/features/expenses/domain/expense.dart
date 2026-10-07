import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/utils/fixed_decimal.dart';

part 'expense.freezed.dart';

/// Spending categories. Wire values match the backend's enum. In spending
/// totals, fill-ups count as [fuel] and services as [maintenance].
enum ExpenseCategory {
  fuel('FUEL'),
  maintenance('MAINTENANCE'),
  repairs('REPAIRS'),
  insurance('INSURANCE'),
  parking('PARKING'),
  tolls('TOLLS'),
  washing('WASHING'),
  other('OTHER');

  const ExpenseCategory(this.wireValue);

  final String wireValue;

  /// Categories that already collect fill-ups or services automatically.
  bool get isFedByRecords => this == fuel || this == maintenance;

  static ExpenseCategory fromWire(String value) => values.firstWhere(
    (category) => category.wireValue == value,
    orElse: () => throw FormatException('Unknown expense category: $value'),
  );
}

/// A running cost logged by the user.
@freezed
abstract class Expense with _$Expense {
  const factory Expense({
    required String id,
    required String vehicleId,
    required ExpenseCategory category,
    required FixedDecimal amount,
    required DateTime date,
    String? notes,
  }) = _Expense;

  const Expense._();

  ExpenseDraft toDraft() => ExpenseDraft(
    category: category,
    amount: amount,
    date: date,
    notes: notes,
  );
}

@freezed
abstract class ExpenseDraft with _$ExpenseDraft {
  const factory ExpenseDraft({
    required ExpenseCategory category,
    required FixedDecimal amount,
    required DateTime date,
    String? notes,
  }) = _ExpenseDraft;
}

/// One category's total in a spending summary.
@freezed
abstract class CategoryTotal with _$CategoryTotal {
  const factory CategoryTotal({
    required ExpenseCategory category,
    required FixedDecimal total,

    /// Fill-ups, services and expenses that make up the total.
    required int count,
  }) = _CategoryTotal;
}

/// What a vehicle cost in a period, by category, calculated by the server.
@freezed
abstract class SpendingSummary with _$SpendingSummary {
  const factory SpendingSummary({
    required FixedDecimal total,

    /// Every category, largest first.
    required List<CategoryTotal> categories,
  }) = _SpendingSummary;
}

/// One vehicle's total in a comparison.
@freezed
abstract class VehicleTotal with _$VehicleTotal {
  const factory VehicleTotal({
    required String vehicleId,
    required String make,
    required String model,
    required String registrationNumber,
    required FixedDecimal total,
  }) = _VehicleTotal;
}
