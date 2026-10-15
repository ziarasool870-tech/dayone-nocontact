/// Widget tests: onboarding flow navigation + home screen rendering.
///
/// Uses sqflite_common_ffi so the on-device database works in tests, and
/// mocked SharedPreferences. Plugin-touching actions (finish onboarding,
/// notifications) are intentionally not tapped here.
library;

import 'package:day_one_nocontact/screens/home_screen.dart';
import 'package:day_one_nocontact/screens/onboarding_screen.dart';
import 'package:day_one_nocontact/state/app_state.dart';
import 'package:day_one_nocontact/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: DayOneTheme.light(),
      home: child,
    );

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
  });

  group('Onboarding', () {
    testWidgets('shows the welcome page first', (tester) async {
      await tester.pumpWidget(
        _wrap(OnboardingScreen(onFinished: () {})),
      );
      await tester.pumpAndSettle();

      expect(find.text('No Contact'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('STEP 1 OF 2'), findsNothing);
    });

    testWidgets('Continue advances through all three pages', (tester) async {
      await tester.pumpWidget(
        _wrap(OnboardingScreen(onFinished: () {})),
      );
      await tester.pumpAndSettle();

      // Page 2: start date picker.
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('STEP 1 OF 2'), findsOneWidget);

      // Page 3: quick setup; CTA becomes "Enter Day One".
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('STEP 2 OF 2'), findsOneWidget);
      expect(find.text('Enter Day One'), findsOneWidget);
    });

    testWidgets('welcome copy is warm and non-clinical', (tester) async {
      await tester.pumpWidget(
        _wrap(OnboardingScreen(onFinished: () {})),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('One day at a time'),
        findsOneWidget,
      );
      // No therapeutic claims anywhere in onboarding.
      expect(find.textContaining('therapist'), findsNothing);
      expect(find.textContaining('therapy'), findsNothing);
    });
  });

  group('Home', () {
    setUp(() {
      // Seed a live streak without touching plugin channels.
      AppState.instance.streakStartMs =
          DateTime.now().millisecondsSinceEpoch;
    });

    testWidgets('renders hero streak card at Day 0', (tester) async {
      await tester.pumpWidget(_wrap(const HomeScreen()));
      await tester.pump();

      // Brand language: "Day 0" hero label from TickingCounter.
      expect(find.text('Day 0'), findsOneWidget);
      // Daily quote card is present.
      expect(find.text('“'), findsOneWidget);
    });

    testWidgets('check-in buttons are visible', (tester) async {
      await tester.pumpWidget(_wrap(const HomeScreen()));
      await tester.pump();

      expect(find.text('Did you hold no contact today?'),
          findsOneWidget);
      expect(find.text('Yes, held strong'), findsOneWidget);
      expect(find.text('I slipped'), findsOneWidget);
    });

    testWidgets('next milestone progress is shown', (tester) async {
      await tester.pumpWidget(_wrap(const HomeScreen()));
      await tester.pump();

      expect(find.textContaining('Next milestone'), findsOneWidget);
    });
  });
}
