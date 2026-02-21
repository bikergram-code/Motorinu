import '../../domain/models/auth_tokens.dart';
import '../../domain/models/user.dart';
import '../datasources/local/token_storage.dart';
import '../datasources/remote/bikergram_api_service.dart';

class AuthRepository {
  AuthRepository({
    required BikergramApiService apiService,
    required TokenStorage tokenStorage,
  })  : _api = apiService,
        _tokenStorage = tokenStorage;

  final BikergramApiService _api;
  final TokenStorage _tokenStorage;

  Future<User> login({
    required String email,
    required String password,
  }) async {
    final raw = await _api.login(email: email, password: password);
    final data = _unwrap(raw);
    final tokens = _extractTokens(data);
    await _tokenStorage.write(tokens, reason: 'login');
    return _extractUser(data);
  }

  Future<User> register({
    required String email,
    required String password,
    String? username,
  }) async {
    final raw = await _api.register(
      email: email,
      password: password,
      username: username,
    );
    final data = _unwrap(raw);
    final tokens = _extractTokens(data);
    await _tokenStorage.write(tokens, reason: 'register');
    return _extractUser(data);
  }

  Future<User> me() async {
    final raw = await _api.me();
    final data = _unwrap(raw);
    return _extractUser(data);
  }

  Future<void> logout() async {
    await _tokenStorage.clear(reason: 'logout');
  }

  Future<AuthTokenPair?> getSavedTokens() => _tokenStorage.read();

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Unwrap PHP response envelope: { "ok": true, "data": { ... } }
  /// If ok==false, throw an exception with the error message.
  Map<String, dynamic> _unwrap(Map<String, dynamic> response) {
    if (response.containsKey('ok')) {
      if (response['ok'] == false) {
        // Extract error info from PHP envelope
        final error = response['error'];
        final code = error is Map ? (error['code'] ?? 'unknown') : 'unknown';
        final message = error is Map ? (error['message'] ?? 'Unbekannter Fehler') : '$error';
        throw Exception('$code: $message');
      }
      final inner = response['data'];
      if (inner is Map<String, dynamic>) return inner;
    }
    return response;
  }

  AuthTokenPair _extractTokens(Map<String, dynamic> data) {
    // Supports: { tokens: { accessToken, refreshToken } }
    // or flat: { accessToken, refreshToken }
    final tokensMap = data['tokens'] as Map<String, dynamic>? ?? data;
    return AuthTokenPair(
      accessToken: tokensMap['accessToken'] ?? tokensMap['access_token'] ?? '',
      refreshToken: tokensMap['refreshToken'] ?? tokensMap['refresh_token'] ?? '',
    );
  }

  User _extractUser(Map<String, dynamic> data) {
    // Supports: { user: { ... } } or flat user fields
    final userMap = data['user'] as Map<String, dynamic>? ?? data;
    return User(
      id: _toInt(userMap['id'] ?? userMap['user_id']),
      email: userMap['email'] ?? '',
      username: userMap['username'] ?? userMap['accountUsername'] ?? userMap['biker_name'] ?? '',
      displayName: userMap['displayName'] ?? userMap['display_name'] ?? userMap['accountUsername'],
      bikername: userMap['bikername'] ?? userMap['biker_name'],
      avatarUrl: userMap['avatarUrl'] ?? userMap['avatar_url'] ?? userMap['profile_image_url'],
      bio: userMap['bio'],
      postalCode: userMap['postalCode'] ?? userMap['postal_code'],
      xpTotal: _toInt(userMap['xpTotal'] ?? userMap['xp_total']),
      level: _toInt(userMap['level'] ?? 1),
      isPremium: userMap['isPremium'] == true || userMap['is_premium'] == true,
      isBusiness: userMap['isBusiness'] == true || userMap['is_business'] == true,
    );
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse('$v') ?? 0;
  }
}
