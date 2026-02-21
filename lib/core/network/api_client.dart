import 'dart:async';

import 'package:dio/dio.dart';
import '../auth/token_store.dart';

typedef RefreshCall = Future<TokenPair?> Function(Dio dio, String refreshToken);

class TokenPair {
  final String accessToken;
  final String refreshToken;
  TokenPair({required this.accessToken, required this.refreshToken});
}

/// Dio Client mit:
/// - Authorization Header automatisch
/// - Auto-Refresh bei 401 (einmal pro Request)
/// - Parallel-Refresh Schutz
class ApiClient {
  final String baseUrl;
  final TokenStore tokenStore;

  /// Übergib hier deine Refresh-Logik (z.B. POST /refresh.php).
  /// Standard: erwartet JSON {access_token, refresh_token}
  final RefreshCall refreshCall;

  late final Dio dio;

  // Damit bei mehreren parallelen 401 nicht 10 Refresh-Calls laufen
  Completer<TokenPair?>? _refreshCompleter;

  ApiClient({
    required this.baseUrl,
    required this.tokenStore,
    RefreshCall? refreshCall,
    Duration connectTimeout = const Duration(seconds: 15),
    Duration receiveTimeout = const Duration(seconds: 20),
  }) : refreshCall = refreshCall ?? _defaultRefreshCall {
    dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
      headers: {'Accept': 'application/json'},
    ));

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await tokenStore.getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (err, handler) async {
          final response = err.response;
          final requestOptions = err.requestOptions;

          final isUnauthorized = response?.statusCode == 401;
          final alreadyRetried = requestOptions.extra['__bg_retried__'] == true;

          if (!isUnauthorized || alreadyRetried) {
            handler.next(err);
            return;
          }

          final refreshToken = await tokenStore.getRefreshToken();
          if (refreshToken == null || refreshToken.isEmpty) {
            handler.next(err);
            return;
          }

          try {
            final pair = await _refreshTokens(refreshToken);
            if (pair == null) {
              handler.next(err);
              return;
            }

            requestOptions.extra['__bg_retried__'] = true;
            requestOptions.headers['Authorization'] = 'Bearer ${pair.accessToken}';

            final retryResponse = await dio.fetch(requestOptions);
            handler.resolve(retryResponse);
          } catch (_) {
            handler.next(err);
          }
        },
      ),
    );
  }

  static Future<TokenPair?> _defaultRefreshCall(Dio dio, String refreshToken) async {
    final res = await dio.post<Map<String, dynamic>>(
      '/refresh.php',
      data: {'refresh_token': refreshToken},
      options: Options(headers: {'Content-Type': 'application/json'}),
    );

    final data = res.data;
    if (data == null) return null;

    final access = (data['access_token'] ?? data['accessToken'])?.toString();
    final refresh = (data['refresh_token'] ?? data['refreshToken'])?.toString();

    if (access == null || refresh == null || access.isEmpty || refresh.isEmpty) return null;

    return TokenPair(accessToken: access, refreshToken: refresh);
  }

  Future<TokenPair?> _refreshTokens(String refreshToken) async {
    final existing = _refreshCompleter;
    if (existing != null) return existing.future;

    final completer = Completer<TokenPair?>();
    _refreshCompleter = completer;

    try {
      final pair = await refreshCall(dio, refreshToken);
      if (pair != null) {
        await tokenStore.setTokens(accessToken: pair.accessToken, refreshToken: pair.refreshToken);
      } else {
        await tokenStore.clear();
      }
      completer.complete(pair);
      return pair;
    } catch (_) {
      await tokenStore.clear();
      completer.complete(null);
      return null;
    } finally {
      _refreshCompleter = null;
    }
  }
}
