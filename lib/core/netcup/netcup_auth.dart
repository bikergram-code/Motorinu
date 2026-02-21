import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bikergram/core/auth/bikergram_auth_api.dart';
import 'package:bikergram/core/auth/token_pair.dart';
import 'package:bikergram/core/auth/token_store.dart';

/// Alias used by the registration wizard.
/// This makes `AuthResponse` assignable to `BikergramAuthResponse`.
typedef BikergramAuthResponse = AuthResponse;

/// Backward-compatible bearer token persistence.
/// Some very old code used `auth_token`. We keep it behind a flag to stay clean by default.
///
/// Web storage note:
/// - SharedPreferences on web automatically prefixes keys with `flutter.` in LocalStorage.
/// - Never prefix keys manually.
class NetcupAuth {
  static const String _tokenKey = 'auth_token';

  /// If you absolutely need legacy `auth_token`, enable it explicitly:
  ///   --dart-define=BG_WRITE_LEGACY_TOKEN_KEYS=true
  static bool get _writeLegacy =>
      const bool.fromEnvironment('BG_WRITE_LEGACY_TOKEN_KEYS', defaultValue: false);

  static Future<void> saveBearerToken(String token) async {
    if (!_writeLegacy) return;

    final sp = await SharedPreferences.getInstance();
    final t = token.trim();

    if (t.isEmpty) {
      await sp.remove(_tokenKey);
    } else {
      await sp.setString(_tokenKey, t);
    }
  }

  static Future<String?> getBearerToken() async {
    final sp = await SharedPreferences.getInstance();
    final v = sp.getString(_tokenKey);
    if (v == null) return null;

    final t = v.trim();
    if (t.isEmpty) return null;
    return t;
  }

  static Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_tokenKey);
  }
}

/// Token store used by the wizard.
///
/// IMPORTANT:
/// - Keep this independent from any specific tokens class name (some branches had AuthTokens,
///   others BikergramAuthTokens, or plain Map).
/// - We accept `dynamic` and extract fields safely.
/// - SSOT: writes ONLY `bikergram_tokens_v1` via TokenStore (access+refresh as a pair).
class WizardTokenStore {
  static String _read(dynamic obj, String key) {
    try {
      if (obj is Map) {
        final v = obj[key];
        if (v != null) return v.toString().trim();
      }
    } catch (_) {}

    // Common getters on token objects
    try {
      if (key == 'accessToken') return (obj.accessToken ?? '').toString().trim();
    } catch (_) {}
    try {
      if (key == 'refreshToken') return (obj.refreshToken ?? '').toString().trim();
    } catch (_) {}

    // snake_case fallbacks
    try {
      if (obj is Map) {
        if (key == 'accessToken') return (obj['access_token'] ?? '').toString().trim();
        if (key == 'refreshToken') return (obj['refresh_token'] ?? '').toString().trim();
      }
    } catch (_) {}

    return '';
  }

  /// Save tokens from:
  /// - `AuthResponse.tokens` (whatever its concrete type is),
  /// - a `Map` decoded from JSON,
  /// - or any object exposing `accessToken`/`refreshToken`.
  static Future<void> saveTokens(dynamic tokens, {String reason = 'wizard'}) async {
    final at = _read(tokens, 'accessToken');
    final rt = _read(tokens, 'refreshToken');

    if (at.isEmpty || rt.isEmpty) {
      if (kDebugMode) {
        debugPrint('[WizardTokenStore.saveTokens] ignored (missing access/refresh) reason=$reason');
      }
      return;
    }

    await TokenStore().write(
      TokenPair(accessToken: at, refreshToken: rt),
      reason: reason,
    );

    // Optional legacy sync
    if (NetcupAuth._writeLegacy) {
      await NetcupAuth.saveBearerToken(at);
    }
  }

  static Future<void> clear({String reason = 'wizard_clear'}) async {
    await TokenStore().clear(reason: reason);
    if (NetcupAuth._writeLegacy) {
      await NetcupAuth.clear();
    }
  }
}
