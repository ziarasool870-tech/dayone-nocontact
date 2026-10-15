/// Typed wrapper over SharedPreferences for Day One settings.
///
/// Keys are namespaced with `dayone.`. NOTE: the Android home-screen widget
/// does NOT read this file — it reads `streak_start_ms` / `widget_theme`
/// from the separate `HomeWidgetPreferences` file, written via
/// `HomeWidget.saveWidgetData` (see AppState._pushWidget). Keep those
/// string keys stable instead.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrefsService {
  PrefsService._(this._prefs);
  final SharedPreferences _prefs;

  static PrefsService? _instance;

  static Future<PrefsService> instance() async {
    final existing = _instance;
    if (existing != null) return existing;
    final prefs = await SharedPreferences.getInstance();
    return _instance = PrefsService._(prefs);
  }

  /// Test-only constructor.
  @visibleForTesting
  static void setTestInstance(PrefsService test) => _instance = test;

  // Keys — STABLE: the native widget reads streak_start_ms.
  static const kOnboardingDone = 'dayone.onboarding_done';
  static const kUserName = 'dayone.user_name';
  static const kStreakStartMs = 'dayone.streak_start_ms';
  static const kLongestDays = 'dayone.longest_days';
  static const kTotalCleanDays = 'dayone.total_clean_days';
  static const kNotificationsOn = 'dayone.notifications_on';
  static const kReminderHour = 'dayone.reminder_hour';
  static const kReminderMinute = 'dayone.reminder_minute';
  static const kIsPro = 'dayone.is_pro';
  static const kProProductId = 'dayone.pro_product_id';
  static const kMilestonesSeen = 'dayone.milestones_seen';
  static const kCustomReasons = 'dayone.custom_reasons';
  static const kHiddenDefaultReasons = 'dayone.hidden_default_reasons';

  bool get onboardingDone => _prefs.getBool(kOnboardingDone) ?? false;
  Future<void> setOnboardingDone(bool v) => _prefs.setBool(kOnboardingDone, v);

  /// Removes every stored setting. Used by "Delete my data" — after
  /// this the app behaves like a fresh install.
  Future<void> clearAll() => _prefs.clear();

  String get userName => _prefs.getString(kUserName) ?? '';
  Future<void> setUserName(String v) => _prefs.setString(kUserName, v);

  /// Day-0 start as epoch millis, local time. Null when never set.
  int? get streakStartMs => _prefs.getInt(kStreakStartMs);
  Future<void> setStreakStartMs(int v) => _prefs.setInt(kStreakStartMs, v);

  int get longestDays => _prefs.getInt(kLongestDays) ?? 0;
  Future<void> setLongestDays(int v) => _prefs.setInt(kLongestDays, v);

  int get totalCleanDays => _prefs.getInt(kTotalCleanDays) ?? 0;
  Future<void> setTotalCleanDays(int v) => _prefs.setInt(kTotalCleanDays, v);

  bool get notificationsOn => _prefs.getBool(kNotificationsOn) ?? true;
  Future<void> setNotificationsOn(bool v) =>
      _prefs.setBool(kNotificationsOn, v);

  int get reminderHour => _prefs.getInt(kReminderHour) ?? 20;
  int get reminderMinute => _prefs.getInt(kReminderMinute) ?? 0;
  Future<void> setReminderTime(int h, int m) async {
    await _prefs.setInt(kReminderHour, h);
    await _prefs.setInt(kReminderMinute, m);
  }

  bool get isPro => _prefs.getBool(kIsPro) ?? false;
  Future<void> setPro(bool v, {String? productId}) async {
    await _prefs.setBool(kIsPro, v);
    if (productId != null) {
      await _prefs.setString(kProProductId, productId);
    } else if (!v) {
      await _prefs.remove(kProProductId);
    }
  }

  String? get proProductId => _prefs.getString(kProProductId);

  /// Milestone days the user has already seen celebrated (comma-separated).
  Set<int> get milestonesSeen {
    final raw = _prefs.getString(kMilestonesSeen) ?? '';
    if (raw.isEmpty) return {};
    return raw.split(',').map(int.tryParse).whereType<int>().toSet();
  }

  Future<void> markMilestoneSeen(int day) async {
    final seen = milestonesSeen..add(day);
    await _prefs.setString(kMilestonesSeen, seen.map((e) => '$e').join(','));
  }

  /// The user's own SOS reasons, shown above the defaults.
  List<String> get customReasons {
    final raw = _prefs.getString(kCustomReasons);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<String>().toList();
      }
    } catch (_) {
      // Corrupt payload: start fresh rather than crash.
    }
    return [];
  }

  Future<void> setCustomReasons(List<String> reasons) =>
      _prefs.setString(kCustomReasons, jsonEncode(reasons));

  /// Indices into [defaultReasons] the user chose to hide.
  Set<int> get hiddenDefaultReasons {
    final raw = _prefs.getString(kHiddenDefaultReasons);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<num>().map((e) => e.toInt()).toSet();
      }
    } catch (_) {
      // Corrupt payload: start fresh rather than crash.
    }
    return {};
  }

  Future<void> setHiddenDefaultReasons(Set<int> indices) =>
      _prefs.setString(kHiddenDefaultReasons, jsonEncode(indices.toList()));

  /// All settings as a plain map for the encrypted export feature.
  Map<String, Object?> exportSettings() {
    final out = <String, Object?>{};
    for (final k in [
      kOnboardingDone,
      kUserName,
      kStreakStartMs,
      kLongestDays,
      kTotalCleanDays,
      kNotificationsOn,
      kReminderHour,
      kReminderMinute,
      kIsPro,
      kProProductId,
      kMilestonesSeen,
      kCustomReasons,
      kHiddenDefaultReasons,
    ]) {
      out[k] = _prefs.get(k);
    }
    return out;
  }

  /// Restores settings from an export map.
  Future<void> importSettings(Map<String, dynamic> map) async {
    for (final e in map.entries) {
      final v = e.value;
      if (v == null) {
        await _prefs.remove(e.key);
      } else if (v is bool) {
        await _prefs.setBool(e.key, v);
      } else if (v is int) {
        await _prefs.setInt(e.key, v);
      } else if (v is double) {
        await _prefs.setDouble(e.key, v);
      } else if (v is String) {
        await _prefs.setString(e.key, v);
      }
    }
  }
}
