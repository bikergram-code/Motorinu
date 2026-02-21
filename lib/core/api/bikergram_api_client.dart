// Bikergram API Client (Phase 2 - Auth + Auto-Refresh)
// Drops into: lib/core/api/bikergram_api_client.dart
//
// Features:
// - Token storage via SharedPreferences
// - Adds Authorization: Bearer <accessToken>
// - On 401: tries /refresh.php once, then retries original request
// - logout() calls /logout.php and clears local tokens
//
// Expected endpoints (server):
// - POST https://api.bikergram.com/refresh.php  { "refreshToken": "..." }
// - POST https://api.bikergram.com/logout.php   { "refreshToken": "..." }
//
// The server response can be either:
// { "ok": true, "data": { "tokens": { "accessToken": "...", "refreshToken": "..." } } }
// or
// { "success": true, "data": { "tokens": { "accessToken": "...", "refreshToken": "..." } } }

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class BikergramTokens {
  final String accessToken;
  final String refreshToken;

  const BikergramTokens({required this.accessToken, required this.refreshToken});

  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        'refreshToken': refreshToken,
      };

  static BikergramTokens? fromUnknown(dynamic json) {
    if (json is! Map) return null;
    final m = json.cast<String, dynamic>();
    final access = (m['accessToken'] ?? m['access_token'] ?? '').toString();
    final refresh = (m['refreshToken'] ?? m['refresh_token'] ?? '').toString();
    if (access.isEmpty || refresh.isEmpty) return null;
    return BikergramTokens(accessToken: access, refreshToken: refresh);
  }
}

class BikergramTokenStore {
  static const _k = 'bikergram_tokens_v1';

  Future<BikergramTokens?> read() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_k);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return BikergramTokens.fromUnknown(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(BikergramTokens t) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_k, jsonEncode(t.toJson()));
  }

  Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_k);
  }
}

class BikergramApiException implements Exception {
  final int status;
  final String code;
  final String message;
  final dynamic details;

  BikergramApiException({
    required this.status,
    required this.code,
    required this.message,
    this.details,
  });

  @override
  String toString() => 'BikergramApiException($status, $code): $message';
}

class BikergramApiClient {
  final String baseUrl; // e.g. https://api.bikergram.com
  final http.Client _http;
  final BikergramTokenStore tokenStore;

  BikergramApiClient({
    required this.baseUrl,
    http.Client? httpClient,
    BikergramTokenStore? store,
  })  : _http = httpClient ?? http.Client(),
        tokenStore = store ?? BikergramTokenStore();

  Future<Map<String, dynamic>> getJson(String path, {bool auth = true}) async {
    return _sendWithAutoRefresh(
      method: 'GET',
      path: path,
      body: null,
      auth: auth,
    );
  }

  Future<Map<String, dynamic>> postJson(String path,
      {Map<String, dynamic>? body, bool auth = true}) async {
    return _sendWithAutoRefresh(
      method: 'POST',
      path: path,
      body: body ?? const {},
      auth: auth,
    );
  }

  Future<Map<String, dynamic>> _sendWithAutoRefresh({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    required bool auth,
  }) async {
    final tokens = auth ? await tokenStore.read() : null;

    final res1 = await _sendOnce(method: method, path: path, body: body, tokens: tokens);

    // Try refresh once if unauthorized
    if (auth && res1.statusCode == 401 && tokens != null && tokens.refreshToken.isNotEmpty) {
      final newTokens = await _refresh(tokens.refreshToken);
      if (newTokens != null) {
        await tokenStore.write(newTokens);
        final res2 = await _sendOnce(method: method, path: path, body: body, tokens: newTokens);
        return _decodeOrThrow(res2);
      }
    }

    return _decodeOrThrow(res1);
  }

  Future<http.Response> _sendOnce({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    BikergramTokens? tokens,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (tokens != null && tokens.accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${tokens.accessToken}';
    }

    switch (method.toUpperCase()) {
      case 'GET':
        return _http.get(uri, headers: headers);
      case 'POST':
        return _http.post(uri, headers: headers, body: jsonEncode(body ?? const {}));
      default:
        throw ArgumentError('Unsupported method: $method');
    }
  }

  Map<String, dynamic> _decodeOrThrow(http.Response res) {
    Map<String, dynamic>? j;
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map) j = decoded.cast<String, dynamic>();
    } catch (_) {
      j = null;
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (j == null) {
        throw BikergramApiException(
          status: res.statusCode,
          code: 'bad_json',
          message: 'Invalid JSON response',
          details: res.body,
        );
      }
      // Some endpoints may return {ok:false,...} even with 200; keep as-is
      return j;
    }

    // Parse common error formats
    final err = (j?['error'] is Map) ? (j!['error'] as Map).cast<String, dynamic>() : null;
    final code = (err?['code'] ?? j?['code'] ?? 'http_${res.statusCode}').toString();
    final msg = (err?['message'] ?? j?['message'] ?? 'HTTP ${res.statusCode}').toString();
    final details = (err?['details'] ?? j?['details']);

    throw BikergramApiException(status: res.statusCode, code: code, message: msg, details: details);
  }

  Future<BikergramTokens?> _refresh(String refreshToken) async {
    try {
      final uri = Uri.parse('$baseUrl/refresh.php');
      final res = await _http.post(
        uri,
        headers: const {'Accept': 'application/json', 'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );

      if (res.statusCode < 200 || res.statusCode >= 300) return null;

      final decoded = jsonDecode(res.body);
      if (decoded is! Map) return null;
      final m = decoded.cast<String, dynamic>();

      // Accept both "ok" and "success"
      final ok = (m['ok'] == true) || (m['success'] == true);
      if (!ok) return null;

      final data = (m['data'] is Map) ? (m['data'] as Map).cast<String, dynamic>() : null;
      final tokens = data?['tokens'] ?? data?['token'] ?? data?['auth'] ?? null;

      return BikergramTokens.fromUnknown(tokens);
    } catch (_) {
      return null;
    }
  }

  /// Call server logout and always clear local tokens.
  Future<void> logout() async {
    final t = await tokenStore.read();
    try {
      await _http.post(
        Uri.parse('$baseUrl/logout.php'),
        headers: const {'Accept': 'application/json', 'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': t?.refreshToken ?? ''}),
      );
    } catch (_) {
      // ignore
    } finally {
      await tokenStore.clear();
    }
  }
}