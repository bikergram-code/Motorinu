import 'dart:async';
import 'package:dio/dio.dart';
import '../auth/token_pair.dart';
import '../auth/token_store.dart';
import 'auth_api.dart';

class AuthInterceptor extends Interceptor {
  final Dio _dio; // Haupt-Dio (für Retry)
  final Dio _refreshDio; // separates Dio ohne AuthInterceptor
  final TokenStore _tokenStore;

  Completer<TokenPair?>? _refreshCompleter;

  AuthInterceptor({
    required Dio dio,
    required Dio refreshDio,
    required TokenStore tokenStore,
  })  : _dio = dio,
        _refreshDio = refreshDio,
        _tokenStore = tokenStore;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // bewusst ohne Auth (login/register/refresh, etc.)
    if (options.extra['noAuth'] == true) {
      return handler.next(options);
    }

    final pair = await _tokenStore.read();
    if (pair != null && pair.accessToken.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer ${pair.accessToken}';
    }

    handler.next(options);
  }

  bool _shouldTryRefresh(DioException err) {
    final ro = err.requestOptions;

    if (ro.extra['noRefresh'] == true) return false;
    if (ro.extra['__retried'] == true) return false;

    // nie auf refresh/login/register reagieren
    final p = ro.path.toLowerCase();
    if (p.contains('refresh.php')) return false;
    if (p.contains('login.php')) return false;
    if (p.contains('register.php')) return false;

    final status = err.response?.statusCode;
    return status == 401;
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (!_shouldTryRefresh(err)) {
      return handler.next(err);
    }

    final newPair = await _refreshTokens();
    if (newPair == null) {
      await _tokenStore.clear();
      return handler.next(err);
    }

    // Retry Original Request mit neuem AccessToken
    final ro = err.requestOptions;
    ro.extra['__retried'] = true;
    ro.headers['Authorization'] = 'Bearer ${newPair.accessToken}';

    try {
      final resp = await _dio.fetch(ro);
      return handler.resolve(resp);
    } catch (e) {
      return handler.next(e is DioException ? e : err);
    }
  }

  Future<TokenPair?> _refreshTokens() async {
    // concurrency-safe: nur 1 refresh gleichzeitig
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    final completer = Completer<TokenPair?>();
    _refreshCompleter = completer;

    () async {
      try {
        final current = await _tokenStore.read();
        final rt = current?.refreshToken ?? '';
        if (rt.isEmpty) {
          completer.complete(null);
          return;
        }

        final api = AuthApi(_refreshDio);
        final rotated = await api.refresh(rt);

        // !!! Rotation: IMMER Access + Refresh speichern
        await _tokenStore.write(rotated);

        completer.complete(rotated);
      } catch (_) {
        completer.complete(null);
      } finally {
        _refreshCompleter = null;
      }
    }();

    return completer.future;
  }
}
