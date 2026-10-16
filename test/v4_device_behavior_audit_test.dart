/// Device-behavior audit for Day One v4 — READ-ONLY review tests.
///
/// Pumps the v4-touched UI under tight real-phone constraints
/// (320x568 logical, textScaleFactor 1.0 and 1.3) and fails on any
/// RenderFlex overflow. Run with: flutter test test/v4_device_behavior_audit_test.dart
///
/// These tests change no app code; they exist to PROVE layout behavior.
library;

import 'dart:io';

import 'package:day_one_nocontact/core/content.dart';
import 'package:day_one_nocontact/data/prefs.dart';
import 'package:day_one_nocontact/screens/milestones_screen.dart';
import 'package:day_one_nocontact/screens/onboarding_screen.dart';
import 'package:day_one_nocontact/screens/profile_screen.dart';
import 'package:day_one_nocontact/screens/sos_breath_screen.dart';
import 'package:day_one_nocontact/theme/app_theme.dart';
import 'package:day_one_nocontact/widgets/premium.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: DayOneTheme.light(),
      home: child,
    );

/// Pump [child] at a fixed logical size + text scale, then drain frames.
Future<void> _pumpSized(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(320, 568),
  double textScale = 1.0,
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

/// Fails the test if any FlutterError (e.g. RenderFlex overflow) was logged.
void _expectNoOverflow(WidgetTester tester, String label) {
  final err = tester.takeException();
  expect(err, isNull,
      reason: '$label: overflow/layout error under test constraints: $err');
}

/// Opens the "Read my reasons" sheet from the SOS options screen.
Future<void> _openReasonsSheet(WidgetTester tester) async {
  await tester.tap(find.text('Read my reasons'));
  await tester.pump(); // flush nested-gesture onTap
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 600)); // prefs async load
}

