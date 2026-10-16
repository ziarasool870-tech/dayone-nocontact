/// Day One: No Contact — entry point.
///
/// Local-first: no backend, no accounts, no Firebase. Crashlytics/Analytics
/// are intentionally NOT wired in v1 (zero third-party SDKs); they can be
/// added later without touching app logic.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/prefs.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'widgets/premium.dart';
import 'screens/onboarding_screen.dart';
import 'screens/main_shell.dart';
import 'services/notification_service.dart';
import 'data/database.dart';
import 'screens/vault_screen.dart';

/// Global navigator key so a notification tap can open a vent re-read
/// even when the tap arrives outside any widget's BuildContext.
final appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  await AppState.instance.init();
  NotificationService.onNotificationTap = _handleNotificationTap;
  runApp(const DayOneApp());
}

/// Payloads: `vent:<id>` → open that vent in re-read mode.
/// Anything else (or a missing/gone vent) → no-op, never a crash.
Future<void> _handleNotificationTap(String? payload) async {
  if (payload == null || !payload.startsWith('vent:')) return;
  final id = int.tryParse(payload.substring(5));
  if (id == null) return;
  final vent = await DayOneDatabase.instance.letterById(id);
  if (vent == null || (vent['kind'] as String?) != 'vent') return;
  appNavigatorKey.currentState?.push(
    FadeSlidePageRoute(child: VentReader(vent: vent)),
  );
}

class DayOneApp extends StatelessWidget {
  const DayOneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Day One: No Contact',
      debugShowCheckedModeBanner: false,
      theme: DayOneTheme.light(),
      navigatorKey: appNavigatorKey,
      home: const _Gate(),
      onGenerateRoute: (settings) {
        // Premium transitions everywhere.
        final builder = _routes[settings.name];
        if (builder == null) return null;
        return FadeSlidePageRoute(child: builder(context));
      },
    );
  }
}

/// First launch → onboarding; afterwards → main app.
class _Gate extends StatefulWidget {
  const _Gate();

  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> {
  bool? _onboardingDone;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await PrefsService.instance();
    if (mounted) {
      setState(() => _onboardingDone = prefs.onboardingDone);
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = _onboardingDone;
    if (done == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!done) {
      return OnboardingScreen(
        onFinished: () async {
          final prefs = await PrefsService.instance();
          await prefs.setOnboardingDone(true);
          if (mounted) setState(() => _onboardingDone = true);
        },
      );
    }
    return const MainShell();
  }
}

final _routes = <String, WidgetBuilder>{
  '/home': (_) => const MainShell(),
};
