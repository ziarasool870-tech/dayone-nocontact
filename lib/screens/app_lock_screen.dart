/// App lock screens: setup (+ one-time recovery code), unlock gate, manage,
/// recovery-code entry, and the honest both-lost screen.
///
/// All copy is warm and humane — a lock screen in a healing app must never
/// feel cold or punishing. English only.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_lock_service.dart';
import '../theme/app_theme.dart';
import '../widgets/premium.dart';

/// Guard so the resume handler never stacks two gates.
bool _appLockGateShowing = false;

/// Called when the app returns to the foreground. If App lock is ON and the
/// session is locked, covers the app with the PIN gate. No-op otherwise.
Future<void> maybeShowAppLockGate(BuildContext context) async {
  if (_appLockGateShowing) return;
  final service = AppLockService.instance;
  final needsGate = await service.isEnabled && !service.isUnlocked;
  if (!needsGate || !context.mounted) return;
  _appLockGateShowing = true;
  try {
    await Navigator.of(context).push(
      FadeSlidePageRoute(child: const AppLockGateScreen()),
    );
  } finally {
    _appLockGateShowing = false;
  }
}

/// Test seam: reset the gate-showing guard between tests.
@visibleForTesting
void debugResetAppLockGate() {
  _appLockGateShowing = false;
}


// ---------------------------------------------------------------------------
// Shared PIN pad
// ---------------------------------------------------------------------------

/// Warm 4-digit PIN pad: dots, numeric keypad, gentle shake on wrong entry.
///
/// Pass [wrongAttemptToken] incremented by the parent after each failed
/// attempt — the pad plays the shake animation and clears itself.
class PinPad extends StatefulWidget {
  const PinPad({
    super.key,
    required this.title,
    this.subtitle,
    required this.onComplete,
    this.errorText,
    this.wrongAttemptToken = 0,
    this.footer,
  });

