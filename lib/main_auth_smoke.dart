import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/auth/token_pair.dart';
import 'core/auth/token_store.dart';
import 'core/network/dio_client.dart';

void main() {
  runApp(const AuthSmokeApp());
}

class AuthSmokeApp extends StatelessWidget {
  const AuthSmokeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bikergram Auth Smoke',
      theme: ThemeData.dark(useMaterial3: true),
      home: const AuthSmokePage(),
    );
  }
}

class AuthSmokePage extends StatefulWidget {
  const AuthSmokePage({super.key});

  @override
  State<AuthSmokePage> createState() => _AuthSmokePageState();
}

class _AuthSmokePageState extends State<AuthSmokePage> {
  final _logs = <String>[];
  final _emailCtrl = TextEditingController(text: 'test+web@bikergram.com');
  final _passCtrl = TextEditingController(text: 'Test1234!');
  final _tokenStore = TokenStore();

  late final _client = DioClient(
    baseUrl: 'https://api.bikergram.com',
    tokenStore: _tokenStore,
  );

  void log(String s) {
    setState(() => _logs.insert(0, '[${DateTime.now().toIso8601String()}] $s'));
  }

  String get logText => _logs.reversed.join('\n');

  Future<void> _copyLogs() async {
    await Clipboard.setData(ClipboardData(text: logText));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logs kopiert')),
      );
    }
  }

  void _logDioError(String label, Object e) {
    if (e is DioException) {
      final sc = e.response?.statusCode;
      final body = e.response?.data;
      log('$label ERROR DioException type=${e.type} status=$sc message=${e.message}');
      if (body != null) log('$label ERROR body=$body');
    } else {
      log('$label ERROR $e');
    }
  }

  Options _json({Map<String, dynamic>? extra}) {
    return Options(
      headers: {'Content-Type': 'application/json'},
      extra: extra ?? const {},
    );
  }

  Map<String, dynamic>? _extractTokens(dynamic body) {
    if (body is! Map) return null;

    final data = body['data'];
    if (data is Map && data['tokens'] is Map) {
      return Map<String, dynamic>.from(data['tokens'] as Map);
    }
    if (body['tokens'] is Map) {
      return Map<String, dynamic>.from(body['tokens'] as Map);
    }
    return null;
  }

  Future<void> _saveTokensFromResponse(dynamic body, String source) async {
    final t = _extractTokens(body);
    if (t == null) return;

    final at = (t['accessToken'] ?? t['access_token'] ?? '') as String;
    final rt = (t['refreshToken'] ?? t['refresh_token'] ?? '') as String;

    if (at.isNotEmpty && rt.isNotEmpty) {
      await _tokenStore.write(TokenPair(accessToken: at, refreshToken: rt), reason: source.toLowerCase());
      log('TOKENS saved (from $source)');
    } else {
      log('TOKENS NOT saved (from $source) - missing at/rt');
    }
  }

  Future<void> register() async {
    log('REGISTER...');
    try {
      final res = await _client.dio.post(
        '/register.php',
        data: {'email': _emailCtrl.text.trim(), 'password': _passCtrl.text},
        options: _json(extra: {'noAuth': true}),
      );
      log('REGISTER status=${res.statusCode} body=${res.data}');
      await _saveTokensFromResponse(res.data, 'REGISTER');
    } catch (e) {
      _logDioError('REGISTER', e);
    }
  }

  Future<void> login() async {
    log('LOGIN...');
    try {
      final res = await _client.dio.post(
        '/login.php',
        data: {'email': _emailCtrl.text.trim(), 'password': _passCtrl.text},
        options: _json(extra: {'noAuth': true}),
      );
      log('LOGIN status=${res.statusCode} body=${res.data}');
      await _saveTokensFromResponse(res.data, 'LOGIN');
    } catch (e) {
      _logDioError('LOGIN', e);
    }
  }

  Future<void> me() async {
    log('ME...');
    try {
      final res = await _client.dio.get('/me.php');
      log('ME status=${res.statusCode} body=${res.data}');
    } catch (e) {
      _logDioError('ME', e);
    }
  }

  Future<void> refreshManual() async {
    log('REFRESH (manual)...');
    try {
      final pair = await _tokenStore.read();
      if (pair == null) {
        log('REFRESH: no tokens saved yet');
        return;
      }

      // RAW JSON senden (refresh.php will JSON)
      final res = await _client.refreshDio.post(
        '/refresh.php',
        data: jsonEncode({'refreshToken': pair.refreshToken}),
        options: Options(
          contentType: Headers.jsonContentType,
          headers: {'Content-Type': 'application/json'},
          extra: {'noAuth': true, 'noRefresh': true},
        ),
      );

      log('REFRESH status=${res.statusCode} body=${res.data}');
      await _saveTokensFromResponse(res.data, 'REFRESH');
    } catch (e) {
      _logDioError('REFRESH', e);
    }
  }

  // ✅ Debug: zeigt kurz AT/RT im Log
  Future<void> showTokens() async {
    final pair = await _tokenStore.read();
    if (pair == null) {
      log('TOKENS: <none>');
      return;
    }
    String short(String s) => s.length <= 10 ? s : '${s.substring(0, 10)}...';
    log('TOKENS: at=${short(pair.accessToken)} rt=${short(pair.refreshToken)}');
  }

  // ✅ Debug: erzwingt 401 (AccessToken kaputt), RefreshToken bleibt gleich
  Future<void> corruptAccessToken() async {
    final pair = await _tokenStore.read();
    if (pair == null) {
      log('CORRUPT: no tokens saved yet');
      return;
    }
    await _tokenStore.write(TokenPair(
      accessToken: 'BAD_${DateTime.now().millisecondsSinceEpoch}',
      refreshToken: pair.refreshToken,
    ));
    log('CORRUPT: accessToken overwritten (refreshToken kept)');
  }

  Future<void> logout() async {
    log('LOGOUT...');
    try {
      final res = await _client.dio.post('/logout.php');
      log('LOGOUT status=${res.statusCode} body=${res.data}');
    } catch (e) {
      _logDioError('LOGOUT', e);
    } finally {
      await _tokenStore.clear(reason: 'logout');
      log('TOKENS cleared');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bikergram Auth/API Smoke'),
        actions: [
          IconButton(
            onPressed: _copyLogs,
            icon: const Icon(Icons.copy),
            tooltip: 'Logs kopieren',
          ),
          IconButton(
            onPressed: () => setState(_logs.clear),
            icon: const Icon(Icons.delete),
            tooltip: 'Logs leeren',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _passCtrl,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton(onPressed: register, child: const Text('Register')),
              ElevatedButton(onPressed: login, child: const Text('Login')),
              ElevatedButton(onPressed: me, child: const Text('Me')),
              ElevatedButton(onPressed: showTokens, child: const Text('ShowTokens')),
              ElevatedButton(onPressed: corruptAccessToken, child: const Text('CorruptAT')),
              ElevatedButton(onPressed: refreshManual, child: const Text('Refresh')),
              ElevatedButton(onPressed: logout, child: const Text('Logout')),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white24),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectionArea(
                  child: SingleChildScrollView(
                    reverse: true,
                    child: Text(
                      logText.isEmpty ? '— logs —' : logText,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}