import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;

import '../models/meta_options.dart';
import '../models/prediction.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, [this.statusCode]);
  @override
  String toString() => message;
}

class LoginResult {
  final String token;
  final String role;
  final String displayName;
  final int expiresIn;
  LoginResult(this.token, this.role, this.displayName, this.expiresIn);
}

/// Thin, cross-platform client for the DARM FastAPI backend.
class DarmApi {
  DarmApi(this.baseUrl, {http.Client? client})
      : _client = client ?? http.Client();

  String baseUrl;
  final http.Client _client;

  Uri _u(String path) =>
      Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}$path');

  Future<bool> health() async {
    try {
      final r =
          await _client.get(_u('/health')).timeout(const Duration(seconds: 8));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> healthDetails() async {
    final r =
        await _client.get(_u('/health')).timeout(const Duration(seconds: 8));
    _ensureOk(r);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<LoginResult> login(String username, String password) async {
    final r = await _client
        .post(
          _u('/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'username': username, 'password': password}),
        )
        .timeout(const Duration(seconds: 15));
    if (r.statusCode == 401) {
      throw ApiException('Invalid username or password', 401);
    }
    _ensureOk(r);
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    return LoginResult(
      j['access_token'] as String,
      j['role'] as String,
      j['display_name'] as String? ?? username,
      (j['expires_in'] as num?)?.toInt() ?? 0,
    );
  }

  Future<MetaOptions> metaOptions() async {
    final r = await _client
        .get(_u('/meta/options'))
        .timeout(const Duration(seconds: 12));
    _ensureOk(r);
    return MetaOptions.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<Prediction> predict({
    required String token,
    required Uint8List imageBytes,
    required String filename,
    double? age,
    String sex = 'unknown',
    String localization = 'unknown',
    bool mcDropout = true,
  }) async {
    final req = http.MultipartRequest('POST', _u('/predict'))
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['sex'] = sex
      ..fields['localization'] = localization
      ..fields['mc_dropout'] = mcDropout.toString();
    if (age != null) req.fields['age'] = age.toString();
    req.files.add(http.MultipartFile.fromBytes(
      'image',
      imageBytes,
      filename: filename,
      contentType: MediaType('image', 'jpeg'),
    ));

    final streamed = await req.send().timeout(const Duration(seconds: 60));
    final r = await http.Response.fromStream(streamed);
    if (r.statusCode == 401) {
      throw ApiException('Session expired — please sign in again.', 401);
    }
    _ensureOk(r);
    return Prediction.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// DARM assistant. Returns the assistant's reply text.
  /// [history] is a list of {'role': 'user'|'assistant', 'text': ...} turns.
  /// [context] is the current result grounding (top_code, top_prob, ...).
  Future<String> chat({
    required String token,
    required String message,
    List<Map<String, String>> history = const [],
    Map<String, dynamic>? context,
    String lang = 'en',
  }) async {
    final r = await _client
        .post(
          _u('/chat'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'message': message,
            'history': history,
            'context': context,
            'lang': lang,
          }),
        )
        .timeout(const Duration(seconds: 45));
    if (r.statusCode == 401) {
      throw ApiException('Session expired — please sign in again.', 401);
    }
    _ensureOk(r);
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    return j['reply'] as String? ?? '';
  }

  void _ensureOk(http.Response r) {
    if (r.statusCode >= 200 && r.statusCode < 300) return;
    String msg = 'Request failed (${r.statusCode})';
    try {
      final j = jsonDecode(r.body);
      if (j is Map && j['detail'] != null) msg = j['detail'].toString();
    } catch (_) {}
    throw ApiException(msg, r.statusCode);
  }

  void close() => _client.close();
}
