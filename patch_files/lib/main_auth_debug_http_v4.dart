// BIKERGRAM Auth Debug (HTTP) v4
// Standalone debug entry for web-server device (no dart:io).
// Buttons: HEALTH / MAKE TEST USER / REGISTER / LOGIN / ME / REFRESH / LOGOUT / CLEAR TOKENS / CLEAR LOG
//
// Usage (Windows PowerShell):
// flutter run -t lib/main_auth_debug_http_v4.dart -d web-server --web-hostname 127.0.0.1 --web-port 5175

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

void main() {
  runApp(const _AuthDebugApp());
}

class _AuthDebugApp extends StatelessWidget {
  const _AuthDebugApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BIKERGRAM Auth Debug v4',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const _AuthDebugHttpScreen(),
    );
  }
}

class _AuthDebugHttpScreen extends StatefulWidget {
  const _AuthDebugHttpScreen();

  @override
  State<_AuthDebugHttpScreen> createState() => _AuthDebugHttpScreenState();
}

class _AuthDebugHttpScreenState extends State<_AuthDebugHttpScreen> {
  static const String _baseUrl = 'https://api.bikergram.com';

  final _emailCtrl = TextEditingController(text: 'test@example.com');
  final _userCtrl = TextEditingController(text: 'test');
  final _passCtrl = TextEditingController(text: 'test');

  final List<String> _log = <String>[];
  bool _busy = false;

  String? _accessToken;
  String? _refreshToken;

