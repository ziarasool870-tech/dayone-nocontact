/// App lock — optional whole-app PIN protection (default OFF).
///
/// The user turns it on from Profile → "App lock". When on, the warm PIN pad
/// appears before any app content on cold start and on return from
/// background, and re-locks when the app goes to background.
///
/// Security model (local-first, no account):
/// - The raw PIN is NEVER stored anywhere — only a salted SHA-256 hash,
///   kept in keystore-backed encrypted storage (flutter_secure_storage).
/// - The salt is random per install, stored alongside the hash.
/// - A 4-digit PIN has 10k combinations: the hash alone is brute-forceable
///   on a rooted device, so the real protection is Android's app sandbox +
///   EncryptedSharedPreferences. This keeps honest people (and nosy
///   friends/family) out — it is not a bank vault.
/// - There is NO recovery path by design: "Forgot PIN" wipes the private
///   content (vault letters + journal). The UI says this plainly before
///   the user sets a PIN.
///
/// Session rule: once unlocked, the app stays unlocked while in the
/// foreground. [lock] is called when the app goes to background
/// (MainShell's WidgetsBindingObserver, on paused only — system dialogs
/// like the widget-pin prompt trigger inactive without leaving the app,
/// and must not re-lock). The flag starts locked, so a cold start with
/// App lock ON always asks for the PIN.
library;

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Minimal storage seam so tests can run without platform channels.
abstract class PinStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<void> deleteAll();
}

/// Production storage: keystore-backed on Android.
class SecurePinStorage implements PinStorage {
  SecurePinStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<void> deleteAll() => _storage.deleteAll();
}

/// In-memory storage for widget/unit tests.
class MemoryPinStorage implements PinStorage {
  final Map<String, String> _map = {};

  @override
  Future<String?> read(String key) async => _map[key];

  @override
  Future<void> write(String key, String value) async {
    _map[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _map.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    _map.clear();
  }

  /// Test helper: peek at raw stored values.
  Map<String, String> get debugValues => Map.unmodifiable(_map);
}

/// Storage that prefers the secure primary but falls back to memory when
/// the platform plugin is missing. MissingPluginException only happens in
/// widget tests (the plugin is always registered on real Android/iOS), so
/// production behavior is unchanged while existing tests that pump the
/// Profile screen keep working without per-test setup.
class ResilientPinStorage implements PinStorage {
  ResilientPinStorage([PinStorage? primary])
      : _primary = primary ?? SecurePinStorage();

  final PinStorage _primary;
  final MemoryPinStorage _fallback = MemoryPinStorage();

  Future<T> _guard<T>(Future<T> Function(PinStorage s) op) async {
    try {
      return await op(_primary);
    } on MissingPluginException {
      return await op(_fallback);
    }
  }

  @override
  Future<String?> read(String key) => _guard((s) => s.read(key));

  @override
  Future<void> write(String key, String value) =>
      _guard((s) => s.write(key, value));

  @override
  Future<void> delete(String key) => _guard((s) => s.delete(key));

  @override
  Future<void> deleteAll() => _guard((s) => s.deleteAll());
}

class AppLockService {
  AppLockService._(this._storage);

  static const _kHashKey = 'vault_pin_hash';
  static const _kSaltKey = 'vault_pin_salt';

  final PinStorage _storage;

  static AppLockService? _instance;

  /// Production singleton (secure storage, resilient in tests).
  static AppLockService get instance =>
      _instance ??= AppLockService._(ResilientPinStorage());

  /// Test seam: replace the singleton with an in-memory-backed one.
  @visibleForTesting
  static void debugReset({PinStorage? storage}) {
    _instance = AppLockService._(storage ?? MemoryPinStorage());
    _instance!._unlockedInSession = false;
  }

  /// True once the user has entered the correct PIN (or just set one)
  /// and the app has not since gone to background / restarted.
  bool _unlockedInSession = false;
  bool get isUnlocked => _unlockedInSession;

