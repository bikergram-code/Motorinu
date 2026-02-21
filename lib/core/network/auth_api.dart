import 'dart:convert';

import 'package:dio/dio.dart';

import '../auth/token_pair.dart';

class AuthApi {
  final Dio _dio;

  AuthApi(this._dio);

  /// refresh.php erwartet JSON: { "refreshToken": "..." }
  /// (Rotation aktiv: Response liefert NEUE access+refresh Tokens)
  Future<TokenPair> refresh(String refreshToken) async {
    final res = await _dio.post(
      '/refresh.php',
      // RAW JSON senden, damit PHP sicher json_decode(php://input) bekommt.
      data: jsonEncode({'refreshToken': refreshToken}),
      options: Options(
        contentType: Headers.jsonContentType,
        headers: const {'Content-Type': 'application/json'},
        extra: const {
          // wichtig: verhindert Auth/Refresh Loop
          'noAuth': true,
          'noRefresh': true,
        },
      ),
    );

    final body = res.data;
    if (body is! Map) {
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        message: 'refresh: invalid response shape',
      );
    }

    Map tokens = {};
    final data = body['data'];
    if (data is Map && data['tokens'] is Map) {
      tokens = data['tokens'] as Map;
    } else if (body['tokens'] is Map) {
      tokens = body['tokens'] as Map;
    } else if (data is Map) {
      // fallback (falls API direkt tokens in data legt)
      tokens = data;
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
