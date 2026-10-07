import 'package:flutter/material.dart';

import '../../../../core/models/monthly_amount.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/utils/number_format.dart';
import '../../../../design_system/design_system.dart';

/// Recent months' totals as bars, newest first, with an optional footnote
/// (e.g. the all-time total). Shared by the Fuel and Expenses tabs.
class MonthlySpendCard extends StatelessWidget {
  const MonthlySpendCard({
    required this.title,
    required this.months,
    this.footnote,
    super.key,
  });

  final String title;

  /// Oldest first, as the API sends them; the last is the current month.
  final List<MonthlyAmount> months;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final largest = months.fold<int>(
      0,
      (max, month) => month.total.units > max ? month.total.units : max,
    );
    final newestFirst = months.reversed.toList();

    return DrivonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: textTheme.titleMedium),
          ),
          const SizedBox(height: DrivonSpacing.lg),
          BarList(
            items: [
              for (final (index, month) in newestFirst.indexed)
                BarListItem(
                  label: formatMonthYear(context, month.month),
                  value: formatRupees(context, month.total),
                  fraction: largest == 0 ? 0 : month.total.units / largest,
                  emphasized: index == 0,
                ),
            ],
          ),
          if (footnote != null) ...[
            const SizedBox(height: DrivonSpacing.lg),
            Text(footnote!, style: textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