  final String title;
  final String? subtitle;
  final ValueChanged<String> onComplete;
  final String? errorText;
  final int wrongAttemptToken;
  final Widget? footer;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> with SingleTickerProviderStateMixin {
  String _pin = '';
  late final AnimationController _shake;
  late Animation<double> _offset;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _offset = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shake, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(PinPad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.wrongAttemptToken != oldWidget.wrongAttemptToken) {
      _shake.forward(from: 0);
      setState(() => _pin = '');
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _press(String digit) {
    if (_pin.length >= 4) return;
    try {
      HapticFeedback.lightImpact();
    } catch (_) {
      // Best-effort only (no haptics in widget tests).
    }
    setState(() => _pin += digit);
    if (_pin.length == 4) {
      final pin = _pin;
      // Let the dots paint before the parent reacts.
      Future.delayed(const Duration(milliseconds: 120), () {
        if (mounted) widget.onComplete(pin);
      });
    }
  }

  void _backspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  /// Gentle shake: small decaying horizontal wobble on the dots row.
  double _shakeDx(double t) {
    if (t == 0) return 0;
    const decay = 10.0;
    return (1 - t) * decay * (t * 12).remainder(2).sign *
        (1 - (t * 6).remainder(1).abs());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.title,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 24, fontWeight: FontWeight.w800, height: 1.25),
        ),
        if (widget.subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            widget.subtitle!,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 15, color: DayOneColors.muted, height: 1.5),
          ),
        ],
        const SizedBox(height: 28),
        AnimatedBuilder(
          animation: _offset,
          builder: (_, child) => Transform.translate(
            offset: Offset(_shakeDx(_offset.value), 0),
            child: child,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (i) {
              final filled = i < _pin.length;
              return Container(
                width: 20,
                height: 20,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: filled
                      ? DayOneColors.terracotta
                      : Colors.transparent,
                  border: Border.all(
                    color: filled
                        ? DayOneColors.terracotta
                        : DayOneColors.faint,
                    width: 2,
                  ),
                ),
              );
            }),
          ),
        ),
        if (widget.errorText != null) ...[
          const SizedBox(height: 12),
          Text(
            widget.errorText!,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 14.5, color: DayOneColors.sos, height: 1.4),
          ),
        ],
        const SizedBox(height: 28),
        _keypadRow(['1', '2', '3']),
        _keypadRow(['4', '5', '6']),
        _keypadRow(['7', '8', '9']),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 76, height: 76),
            _keyButton('0'),
            _backspaceButton(),
          ],
        ),
        if (widget.footer != null) ...[
          const SizedBox(height: 16),
          widget.footer!,
        ],
      ],
    );
  }

  Widget _keypadRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: digits.map(_keyButton).toList(),
    );
  }

  Widget _keyButton(String digit) {
    return Container(
      width: 76,
      height: 76,
      margin: const EdgeInsets.all(4),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(38),
        child: InkWell(
          borderRadius: BorderRadius.circular(38),
          onTap: () => _press(digit),
          child: Center(
            child: Text(
              digit,
              style: const TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }

  Widget _backspaceButton() {
    return SizedBox(
      width: 76,
      height: 76,
      child: IconButton(
        onPressed: _backspace,
        icon: const Icon(Icons.backspace_outlined,
            color: DayOneColors.muted, size: 28),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Setup: choose → confirm → save recovery code → done
// ---------------------------------------------------------------------------

/// App lock setup. Phases:
/// 1. choose a 4-digit PIN → 2. confirm it →
/// 3. recovery code shown ONCE (must tap "I've saved it") → 4. done.
///
/// [isReset] tweaks the copy for the post-recovery "choose a new PIN" flow.
/// Pops with `true` when the lock is fully configured.
class AppLockSetupScreen extends StatefulWidget {
  const AppLockSetupScreen({super.key, this.isReset = false});

  final bool isReset;

  @override
  State<AppLockSetupScreen> createState() => _AppLockSetupScreenState();
}

class _AppLockSetupScreenState extends State<AppLockSetupScreen> {
  String? _first;
  String? _error;
  int _wrongToken = 0;
  String? _recoveryCode;
  bool _done = false;

  void _onComplete(String pin) {
    if (_first == null) {
      setState(() {
        _first = pin;
        _error = null;
      });
      return;
    }
    if (pin == _first) {
      setState(() {
        _error = null;
        // The code is shown exactly once, on the next screen.
        _recoveryCode = AppLockService.generateRecoveryCode();
      });
    } else {
      setState(() {
        _first = null;
        _error = "Those PINs don't match — try again.";
        _wrongToken++;
      });
    }
  }

  /// "I've saved it" → persist PIN + code hash, then the success view.
  /// Setup can never complete without this confirmation.
  Future<void> _onCodeSaved() async {
    final pin = _first;
    final code = _recoveryCode;
    if (pin == null || code == null) return;
    await AppLockService.instance.setPin(pin);
    await AppLockService.instance.setRecoveryCode(code);
    if (mounted) setState(() => _done = true);
  }

  @override
  Widget build(BuildContext context) {
    final code = _recoveryCode;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isReset ? 'New PIN' : 'App lock'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: _done
                ? _successView()
                : code != null
                    ? _recoveryCodeView(code)
                    : PinPad(
                        key: ValueKey(_first == null ? 'choose' : 'confirm'),
                        title: _first == null
                            ? (widget.isReset
                                ? 'Choose a new 4-digit PIN'
                                : 'Choose a 4-digit PIN')
                            : 'Confirm your PIN',
                        subtitle: _first == null
                            ? 'Only you will know it. If you forget your PIN, your private words can\u2019t be recovered.'
                            : null,
                        errorText: _error,
                        wrongAttemptToken: _wrongToken,
                        onComplete: _onComplete,
                      ),
          ),
        ),
      ),
    );
  }

  /// The recovery code, shown exactly once. The user must confirm they
  /// saved it — there is no other way back in.
  Widget _recoveryCodeView(String code) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: DayOneColors.terracottaSoft,
          ),
          child: const Icon(Icons.key_rounded,
              color: DayOneColors.terracottaDeep, size: 36),
        ),
        const SizedBox(height: 20),
        const Text(
          'Save this code',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 24, fontWeight: FontWeight.w800, height: 1.25),
        ),
        const SizedBox(height: 8),
        const Text(
          'Screenshot it or write it down — if you forget your PIN, this code is the ONLY way back in. You will never see it again.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 15, color: DayOneColors.muted, height: 1.6),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: DayOneColors.faint),
          ),
          child: Text(
            code,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              color: DayOneColors.ink,
            ),
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _onCodeSaved,
            child: const Text('I\u2019ve saved it'),
          ),
        ),
      ],
    );
  }

  Widget _successView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: DayOneColors.sageSoft,
          ),
          child: const Icon(Icons.check_rounded,
              color: DayOneColors.sage, size: 40),
        ),
        const SizedBox(height: 20),
        Text(
          widget.isReset ? 'Your new PIN is ready.' : 'Your app is locked.',
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 24, fontWeight: FontWeight.w800, height: 1.25),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your private words stay private — even from us.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 15, color: DayOneColors.muted, height: 1.5),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Done'),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Gate: app-level PIN pad (cold start + return from background)
// ---------------------------------------------------------------------------