  Dio _dio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
        responseType: ResponseType.json,
        headers: const {
          'Accept': 'application/json',
        },
        validateStatus: (code) => true, // we want to log all statuses
      ),
    );
    return dio;
  }

  void _pushLog(String msg) {
    final ts = DateTime.now().toIso8601String().replaceFirst('T', ' ').split('.').first;
    setState(() {
      _log.insert(0, '[$ts] $msg');
    });
  }

  void _pushJson(Object? obj) {
    try {
      const encoder = JsonEncoder.withIndent('  ');
      _pushLog(encoder.convert(obj));
    } catch (_) {
      _pushLog(obj.toString());
    }
  }

  String _mask(String? s, {int head = 8, int tail = 6}) {
    if (s == null || s.isEmpty) return '(none)';
    if (s.length <= head + tail) return s;
    return '${s.substring(0, head)}…${s.substring(s.length - tail)}';
  }

  Map<String, dynamic> _extractBody(Response res) {
    // Dio may give Map already; or String for non-JSON.
    final data = res.data;
    if (data is Map) return Map<String, dynamic>.from(data as Map);
    if (data is String) {
      // try json
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) return Map<String, dynamic>.from(decoded as Map);
        return <String, dynamic>{'raw': data};
      } catch (_) {
        return <String, dynamic>{'raw': data};
      }
    }
    return <String, dynamic>{'raw': data?.toString()};
  }

  void _updateTokensFromBody(Map<String, dynamic> body, {String source = 'response'}) {
    // Expected shape:
    // { ok:true, data:{ tokens:{ accessToken, refreshToken, ... } } }
    final data = body['data'];
    if (data is! Map) return;
    final tokens = data['tokens'];
    if (tokens is! Map) return;

    final at = tokens['accessToken'];
    final rt = tokens['refreshToken'];

    bool changed = false;

    if (at is String && at.isNotEmpty) {
      _accessToken = at;
      changed = true;
    }
    if (rt is String && rt.isNotEmpty) {
      _refreshToken = rt;
      changed = true;
    }

    if (changed) {
      _pushLog('TokenStore: set from $source | access=${_mask(_accessToken)} | refresh=${_mask(_refreshToken)}');
    } else {
      _pushLog('TokenStore: no tokens found in $source');
    }
  }

  Future<void> _call(String label, Future<Response> Function(Dio dio) fn) async {
    if (_busy) return;
    setState(() => _busy = true);
    _pushLog('--- $label ---');
    try {
      final dio = _dio();
      final res = await fn(dio);

      final headers = <String, dynamic>{};
      // only a few headers are useful
      for (final k in ['content-type', 'access-control-allow-origin']) {
        final v = res.headers.value(k);
        if (v != null) headers[k] = v;
      }

      final body = _extractBody(res);

      _pushJson({
        'body': body,
        '_status': res.statusCode,
        '_headers': headers,
        '_request': {
          'baseUrl': _baseUrl,
          'label': label,
          'sentAccess': _accessToken != null,
          'sentRefresh': _refreshToken != null,
        }
      });

      // If this response carries tokens, update.
      final ok = body['ok'];
      if (ok == true) {
        _updateTokensFromBody(body, source: label);
      }
    } catch (e) {
      _pushLog('ERROR: $e');
    } finally {
      _pushLog('--- $label done ---');
      setState(() => _busy = false);
    }
  }

  void _makeTestUser() {
    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    setState(() {
      _emailCtrl.text = 'test$ts@example.com';
      _userCtrl.text = 'test$ts';
      _passCtrl.text = 'test$ts';
    });
    _pushLog('Filled test credentials (unique): ${_emailCtrl.text} / ${_userCtrl.text}');
  }

  void _clearTokens() {
    setState(() {
      _accessToken = null;
      _refreshToken = null;
    });
    _pushLog('TokenStore: cleared');
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
    final tokenLine = 'access=${_mask(_accessToken)} | refresh=${_mask(_refreshToken)}';
    return Scaffold(
      appBar: AppBar(
        title: const Text('BIKERGRAM Auth Debug v4'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(child: Text(_busy ? 'busy…' : 'idle')),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('API: $_baseUrl', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text('Tokens: $tokenLine'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _emailCtrl,
                          decoration: const InputDecoration(labelText: 'Email'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _userCtrl,
                          decoration: const InputDecoration(labelText: 'Username'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _passCtrl,
                          decoration: const InputDecoration(labelText: 'Password'),
                          obscureText: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonal(
                        onPressed: _busy
                            ? null
                            : () => _call('HEALTH', (dio) => dio.get('/health.php', options: Options(responseType: ResponseType.plain))),
                        child: const Text('HEALTH'),
                      ),
                      FilledButton.tonal(
                        onPressed: _busy ? null : _makeTestUser,
                        child: const Text('MAKE TEST USER'),
                      ),
                      FilledButton(
                        onPressed: _busy
                            ? null
                            : () {
                                final email = _emailCtrl.text.trim();
                                final user = _userCtrl.text.trim();
                                final pass = _passCtrl.text;
                                _call(
                                  'REGISTER',
                                  (dio) => dio.post(
                                    '/register.php',
                                    data: {'email': email, 'username': user, 'password': pass},
                                    options: Options(contentType: Headers.jsonContentType),
                                  ),
                                );
                              },
                        child: const Text('REGISTER'),
                      ),
                      FilledButton(
                        onPressed: _busy
                            ? null
                            : () {
                                final email = _emailCtrl.text.trim();
                                final pass = _passCtrl.text;
                                _call(
                                  'LOGIN',
                                  (dio) => dio.post(
                                    '/login.php',
                                    data: {'email': email, 'password': pass},
                                    options: Options(contentType: Headers.jsonContentType),
                                  ),
                                );
                              },
                        child: const Text('LOGIN'),
                      ),
                      FilledButton.tonal(
                        onPressed: _busy
                            ? null
                            : () => _call(
                                  'ME',
                                  (dio) => dio.get(
                                    '/me.php',
                                    options: Options(
                                      headers: _accessToken == null ? {} : {'Authorization': 'Bearer $_accessToken'},
                                      contentType: Headers.jsonContentType,
                                    ),
                                  ),
                                ),
                        child: const Text('ME'),
                      ),
                      FilledButton.tonal(
                        onPressed: _busy
                            ? null
                            : () => _call(
                                  'REFRESH',
                                  (dio) => dio.post(
                                    '/refresh.php',
                                    data: {'refreshToken': _refreshToken},
                                    options: Options(
                                      headers: {
                                        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
                                      },
                                      contentType: Headers.jsonContentType,
                                    ),
                                  ),
                                ),
                        child: const Text('REFRESH'),
                      ),
                      FilledButton.tonal(
                        onPressed: _busy
                            ? null
                            : () => _call(
                                  'LOGOUT',
                                  (dio) => dio.post(
                                    '/logout.php',
                                    data: {'refreshToken': _refreshToken},
                                    options: Options(
                                      headers: {
                                        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
                                      },
                                      contentType: Headers.jsonContentType,
                                    ),
                                  ),
                                ),
                        child: const Text('LOGOUT'),
                      ),
                      OutlinedButton(
                        onPressed: _busy ? null : _clearTokens,
                        child: const Text('CLEAR TOKENS'),
                      ),
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () {
                                setState(() => _log.clear());
                              },
                        child: const Text('CLEAR LOG'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _Card(
                child: _log.isEmpty
                    ? const Center(child: Text('No log yet.'))
                    : ListView.builder(
                        reverse: true,
                        itemCount: _log.length,
                        itemBuilder: (context, i) {
                          final line = _log[i];
                          return SelectableText(
                            line,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
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

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF111318),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2B2F3A)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: child,
      ),
    );
  }
}
