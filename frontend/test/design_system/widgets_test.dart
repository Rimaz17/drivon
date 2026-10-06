import 'package:drivon/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  theme: DrivonTheme.dark(),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('StatTile', () {
    testWidgets('shows label, value, unit and caption', (tester) async {
      await tester.pumpWidget(
        _host(
          const StatTile(
            label: 'Average',
            value: '14.2',
            unit: 'km/L',
            caption: 'Last 3 tanks',
          ),
        ),
      );

      expect(find.text('Average'), findsOneWidget);
      expect(find.textContaining('14.2'), findsOneWidget);
      expect(find.textContaining('km/L'), findsOneWidget);
      expect(find.text('Last 3 tanks'), findsOneWidget);
    });

    testWidgets('exposes one combined label to screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(const StatTile(label: 'This month', value: 'Rs. 18,500')),
      );

      expect(find.bySemanticsLabel('This month, Rs. 18,500'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('reports taps when tappable', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(StatTile(label: 'Cost', value: '32', onTap: () => taps++)),
      );

      await tester.tap(find.byType(StatTile));
      expect(taps, 1);
    });
  });

  group('ArcGauge', () {
    testWidgets('is described to screen readers and shows its value', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          const ArcGauge(
            progress: 0.7,
            value: '14.2',
            unit: 'km/L',
            semanticsLabel: 'Average 14.2 km per litre',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel('Average 14.2 km per litre'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('clamps progress outside 0..1', (tester) async {
      await tester.pumpWidget(
        _host(const ArcGauge(progress: 3, value: '99', semanticsLabel: 'Full')),
      );
      await tester.pumpAndSettle();

      final paint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(ArcGauge),
          matching: find.byType(CustomPaint),
        ),
      );
      expect((paint.painter! as ArcGaugePainter).progress, 1.0);
    });
  });

  group('state views', () {
    testWidgets('EmptyState runs its action', (tester) async {
      var pressed = false;
      await tester.pumpWidget(
        _host(
          EmptyState(
            icon: Icons.directions_car_outlined,
            title: 'No vehicles yet',
            message: 'Add a vehicle to start tracking.',
            actionLabel: 'Add vehicle',
            onAction: () => pressed = true,
          ),
        ),
      );

      await tester.tap(find.text('Add vehicle'));
      expect(pressed, isTrue);
    });

    testWidgets('ErrorState offers a retry', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        _host(
          ErrorState(
            title: 'Could not load',
            message: 'Check your connection and try again.',
            retryLabel: 'Try again',
            onRetry: () => retried = true,
          ),
        ),
      );

      await tester.tap(find.text('Try again'));
      expect(retried, isTrue);
    });

    testWidgets('LoadingState has a spoken label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(const LoadingState(semanticsLabel: 'Loading vehicles')),
      );

      expect(find.bySemanticsLabel('Loading vehicles'), findsOneWidget);
      handle.dispose();
    });
  });

  testWidgets('TagChip and highlight card use readable dark text', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const DrivonCard(
          tone: DrivonCardTone.highlight,
          child: TagChip(label: 'Due soon', tone: TagTone.violet),
        ),
      ),
    );

    final text = tester.widget<Text>(find.text('Due soon'));
    expect(text.style?.color, DrivonColors.dark.onHighlight);
  });

  testWidgets('highlight card re-colors themed text inside it', (tester) async {
    await tester.pumpWidget(
      _host(
        DrivonCard(
          tone: DrivonCardTone.highlight,
          child: Builder(
            builder: (context) => Text(
              'Insurance renews in 12 days',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
      ),
    );

    final text = tester.widget<Text>(find.text('Insurance renews in 12 days'));
    expect(text.style?.color, DrivonColors.dark.onHighlight);
  });

  testWidgets('highlight StatTile renders its value in dark text', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const StatTile(
          label: 'Next service',
          value: '1,200',
          unit: 'km',
          tone: DrivonCardTone.highlight,
        ),
      ),
    );

    final rich = tester.widget<RichText>(
      find.descendant(
        of: find.byType(StatTile),
        matching: find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().startsWith('1,200'),
        ),
      ),
    );
    TextSpan? valueSpan;
    rich.text.visitChildren((span) {
      if (span is TextSpan && span.text == '1,200') {
        valueSpan = span;
        return false;
      }
      return true;
    });
    expect(valueSpan?.style?.color, DrivonColors.dark.onHighlight);
  });
}