/// Loads the bundled Lora fonts so text metrics match a real device.
/// Without this, flutter_test's fallback font renders much wider/taller
/// glyphs and every width-constrained test produces false overflow positives.
/// NOTE: the app uses family 'Lora' (static TTFs: Regular/Medium/SemiBold/Bold).
Future<void> _loadFonts() async {
  final loader = FontLoader('Lora');
  for (final name in [
    'Lora.ttf', // 400
    'Lora-Medium.ttf', // 500
    'Lora-SemiBold.ttf', // 600
    'Lora-Bold.ttf', // 700
  ]) {
    final bytes = await File('assets/fonts/lora/$name').readAsBytes();
    loader.addFont(Future.value(bytes.buffer.asByteData()));
  }
  await loader.load();
}

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
    await _loadFonts();
  });

  setUp(() async {
    // Fresh reason state per test so sheet state doesn't leak between tests.
    final sp = await SharedPreferences.getInstance();
    await sp.remove(PrefsService.kCustomReasons);
    await sp.remove(PrefsService.kHiddenDefaultReasons);
  });

  group('SOS reasons sheet (v4)', () {
    testWidgets('320x568 @1.0: sheet renders and the list scrolls',
        (tester) async {
      await _pumpSized(tester, const SosOptionsScreen());
      await _openReasonsSheet(tester);

      expect(find.text('Read this before you text them'), findsOneWidget);
      // Scroll the inner list to the bottom.
      await tester.drag(
          find.byType(ListView).first, const Offset(0, -600));
      await tester.pump(const Duration(milliseconds: 300));
      _expectNoOverflow(tester, 'reasons sheet @1.0');
    });

    testWidgets('320x568 @1.3: sheet renders and the list scrolls',
        (tester) async {
      await _pumpSized(tester, const SosOptionsScreen(), textScale: 1.3);
      await _openReasonsSheet(tester);

      expect(find.text('Read this before you text them'), findsOneWidget);
      await tester.drag(
          find.byType(ListView).first, const Offset(0, -600));
      await tester.pump(const Duration(milliseconds: 300));
      _expectNoOverflow(tester, 'reasons sheet @1.3');
    });

    testWidgets('add dialog survives a simulated keyboard + contrast is explicit',
        (tester) async {
      // Simulate an open soft keyboard: 300px bottom inset.
      const keyboard = EdgeInsets.only(bottom: 300);
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(viewInsets: keyboard),
        child: _wrap(const SosOptionsScreen()),
      ));
      await tester.pump(const Duration(milliseconds: 600));
      await _openReasonsSheet(tester);

      await tester.tap(find.text('Add your own reason'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Add your reason'), findsOneWidget);

      // Contrast: explicit ink-on-card, never white-on-white.
      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      expect(dialog.backgroundColor, DayOneColors.card,
          reason: 'dialog background must be the card color');
      final title = tester.widget<Text>(find.text('Add your reason'));
      expect(title.style?.color, DayOneColors.ink,
          reason: 'dialog title must be explicit ink');
      final field = tester.widget<TextField>(find.byType(TextField).last);
      expect(field.style?.color, DayOneColors.ink,
          reason: 'dialog TextField text must be explicit ink');

      await tester.enterText(find.byType(TextField).last,
          'I choose my own peace');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pump(const Duration(milliseconds: 400));

      // The new reason shows in the sheet.
      expect(find.text('I choose my own peace'), findsOneWidget);
      _expectNoOverflow(tester, 'add-reason dialog with keyboard');
    });

    testWidgets('edit + delete flow persists via prefs', (tester) async {
      await _pumpSized(tester, const SosOptionsScreen());
      await _openReasonsSheet(tester);

      // Add
      await tester.tap(find.text('Add your own reason'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(
          find.byType(TextField).last, 'First version');
      await tester.tap(find.text('Save'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('First version'), findsOneWidget);

      // Edit
      await tester.tap(find.byTooltip('Edit reason').first);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Edit your reason'), findsOneWidget);
      await tester.enterText(
          find.byType(TextField).last, 'Edited version');
      await tester.tap(find.text('Save'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Edited version'), findsOneWidget);
      expect(find.text('First version'), findsNothing);

      // Delete (confirm dialog is also ink-on-card)
      await tester.tap(find.byTooltip('Delete reason').first);
      await tester.pump(const Duration(milliseconds: 400));
      final confirm =
          tester.widget<AlertDialog>(find.byType(AlertDialog));
      expect(confirm.backgroundColor, DayOneColors.card);
      await tester.tap(find.text('Remove'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Edited version'), findsNothing);

      // Persistence: dismiss the sheet and reopen — defaults still hide-able.
      final prefs = await PrefsService.instance();
      expect(prefs.customReasons, isEmpty);

      await tester.tap(find.text('Add your own reason'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(find.byType(TextField).last, 'Survivor');
      await tester.tap(find.text('Save'));
      await tester.pump(const Duration(milliseconds: 400));
      Navigator.of(tester.element(find.text('Survivor'))).pop();
      await tester.pump(const Duration(milliseconds: 600));

      // Reopen: persisted reason is still there.
      await _openReasonsSheet(tester);
      expect(find.text('Survivor'), findsOneWidget);
      _expectNoOverflow(tester, 'edit/delete/persist flow');
    });

    testWidgets('hide default + unhide + restore-all flow', (tester) async {
      await _pumpSized(tester, const SosOptionsScreen());
      await _openReasonsSheet(tester);

      // Hide the first default reason.
      await tester.tap(find.byTooltip('Hide this reason').first);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(defaultReasons.first), findsNothing);
      // The hidden-section affordance lives at the END of the sheet's
      // list: the first drag expands the sheet, the second scrolls the
      // list to build it.
      final listFinder = find.byType(ListView).first;
      await tester.drag(listFinder, const Offset(0, -800));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.drag(listFinder, const Offset(0, -300));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Show 1 hidden reason'), findsOneWidget);

      // Reveal hidden section, unhide it.
      await tester.tap(find.text('Show 1 hidden reason'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.drag(find.byType(ListView).first, const Offset(0, -300));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Restore all defaults'), findsOneWidget);
      await tester.tap(find.byTooltip('Show this reason').first);
      await tester.pump(const Duration(milliseconds: 400));
      // The restored card returns to the top of the list: scroll back up.
      await tester.drag(find.byType(ListView).first, const Offset(0, 1200));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(defaultReasons.first), findsOneWidget);
      // Persisted: the hidden set is empty again.
      final prefs = await PrefsService.instance();
      expect(prefs.hiddenDefaultReasons, isEmpty);
      _expectNoOverflow(tester, 'hide/unhide flow');
    });
  });

  group('SOS options screen (v4 crisis card)', () {
    testWidgets('320x568 @1.3: no overflow', (tester) async {
      await _pumpSized(tester, const SosOptionsScreen(), textScale: 1.3);
      _expectNoOverflow(tester, 'SOS options @1.3');
    });

    testWidgets('320x568 @1.0: no overflow', (tester) async {
      await _pumpSized(tester, const SosOptionsScreen());
      _expectNoOverflow(tester, 'SOS options @1.0');
    });
  });

  group('Day-1 display (v4)', () {
    testWidgets('TickingCounter pill stays single-line: 3-digit days @1.3',
        (tester) async {
      final startMs = DateTime.now()
          .subtract(const Duration(days: 367, hours: 5))
          .millisecondsSinceEpoch;
      await _pumpSized(tester, TickingCounter(startMs: startMs),
          textScale: 1.3);
      await tester.pump(const Duration(seconds: 2)); // count-up + ticks
      _expectNoOverflow(tester, 'TickingCounter 3-digit @1.3');

      // The pill must not wrap to two lines: height stays single-line.
      final pill = find.byWidgetPredicate((w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).color ==
              DayOneColors.terracottaSoft);
      expect(pill, findsOneWidget);
      final size = tester.getSize(pill);
      debugPrint('AUDIT: 3-digit pill @320/1.3 = ${size.width}x${size.height}');
      expect(size.height, lessThan(48),
          reason: 'pill wrapped to two lines at 3-digit days');
    });

    testWidgets('TickingCounter pill stays single-line: 4-digit days @1.0',
        (tester) async {
      final startMs = DateTime.now()
          .subtract(const Duration(days: 1234))
          .millisecondsSinceEpoch;
      await _pumpSized(tester, TickingCounter(startMs: startMs));
      await tester.pump(const Duration(seconds: 2));
      _expectNoOverflow(tester, 'TickingCounter 4-digit @1.0');

      final pill = find.byWidgetPredicate((w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).color ==
              DayOneColors.terracottaSoft);
      final size = tester.getSize(pill);
      debugPrint('AUDIT: 4-digit pill @320/1.0 = ${size.width}x${size.height}');
      expect(size.height, lessThan(48),
          reason: 'pill wrapped to two lines at 4-digit days');
    });

    testWidgets('TickingCounter pill stays single-line: 4-digit days @1.3',
        (tester) async {
      final startMs = DateTime.now()
          .subtract(const Duration(days: 1234))
          .millisecondsSinceEpoch;
      await _pumpSized(tester, TickingCounter(startMs: startMs),
          textScale: 1.3);
      await tester.pump(const Duration(seconds: 2));
      _expectNoOverflow(tester, 'TickingCounter 4-digit @1.3');

      final pill = find.byWidgetPredicate((w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).color ==
              DayOneColors.terracottaSoft);
      final size = tester.getSize(pill);
      debugPrint('AUDIT: 4-digit pill @320/1.3 = ${size.width}x${size.height}');
      expect(size.height, lessThan(48),
          reason: 'pill wrapped to two lines at 4-digit days @1.3');
    });
  });

  group('Onboarding under tight constraints', () {
    Future<void> tapContinue(WidgetTester tester) async {
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('setup page (page 3) @320/1.3: no overflow', (tester) async {
      await _pumpSized(tester, OnboardingScreen(onFinished: () {}),
          textScale: 1.3);
      await tapContinue(tester); // -> date page
      await tapContinue(tester); // -> setup page
      expect(find.text('STEP 2 OF 2'), findsOneWidget);
      _expectNoOverflow(tester, 'onboarding setup page @1.3');
    });

    testWidgets('date month grid @320/1.3: no overflow', (tester) async {
      await _pumpSized(tester, OnboardingScreen(onFinished: () {}),
          textScale: 1.3);
      await tapContinue(tester); // -> date page
      expect(find.text('STEP 1 OF 2'), findsOneWidget);
      // Select a two-digit day to exercise the selected-cell Row.
      final day15 = find.text('15');
      if (day15.evaluate().isNotEmpty) {
        await tester.tap(day15.first);
        await tester.pump(const Duration(milliseconds: 300));
      }
      _expectNoOverflow(tester, 'onboarding date grid @1.3');
    });
  });

  group('Milestone tiles (v4 Day-1 display)', () {
    testWidgets('tiles @320/1.3: no overflow', (tester) async {
      await _pumpSized(tester, const MilestonesScreen(), textScale: 1.3);
      _expectNoOverflow(tester, 'milestone tiles @1.3');
    });
  });

  group('Profile stats row (v4 Day-1 display)', () {
    testWidgets('stats @320/1.3: no overflow', (tester) async {
      await _pumpSized(tester, const ProfileScreen(), textScale: 1.3);
      _expectNoOverflow(tester, 'profile stats @1.3');
    });
  });

  group('Crisis helpline resolution (v4, v7 safety fix)', () {
    test('null / empty / unknown country resolves to null (directory only)', () {
      // Safety: never show a foreign country's number on a crisis
      // screen. Uncovered countries get the international directory.
      expect(resolveCrisisHelpline(null), isNull);
      expect(resolveCrisisHelpline(''), isNull);
      expect(resolveCrisisHelpline('DE'), isNull);
      expect(resolveCrisisHelpline('IN'), isNull);
      expect(resolveCrisisHelpline('gb')!['dial'], '116123');
      expect(resolveCrisisHelpline('GB')!['dial'], '116123');
    });

    test('all 7 premium entries have digits-only dial paths', () {
      for (final e in crisisHelplines.entries) {
        final dial = e.value['dial']!;
        expect(RegExp(r'^[0-9]+$').hasMatch(dial), isTrue,
            reason: '${e.key} dial path "$dial" is not digits-only');
        expect(e.value['number']!.isNotEmpty, isTrue);
      }
    });
  });

  group('KNOWN-BUG regressions (fail until fixed)', () {
    testWidgets('BUG-1 distract sheet overflows: not scrollable',
        (tester) async {
      // _distractSheet is a mainAxisSize.min Column with no scroll view:
      // on a 320x568 phone the 6 cards (~915px @1.0) overflow and the
      // bottom cards are unreachable. Fix: wrap in SingleChildScrollView
      // or make it isScrollControlled + draggable like the reasons sheet.
      await _pumpSized(tester, const SosOptionsScreen());
      await tester.tap(find.text('Distract me'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      _expectNoOverflow(tester, 'distract sheet @1.0');
    });

    testWidgets('BUG-2 reason dialog overflows with keyboard @1.3',
        (tester) async {
      // Add/edit dialog content exceeds the space above the keyboard at
      // 320x568 @1.3 once the user types (TextField grows to 2-3 lines):
      // the Save/Cancel actions get clipped. Fix: AlertDialog(
      // scrollable: true) or constrain content height.
      await _pumpSized(tester, const SosOptionsScreen(), textScale: 1.3);
      await tester.tap(find.text('Read my reasons'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      await tester.tap(find.text('Add your own reason'));
      await tester.pump(const Duration(milliseconds: 500));
      tester.view.viewInsets = FakeViewPadding(bottom: 300);
      await tester.pump(const Duration(milliseconds: 300));
      // The user types their reason — the field grows, the dialog breaks.
      await tester.enterText(
          find.byType(TextField).last,
          'I choose my own peace over their chaos');
      await tester.pump(const Duration(milliseconds: 300));
      tester.view.viewInsets = FakeViewPadding.zero;
      _expectNoOverflow(tester, 'reason dialog + keyboard @1.3');
    });

    testWidgets('BUG-3 TickingCounter pill scales down at 4-digit days @1.3',
        (tester) async {
      // FIXED: premium.dart now wraps the pill Row in
      // FittedBox(BoxFit.scaleDown) — long streaks + large fonts scale
      // down instead of overflowing. This pumps the REAL TickingCounter
      // at worst-case width; any wall-clock second value must fit.
      final startMs = DateTime.now()
          .subtract(const Duration(days: 1234, hours: 23, minutes: 59))
          .millisecondsSinceEpoch;
      await _pumpSized(
          tester,
          Center(
            child: SizedBox(
                width: 280, child: TickingCounter(startMs: startMs)),
          ),
          textScale: 1.3);
      await tester.pump(const Duration(seconds: 2));
      _expectNoOverflow(tester, 'pill 4-digit @1.3 in 280px (fixed)');
    });
  });
}
