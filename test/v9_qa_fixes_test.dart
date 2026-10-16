/// v9: device-QA fixes — sealed-dialog trap, SMS intent, Home vault card.
library;

import 'package:day_one_nocontact/data/database.dart';
import 'package:day_one_nocontact/screens/home_screen.dart';
import 'package:day_one_nocontact/screens/profile_screen.dart';
import 'package:day_one_nocontact/screens/sos_breath_screen.dart';
import 'package:day_one_nocontact/screens/vault_screen.dart';
import 'package:day_one_nocontact/theme/app_theme.dart';
import 'package:day_one_nocontact/widgets/premium.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:url_launcher/url_launcher.dart';

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

  setUp(() async {
    final sp = await SharedPreferences.getInstance();
    await sp.clear();
    final db = await DayOneDatabase.instance.database;
    await db.delete('letters');
    await DayOneDatabase.instance.close();
  });

  group('Bug 1: sealed dialog has a way forward', () {
    // DB-backed flows run inside runAsync (sqflite_ffi deadlocks under
    // testWidgets' FakeAsync); pumps that must render navigation happen
    // outside runAsync (established repo pattern).
    testWidgets('seal shows the ritual dialog with a way forward',
        (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(_wrap(const LetterComposer()));
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pump();

      await tester.enterText(find.byType(TextField).at(0), 'Test title');
      await tester.enterText(
          find.byType(TextField).at(1), 'Everything I never said.');

      await tester.runAsync(() async {
        await tester.tap(find.byType(ElevatedButton));
        await Future<void>.delayed(const Duration(seconds: 2));
      });
      await tester.pump(const Duration(milliseconds: 300));

      // The ritual copy is unchanged, and there is now a forward action.
      expect(find.text('Sealed.'), findsOneWidget);
      expect(find.text("It's yours now. You never have to send it."),
          findsOneWidget);
      expect(find.text('See your letters'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'seal → "See your letters" → vault list with the letter on top',
        (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(_wrap(const LetterComposer()));
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pump();

      await tester.enterText(find.byType(TextField).at(0), 'Test title');
      await tester.enterText(
          find.byType(TextField).at(1), 'Everything I never said.');

      await tester.runAsync(() async {
        await tester.tap(find.byType(ElevatedButton));
        await Future<void>.delayed(const Duration(seconds: 2));
      });
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('See your letters'), findsOneWidget);

      // Through the dialog to the vault list (standalone composer, so the
      // defensive branch swaps to the vault).
      await tester.runAsync(() async {
        await tester.tap(find.text('See your letters'));
        await Future<void>.delayed(const Duration(milliseconds: 500));
        // Mount the vault list while real async is available so its
        // reload completes.
        await tester.pump(const Duration(milliseconds: 500));
        await Future<void>.delayed(const Duration(milliseconds: 1500));
        await tester.pump(const Duration(milliseconds: 500));
      });
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Letter vault'), findsOneWidget);
      expect(find.text('Test title'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('returnToVaultList pops back when a vault list is beneath',
        (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(_wrap(const VaultScreen()));
        await Future<void>.delayed(const Duration(milliseconds: 800));
      });
      await tester.pump();

      // Push the composer the way _compose() does (push itself needs no DB).
      final vaultCtx = tester.element(find.byType(VaultScreen));
      Navigator.of(vaultCtx).push(
        FadeSlidePageRoute(child: const LetterComposer()),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(LetterComposer), findsOneWidget);

      final composerCtx = tester.element(find.byType(LetterComposer));
      await returnToVaultList(composerCtx);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Letter vault'), findsOneWidget);
      expect(find.byType(LetterComposer), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('Bug 2: "Text a friend instead" intent', () {
    testWidgets('uses externalApplication mode with pre-filled body',
        (tester) async {
      Uri? gotUri;
      LaunchMode? gotMode;
      Future<bool> fake(Uri uri, {LaunchMode mode = LaunchMode.platformDefault}) async {
        gotUri = uri;
        gotMode = mode;
        return true;
      }

      await tester.pumpWidget(_wrap(Builder(
        builder: (ctx) => Scaffold(
          body: TextButton(
            onPressed: () => launchSmsIntent(ctx, launch: fake),
            child: const Text('go'),
          ),
        ),
      )));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(gotUri, isNotNull);
      expect(gotUri!.scheme, 'sms');
      expect(gotUri!.queryParameters['body'],
          startsWith('One good thing about today: '));
      expect(gotMode, LaunchMode.externalApplication);
      // No failure snackbar when the intent launches.
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('shows a snackbar instead of failing silently',
        (tester) async {
      Future<bool> failing(Uri uri,
              {LaunchMode mode = LaunchMode.platformDefault}) async =>
          false;

      await tester.pumpWidget(_wrap(Builder(
        builder: (ctx) => Scaffold(
          body: TextButton(
            onPressed: () => launchSmsIntent(ctx, launch: failing),
            child: const Text('go'),
          ),
        ),
      )));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining("Couldn't open messages"), findsOneWidget);
    });
  });

  group('Home vault card subtitle', () {
    test('free user sees the Pro teaser', () {
      expect(vaultCardSubtitle(isPro: false, count: 0),
          'Letters · Let it out · Pro');
    });

    test('pro user with no letters', () {
      expect(vaultCardSubtitle(isPro: true, count: 0),
          'Letters · Let it out — nothing sealed yet');
    });

    test('pro user with sealed letters names both tabs', () {
      expect(vaultCardSubtitle(isPro: true, count: 1),
          'Letters · Let it out — 1 sealed');
    });

    test('pro user with several letters', () {
      expect(vaultCardSubtitle(isPro: true, count: 5),
          'Letters · Let it out — 5 sealed');
    });
  });

  group('About row (v9)', () {
    testWidgets('About row opens the Daybreak Studio sheet', (tester) async {
      await tester.pumpWidget(_wrap(const ProfileScreen()));
      await tester.pump(const Duration(milliseconds: 600));

      // The row sits at the bottom of the profile; scroll it into view.
      // (Identified by its subtitle — the section header is also "About".)
      final rowSub = find.text('Made with care by Daybreak Studio');
      await tester.scrollUntilVisible(rowSub, 400);
      expect(rowSub, findsOneWidget);

      await tester.tap(rowSub);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Day One: No Contact'), findsOneWidget);
      expect(find.text('Made with care by Daybreak Studio'), findsWidgets);
      expect(find.textContaining('Your words never leave your phone'),
          findsOneWidget);
      expect(find.textContaining('Version 1.0.9'), findsOneWidget);
      // No personal names, no location anywhere in the sheet.
      expect(find.textContaining('Pakistan'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
