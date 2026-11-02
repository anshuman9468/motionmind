import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:skillverse_ai/core/theme/app_theme.dart';
import 'package:skillverse_ai/features/home/home_page.dart';
import 'package:skillverse_ai/features/marketplace/marketplace_page.dart';
import 'package:skillverse_ai/features/practice/exercise_selection_page.dart';
import 'package:skillverse_ai/features/onboarding/onboarding_details_page.dart';
import 'package:skillverse_ai/features/dashboard/dashboard_page.dart';
import 'package:skillverse_ai/features/digital_twin/digital_twin_page.dart';
import 'package:skillverse_ai/features/achievements/achievements_page.dart';
import 'package:skillverse_ai/features/profile/profile_page.dart';
import 'package:skillverse_ai/features/leaderboard/leaderboard_page.dart';
import 'package:skillverse_ai/features/community/community_page.dart';
import 'package:skillverse_ai/features/ai_coach/ai_coach_page.dart';

void main() {
  Future<void> pumpAtSize(WidgetTester tester, Widget child, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.darkTheme, home: child),
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

  testWidgets('practice catalogue fits without layout exceptions', (
    tester,
  ) async {
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

  testWidgets('onboarding details renders its first step on a phone', (
    tester,
  ) async {
    await pumpAtSize(
      tester,
      const OnboardingDetailsPage(),
      const Size(393, 852),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Telemetry setup'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);

    // Exercise every setup page so a later page cannot reintroduce a blank
    // screen or a phone-size layout exception.
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Physical Telemetry'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Skills & Ecosystem'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Habits & Levels'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preview sections remain visible without layout overflow', (
    tester,
  ) async {
    final pages = <Widget>[
      const DashboardPage(),
      const DigitalTwinPage(),
      const AchievementsPage(),
      const ProfilePage(),
      const LeaderboardPage(),
      const CommunityPage(),
      const AiCoachPage(),
    ];

    for (final page in pages) {
      await pumpAtSize(tester, page, const Size(393, 852));
      expect(tester.takeException(), isNull);
      expect(find.byType(Scaffold), findsOneWidget);
    }
  });
}