/// Shown before ANY app content when App lock is ON and the session is
/// locked. Cannot be dismissed — no close button, back button blocked.
/// [onUnlocked] is used when embedded (cold start); otherwise pops `true`.
class AppLockGateScreen extends StatefulWidget {
  const AppLockGateScreen({super.key, this.onUnlocked});

  final VoidCallback? onUnlocked;

  @override
  State<AppLockGateScreen> createState() => _AppLockGateScreenState();
}

class _AppLockGateScreenState extends State<AppLockGateScreen> {
  String? _error;
  int _wrongToken = 0;

  void _onComplete(String pin) async {
    final ok = await AppLockService.instance.verifyPin(pin);
    if (!mounted) return;
    if (ok) {
      AppLockService.instance.unlock();
      if (widget.onUnlocked != null) {
        widget.onUnlocked!();
      } else {
        Navigator.of(context).pop(true);
      }
    } else {
      setState(() {
        _error = "That wasn't it — try again.";
        _wrongToken++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('App lock'),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: PinPad(
                title: 'Enter your PIN',
                subtitle: 'Welcome back — your space is locked.',
                errorText: _error,
                wrongAttemptToken: _wrongToken,
                onComplete: _onComplete,
                footer: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      FadeSlidePageRoute(
                          child: const AppLockRecoverScreen()),
                    );
                  },
                  child: const Text('Forgot PIN?'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Manage: change or turn off (current PIN required first)
// ---------------------------------------------------------------------------

/// Entry from the Profile "App lock" row when a lock is already set.
/// Verifies the current PIN first, then offers Change / Turn off.
class AppLockManageScreen extends StatefulWidget {
  const AppLockManageScreen({super.key});

  @override
  State<AppLockManageScreen> createState() => _AppLockManageScreenState();
}

class _AppLockManageScreenState extends State<AppLockManageScreen> {
  bool _verified = false;
  String? _error;
  int _wrongToken = 0;

  void _onComplete(String pin) async {
    final ok = await AppLockService.instance.verifyPin(pin);
    if (!mounted) return;
    if (ok) {
      setState(() {
        _verified = true;
        _error = null;
      });
    } else {
      setState(() {
        _error = "That wasn't it — try again.";
        _wrongToken++;
      });
    }
  }

  Future<void> _changePin() async {
    final changed = await Navigator.of(context).push<bool>(
      FadeSlidePageRoute(child: const AppLockSetupScreen(isReset: true)),
    );
    if (changed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your PIN was changed.')),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _turnOff() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Turn off App lock?'),
        content: const Text(
          'Anyone who picks up your phone will be able to open Day One.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Turn off',
                style: TextStyle(color: DayOneColors.sos)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await AppLockService.instance.clearAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('App lock turned off.')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('App lock')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: _verified ? _optionsView() : _verifyView(),
          ),
        ),
      ),
    );
  }

  Widget _verifyView() {
    return PinPad(
      title: 'Enter your current PIN',
      errorText: _error,
      wrongAttemptToken: _wrongToken,
      onComplete: _onComplete,
    );
  }

  Widget _optionsView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: DayOneColors.terracottaSoft,
          ),
          child: const Icon(Icons.lock_outline_rounded,
              color: DayOneColors.terracottaDeep, size: 36),
        ),
        const SizedBox(height: 20),
        const Text(
          'App lock is on.',
          style: TextStyle(
              fontSize: 24, fontWeight: FontWeight.w800, height: 1.25),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _changePin,
            child: const Text('Change PIN'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _turnOff,
            style: OutlinedButton.styleFrom(
              foregroundColor: DayOneColors.sos,
              side: const BorderSide(color: DayOneColors.sos),
            ),
            child: const Text('Turn off App lock'),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Recover: enter the recovery code → new PIN (code rotates)
// ---------------------------------------------------------------------------

/// The way back in after a forgotten PIN. A correct code starts the
/// new-PIN setup, which generates a brand-new recovery code — the old one
/// is invalidated automatically when the new one is stored.
class AppLockRecoverScreen extends StatefulWidget {
  const AppLockRecoverScreen({super.key});

  @override
  State<AppLockRecoverScreen> createState() => _AppLockRecoverScreenState();
}

class _AppLockRecoverScreenState extends State<AppLockRecoverScreen> {
  final _controller = TextEditingController();
  String? _error;
  bool _checking = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _controller.text;
    if (code.trim().isEmpty || _checking) return;
    setState(() {
      _checking = true;
      _error = null;
    });
    final ok = await AppLockService.instance.verifyRecoveryCode(code);
    if (!mounted) return;
    setState(() => _checking = false);
    if (ok) {
      final done = await Navigator.of(context).push<bool>(
        FadeSlidePageRoute(
            child: const AppLockSetupScreen(isReset: true)),
      );
      // New PIN set → new code shown & saved → the old code is now dead.
      // Return to the gate, which will now accept the new PIN.
      if (done == true && mounted) {
        Navigator.of(context).pop(true);
      }
    } else {
      setState(() => _error = "That code doesn't match — try again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recover access')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: DayOneColors.terracottaSoft,
                ),
                child: const Icon(Icons.key_rounded,
                    color: DayOneColors.terracottaDeep, size: 36),
              ),
              const SizedBox(height: 20),
              const Text(
                'Enter your recovery code',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w800, height: 1.25),
              ),
              const SizedBox(height: 8),
              const Text(
                'The 12-character code you saved when you turned App lock on.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15, color: DayOneColors.muted, height: 1.6),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _controller,
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => setState(() => _error = null),
                onSubmitted: (_) => _submit(),
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2),
                decoration: InputDecoration(
                  hintText: 'XXXX-XXXX-XXXX',
                  filled: true,
                  fillColor: Colors.white,
                  errorText: _error,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: DayOneColors.faint),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _checking ? null : _submit,
                child: _checking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Continue'),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      FadeSlidePageRoute(
                          child: const AppLockNoRecoveryScreen()),
                    );
                  },
                  child: const Text('I don\u2019t have my code either'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Both lost: honest, no wipe
// ---------------------------------------------------------------------------

/// When neither the PIN nor the recovery code is available, the truth is
/// kind but firm: the words stay locked. Nothing is ever wiped — the user
/// explicitly rejected data loss as a "recovery" path.
class AppLockNoRecoveryScreen extends StatelessWidget {
  const AppLockNoRecoveryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Locked')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: DayOneColors.terracottaSoft,
                ),
                child: const Icon(Icons.lock_rounded,
                    color: DayOneColors.terracottaDeep, size: 36),
              ),
              const SizedBox(height: 20),
              const Text(
                'Your words stay locked.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w800, height: 1.3),
              ),
              const SizedBox(height: 12),
              const Text(
                'Without your PIN or recovery code, there is no way back in — even we can\u2019t open them. That\u2019s the promise that keeps them private.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15, color: DayOneColors.muted, height: 1.7),
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Profile row: "App lock"
// ---------------------------------------------------------------------------

/// Profile "Healing" section row for App lock. Tapping opens the setup
/// flow when no lock exists, or the manage screen (after current-PIN
/// verify) when one does. Always optional, default off.
class AppLockRow extends StatefulWidget {
  const AppLockRow({super.key});

  @override
  State<AppLockRow> createState() => _AppLockRowState();
}

class _AppLockRowState extends State<AppLockRow> {
  bool? _enabled;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final enabled = await AppLockService.instance.isEnabled;
    if (mounted) setState(() => _enabled = enabled);
  }

  Future<void> _onTap() async {
    final enabled = await AppLockService.instance.isEnabled;
    if (!mounted) return;
    if (enabled) {
      await Navigator.of(context).push(
        FadeSlidePageRoute(child: const AppLockManageScreen()),
      );
    } else {
      await Navigator.of(context).push(
        FadeSlidePageRoute(child: const AppLockSetupScreen()),
      );
    }
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _enabled;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: DayOneColors.terracottaSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    (enabled ?? false)
                        ? Icons.lock_rounded
                        : Icons.lock_open_rounded,
                    color: DayOneColors.terracottaDeep,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('App lock',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: DayOneColors.ink)),
                    ],
                  ),
                ),
                Text(
                  enabled == null ? '' : (enabled ? 'On' : 'Off'),
                  style: const TextStyle(
                      fontSize: 14, color: DayOneColors.muted),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right,
                    color: DayOneColors.faint, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
