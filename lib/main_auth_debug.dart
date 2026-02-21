// lib/main_auth_debug.dart
//
// Debug entrypoint to test API auth end-to-end without touching your real app routes.
// Run (Windows PowerShell | lokal):
//   flutter run -t lib/main_auth_debug.dart -d chrome
//
// Optional:
//   flutter run -t lib/main_auth_debug.dart -d windows

import 'dart:convert';

import 'package:flutter/material.dart';

import 'core/api_client.dart';
import 'core/api_config.dart';
import 'core/auth/bikergram_auth_service.dart';
import 'core/auth/bikergram_token_store.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Ensure we point to your live API.
  ApiClient.configure(baseUrl: ApiConfig.apiBaseUrl);

  // Load stored token into client (optional).
  await BikergramAuthService().restoreSession();
  runApp(const _AuthDebugApp());
}

class _AuthDebugApp extends StatelessWidget {
  const _AuthDebugApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bikergram Auth Debug',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const AuthDebugScreen(),
    );
  }
}

class AuthDebugScreen extends StatefulWidget {
  const AuthDebugScreen({super.key});

  @override
  State<AuthDebugScreen> createState() => _AuthDebugScreenState();
}

class _AuthDebugScreenState extends State<AuthDebugScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _log = ValueNotifier<String>('');
  bool _busy = false;

  void _append(Object msg) {
    final ts = DateTime.now().toIso8601String().replaceFirst('T', ' ').split('.').first;
    _log.value = '${_log.value}[$ts] $msg\n';
  }

  Future<void> _run(Future<Map<String, dynamic>> Function() fn) async {
    setState(() => _busy = true);
    try {
      final res = await fn();
      _append(const JsonEncoder.withIndent('  ').convert(res));
    } catch (e, st) {
      _append('ERROR: $e');
      _append(st);
    } finally {
      setState(() => _busy = false);
    }
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
    final svc = BikergramAuthService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bikergram Auth Debug'),
      ),
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
                  onPressed: _busy
                      ? null
                      : () => _run(() => svc.login(
                            email: _email.text.trim(),
                            password: _pass.text,
                          )),
                  child: const Text('LOGIN'),
                ),
                ElevatedButton(
                  onPressed: _busy ? null : () => _run(svc.refresh),
                  child: const Text('REFRESH'),
                ),
                ElevatedButton(
                  onPressed: _busy ? null : () => _run(svc.me),
                  child: const Text('ME'),
                ),
                ElevatedButton(
                  onPressed: _busy ? null : () => _run(svc.logout),
                  child: const Text('LOGOUT'),
                ),
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          await BikergramTokenStore.clear();
                          _append('TokenStore: cleared');
                        },
                  child: const Text('CLEAR TOKENS'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FutureBuilder(
              future: Future.wait([
                BikergramTokenStore.readAccessToken(),
                BikergramTokenStore.readRefreshToken(),
              ]),
              builder: (context, snap) {
                final access = (snap.data is List && (snap.data as List).isNotEmpty) ? (snap.data as List)[0] as String? : null;
                final refresh = (snap.data is List && (snap.data as List).isNotEmpty) ? (snap.data as List)[1] as String? : null;
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Stored:\n- accessToken: ${access == null ? "(none)" : "${access.substring(0, access.length > 18 ? 18 : access.length)}..."}\n- refreshToken: ${refresh == null ? "(none)" : "${refresh.substring(0, refresh.length > 18 ? 18 : refresh.length)}..."}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
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
