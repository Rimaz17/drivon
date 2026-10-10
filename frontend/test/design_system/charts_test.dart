import 'package:drivon/design_system/design_system.dart';
import 'package:drivon/features/analytics/presentation/widgets/cost_charts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _themed(Widget child) => MaterialApp(
  theme: DrivonTheme.dark(),
  home: Scaffold(
    body: Center(child: SizedBox(width: 300, child: child)),
  ),
);

void main() {
  test('axis steps are round numbers at or above the rough step', () {
    expect(niceStep(34266), 50000);
    expect(niceStep(12000), 20000);
    expect(niceStep(800), 1000);
    expect(niceStep(4.2), 5);
    expect(niceStep(1), 1);
  });

  test('axis labels are compact rupee amounts', () {
    expect(compactRupees(950), '950');
    expect(compactRupees(1500), '1.5k');
    expect(compactRupees(50000), '50k');
    expect(compactRupees(1250000), '1.3M');
  });

  testWidgets('segmented bar splits its width in proportion, with gaps', (
    tester,
  ) async {
    await tester.pumpWidget(
      _themed(
        const SegmentedBar(
          semanticsLabel: 'Split',
          segments: [
            BarSegment(value: 3, color: Colors.purple),
            BarSegment(value: 0, color: Colors.teal),
            BarSegment(value: 1, color: Colors.orange),
          ],
        ),
      ),
    );

    final boxes = tester
        .widgetList<ColoredBox>(find.byType(ColoredBox))
        .where(
          (box) => box.color == Colors.purple || box.color == Colors.orange,
        )
        .toList();
    expect(boxes, hasLength(2));
    final purple = tester.getSize(find.byWidget(boxes.first));
    final orange = tester.getSize(find.byWidget(boxes.last));
    // 300 dp less one 2 dp gap, split 3:1; the empty part is left out.
    expect(purple.width, closeTo(223.5, 0.01));
    expect(orange.width, closeTo(74.5, 0.01));
    expect(purple.height, 12);
    expect(find.bySemanticsLabel('Split'), findsOneWidget);
  });

  testWidgets('a legend names every series', (tester) async {
    await tester.pumpWidget(
      _themed(
        const ChartLegend(
          entries: [
            LegendEntry(color: Colors.purple, label: 'Fuel', value: 'Rs. 24'),
            LegendEntry(color: Colors.teal, label: 'Maintenance'),
          ],
        ),
      ),
    );

    expect(find.text('Fuel Rs. 24', findRichText: true), findsOneWidget);
    expect(find.text('Maintenance', findRichText: true), findsOneWidget);
  });

  testWidgets('charts are read as their summary', (tester) async {
    await tester.pumpWidget(
      _themed(
        const StackedBarChart(
          colors: [Colors.purple, Colors.teal],
          formatAxisValue: compactRupees,
          semanticsLabel: 'Monthly costs: Sep 12k, Oct 8k',
          columns: [
            StackedBarColumn(label: 'Sep', values: [10000, 2000], tooltip: ''),
            StackedBarColumn(label: 'Oct', values: [8000, 0], tooltip: ''),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel('Monthly costs: Sep 12k, Oct 8k'),
      findsOneWidget,
    );
  });
}
