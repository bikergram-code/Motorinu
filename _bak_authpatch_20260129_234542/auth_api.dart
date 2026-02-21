import 'package:dio/dio.dart';
import '../auth/token_pair.dart';

class AuthApi {
  final Dio _dio;

  AuthApi(this._dio);

  /// refresh.php erwartet JSON: { "refresh_token": "..." }
  Future<TokenPair> refresh(String refreshToken) async {
    final res = await _dio.post(
      '/refresh.php',
      data: {'refresh_token': refreshToken},
      options: Options(
        headers: {'Content-Type': 'application/json'},
        extra: {
          // wichtig: verhindert Refresh-Loop
          'noAuth': true,
          'noRefresh': true,
        },
      ),
    );

    final data = res.data;
    if (data is! Map) {
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        message: 'refresh: invalid response shape',
      );
    }

    // akzeptiere mehrere mögliche Antwortformate
    Map tokens = {};
    if (data['data'] is Map && (data['data']['tokens'] is Map)) {
      tokens = data['data']['tokens'] as Map;
    } else if (data['tokens'] is Map) {
      tokens = data['tokens'] as Map;
    } else if (data['data'] is Map) {
      // fallback
      tokens = data['data'] as Map;
    }

    final at = (tokens['accessToken'] ??
            tokens['access_token'] ??
            tokens['access'] ??
            '') as String;
    final rt = (tokens['refreshToken'] ??
            tokens['refresh_token'] ??
            tokens['refresh'] ??
            '') as String;

    if (at.isEmpty || rt.isEmpty) {
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        message: 'refresh: missing tokens in response',
      );
    }

    return TokenPair(accessToken: at, refreshToken: rt);
  }
}
