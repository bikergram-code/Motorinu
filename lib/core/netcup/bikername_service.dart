import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class BikernameService {
  final String baseUrl;

  BikernameService({required this.baseUrl});

  static const String _tokenKey = 'bikername_client_token';
  static String? _cachedToken;

  static Future<String> get clientToken async {
    if (_cachedToken != null) return _cachedToken!;

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_tokenKey);
    if (stored != null && stored.isNotEmpty) {
      _cachedToken = stored;
      return stored;
    }

    final token = _generateToken();
    await prefs.setString(_tokenKey, token);
    _cachedToken = token;
    return token;
  }

  static String _generateToken() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  Uri _u(String path, [Map<String, String>? query]) {
    final clean = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final p = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$clean$p');
    if (query == null || query.isEmpty) return uri;
    return uri.replace(queryParameters: {...uri.queryParameters, ...query});
  }

  Future<http.Response> _postJsonWithFallback(List<String> paths, Map<String, dynamic> body) async {
    for (final p in paths) {
      final res = await http.post(
        _u(p),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (res.statusCode != 404) return res;
    }
    return http.Response('{"ok":false,"reason":"not_found"}', 404);
  }

  Future<http.Response> _getWithFallback(List<String> paths, [Map<String, String>? query]) async {
    for (final p in paths) {
      final res = await http.get(_u(p, query));
      if (res.statusCode != 404) return res;
    }
    return http.Response('{"ok":false,"reason":"not_found"}', 404);
  }

  Future<NameCheckResult> check(String name) async {
    final token = await clientToken;

    final res = await _postJsonWithFallback(
      const ['/bikername_check.php', '/api/bikername_check.php'],
      {'name': name, 'client_token': token},
    );

    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }

    final data = (jsonDecode(res.body) as Map).cast<String, dynamic>();
    return NameCheckResult.fromJson(data);
  }

  Future<bool> isAvailable(String name) async {
    final r = await check(name);
    return r.available;
  }

  Future<bool> reserve(String name) async {
    final token = await clientToken;

    final res = await _postJsonWithFallback(
      const ['/bikername_reserve.php', '/api/bikername_reserve.php'],
      {'name': name, 'client_token': token},
    );

    if (res.statusCode != 200) return false;

    final data = (jsonDecode(res.body) as Map).cast<String, dynamic>();
    final ok = data['ok'] == true;

    // some backends return {"ok":true,"reserved":true}
    final reserved = data['reserved'] == true;

    return ok && (reserved || !data.containsKey('reserved'));
  }

  Future<List<String>> generate({int count = 5, int maxAttempts = 60}) async {
    final token = await clientToken;

    // Try GET first (works well with self-signed SSL + caching)
    var res = await _getWithFallback(
      const ['/bikername_generate.php', '/api/bikername_generate.php'],
      {'count': '$count', 'max_attempts': '$maxAttempts', 'client_token': token},
    );

    // Some servers only accept POST
    if (res.statusCode == 405) {
      res = await _postJsonWithFallback(
        const ['/bikername_generate.php', '/api/bikername_generate.php'],
        {'count': count, 'max_attempts': maxAttempts, 'client_token': token},
      );
    }

    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }

    final data = (jsonDecode(res.body) as Map).cast<String, dynamic>();
    final ok = data['ok'] == true;
    if (!ok) {
      final reason = data['reason']?.toString() ?? 'unknown';
      throw Exception('generate_failed: $reason');
    }

    final names = <String>[];

    final n1 = data['name'];
    if (n1 is String && n1.trim().isNotEmpty) {
      names.add(n1.trim());
    }

    final n2 = data['names'];
    if (n2 is List) {
      for (final v in n2) {
        final s = v?.toString().trim() ?? '';
        if (s.isNotEmpty) names.add(s);
      }
    }

    return names;
  }

  Future<String> generateAvailableName({int maxAttempts = 60}) async {
    var tries = 0;

    while (tries < maxAttempts) {
      final batch = await generate(count: 6, maxAttempts: maxAttempts);

      for (final candidate in batch) {
        tries++;
        if (tries > maxAttempts) break;

        final r = await check(candidate);
        if (r.available) {
          final reserved = await reserve(candidate);
          if (reserved) return candidate;
        }
      }
    }

    throw Exception('no_available_name');
  }
}

class NameCheckResult {
  final bool available;
  final bool reservedByMe;
  final String? reason;

  const NameCheckResult({
    required this.available,
    required this.reservedByMe,
    this.reason,
  });

  factory NameCheckResult.fromJson(Map<String, dynamic> json) {
    return NameCheckResult(
      available: json['available'] == true,
      reservedByMe: json['reserved_by_me'] == true || json['reservedByMe'] == true,
      reason: json['reason']?.toString(),
    );
  }
}
