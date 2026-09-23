import 'dart:async';

import 'package:flutter/material.dart';

import 'dart:convert';

import '../core/config.dart';
import '../models/chat_session.dart';
import '../models/meta_options.dart';
import '../models/prediction.dart';
import '../services/api.dart';
import '../services/storage.dart';

enum AuthStatus { unknown, signedOut, signedIn }

/// App-wide controller: auth session, API base URL, metadata catalogue, history.
class AppController extends ChangeNotifier {
  AppController(this._storage);

  final Storage _storage;

  AuthStatus status = AuthStatus.unknown;
  String baseUrl = AppConfig.defaultApiBase;
  String? token;
  String role = 'patient';
  String displayName = '';
  bool backendOnline = false;
  bool mockMode = false;
  bool chatEnabled = false;

  ThemeMode themeMode = ThemeMode.system;
  bool termsAccepted = false;

  MetaOptions meta = MetaOptions.fallback();
  List<Prediction> history = [];
  List<ChatSession> chats = [];

  late DarmApi _api = DarmApi(AppConfig.defaultApiBase);
  DarmApi get api => _api;

  bool get isClinic => role == 'clinic';
  bool get isPatient => role == 'patient';

  Future<void> bootstrap() async {
    baseUrl = (await _storage.getBaseUrl()) ?? AppConfig.defaultApiBase;
    _api = DarmApi(baseUrl);

    themeMode = _parseThemeMode(await _storage.getThemeMode());
    termsAccepted = await _storage.getTermsAccepted();

    final session = await _storage.loadSession();
    if (session != null) {
      token = session['token'];
      role = session['role']!;
      displayName = session['name']!;
      status = AuthStatus.signedIn;
    } else {
      status = AuthStatus.signedOut;
    }
    history = await _storage.loadHistory();
    chats = await _loadChats();
    notifyListeners();

    // Fire-and-forget connectivity + metadata refresh.
    unawaited(refreshBackendState());
  }

  // ----- Chat history -----
  Future<List<ChatSession>> _loadChats() async {
    try {
      final raw = await _storage.loadChatsRaw();
      return raw
          .map((s) =>
              ChatSession.fromJson(jsonDecode(s) as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _persistChats() async {
    await _storage
        .saveChatsRaw(chats.map((c) => jsonEncode(c.toJson())).toList());
  }

  /// Insert or update a conversation (most-recent first), keeping the last 50.
  Future<void> saveChat(ChatSession session) async {
    chats.removeWhere((c) => c.id == session.id);
    chats.insert(0, session);
    if (chats.length > 50) chats = chats.sublist(0, 50);
    notifyListeners();
    await _persistChats();
  }

  Future<void> deleteChat(String id) async {
    chats.removeWhere((c) => c.id == id);
    notifyListeners();
    await _persistChats();
  }

  Future<void> clearChats() async {
    chats = [];
    notifyListeners();
    await _persistChats();
  }

  ThemeMode _parseThemeMode(String s) => switch (s) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    notifyListeners();
    await _storage.setThemeMode(mode.name);
  }

  Future<void> acceptTerms() async {
    termsAccepted = true;
    notifyListeners();
    await _storage.setTermsAccepted(true);
  }

  Future<void> setBaseUrl(String url) async {
    baseUrl = url.trim();
    await _storage.setBaseUrl(baseUrl);
    _api.baseUrl = baseUrl;
    await refreshBackendState();
    notifyListeners();
  }

  Future<void> refreshBackendState() async {
    try {
      final details = await _api.healthDetails();
      backendOnline = true;
      mockMode = details['mock_mode'] as bool? ?? false;
      chatEnabled = details['chat_enabled'] as bool? ?? false;
    } catch (_) {
      backendOnline = false;
    }
    try {
      meta = await _api.metaOptions();
    } catch (_) {
      // keep fallback
    }
    notifyListeners();
  }

  Future<String?> login(String username, String password) async {
    try {
      final res = await _api.login(username, password);
      token = res.token;
      role = res.role;
      displayName = res.displayName;
      status = AuthStatus.signedIn;
      await _storage.saveSession(res.token, res.role, res.displayName);
      notifyListeners();
      unawaited(refreshBackendState());
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return 'Could not reach the server. Check the API URL in Settings.';
    }
  }

  Future<void> logout() async {
    token = null;
    status = AuthStatus.signedOut;
    await _storage.clearSession();
    notifyListeners();
  }

  Future<void> addToHistory(Prediction p) async {
    history = [p, ...history];
    if (history.length > 50) history = history.sublist(0, 50);
    await _storage.addHistory(p);
    notifyListeners();
  }

  Future<void> clearHistory() async {
    history = [];
    await _storage.clearHistory();
    notifyListeners();
  }
}
