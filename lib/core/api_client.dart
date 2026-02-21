import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';

/// Minimal HTTP client wrapper for the Bikergram API.
/// - Supports a global `baseUrl`
/// - Supports bearer token via `setToken()`
/// - Supports lazy token retrieval via `sessionTokenProvider` (e.g. from secure storage)
class ApiClient {
  ApiClient._internal();

  /// Singleton accessor (allows calling `ApiClient()` in other layers).
  factory ApiClient() => instance;

  static final ApiClient instance = ApiClient._internal();

  static String _baseUrl = ApiConfig.apiBaseUrl;
  static String? _token;

  /// Optional async token provider. If set, it will be consulted when a request
  /// needs auth and no token is currently stored (or to refresh, if you choose
  /// to keep _token empty).
  static Future<String?> Function()? _sessionTokenProvider;

  static const Duration _timeout = Duration(seconds: 25);

  /// Configure the API client.
  /// - [baseUrl] should be the API base, e.g. https://api.bikergram.com
  /// - [token] optional initial bearer token
  /// - [sessionTokenProvider] optional async function returning the current token
  static void configure({
    required String baseUrl,
    String? token,
    Future<String?> Function()? sessionTokenProvider,
  }) {
    _baseUrl = baseUrl.trim().isEmpty ? _baseUrl : baseUrl.trim();
    if (token != null) {
      _token = token.trim().isEmpty ? null : token.trim();
    }
    if (sessionTokenProvider != null) {
      _sessionTokenProvider = sessionTokenProvider;
    }
  }

  /// Set/replace bearer token (e.g. after login).
  Future<void> setToken(String? token) async {
    _token = (token == null || token.trim().isEmpty) ? null : token.trim();
  }

  /// Optional: update token provider after configure.
  static void setSessionTokenProvider(Future<String?> Function()? provider) {
    _sessionTokenProvider = provider;
  }

  static Uri _resolveUri(String path) {
    final base = Uri.parse(_baseUrl.endsWith('/') ? _baseUrl : '$_baseUrl/');
    final p = path.startsWith('/') ? path.substring(1) : path;
    return base.resolve(p);
  }

  static Future<String?> _resolveToken() async {
    if (_token != null && _token!.isNotEmpty) return _token;

    final provider = _sessionTokenProvider;
    if (provider == null) return _token;

    try {
      final t = await provider();
      if (t != null && t.trim().isNotEmpty) {
        _token = t.trim();
        return _token;
      }
    } catch (_) {
      // ignore; fall back to existing token
    }
    return _token;
  }

  static Map<String, dynamic> _decodeJson(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    return {'data': decoded};
  }

  static Map<String, dynamic> _asError(int status, String message, [dynamic details]) {
    final m = <String, dynamic>{
      'ok': false,
      '_status': status,
      'status': status,
      'message': message,
    };
    if (details != null) m['details'] = details;
    return m;
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? headers,
    bool withAuth = true,
  }) async {
    final uri = _resolveUri(path);

    final h = <String, String>{
      'Accept': 'application/json',
      ...?headers,
    };

    if (withAuth) {
      final t = await _resolveToken();
      if (t != null && t.isNotEmpty) h['Authorization'] = 'Bearer $t';
    }

    final res = await http.get(uri, headers: h).timeout(_timeout);
    return _handleResponse(res);
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    bool withAuth = true,
  }) async {
    final uri = _resolveUri(path);

    final h = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
      ...?headers,
    };

    if (withAuth) {
      final t = await _resolveToken();
      if (t != null && t.isNotEmpty) h['Authorization'] = 'Bearer $t';
    }

    final res = await http
        .post(uri, headers: h, body: jsonEncode(body ?? const {}))
        .timeout(_timeout);

    return _handleResponse(res);
  }

  Future<Map<String, dynamic>> putJson(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    bool withAuth = true,
  }) async {
    final uri = _resolveUri(path);

    final h = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
      ...?headers,
    };

    if (withAuth) {
      final t = await _resolveToken();
      if (t != null && t.isNotEmpty) h['Authorization'] = 'Bearer $t';
    }

    final res = await http
        .put(uri, headers: h, body: jsonEncode(body ?? const {}))
        .timeout(_timeout);

    return _handleResponse(res);
  }

  Future<Map<String, dynamic>> deleteJson(
    String path, {
    Map<String, String>? headers,
    bool withAuth = true,
  }) async {
    final uri = _resolveUri(path);

    final h = <String, String>{
      'Accept': 'application/json',
      ...?headers,
    };

    if (withAuth) {
      final t = await _resolveToken();
      if (t != null && t.isNotEmpty) h['Authorization'] = 'Bearer $t';
    }

    final res = await http.delete(uri, headers: h).timeout(_timeout);
    return _handleResponse(res);
  }

  Map<String, dynamic> _handleResponse(http.Response res) {
    final status = res.statusCode;

    // Try JSON first
    try {
      final map = _decodeJson(res.body);
      map.putIfAbsent('_status', () => status);

      // if API doesn't include ok, still return parsed payload
      return map;
    } catch (_) {
      // Not JSON
    }

    if (status >= 200 && status < 300) {
      // Successful but not JSON
      return {'ok': true, '_status': status, 'status': status, 'body': res.body};
    }

    return _asError(status, 'HTTP $status', res.body);
  }
}