  /// Mark the session unlocked (called after a correct PIN entry).
  void unlock() {
    _unlockedInSession = true;
  }

  /// Re-lock the vault. Called on app backgrounding; also the default
  /// state, so a cold start always starts locked.
  void lock() {
    _unlockedInSession = false;
  }

  /// Whether a PIN is currently set.
  Future<bool> get isEnabled async =>
      (await _storage.read(_kHashKey)) != null;

  /// Store a new PIN. Only the salted hash is persisted — never [pin].
  Future<void> setPin(String pin) async {
    assert(pin.length == 4 && int.tryParse(pin) != null,
        'PIN must be 4 digits');
    final salt = _randomSalt();
    final hash = _hash(pin, salt);
    await _storage.write(_kSaltKey, salt);
    await _storage.write(_kHashKey, hash);
    _unlockedInSession = true;
  }

  /// Check a candidate PIN against the stored hash.
  Future<bool> verifyPin(String pin) async {
    final salt = await _storage.read(_kSaltKey);
    final stored = await _storage.read(_kHashKey);
    if (salt == null || stored == null) return false;
    return _constantTimeEquals(_hash(pin, salt), stored);
  }

  /// Remove the PIN (hash + salt). App data is untouched.
  Future<void> clearPin() async {
    await _storage.delete(_kHashKey);
    await _storage.delete(_kSaltKey);
    _unlockedInSession = false;
  }

  /// Remove the PIN and the recovery code together (turning App lock off).
  Future<void> clearAll() async {
    await clearPin();
    await _storage.delete(_kRecoveryHashKey);
    await _storage.delete(_kRecoverySaltKey);
  }

  // ------------------------------------------------------------------
  // Recovery code: the ONLY way back in after a forgotten PIN.
  // Shown to the user exactly once at setup; only its salted hash is
  // stored — never the plaintext. A successful recovery always rotates
  // to a brand-new code (the old one is invalidated).
  // ------------------------------------------------------------------

  static const _kRecoveryHashKey = 'app_lock_recovery_hash';
  static const _kRecoverySaltKey = 'app_lock_recovery_salt';

  /// Unambiguous alphabet: no 0/O, no 1/I.
  static const _codeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  /// Generates a 12-character code in XXXX-XXXX-XXXX form.
  static String generateRecoveryCode() {
    final chars = List<String>.generate(
        12, (_) => _codeChars[_random.nextInt(_codeChars.length)]);
    final raw = chars.join();
    return '${raw.substring(0, 4)}-${raw.substring(4, 8)}-${raw.substring(8, 12)}';
  }

  /// Whether a recovery code is currently set.
  Future<bool> get hasRecoveryCode async =>
      (await _storage.read(_kRecoveryHashKey)) != null;

  /// Store a recovery code (salted hash only — never [code]).
  /// Replaces any previous code, invalidating it.
  Future<void> setRecoveryCode(String code) async {
    final salt = _randomSalt();
    final hash = _hash(_normalizeCode(code), salt);
    await _storage.write(_kRecoverySaltKey, salt);
    await _storage.write(_kRecoveryHashKey, hash);
  }

  /// Check a candidate code. Accepts lowercase and ignores dashes/spaces
  /// so typed codes are forgiving.
  Future<bool> verifyRecoveryCode(String code) async {
    final salt = await _storage.read(_kRecoverySaltKey);
    final stored = await _storage.read(_kRecoveryHashKey);
    if (salt == null || stored == null) return false;
    return _constantTimeEquals(_hash(_normalizeCode(code), salt), stored);
  }

  /// Canonical form for hashing/comparison: uppercase, no separators.
  static String _normalizeCode(String code) =>
      code.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  String _randomSalt() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return base64Url.encode(bytes);
  }

  static final _random = Random.secure();

  String _hash(String pin, String salt) {
    final bytes = utf8.encode('$salt:$pin');
    return sha256.convert(bytes).toString();
  }

  /// Constant-time comparison so timing can't leak hash prefixes.
  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
