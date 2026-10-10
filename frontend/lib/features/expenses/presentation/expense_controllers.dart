import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/monthly_amount.dart';
import '../../../core/models/paged.dart';
import '../../../core/ui/paged_list_controller.dart';
import '../../../core/utils/date_format.dart';
import '../../analytics/presentation/analytics_controllers.dart';
import '../../auth/presentation/session_controller.dart';
import '../data/expense_repository.dart';
import '../domain/expense.dart';

/// The period the Expenses tab totals over; this month by default.
class SpendingPeriodController extends Notifier<SpendingPeriod> {
  @override
  SpendingPeriod build() => SpendingPeriod.thisMonth;

  void select(SpendingPeriod period) => state = period;
}

final spendingPeriodProvider =
    NotifierProvider<SpendingPeriodController, SpendingPeriod>(
      SpendingPeriodController.new,
    );

/// A vehicle's expenses, newest first, a page at a time.
class ExpenseHistoryController extends PagedListController<Expense> {
  ExpenseHistoryController(this.vehicleId);

  final String vehicleId;

  @override
  Future<Paged<Expense>> fetchPage(int page) =>
      ref.read(expenseRepositoryProvider).list(vehicleId, page: page);
}

final expenseHistoryProvider = AsyncNotifierProvider.autoDispose
    .family<ExpenseHistoryController, PagedList<Expense>, String>(
      ExpenseHistoryController.new,
      // Failures are shown with a retry button instead of retried silently.
      retry: (_, _) => null,
    );

/// A vehicle's spend by category over a period.
final spendingSummaryProvider = FutureProvider.autoDispose
    .family<SpendingSummary, ({String vehicleId, SpendingPeriod period})>((
      ref,
      key,
    ) {
      ref.watch(currentUserProvider);
      return ref
          .read(expenseRepositoryProvider)
          .summary(key.vehicleId, key.period, today());
    }, retry: (_, _) => null);

/// A vehicle's total spend for the last six months, oldest first.
final monthlySpendingProvider = FutureProvider.autoDispose
    .family<List<MonthlyAmount>, String>((ref, vehicleId) {
      ref.watch(currentUserProvider);
      return ref.read(expenseRepositoryProvider).monthly(vehicleId);
    }, retry: (_, _) => null);

/// Each of the user's vehicles' total over a period, to compare them.
final vehicleTotalsProvider = FutureProvider.autoDispose
    .family<List<VehicleTotal>, SpendingPeriod>((ref, period) {
      ref.watch(currentUserProvider);
      return ref.read(expenseRepositoryProvider).byVehicle(period, today());
    }, retry: (_, _) => null);

/// An expense to edit, from the loaded history when possible.
final expenseProvider = FutureProvider.autoDispose
    .family<Expense, ({String vehicleId, String expenseId})>((ref, key) {
      final loaded = ref.read(expenseHistoryProvider(key.vehicleId)).value;
      for (final expense in loaded?.items ?? const <Expense>[]) {
        if (expense.id == key.expenseId) return expense;
      }
      return ref
          .read(expenseRepositoryProvider)
          .get(key.vehicleId, key.expenseId);
    }, retry: (_, _) => null);

/// Reloads every spending total, and the Insights figures built on them.
/// Fill-ups, services and expenses all feed them, so each of those features
/// calls this after a change.
void refreshSpending(Ref ref) {
  ref
    ..invalidate(spendingSummaryProvider)
    ..invalidate(monthlySpendingProvider)
    ..invalidate(vehicleTotalsProvider);
  refreshInsights(ref.invalidate);
}

/// Logs, edits and deletes expenses, then refreshes the list and totals.
/// Throws AppExceptions for forms to explain.
class ExpenseMutations {
  ExpenseMutations(this._ref);

  final Ref _ref;

  ExpenseRepository get _repository => _ref.read(expenseRepositoryProvider);

  Future<void> add(String vehicleId, ExpenseDraft draft) async {
    await _repository.create(vehicleId, draft);
    _refresh(vehicleId);
  }

  Future<void> edit(String vehicleId, String id, ExpenseDraft draft) async {
    await _repository.update(vehicleId, id, draft);
    _refresh(vehicleId);
  }

  Future<void> remove(String vehicleId, String id) async {
    await _repository.delete(vehicleId, id);
    _refresh(vehicleId);
  }

  void _refresh(String vehicleId) {
    _ref.invalidate(expenseHistoryProvider(vehicleId));
    refreshSpending(_ref);
  }
}

final expenseMutationsProvider = Provider<ExpenseMutations>(
  ExpenseMutations.new,
);
