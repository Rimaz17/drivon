import '../../../l10n/app_localizations.dart';
import '../domain/expense.dart';

extension ExpenseCategoryLabel on ExpenseCategory {
  String label(AppLocalizations l10n) => switch (this) {
    ExpenseCategory.fuel => l10n.categoryFuel,
    ExpenseCategory.maintenance => l10n.categoryMaintenance,
    ExpenseCategory.repairs => l10n.categoryRepairs,
    ExpenseCategory.insurance => l10n.categoryInsurance,
    ExpenseCategory.parking => l10n.categoryParking,
    ExpenseCategory.tolls => l10n.categoryTolls,
    ExpenseCategory.washing => l10n.categoryWashing,
    ExpenseCategory.other => l10n.categoryOther,
  };
}
