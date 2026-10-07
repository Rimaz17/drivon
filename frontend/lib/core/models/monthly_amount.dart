import 'package:flutter/foundation.dart';

import '../utils/date_format.dart';
import '../utils/fixed_decimal.dart';

/// A rupee total for one calendar month, as the API's monthly series send it.
@immutable
class MonthlyAmount {
  const MonthlyAmount({required this.month, required this.total});

  /// Reads `{"month": "2026-10", "total": "18500.00"}`.
  factory MonthlyAmount.fromJson(Map<String, dynamic> json) => MonthlyAmount(
    month: ApiDate.parseMonth(json['month'] as String),
    total: FixedDecimal.parse(
      json['total'] as String,
      scale: FixedDecimal.moneyScale,
    ),
  );

  /// The first day of the month.
  final DateTime month;
  final FixedDecimal total;

  @override
  bool operator ==(Object other) =>
      other is MonthlyAmount && other.month == month && other.total == total;

  @override
  int get hashCode => Object.hash(month, total);
}
