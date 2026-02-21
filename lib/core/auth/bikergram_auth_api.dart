import '../api_client.dart';
import '../api_config.dart';
import 'auth_tokens.dart';

class AuthUser {
  final int id;
  final String email;
  final String username;

  const AuthUser({required this.id, required this.email, required this.username});
}

class AuthResponse {
  final AuthUser user;
  final AuthTokens tokens;

  const AuthResponse({required this.user, required this.tokens});
}

/// PHP Auth API wrapper for:
/// - POST /register.php
/// - POST /login.php
/// - GET  /me.php
class BikergramAuthApi {
  final ApiClient _api;

  BikergramAuthApi({ApiClient? api}) : _api = api ?? ApiClient.instance {
    // Ensure configured base url even if caller forgot.
    ApiClient.configure(baseUrl: ApiConfig.apiBaseUrl);
  }

  Future<AuthResponse> register({
    required String email,
    required String password,
    String? username,
  }) async {
    final res = await _api.postJson(
      '/register.php',
      withAuth: false,
      body: {
        'email': email.trim(),
        'password': password,
        if (username != null && username.trim().isNotEmpty) 'username': username.trim(),
      },
    );
    return _parseAuth(res);
  }

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final res = await _api.postJson(
      '/login.php',
      withAuth: false,
      body: {
        'email': email.trim(),
        'password': password,
      },
    );
    return _parseAuth(res);
  }

  Future<AuthUser> me({required String accessToken}) async {
    // Use raw request to avoid interfering with global token.
    final res = await _api.getJson(
      '/me.php',
      withAuth: false,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    final ok = res['ok'] == true;
    if (!ok) {
      final msg = (res['error']?['message'] ?? res['message'] ?? 'Unauthorized').toString();
      throw StateError('me() failed: $msg');
    }

    final user = res['data']?['user'];
    if (user is! Map) throw StateError('me() invalid response');

    return AuthUser(
      id: (user['id'] as num?)?.toInt() ?? 0,
      email: (user['email'] ?? '').toString(),
      username: (user['username'] ?? '').toString(),
    );
  }

  AuthResponse _parseAuth(Map<String, dynamic> res) {
    final ok = res['ok'] == true;
    if (!ok) {
      final err = res['error'];
      final msg = (err is Map ? err['message'] : null) ?? res['message'] ?? 'Auth failed';
      throw StateError(msg.toString());
    }

    final data = res['data'];
    if (data is! Map) throw StateError('Invalid auth response');

    final user = data['user'];
    final tokens = data['tokens'];
    if (user is! Map || tokens is! Map) throw StateError('Invalid auth response');

    final accessToken = (tokens['accessToken'] ?? '').toString();
    final refreshToken = (tokens['refreshToken'] ?? '').toString();

    final accessExp = DateTime.tryParse((tokens['accessExpiresAt'] ?? '').toString());
    final refreshExp = DateTime.tryParse((tokens['refreshExpiresAt'] ?? '').toString());

    if (accessToken.isEmpty || refreshToken.isEmpty || accessExp == null || refreshExp == null) {
      throw StateError('Auth tokens missing in response');
    }

    return AuthResponse(
      user: AuthUser(
        id: (user['id'] as num?)?.toInt() ?? 0,
        email: (user['email'] ?? '').toString(),
        username: (user['username'] ?? '').toString(),
      ),
      tokens: AuthTokens(
        accessToken: accessToken,
        accessExpiresAt: accessExp,
        refreshToken: refreshToken,
        refreshExpiresAt: refreshExp,
      ),
    );
  }
}
