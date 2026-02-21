import 'package:dio/dio.dart';
import '../../../core/auth/token_store.dart';
import '../../../core/network/api_client.dart';

class AuthApi {
  final ApiClient apiClient;
  final TokenStore tokenStore;

  AuthApi({required this.apiClient, required this.tokenStore});

  Dio get _dio => apiClient.dio;

  /// Passe diese Pfade an deine PHP-Dateien an, falls nötig.
  static const String loginPath = '/login.php';
  static const String registerPath = '/register.php';
  static const String mePath = '/me.php';
  static const String refreshPath = '/refresh.php';
  static const String logoutPath = '/logout.php';

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      loginPath,
      data: {'email': email, 'password': password},
      options: Options(headers: {'Content-Type': 'application/json'}),
    );

    final data = res.data ?? <String, dynamic>{};

    final access = (data['access_token'] ?? data['accessToken'])?.toString();
    final refresh = (data['refresh_token'] ?? data['refreshToken'])?.toString();

    if (access != null && refresh != null && access.isNotEmpty && refresh.isNotEmpty) {
      await tokenStore.setTokens(accessToken: access, refreshToken: refresh);
    }

    return data;
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    String? username,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      registerPath,
      data: {'email': email, 'password': password, if (username != null) 'username': username},
      options: Options(headers: {'Content-Type': 'application/json'}),
    );
    return res.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> me() async {
    final res = await _dio.get<Map<String, dynamic>>(mePath);
    return res.data ?? <String, dynamic>{};
  }

  Future<bool> refresh() async {
    final rt = await tokenStore.getRefreshToken();
    if (rt == null || rt.isEmpty) return false;

    final res = await _dio.post<Map<String, dynamic>>(
      refreshPath,
      data: {'refresh_token': rt},
      options: Options(headers: {'Content-Type': 'application/json'}),
    );

    final data = res.data;
    if (data == null) return false;

    final access = (data['access_token'] ?? data['accessToken'])?.toString();
    final refresh = (data['refresh_token'] ?? data['refreshToken'])?.toString();

    if (access == null || refresh == null || access.isEmpty || refresh.isEmpty) return false;

    await tokenStore.setTokens(accessToken: access, refreshToken: refresh);
    return true;
  }

  Future<void> logout() async {
    try {
      await _dio.post(logoutPath);
    } catch (_) {
      // egal
    } finally {
      await tokenStore.clear();
    }
  }
}
