/// Vault PIN screens: setup, unlock gate, manage, and forgot-PIN erase.
///
/// All copy is warm and humane — a lock screen in a healing app must never
/// feel cold or punishing. English only.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/database.dart';
import '../services/vault_pin_service.dart';
import '../theme/app_theme.dart';
import '../widgets/premium.dart';
import 'paywall_screen.dart';

/// Vault entry choke point: every path into the vault goes through here.
///
/// - Free users: unchanged Pro behavior (paywall).
/// - Pro users with a PIN set and a cold session: PIN pad first;
///   the vault opens only after a correct PIN.
/// Returns true when the caller may open the vault.
Future<bool> ensureVaultUnlocked(BuildContext context,
    {required bool isPro, required Widget vault}) async {
  // Capture the navigator before any async gap.
  final navigator = Navigator.of(context);
  if (!isPro) {
    await navigator.push(
      FadeSlidePageRoute(child: const PaywallScreen()),
    );
    return false;
  }
  final service = VaultPinService.instance;
  if (await service.isEnabled && !service.isUnlocked) {
    final ok = await navigator.push<bool>(
      FadeSlidePageRoute(child: const VaultPinGateScreen()),
    );
    if (ok != true) return false;
  }
  await navigator.push(
    FadeSlidePageRoute(child: vault),
  );
  return true;
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
// Setup: choose → confirm → done
// ---------------------------------------------------------------------------

/// First-time PIN setup (also reused for "Change PIN").
class VaultPinSetupScreen extends StatefulWidget {
  const VaultPinSetupScreen({super.key, this.isChange = false});

  final bool isChange;

  @override
  State<VaultPinSetupScreen> createState() => _VaultPinSetupScreenState();
}

class _VaultPinSetupScreenState extends State<VaultPinSetupScreen> {
  String? _first;
  String? _error;
  int _wrongToken = 0;
  bool _done = false;

  void _onComplete(String pin) async {
    if (_first == null) {
      setState(() {
        _first = pin;
        _error = null;
      });
      return;
    }
    if (pin == _first) {
      await VaultPinService.instance.setPin(pin);
      if (mounted) setState(() => _done = true);
    } else {
      setState(() {
        _first = null;
        _error = "Those PINs don't match — try again.";
        _wrongToken++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isChange ? 'Change PIN' : 'Vault PIN'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: _done
                ? _successView()
                : PinPad(
                    key: ValueKey(_first == null ? 'choose' : 'confirm'),
                    title: _first == null
                        ? (widget.isChange
                            ? 'Choose a new 4-digit PIN'
                            : 'Choose a 4-digit PIN')
                        : 'Confirm your PIN',
                    subtitle: _first == null
                        ? 'Only you will know it. There is no way to recover a forgotten PIN.'
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
        const Text(
          'Your vault is locked.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 24, fontWeight: FontWeight.w800, height: 1.25),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your letters stay private — even from us.',
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
// Gate: enter PIN to open the vault
// ---------------------------------------------------------------------------

/// Shown before the vault whenever a PIN is set and the session is locked.
/// Pops with `true` on success, `false`/null when dismissed.
class VaultPinGateScreen extends StatefulWidget {
  const VaultPinGateScreen({super.key});

  @override
  State<VaultPinGateScreen> createState() => _VaultPinGateScreenState();
}

class _VaultPinGateScreenState extends State<VaultPinGateScreen> {
  String? _error;
  int _wrongToken = 0;

  void _onComplete(String pin) async {
    final ok = await VaultPinService.instance.verifyPin(pin);
    if (!mounted) return;
    if (ok) {
      VaultPinService.instance.unlock();
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _error = "That wasn't it — try again.";
        _wrongToken++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: const Text('Vault PIN'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: PinPad(
              title: 'Enter your PIN',
              subtitle: 'Your letters are waiting behind this lock.',
              errorText: _error,
              wrongAttemptToken: _wrongToken,
              onComplete: _onComplete,
              footer: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    FadeSlidePageRoute(
                        child: const VaultPinForgotScreen()),
                  );
                },
                child: const Text('Forgot PIN?'),
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

/// Entry from the Profile "Vault PIN" row when a PIN is already set.
/// Verifies the current PIN first, then offers Change / Turn off.
class VaultPinManageScreen extends StatefulWidget {
  const VaultPinManageScreen({super.key});

  @override
  State<VaultPinManageScreen> createState() => _VaultPinManageScreenState();
}

class _VaultPinManageScreenState extends State<VaultPinManageScreen> {
  bool _verified = false;
  String? _error;
  int _wrongToken = 0;

  void _onComplete(String pin) async {
    final ok = await VaultPinService.instance.verifyPin(pin);
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
      FadeSlidePageRoute(
          child: const VaultPinSetupScreen(isChange: true)),
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
        title: const Text('Turn off the PIN?'),
        content: const Text(
          'Anyone who picks up your phone will be able to open your vault.',
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
      await VaultPinService.instance.clearPin();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vault PIN turned off.')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vault PIN')),
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
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: DayOneColors.terracottaSoft,
          ),
          child: const Icon(Icons.lock_outline_rounded,
              color: DayOneColors.terracottaDeep, size: 36),
        ),
        const SizedBox(height: 20),
        const Text(
          'Vault PIN is on.',
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
            child: const Text('Turn off PIN'),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Profile row: "Vault PIN" — shows Locked/Off, opens setup or manage.
// ---------------------------------------------------------------------------

/// Profile "Healing" section row for the vault PIN. Tapping opens the setup
/// flow when no PIN exists, or the manage screen (after current-PIN verify)
/// when one does. Visible to everyone; the vault itself stays Pro-gated.
class VaultPinRow extends StatefulWidget {
  const VaultPinRow({super.key});

  @override
  State<VaultPinRow> createState() => _VaultPinRowState();
}

class _VaultPinRowState extends State<VaultPinRow> {
  bool? _enabled;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final enabled = await VaultPinService.instance.isEnabled;
    if (mounted) setState(() => _enabled = enabled);
  }

  Future<void> _onTap() async {
    final enabled = await VaultPinService.instance.isEnabled;
    if (!mounted) return;
    if (enabled) {
      await Navigator.of(context).push(
        FadeSlidePageRoute(child: const VaultPinManageScreen()),
      );
    } else {
      await Navigator.of(context).push(
        FadeSlidePageRoute(child: const VaultPinSetupScreen()),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Vault PIN',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: DayOneColors.ink)),
                      Text(
                        enabled == null
                            ? ''
                            : (enabled ? 'Locked' : 'Off'),
                        style: const TextStyle(
                            fontSize: 14, color: DayOneColors.muted),
                      ),
                    ],
                  ),
                ),
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

/// The ONLY recovery path: there is no way to recover a forgotten PIN
/// (local-first, no account), so the vault itself must be erased.
/// The user must type ERASE to confirm — no accidental taps.
// ---------------------------------------------------------------------------
// Forgot PIN: honest warning → type ERASE → wipe vault
// ---------------------------------------------------------------------------

/// The ONLY recovery path: there is no way to recover a forgotten PIN
/// (local-first, no account), so the vault itself must be erased.
/// The user must type ERASE to confirm — no accidental taps.
class VaultPinForgotScreen extends StatefulWidget {
  const VaultPinForgotScreen({super.key});

  @override
  State<VaultPinForgotScreen> createState() => _VaultPinForgotScreenState();
}

class _VaultPinForgotScreenState extends State<VaultPinForgotScreen> {
  final _controller = TextEditingController();
  bool _wiping = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _erase() async {
    setState(() => _wiping = true);
    try {
      final db = await DayOneDatabase.instance.database;
      await db.delete('letters');
      await VaultPinService.instance.wipeSecrets();
    } finally {
      if (mounted) setState(() => _wiping = false);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Your vault was erased. A fresh start.')),
    );
    // Back to the app root — the vault no longer exists.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot PIN')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: DayOneColors.terracottaSoft,
                ),
                child: const Icon(Icons.heart_broken_outlined,
                    color: DayOneColors.terracottaDeep, size: 36),
              ),
              const SizedBox(height: 20),
              const Text(
                "There's no way to get your PIN back.",
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800, height: 1.3),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your letters stay private — even from us. The only way forward is to erase the vault and start fresh. Your streak, journal and everything else stay untouched.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15, color: DayOneColors.muted, height: 1.6),
              ),
              const SizedBox(height: 28),
              const Text(
                'Type ERASE to confirm',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: DayOneColors.muted),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _controller,
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'ERASE',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: DayOneColors.faint),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: (_controller.text.trim() == 'ERASE' && !_wiping)
                    ? _erase
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: DayOneColors.sos,
                  disabledBackgroundColor:
                      DayOneColors.sos.withValues(alpha: 0.35),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _wiping
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Erase vault and start fresh'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
