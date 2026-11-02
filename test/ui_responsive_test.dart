import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:skillverse_ai/core/theme/app_theme.dart';
import 'package:skillverse_ai/features/home/home_page.dart';
import 'package:skillverse_ai/features/marketplace/marketplace_page.dart';
import 'package:skillverse_ai/features/practice/exercise_selection_page.dart';

void main() {
  Future<void> pumpAtSize(
    WidgetTester tester,
    Widget child,
    Size size,
  ) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: child,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('home remains usable on compact phone widths', (tester) async {
    for (final size in [const Size(360, 800), const Size(393, 852)]) {
      await pumpAtSize(tester, const HomePage(), size);
      expect(tester.takeException(), isNull);
      expect(find.text('Start practice'), findsOneWidget);
    }
  });

  testWidgets('practice catalogue fits without layout exceptions',
      (tester) async {
    for (final size in [const Size(360, 800), const Size(412, 915)]) {
      await pumpAtSize(tester, const ExerciseSelectionPage(), size);
      expect(tester.takeException(), isNull);
      expect(find.text('What would you like\nto practice?'), findsOneWidget);
    }
  });

  testWidgets('explore catalogue fits on a narrow display', (tester) async {
    await pumpAtSize(tester, const MarketplacePage(), const Size(360, 800));
    expect(tester.takeException(), isNull);
    expect(find.text('Explore'), findsOneWidget);
  });
}
