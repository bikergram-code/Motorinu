// lib/main_auth_debug_http.dart
//
// Self-contained Auth Debug (Dio + SharedPreferences) to test:
// - POST https://api.bikergram.com/login.php
// - POST https://api.bikergram.com/refresh.php
// - POST https://api.bikergram.com/logout.php
// - GET  https://api.bikergram.com/me.php
//
// Run (Windows PowerShell | lokal):
//   flutter run -t lib/main_auth_debug_http.dart -d web-server --web-hostname 127.0.0.1 --web-port 5174
//
// Open in browser:
//   http://127.0.0.1:5174

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kApiBase = 'https://api.bikergram.com';
const String kKeyAccess = 'bg_access_token';
const String kKeyRefresh = 'bg_refresh_token';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _AuthDebugHttpApp());
}

class _AuthDebugHttpApp extends StatelessWidget {
  const _AuthDebugHttpApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bikergram Auth Debug (HTTP)',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const AuthDebugHttpScreen(),
    );
  }
}

class AuthDebugHttpScreen extends StatefulWidget {
  const AuthDebugHttpScreen({super.key});

  @override
  State<AuthDebugHttpScreen> createState() => _AuthDebugHttpScreenState();
}

class _AuthDebugHttpScreenState extends State<AuthDebugHttpScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _log = ValueNotifier<String>('');
  bool _busy = false;

  Dio _dio(String? accessToken) {
    final d = Dio(BaseOptions(
      baseUrl: kApiBase,
      connectTimeout: const Duration(seconds: 8),
      sendTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 12),
      headers: {
        'Content-Type': 'application/json',
        if (accessToken != null && accessToken.trim().isNotEmpty) 'Authorization': 'Bearer $accessToken',
      },
      responseType: ResponseType.json,
      validateStatus: (s) => s != null && s >= 200 && s < 600, // handle errors ourselves
    ));
    return d;
  }

  void _append(Object msg) {
    final ts = DateTime.now().toIso8601String().replaceFirst('T', ' ').split('.').first;
    _log.value = '${_log.value}[$ts] $msg\n';
  }

  Future<SharedPreferences> _sp() => SharedPreferences.getInstance();

  Future<void> _saveTokens({String? access, String? refresh}) async {
    final sp = await _sp();
    if (access != null) await sp.setString(kKeyAccess, access);
    if (refresh != null) await sp.setString(kKeyRefresh, refresh);
  }

  Future<String?> _readAccess() async {
    final sp = await _sp();
    final v = sp.getString(kKeyAccess);
    return (v == null || v.trim().isEmpty) ? null : v.trim();
  }

  Future<String?> _readRefresh() async {
    final sp = await _sp();
    final v = sp.getString(kKeyRefresh);
    return (v == null || v.trim().isEmpty) ? null : v.trim();
  }

  Future<void> _clearTokens() async {
    final sp = await _sp();
    await sp.remove(kKeyAccess);
    await sp.remove(kKeyRefresh);
  }

  String? _extractToken(Map<String, dynamic> json, List<String> keys) {
    for (final k in keys) {
      final v = json[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    final data = json['data'];
    if (data is Map) {
      final dm = Map<String, dynamic>.from(data);
      for (final k in keys) {
        final v = dm[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      final tokens = dm['tokens'];
      if (tokens is Map) {
        final tm = Map<String, dynamic>.from(tokens);
        for (final k in keys) {
          final v = tm[k];
          if (v is String && v.trim().isNotEmpty) return v.trim();
        }
      }
    }
    return null;
  }

  Map<String, dynamic> _asJson(Response r) {
    try {
      if (r.data is Map) return Map<String, dynamic>.from(r.data as Map);
      if (r.data is String) return json.decode(r.data as String) as Map<String, dynamic>;
    } catch (_) {}
    return {
      'httpStatus': r.statusCode,
      'raw': r.data?.toString(),
    };
  }

  Future<void> _run(String label, Future<Map<String, dynamic>> Function() fn) async {
    setState(() => _busy = true);
    final sw = Stopwatch()..start();
    _append('--- $label ---');
    try {
      final res = await fn();
      _append(const JsonEncoder.withIndent('  ').convert(res));
    } catch (e) {
      _append('ERROR: $e');
    } finally {
      sw.stop();
      _append('--- $label done (${sw.elapsedMilliseconds} ms) ---');
      setState(() => _busy = false);
    }
  }

  Future<Map<String, dynamic>> _health() async {
    final d = _dio(null);
    final r = await d.get('/health.php');
    return {
      'httpStatus': r.statusCode,
      'body': r.data?.toString(),
    };
  }

Future<Map<String, dynamic>> _register() async {
  final email = _emailCtrl.text.trim();
  final password = _passCtrl.text;
  if (email.isEmpty || password.isEmpty) {
    return {
      "ok": false,
      "error": {"code": "client_input", "message": "Email & Passwort sind erforderlich", "details": {}},
      "_status": 0,
    };
  }

  final dio = _dio();
  final res = await dio.post(
    '/register.php',
    data: {"email": email, "password": password},
    options: Options(headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    }),
  );

  final data = (res.data is Map<String, dynamic>)
      ? (res.data as Map<String, dynamic>)
      : <String, dynamic>{"raw": res.data};

  data["_status"] = res.statusCode ?? 0;

  // Wenn Register Tokens zurückgibt -> direkt speichern
  final tokens = (data["data"] is Map<String, dynamic>)
      ? (data["data"]["tokens"] as Map<String, dynamic>?)
      : null;

  if (tokens != null) {
    final access = tokens["accessToken"]?.toString();
    final refresh = tokens["refreshToken"]?.toString();
    if ((access ?? "").isNotEmpty && (refresh ?? "").isNotEmpty) {
      await _saveTokens(accessToken: access!, refreshToken: refresh!);
      setState(() {
        _accessToken = access;
        _refreshToken = refresh;
      });
    }
  }

  return data;
}


  Future<Map<String, dynamic>> _login() async {
    final d = _dio(null);
    final r = await d.post(
      '/login.php',
      data: json.encode({'email': _email.text.trim(), 'password': _pass.text}),
    );
    final j = _asJson(r);

    final access = _extractToken(j, const ['accessToken', 'access_token', 'token', 'jwt']);
    final refresh = _extractToken(j, const ['refreshToken', 'refresh_token']);

    if (access != null) await _saveTokens(access: access);
    if (refresh != null) await _saveTokens(refresh: refresh);

    return {
      'httpStatus': r.statusCode,
      ...j,
      '_saved': {
        'accessToken': access != null ? '${access.substring(0, access.length > 18 ? 18 : access.length)}...' : null,
        'refreshToken': refresh != null ? '${refresh.substring(0, refresh.length > 18 ? 18 : refresh.length)}...' : null,
      },
    };
  }

  Future<Map<String, dynamic>> _me() async {
    final access = await _readAccess();
    final d = _dio(access);
    final r = await d.get('/me.php');
    final j = _asJson(r);
    return {'httpStatus': r.statusCode, ...j};
  }

  Future<Map<String, dynamic>> _refresh() async {
    final refresh = await _readRefresh();
    final d = _dio(null);
    final r = await d.post('/refresh.php', data: json.encode({'refreshToken': refresh ?? ''}));
    final j = _asJson(r);

    final accessNew = _extractToken(j, const ['accessToken', 'access_token', 'token', 'jwt']);
    final refreshNew = _extractToken(j, const ['refreshToken', 'refresh_token']);

    if (accessNew != null) await _saveTokens(access: accessNew);
    if (refreshNew != null) await _saveTokens(refresh: refreshNew);

    return {
      'httpStatus': r.statusCode,
      ...j,
      '_saved': {
        'accessToken': accessNew != null ? '${accessNew.substring(0, accessNew.length > 18 ? 18 : accessNew.length)}...' : null,
        'refreshToken': refreshNew != null ? '${refreshNew.substring(0, refreshNew.length > 18 ? 18 : refreshNew.length)}...' : null,
      },
    };
  }

  Future<Map<String, dynamic>> _logout() async {
    final refresh = await _readRefresh();
    final d = _dio(null);
    final r = await d.post('/logout.php', data: json.encode({'refreshToken': refresh ?? ''}));
    final j = _asJson(r);
    await _clearTokens();
    return {'httpStatus': r.statusCode, ...j, '_clearedLocalTokens': true};
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    _log.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bikergram Auth Debug (HTTP)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _pass,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ElevatedButton(
                  onPressed: _busy ? null : () => _run('HEALTH', _health),
                  child: const Text('HEALTH'),
                ),
                ElevatedButton(
                  onPressed: _busy ? null : () => _run('REGISTER', _register),
                  child: const Text('REGISTER'),
                ),
                ElevatedButton(
                  onPressed: _busy ? null : () => _run('LOGIN', _login),
                  child: const Text('LOGIN'),
                ),
                ElevatedButton(
                  onPressed: _busy ? null : () => _run('ME', _me),
                  child: const Text('ME'),
                ),
                ElevatedButton(
                  onPressed: _busy ? null : () => _run('REFRESH', _refresh),
                  child: const Text('REFRESH'),
                ),
                ElevatedButton(
                  onPressed: _busy ? null : () => _run('LOGOUT', _logout),
                  child: const Text('LOGOUT'),
                ),
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          await _clearTokens();
                          _append('TokenStore: cleared');
                          setState(() {});
                        },
                  child: const Text('CLEAR TOKENS'),
                ),
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () {
                          _log.value = '';
                          setState(() {});
                        },
                  child: const Text('CLEAR LOG'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FutureBuilder(
              future: Future.wait([_readAccess(), _readRefresh()]),
              builder: (context, snap) {
                final access = (snap.data is List) ? (snap.data as List)[0] as String? : null;
                final refresh = (snap.data is List) ? (snap.data as List)[1] as String? : null;
                String short(String? t) => t == null ? '(none)' : '${t.substring(0, t.length > 18 ? 18 : t.length)}...';
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Stored:\n- accessToken: ${short(access)}\n- refreshToken: ${short(refresh)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            if (_busy)
              const LinearProgressIndicator(minHeight: 3),
            if (_busy) const SizedBox(height: 8),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: ValueListenableBuilder<String>(
                  valueListenable: _log,
                  builder: (context, value, _) {
                    return SingleChildScrollView(
                      child: SelectableText(value.isEmpty ? 'Log...' : value),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
