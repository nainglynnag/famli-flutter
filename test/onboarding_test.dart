import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:famli/features/onboarding/onboarding_screen.dart';
import 'package:famli/features/onboarding/widgets/onboarding_graphics.dart';

void main() {
  testWidgets('OnboardingScreen renders first slide and navigates through slides',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: OnboardingScreen(),
        ),
      ),
    );
    await tester.pump();

    // Verify slide 1 is displayed
    expect(find.byType(FamliBloomHero), findsOneWidget);
    expect(find.text('Welcome to Famli'), findsOneWidget);
    expect(find.text('Healthy Habits 🌱'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);

    // Tap "Next" to go to slide 2
    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    // Verify slide 2 is displayed
    expect(find.byType(ParentDashboardHero), findsOneWidget);
    expect(find.text('One Unified Dashboard'), findsOneWidget);
    expect(find.text('Daily Routines 🔁'), findsOneWidget);

    // Tap "Next" to go to slide 3
    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    // Verify slide 3 is displayed
    expect(find.byType(CoParentingHero), findsOneWidget);
    expect(find.text('Co-Parenting in Harmony'), findsOneWidget);

    // Tap "Next" to go to slide 4
    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    // Verify slide 4 is displayed
    expect(find.byType(GamificationShowcaseHero), findsOneWidget);
    expect(find.text('Custom Rewards & Nudges'), findsOneWidget);

    // Tap "Next" to go to slide 5
    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    // Verify slide 5 is displayed
    expect(find.byType(PrivilegeTicketHero), findsOneWidget);
    expect(find.text('Empower Kids & Privileges'), findsOneWidget);
    expect(find.text('Get Started 🚀'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
