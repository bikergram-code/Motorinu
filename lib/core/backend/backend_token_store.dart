import 'package:shared_preferences/shared_preferences.dart';

import '../auth/token_pair.dart';
import '../auth/token_store.dart';
import 'backend_models.dart';

/// Stores tokens locally.
///
/// SAUBERKEIT:
/// - Tokens werden **nur** über [TokenStore] (SSOT) gespeichert.
/// - Dieses File behält die Public-API von [BackendTokenStore] + [AuthTokenStore],
///   aber schreibt keine legacy keys mehr.
class BackendTokenStore {
  final TokenStore _store = TokenStore();

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    final at = accessToken.trim();
    final rt = refreshToken.trim();
    if (at.isEmpty || rt.isEmpty) return;
    await _store.write(TokenPair(accessToken: at, refreshToken: rt), reason: 'backend_saveTokens');
  }

  Future<String?> getAccessToken() async {
    final p = await _store.read();
    final at = (p?.accessToken ?? '').trim();
    return at.isEmpty ? null : at;
  }

  Future<String?> getRefreshToken() async {
    final p = await _store.read();
    final rt = (p?.refreshToken ?? '').trim();
    return rt.isEmpty ? null : rt;
  }

  Future<void> clear() async {
    await _store.clear(reason: 'backend_clear');
  }
}

/// Compatibility token store for the registration wizard.
/// Exposes static methods like `AuthTokenStore.saveTokens(auth.tokens)`.
///
/// SAUBERKEIT:
/// - Access+Refresh gehen in SSOT ([TokenStore]).
/// - Expiry-Metadaten bleiben separat (bg_access_expires_at/bg_refresh_expires_at).
class AuthTokenStore {
  static const String _kAccessExp = 'bg_access_expires_at';
  static const String _kRefreshExp = 'bg_refresh_expires_at';

  static final TokenStore _store = TokenStore();

  static Future<void> saveTokens(BikergramAuthTokens tokens) async {
    final at = tokens.accessToken.trim();
    final rt = tokens.refreshToken.trim();

    if (at.isNotEmpty && rt.isNotEmpty) {
      await _store.write(TokenPair(accessToken: at, refreshToken: rt), reason: 'wizard_saveTokens');
    }

    // keep expiry metadata (optional)
    final sp = await SharedPreferences.getInstance();
    final ae = tokens.accessExpiresAt?.trim() ?? '';
    final re = tokens.refreshExpiresAt?.trim() ?? '';
    if (ae.isNotEmpty) await sp.setString(_kAccessExp, ae);
    if (re.isNotEmpty) await sp.setString(_kRefreshExp, re);
  }

  static Future<BikergramAuthTokens?> loadTokens() async {
    final p = await _store.read();
    if (p == null) return null;

    final sp = await SharedPreferences.getInstance();
    final ae = sp.getString(_kAccessExp);
    final re = sp.getString(_kRefreshExp);

    return BikergramAuthTokens(
      accessToken: p.accessToken,
      refreshToken: p.refreshToken,
      accessExpiresAt: (ae == null || ae.trim().isEmpty) ? null : ae.trim(),
      refreshExpiresAt: (re == null || re.trim().isEmpty) ? null : re.trim(),
    );
  }

  static Future<String?> getAccessToken() async {
    final p = await _store.read();
    final at = (p?.accessToken ?? '').trim();
    return at.isEmpty ? null : at;
  }

  static Future<String?> getRefreshToken() async {
    final p = await _store.read();
    final rt = (p?.refreshToken ?? '').trim();
    return rt.isEmpty ? null : rt;
  }

  static Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await _store.clear(reason: 'wizard_clear');
    await sp.remove(_kAccessExp);
    await sp.remove(_kRefreshExp);
  }
}
