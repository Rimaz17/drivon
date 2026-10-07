import 'package:drivon/core/errors/app_exception.dart';
import 'package:drivon/core/models/monthly_amount.dart';
import 'package:drivon/core/models/paged.dart';
import 'package:drivon/core/utils/fixed_decimal.dart';
import 'package:drivon/features/expenses/data/expense_api.dart';
import 'package:drivon/features/expenses/domain/expense.dart';

FixedDecimal rupees(String text) => FixedDecimal.parse(text, scale: 2);

Expense expense({
  String id = 'expense-1',
  ExpenseCategory category = ExpenseCategory.insurance,
  String amount = '45000.00',
  DateTime? date,
  String? notes,
}) => Expense(
  id: id,
  vehicleId: 'vehicle-1',
  category: category,
  amount: rupees(amount),
  date: date ?? DateTime(2026, 10, 7),
  notes: notes,
);

/// A summary listing every category; [totals] sets some of them.
SpendingSummary spendingSummary(Map<ExpenseCategory, String> totals) {
  final categories = [
    for (final category in ExpenseCategory.values)
      CategoryTotal(
        category: category,
        total: rupees(totals[category] ?? '0'),
        count: totals.containsKey(category) ? 1 : 0,
      ),
  ]..sort((a, b) => b.total.compareTo(a.total));
  final total = categories.fold<int>(0, (sum, c) => sum + c.total.units);
  return SpendingSummary(total: FixedDecimal(total, 2), categories: categories);
}

/// In-memory [ExpenseApi] for tests. Totals are scripted.
class FakeExpenseApi implements ExpenseApi {
  FakeExpenseApi([List<Expense>? expenses]) : expenses = expenses ?? [];

  final List<Expense> expenses;
  SpendingSummary summaryResponse = spendingSummary(const {});
  List<MonthlyAmount> monthlyResponse = [
    for (var month = 5; month <= 10; month++)
      MonthlyAmount(month: DateTime(2026, month), total: rupees('0')),
  ];
  List<VehicleTotal> vehicleTotalsResponse = [];

  /// When set, the next call throws it once.
  AppException? nextError;
  final List<ExpenseDraft> savedDrafts = [];
  final List<DateTime?> summaryStarts = [];
  int summaryCalls = 0;

  @override
  Future<Paged<Expense>> list(
    String vehicleId, {
    required int page,
    int size = 20,
  }) async {
    _throwIfScripted();
    return Paged(items: List.of(expenses), hasMore: false);
  }

  @override
  Future<Expense> get(String vehicleId, String id) async {
    _throwIfScripted();
    return expenses.firstWhere((e) => e.id == id);
  }

  @override
  Future<Expense> create(
    String vehicleId,
    ExpenseDraft draft, {
    required String id,
  }) async {
    _throwIfScripted();
    savedDrafts.add(draft);
    final saved = _fromDraft(id, draft);
    expenses.insert(0, saved);
    return saved;
  }

  @override
  Future<Expense> update(
    String vehicleId,
    String id,
    ExpenseDraft draft,
  ) async {
    _throwIfScripted();
    savedDrafts.add(draft);
    final saved = _fromDraft(id, draft);
    expenses[expenses.indexWhere((e) => e.id == id)] = saved;
    return saved;
  }

  @override
  Future<void> delete(String vehicleId, String id) async {
    _throwIfScripted();
    expenses.removeWhere((e) => e.id == id);
  }

  @override
  Future<SpendingSummary> summary(String vehicleId, {DateTime? from}) async {
    _throwIfScripted();
    summaryCalls++;
    summaryStarts.add(from);
    return summaryResponse;
  }

  @override
  Future<List<MonthlyAmount>> monthly(
    String vehicleId, {
    required int months,
  }) async => monthlyResponse;

  @override
  Future<List<VehicleTotal>> byVehicle({DateTime? from}) async =>
      vehicleTotalsResponse;

  void _throwIfScripted() {
    final error = nextError;
    if (error != null) {
      nextError = null;
      throw error;
    }
  }

  static Expense _fromDraft(String id, ExpenseDraft draft) => Expense(
    id: id,
    vehicleId: 'vehicle-1',
    category: draft.category,
    amount: draft.amount,
    date: draft.date,
    notes: draft.notes,
  );
}
