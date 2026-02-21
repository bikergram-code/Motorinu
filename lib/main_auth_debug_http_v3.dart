import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

/// Standalone Auth HTTP Debug Screen (Web friendly)
/// Endpoints:
/// - GET  https://api.bikergram.com/health.php
/// - POST https://api.bikergram.com/register.php
/// - POST https://api.bikergram.com/login.php
/// - GET  https://api.bikergram.com/me.php   (Bearer access token)
/// - POST https://api.bikergram.com/refresh.php (refreshToken in body)
/// - POST https://api.bikergram.com/logout.php  (refreshToken in body)
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AuthDebugHttpV3App());
}

class AuthDebugHttpV3App extends StatelessWidget {
  const AuthDebugHttpV3App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bikergram Auth Debug (HTTP v3)',
      theme: ThemeData(useMaterial3: true),
      home: const AuthDebugHttpV3Screen(),
    );
  }
}

class AuthDebugHttpV3Screen extends StatefulWidget {
  const AuthDebugHttpV3Screen({super.key});

  @override
  State<AuthDebugHttpV3Screen> createState() => _AuthDebugHttpV3ScreenState();
}

class _AuthDebugHttpV3ScreenState extends State<AuthDebugHttpV3Screen> {
  final _emailCtrl = TextEditingController(text: 'test@example.com');
  final _userCtrl = TextEditingController(text: 'test');
  final _passCtrl = TextEditingController(text: 'test');

  final List<String> _lines = <String>[];

  String? _accessToken;
  String? _refreshToken;

  Dio _dio({bool auth = false}) {
    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://api.bikergram.com',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
        validateStatus: (_) => true,
        headers: <String, dynamic>{
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    // Add bearer token when requested and available.
    if (auth && (_accessToken?.isNotEmpty ?? false)) {
      dio.options.headers['Authorization'] = 'Bearer $_accessToken';
    }

    return dio;
  }

  void _log(String s) {
    final ts = DateTime.now().toIso8601String().replaceFirst('T', ' ').split('.').first;
    setState(() => _lines.add('[$ts] $s'));
  }

  String _pretty(dynamic data) {
    try {
      if (data is String) return data;
      return const JsonEncoder.withIndent('  ').convert(data);
    } catch (_) {
      return data.toString();
    }
  }

  Map<String, dynamic>? _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) {
      return data.map((k, v) => MapEntry(k.toString(), v));
    }
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        return _asMap(decoded);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  void _applyTokensFromBody(dynamic body) {
    final m = _asMap(body);
    if (m == null) return;

    final data = _asMap(m['data']);
    final tokens = data != null ? _asMap(data['tokens']) : null;
    final access = tokens?['accessToken']?.toString();
    final refresh = tokens?['refreshToken']?.toString();

    if (access != null && access.isNotEmpty) {
      _accessToken = access;
      _log('TokenStore: accessToken set (${access.substring(0, access.length < 10 ? access.length : 10)}...)');
    }
    if (refresh != null && refresh.isNotEmpty) {
      _refreshToken = refresh;
      _log('TokenStore: refreshToken set (${refresh.substring(0, refresh.length < 10 ? refresh.length : 10)}...)');
    }
  }

