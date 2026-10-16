/// Supplementary device-behavior audit (self-run): overlap checks at small
/// screens + large text scales for screens not covered by qa_round4_test.dart:
/// onboarding date page (chips + grid + preview), SOS breath screen,
/// Profile screen, journal editor with keyboard insets, and 1.5x text scale
/// on the main tabs. flutter_test fails automatically on RenderFlex overflow.
library;

import 'package:day_one_nocontact/screens/journal_screen.dart';
import 'package:day_one_nocontact/screens/main_shell.dart';
import 'package:day_one_nocontact/screens/onboarding_screen.dart';
import 'package:day_one_nocontact/screens/profile_screen.dart';
import 'package:day_one_nocontact/screens/sos_breath_screen.dart';
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

Future<void> _pumpSized(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(320, 568),
  double textScale = 1.3,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
  await tester.pumpWidget(_wrap(child));
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
  });

  group('device audit: date page', () {
    testWidgets('chips + grid + preview at 320px + 1.3x', (tester) async {
      await _pumpSized(tester, OnboardingScreen(onFinished: () {}));
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('STEP 1 OF 2'), findsOneWidget);
      // Tap a chip, then scroll the page — no overflow.
      await tester.tap(find.text('A week ago'));
      await tester.pump();
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -800));
      await tester.pump(const Duration(milliseconds: 300));
    });
  });

  group('device audit: SOS + profile', () {
    testWidgets('SOS breath screen at 320px + 1.3x', (tester) async {
      await _pumpSized(tester, const SosBreathScreen());
    });

    testWidgets('Profile screen at 320px + 1.3x, scrolled to bottom',
        (tester) async {
      AppState.instance.streakStartMs =
          DateTime.now().millisecondsSinceEpoch;
      await _pumpSized(tester, const ProfileScreen());
      final scrollables = find.byType(Scrollable);
      if (scrollables.evaluate().isNotEmpty) {
        await tester.drag(scrollables.first, const Offset(0, -3000));
        await tester.pump(const Duration(milliseconds: 300));
      }
    });
  });

  group('device audit: journal editor', () {
    testWidgets('editor with keyboard insets at 320px + 1.3x', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      tester.view.viewInsets =
          const FakeViewPadding(bottom: 300); // open keyboard
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetViewInsets();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      await tester.pumpWidget(_wrap(const JournalEditor()));
      await tester.pump(const Duration(milliseconds: 300));
    });
  });

  group('device audit: 1.5x text scale', () {
    testWidgets('main tabs at 320px + 1.5x, scrolled', (tester) async {
      AppState.instance.streakStartMs =
          DateTime.now().millisecondsSinceEpoch;
      await _pumpSized(
        tester,
        const MainShell(),
        textScale: 1.5,
      );
      for (final tab in ['Journal', 'Milestones', 'Home']) {
        await tester.tap(find.text(tab));
        await tester.pump(const Duration(milliseconds: 500));
        final scrollables = find.byType(Scrollable);
        if (scrollables.evaluate().isNotEmpty) {
          await tester.drag(scrollables.first, const Offset(0, -3000));
          await tester.pump(const Duration(milliseconds: 300));
        }
      }
    });
  });
}
