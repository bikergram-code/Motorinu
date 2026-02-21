import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'token_pair.dart';
import 'token_store.dart';

// Mobile: Keychain/Keystore via FlutterSecureStorage
// Web: we keep LocalStorage clean by using TokenStore (SSOT) instead of secure storage keys.

class AuthTokens {
  final String accessToken;
  final String refreshToken;

  const AuthTokens({required this.accessToken, required this.refreshToken});
}

class AuthTokenStore {
  static const _storage = FlutterSecureStorage();

  // historical key names for mobile secure storage
  static const _kAccess = 'bg_access_token';
  static const _kRefresh = 'bg_refresh_token';
  static const _kLegacyAuth = 'auth_token';

  static final TokenStore _webStore = TokenStore();

  static String _short(String s) {
    if (s.isEmpty) return '<empty>';
    return '${s.substring(0, s.length < 10 ? s.length : 10)}...';
  }

  /// Prefer legacy auth_token if present, otherwise accessToken.
  static Future<String?> readAccessToken() async {
    if (kIsWeb) {
      final pair = await _webStore.read();
      final at = (pair?.accessToken ?? '').trim();
      return at.isEmpty ? null : at;
    }

    final legacy = await _storage.read(key: _kLegacyAuth);
    if (legacy != null && legacy.isNotEmpty) return legacy;
    final at = await _storage.read(key: _kAccess);
    return (at == null || at.isEmpty) ? null : at;
  }

  static Future<AuthTokens?> readTokens() async {
    if (kIsWeb) {
      final pair = await _webStore.read();
      if (pair == null) return null;
      return AuthTokens(accessToken: pair.accessToken, refreshToken: pair.refreshToken);
    }

    final at = await _storage.read(key: _kAccess) ?? '';
    final rt = await _storage.read(key: _kRefresh) ?? '';
    if (at.isEmpty && rt.isEmpty) return null;
    return AuthTokens(accessToken: at, refreshToken: rt);
  }

  /// Save full token pair.
  static Future<void> saveTokens(AuthTokens tokens) async {
    if (kDebugMode) {
      debugPrint('[AuthTokenStore.saveTokens] at=${_short(tokens.accessToken)} rt=${_short(tokens.refreshToken)}');
      debugPrintStack(label: '[AuthTokenStore.saveTokens] CALLER', maxFrames: 25);
    }

    final at = tokens.accessToken.trim();
    final rt = tokens.refreshToken.trim();
    if (at.isEmpty || rt.isEmpty) {
      // never write half-state
      return;
    }

    if (kIsWeb) {
      await _webStore.write(TokenPair(accessToken: at, refreshToken: rt), reason: 'auth_token_store_web');
      return;
    }

    await _storage.write(key: _kAccess, value: at);
    await _storage.write(key: _kRefresh, value: rt);

    // also keep legacy key in sync (mobile only)
    await _storage.write(key: _kLegacyAuth, value: at);
  }

  static Future<void> clear() async {
    if (kDebugMode) {
      debugPrint('[AuthTokenStore.clear]');
      debugPrintStack(label: '[AuthTokenStore.clear] CALLER', maxFrames: 25);
    }

    if (kIsWeb) {
      await _webStore.clear(reason: 'auth_token_store_web_clear');
      return;
    }

    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
    await _storage.delete(key: _kLegacyAuth);
  }
}
