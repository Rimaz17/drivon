import 'package:drivon/core/ui/date_form_field.dart';
import 'package:drivon/core/utils/date_format.dart';
import 'package:drivon/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Opens an empty or filled date field with dates allowed up to 2100, the
/// range of a next service date or a reminder's due date.
Future<void> _openPicker(
  WidgetTester tester, {
  required DateTime firstDate,
  DateTime? value,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: DrivonTheme.dark(),
      home: Scaffold(
        body: DateFormField(
          label: 'Next service date',
          doneLabel: 'Done',
          initialValue: value,
          firstDate: firstDate,
          lastDate: DateTime(2100),
          onChanged: (_) {},
        ),
      ),
    ),
  );
  await tester.tap(find.byType(InputDecorator));
  await tester.pumpAndSettle();
}

String _monthYear(WidgetTester tester, DateTime month) =>
    MaterialLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    ).formatMonthYear(month);

void main() {
  testWidgets('an empty date opens on the current month, not the last date', (
    tester,
  ) async {
    final now = today();
    await _openPicker(tester, firstDate: now);

    expect(find.text(_monthYear(tester, now)), findsOneWidget);
    expect(find.text(_monthYear(tester, DateTime(2100))), findsNothing);
  });

  testWidgets('an empty date whose first day is still ahead opens there', (
    tester,
  ) async {
    final first = today().add(const Duration(days: 70));
    await _openPicker(tester, firstDate: first);

    expect(find.text(_monthYear(tester, first)), findsOneWidget);
  });

  testWidgets('a chosen date opens on its own month', (tester) async {
    final now = today();
    final chosen = DateTime(now.year + 2, 3, 15);
    await _openPicker(tester, firstDate: now, value: chosen);

    expect(find.text(_monthYear(tester, chosen)), findsOneWidget);
  });
}
