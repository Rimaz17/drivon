import 'package:drivon/app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app starts on the home screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DrivonApp()));
    await tester.pumpAndSettle();

    expect(find.text('Drivon'), findsOneWidget);
    expect(find.textContaining('in one place'), findsOneWidget);
  });
}
