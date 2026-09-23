import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/prediction.dart';

/// Cross-platform local persistence (token, settings, scan history).
/// All reads/writes are defensive so the app works even if storage is blocked.
class Storage {
  static const _kBaseUrl = 'darm.base_url';
  static const _kToken = 'darm.token';
  static const _kRole = 'darm.role';
  static const _kName = 'darm.name';
  static const _kHistory = 'darm.history';
  static const _kThemeMode = 'darm.theme_mode';
  static const _kChats = 'darm.chats';
  static const _kTermsAccepted = 'darm.terms_accepted';

  SharedPreferences? _prefs;
  Future<SharedPreferences> get _p async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<String?> getBaseUrl() async => (await _p).getString(_kBaseUrl);
  Future<void> setBaseUrl(String v) async => (await _p).setString(_kBaseUrl, v);

  // ----- Theme mode ('system' | 'light' | 'dark') -----
  Future<String> getThemeMode() async =>
      (await _p).getString(_kThemeMode) ?? 'system';
  Future<void> setThemeMode(String v) async =>
      (await _p).setString(_kThemeMode, v);

  // ----- Terms & Conditions acceptance -----
  Future<bool> getTermsAccepted() async =>
      (await _p).getBool(_kTermsAccepted) ?? false;
  Future<void> setTermsAccepted(bool v) async =>
      (await _p).setBool(_kTermsAccepted, v);

  // ----- Chat history (list of conversation JSON) -----
  Future<List<String>> loadChatsRaw() async {
    try {
      return (await _p).getStringList(_kChats) ?? [];
    } catch (_) {
      return [];
    }
  }

  Future<void> saveChatsRaw(List<String> chats) async {
    try {
      await (await _p).setStringList(_kChats, chats);
    } catch (_) {}
  }

  Future<void> saveSession(String token, String role, String name) async {
    final p = await _p;
    await p.setString(_kToken, token);
    await p.setString(_kRole, role);
    await p.setString(_kName, name);
  }

  Future<Map<String, String>?> loadSession() async {
    final p = await _p;
    final t = p.getString(_kToken);
    if (t == null) return null;
    return {
      'token': t,
      'role': p.getString(_kRole) ?? 'patient',
      'name': p.getString(_kName) ?? '',
    };
  }

  Future<void> clearSession() async {
    final p = await _p;
    await p.remove(_kToken);
    await p.remove(_kRole);
    await p.remove(_kName);
  }

  // ----- History (stored as list of prediction JSON) -----
  Future<List<Prediction>> loadHistory() async {
    try {
      final raw = (await _p).getStringList(_kHistory) ?? [];
      return raw
          .map((s) =>
              Prediction.fromStored(jsonDecode(s) as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> addHistory(Prediction p, {int max = 50}) async {
    try {
      final prefs = await _p;
      final list = prefs.getStringList(_kHistory) ?? [];
      list.insert(0, jsonEncode(p.toJson()));
      if (list.length > max) list.removeRange(max, list.length);
      await prefs.setStringList(_kHistory, list);
    } catch (_) {}
  }

  Future<void> clearHistory() async => (await _p).remove(_kHistory);
}
