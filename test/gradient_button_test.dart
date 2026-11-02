import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:skillverse_ai/core/widgets/gradient_button.dart';

void main() {
  testWidgets('long action labels stay within narrow mobile buttons', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 150,
            height: 54,
            child: GradientButton(
              text: 'Finish Session',
              icon: Icons.stop_rounded,
              onPressed: () {},
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Finish Session'), findsOneWidget);
  });
}
