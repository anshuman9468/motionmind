import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skillverse_ai/main.dart';

void main() {
  testWidgets('MotionMind app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MotionMindApp(),
      ),
    );
    // Pump past the 2.8s splash timer
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('MotionMind'), findsWidgets);
  });
}
