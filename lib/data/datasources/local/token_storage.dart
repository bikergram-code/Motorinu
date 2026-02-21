import '../../../core/auth/token_store.dart';
import '../../../core/auth/token_pair.dart';
import '../../../domain/models/auth_tokens.dart';

/// Wraps the existing [TokenStore] SSOT to expose typed [AuthTokenPair] models.
/// This is the bridge between the legacy token system and the new Riverpod layer.
class TokenStorage {
  TokenStorage({TokenStore? store}) : _store = store ?? TokenStore();

  final TokenStore _store;

  Future<AuthTokenPair?> read() async {
    final pair = await _store.read();
    if (pair == null) return null;
    return AuthTokenPair(
      accessToken: pair.accessToken,
      refreshToken: pair.refreshToken,
    );
  }

  Future<void> write(AuthTokenPair tokens, {String reason = 'unknown'}) async {
    await _store.write(
      TokenPair(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      ),
      reason: reason,
    );
  }

  Future<void> clear({String reason = 'unknown'}) async {
    await _store.clear(reason: reason);
  }

  /// Returns the current access token, or null if not logged in.
  Future<String?> get accessToken async {
    final tokens = await read();
    return tokens?.accessToken;
  }
}
