import 'package:flutter/foundation.dart';

import 'token_pair.dart';
import 'token_store.dart';

class BikergramTokenPair {
  final String accessToken;
  final String refreshToken;

  const BikergramTokenPair({required this.accessToken, required this.refreshToken});
}

/// Backward-compatible token store API used across the project.
///
/// SAUBERKEIT:
/// - Delegiert an [TokenStore] (SSOT: bikergram_tokens_v1)
/// - Schreibt KEINE legacy keys (bg_access_token/bg_refresh_token/auth_token)
///
/// Wichtig:
/// - Unterstützt *partial* calls (nur access oder nur refresh) ohne Corruption:
///   -> wir mergen mit dem vorhandenen Pair, aber schreiben nur wenn das Paar komplett ist.
class BikergramTokenStore {
  static final TokenStore _store = TokenStore();

  static Future<BikergramTokenPair?> load() async {
    final p = await _store.read();
    if (p == null) return null;
    return BikergramTokenPair(accessToken: p.accessToken, refreshToken: p.refreshToken);
  }

  static Future<String?> readAccessToken() async {
    final p = await _store.read();
    final at = (p?.accessToken ?? '').trim();
    return at.isEmpty ? null : at;
  }

  static Future<String?> readRefreshToken() async {
    final p = await _store.read();
    final rt = (p?.refreshToken ?? '').trim();
    return rt.isEmpty ? null : rt;
  }

  /// Save tokens.
  ///
  /// Wenn nur eins der Tokens übergeben wird, wird mit dem gespeicherten Pair gemerged.
  /// Es wird aber **niemals** ein Halb-State gespeichert.
  static Future<void> save({
    String? accessToken,
    String? refreshToken,
    String reason = 'legacy_save',
  }) async {
    final current = await _store.read();
    final at = (accessToken ?? current?.accessToken ?? '').trim();
    final rt = (refreshToken ?? current?.refreshToken ?? '').trim();

    // beide leer => clear
    if (at.isEmpty && rt.isEmpty) {
      await clear(reason: '$reason:both_empty');
      return;
    }

    // half-state => SKIP (sauber)
    if (at.isEmpty || rt.isEmpty) {
      if (kDebugMode) {
        debugPrint('[BikergramTokenStore.save] SKIP half-state reason=$reason atEmpty=${at.isEmpty} rtEmpty=${rt.isEmpty}');
        debugPrintStack(label: '[BikergramTokenStore.save] CALLER', maxFrames: 25);
      }
      return;
    }

    await _store.write(TokenPair(accessToken: at, refreshToken: rt), reason: reason);
  }

  static Future<void> clear({String reason = 'legacy_clear'}) async {
    if (kDebugMode) {
      debugPrint('[BikergramTokenStore.clear]');
      debugPrintStack(label: '[BikergramTokenStore.clear] CALLER', maxFrames: 25);
    }
    await _store.clear(reason: reason);
  }
}