  String _fallbackUsernameFromEmail(String email) {
    final at = email.indexOf('@');
    final raw = (at > 0) ? email.substring(0, at) : email;
    // sanitize: keep letters, digits, underscore, dash, dot
    return raw.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '').trim();
  }

  Future<void> _health() async {
    _log('--- HEALTH ---');
    final dio = _dio();
    final res = await dio.get('/health.php', options: Options(responseType: ResponseType.plain));
    _log('--- HEALTH done ---');
    _log(_pretty({
      'body': res.data,
      '_status': res.statusCode,
      '_headers': {'content-type': res.headers.value('content-type')},
    }));
  }

  Future<void> _register() async {
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;
    var username = _userCtrl.text.trim();
    if (username.isEmpty) username = _fallbackUsernameFromEmail(email);

    _log('--- REGISTER ---');
    final dio = _dio();
    final res = await dio.post('/register.php', data: <String, dynamic>{
      'email': email,
      'username': username,
      'password': password,
    });

    _log('--- REGISTER done ---');
    _log(_pretty({
      'body': res.data,
      '_status': res.statusCode,
      '_headers': {'content-type': res.headers.value('content-type')},
    }));

    _applyTokensFromBody(res.data);
    _syncHeaderLine();
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;

    _log('--- LOGIN ---');
    final dio = _dio();
    final res = await dio.post('/login.php', data: <String, dynamic>{
      'email': email,
      'password': password,
    });

    _log('--- LOGIN done ---');
    _log(_pretty({
      'body': res.data,
      '_status': res.statusCode,
      '_headers': {'content-type': res.headers.value('content-type')},
    }));

    _applyTokensFromBody(res.data);
    _syncHeaderLine();
  }

  Future<void> _me() async {
    _log('--- ME ---');
    final dio = _dio(auth: true);
    final res = await dio.get('/me.php');

    _log('--- ME done ---');
    _log(_pretty({
      'body': res.data,
      '_status': res.statusCode,
      '_headers': {'content-type': res.headers.value('content-type')},
    }));
  }

  Future<void> _refresh() async {
    _log('--- REFRESH ---');
    final dio = _dio();
    final rt = _refreshToken;

    final res = await dio.post('/refresh.php', data: <String, dynamic>{
      if (rt != null && rt.isNotEmpty) 'refreshToken': rt,
    });

    _log('--- REFRESH done ---');
    _log(_pretty({
      'body': res.data,
      '_status': res.statusCode,
      '_headers': {'content-type': res.headers.value('content-type')},
    }));

    _applyTokensFromBody(res.data);
    _syncHeaderLine();
  }

  Future<void> _logout() async {
    _log('--- LOGOUT ---');
    final dio = _dio();
    final rt = _refreshToken;

    final res = await dio.post('/logout.php', data: <String, dynamic>{
      if (rt != null && rt.isNotEmpty) 'refreshToken': rt,
    });

    _log('--- LOGOUT done ---');
    _log(_pretty({
      'body': res.data,
      '_status': res.statusCode,
      '_headers': {'content-type': res.headers.value('content-type')},
    }));

    // clear local tokens after any logout attempt
    _accessToken = null;
    _refreshToken = null;
    _log('TokenStore: cleared (after LOGOUT)');
    _syncHeaderLine();
  }

  void _clearLog() {
    setState(() => _lines.clear());
  }

  void _clearTokens() {
    setState(() {
      _accessToken = null;
      _refreshToken = null;
    });
    _log('TokenStore: cleared (manual)');
    _syncHeaderLine();
  }

  void _syncHeaderLine() {
    // purely UI refresh
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accessShort = (_accessToken == null || _accessToken!.isEmpty)
        ? '—'
        : '${_accessToken!.substring(0, _accessToken!.length < 10 ? _accessToken!.length : 10)}…';
    final refreshShort = (_refreshToken == null || _refreshToken!.isEmpty)
        ? '—'
        : '${_refreshToken!.substring(0, _refreshToken!.length < 10 ? _refreshToken!.length : 10)}…';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bikergram Auth Debug (HTTP v3)'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          width: 320,
                          child: TextField(
                            controller: _emailCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: TextField(
                            controller: _userCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Username (optional)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: TextField(
                            controller: _passCtrl,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Password',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        ElevatedButton(onPressed: _health, child: const Text('HEALTH')),
                        ElevatedButton(onPressed: _register, child: const Text('REGISTER')),
                        ElevatedButton(onPressed: _login, child: const Text('LOGIN')),
                        ElevatedButton(onPressed: _me, child: const Text('ME')),
                        ElevatedButton(onPressed: _refresh, child: const Text('REFRESH')),
                        ElevatedButton(onPressed: _logout, child: const Text('LOGOUT')),
                        OutlinedButton(onPressed: _clearTokens, child: const Text('CLEAR TOKENS')),
                        OutlinedButton(onPressed: _clearLog, child: const Text('CLEAR LOG')),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'access: $accessShort   |   refresh: $refreshShort',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Scrollbar(
                    child: ListView.builder(
                      itemCount: _lines.length,
                      itemBuilder: (context, i) {
                        return Text(
                          _lines[i],
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
