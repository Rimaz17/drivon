import 'package:drivon/core/utils/date_format.dart';
import 'package:drivon/core/utils/fixed_decimal.dart';
import 'package:drivon/core/utils/number_format.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_app.dart';

FixedDecimal money(String text) =>
    FixedDecimal.parse(text, scale: FixedDecimal.moneyScale);

/// Runs [check] with a BuildContext that has the app's localizations.
Future<void> withContext(
  WidgetTester tester,
  void Function(BuildContext context) check,
) async {
  late BuildContext captured;
  await tester.pumpWidget(
    localizedApp(
      Builder(
        builder: (context) {
          captured = context;
          return const SizedBox();
        },
      ),
    ),
  );
  check(captured);
}

void main() {
  testWidgets('formats rupees with grouping and cents only when present', (
    tester,
  ) async {
    await withContext(tester, (context) {
      expect(formatRupees(context, money('18500.00')), 'Rs. 18,500');
      expect(formatRupees(context, money('3694.90')), 'Rs. 3,694.90');
      expect(formatRupees(context, money('3694.95')), 'Rs. 3,694.95');
      expect(
        formatRupees(context, money('365.00'), showCents: true),
        'Rs. 365.00',
      );
      expect(formatRupees(context, money('0.00')), 'Rs. 0');
    });
  });

  testWidgets('formats decimals with grouping', (tester) async {
    await withContext(tester, (context) {
      final litres = FixedDecimal.parse('1250.500', scale: 3);
      expect(formatDecimal(context, litres), '1,250.5');
      expect(formatDecimal(context, litres, trimZeros: false), '1,250.500');
      expect(formatInteger(context, 45000), '45,000');
    });
  });

  testWidgets('formats dates day first and months by name', (tester) async {
    await withContext(tester, (context) {
      expect(formatDate(context, DateTime(2026, 10, 7)), '7 Oct 2026');
      expect(formatMonthYear(context, DateTime(2026, 9)), 'September 2026');
      expect(formatShortMonth(context, DateTime(2026, 9)), 'Sep');
    });
  });

  test('reads and writes API dates without time zones', () {
    expect(ApiDate.parse('2026-10-07'), DateTime(2026, 10, 7));
    expect(ApiDate.format(DateTime(2026, 1, 5, 23, 59)), '2026-01-05');
    expect(ApiDate.parseMonth('2026-10'), DateTime(2026, 10));
    expect(today(DateTime(2026, 10, 7, 18, 30)), DateTime(2026, 10, 7));
  });
}
