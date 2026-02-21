import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/auth/token_pair.dart';
import '../../core/auth/token_store.dart';
import '../../core/auth/bikergram_auth_api.dart';
import '../../routes/app_routes.dart';

/// Auth gate:
/// - If tokens exist and /me.php returns 200 => go to main feed
/// - Else try refresh once (rotation) and re-check /me.php
/// - If still not valid => go to wizard
class StartGate extends StatefulWidget {
  const StartGate({super.key});

  @override
  State<StartGate> createState() => _StartGateState();
}

class _StartGateState extends State<StartGate> {
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    setState(() => _busy = true);

    final store = TokenStore();
    final pair = await store.read();

    if (!mounted) return;

    if (pair == null || !pair.isValid) {
      _go(AppRoutes.wizard);
      return;
    }

    final ok = await _checkMe(pair.accessToken);
    if (ok) {
      _go(AppRoutes.mainSocialFeed);
      return;
    }

    // If access token is invalid/expired, attempt ONE refresh (rotation).
    final refreshed = await _tryRefresh(pair);
    if (!mounted) return;

    if (refreshed != null) {
      final ok2 = await _checkMe(refreshed.accessToken);
      if (!mounted) return;
      if (ok2) {
        _go(AppRoutes.mainSocialFeed);
        return;
      }
    }

    // Invalid session -> clean and go to wizard.
    await store.clear(reason: 'start_gate_invalid');
    await ApiClient.instance.setToken(null);
    if (!mounted) return;
    _go(AppRoutes.wizard);
  }

  Future<bool> _checkMe(String accessToken) async {
    try {
      final api = BikergramAuthApi();
      await api.me(accessToken: accessToken);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<TokenPair?> _tryRefresh(TokenPair current) async {
    try {
      final rt = current.refreshToken.trim();
      if (rt.isEmpty) return null;

      final res = await ApiClient.instance.postJson(
        '/refresh.php',
        withAuth: false,
        body: {'refreshToken': rt},
      );

      final tokens = _extractTokens(res);
      if (tokens == null) return null;

      final at = (tokens['accessToken'] ?? tokens['access_token'] ?? '') as String;
      final newAt = at.trim();
      final newRtRaw = (tokens['refreshToken'] ?? tokens['refresh_token'] ?? '') as String;
      final newRt = newRtRaw.trim().isEmpty ? rt : newRtRaw.trim(); // rotation may return new refreshToken

      if (newAt.isEmpty || newRt.isEmpty) return null;

      final pair = TokenPair(accessToken: newAt, refreshToken: newRt);
      await TokenStore().write(pair, reason: 'start_gate_refresh');
      await ApiClient.instance.setToken(newAt);

      return pair;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _extractTokens(Map<String, dynamic> body) {
    // tokens could be at top-level, body["data"], or body["data"]["tokens"]
    final t1 = body['tokens'];
    if (t1 is Map) return Map<String, dynamic>.from(t1);

    final data = body['data'];
    if (data is Map) {
      final dm = Map<String, dynamic>.from(data);
      final t2 = dm['tokens'];
      if (t2 is Map) return Map<String, dynamic>.from(t2);

      // sometimes tokens directly in data
      if (dm.containsKey('accessToken') || dm.containsKey('refreshToken')) return dm;
    }

    // sometimes directly top-level keys
    if (body.containsKey('accessToken') || body.containsKey('refreshToken')) return body;

    return null;
  }

  void _go(String route) {
    Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: _busy
            ? const CircularProgressIndicator()
            : const SizedBox.shrink(),
      ),
    );
  }
}
