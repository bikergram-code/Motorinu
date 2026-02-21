import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../api_config.dart';
import 'backend_token_store.dart';
import 'backend_models.dart';

/// NestJS Backend API (DEV lokal + später VPS)
/// Endpoints:
/// - GET  /health
/// - POST /auth/register
/// - POST /auth/login
/// - POST /auth/refresh
/// - POST /auth/logout
/// - GET  /users/me
/// - POST /posts
/// - GET  /posts
/// - POST /media/presign
class BikergramBackendApi {
  BikergramBackendApi({
    required this.tokens,
    String? baseUrl,
  }) : _baseUrl = (baseUrl ?? ApiConfig.baseUrl()).trim() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 25),
        sendTimeout: const Duration(seconds: 25),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    // Separate dio without auth interceptor for refresh/logout calls
    _authDio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 25),
        sendTimeout: const Duration(seconds: 25),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final skipAuth = options.extra['skipAuth'] == true;

          if (!skipAuth) {
            final access = await tokens.getAccessToken();
            if (access != null && access.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $access';
            } else {
              options.headers.remove('Authorization');
            }
          }

          if (kDebugMode) {
            debugPrint('➡️  [Backend] ${options.method} ${options.uri}');
          }
          handler.next(options);
        },
        onResponse: (resp, handler) {
          if (kDebugMode) {
            debugPrint(
              '✅ [Backend] ${resp.statusCode} ${resp.requestOptions.method} ${resp.requestOptions.uri}',
            );
          }
          handler.next(resp);
        },
        onError: (e, handler) async {
          final status = e.response?.statusCode;
          final ro = e.requestOptions;

          // Try refresh ONCE if unauthorized and request wasn't retried yet.
          if (status == 401 && ro.extra['__retried'] != true) {
            ro.extra['__retried'] = true;

            final ok = await _refreshIfPossible();
            if (ok) {
              try {
                final retryResp = await _dio.fetch(ro);
                handler.resolve(retryResp);
                return;
              } catch (_) {
                // fallthrough
              }
            } else {
              await tokens.clear();
            }
          }

          if (kDebugMode) {
            debugPrint(
              '❌ [Backend] ${e.type} ${ro.method} ${ro.uri} -> ${e.message}',
            );
          }
          handler.next(e);
        },
      ),
    );
  }

  final BackendTokenStore tokens;
  late final Dio _dio;
  late final Dio _authDio;
  final String _baseUrl;

  Future<Map<String, dynamic>> health() async {
    final res = await _dio.get(
      '/health',
      options: Options(extra: {'skipAuth': true}),
    );
    return _ensureMap(res.data);
  }

  Future<BackendAuthResult> register({
    required String language,
    required String name,
    required int age,
    required String postalCode,
    required String email,
    required int experienceYears,
    required bool trackExperience,
    required int bikeCount,
    required String diy,
    String? profileImageUrl,
    required String password,
  }) async {
    final body = <String, dynamic>{
      'language': language,
      'name': name,
      'age': age,
      'postalCode': postalCode,
      'email': email,
      'experienceYears': experienceYears,
      'trackExperience': trackExperience,
      'bikeCount': bikeCount,
      'diy': diy,
      if (profileImageUrl != null) 'profileImageUrl': profileImageUrl,
      'password': password,
    };

    final res = await _dio.post(
      '/auth/register',
      data: jsonEncode(body),
      options: Options(extra: {'skipAuth': true}),
    );

    final data = _ensureMap(res.data);
    final result = BackendAuthResult.fromJson(data);

    if (result.accessToken.isNotEmpty && result.refreshToken.isNotEmpty) {
      await tokens.saveTokens(
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
      );
    }
    return result;
  }

  Future<BackendAuthResult> login({
    required String email,
    required String password,
  }) async {
    final res = await _dio.post(
      '/auth/login',
      data: jsonEncode({'email': email, 'password': password}),
      options: Options(extra: {'skipAuth': true}),
    );

    final data = _ensureMap(res.data);
    final result = BackendAuthResult.fromJson(data);

    if (result.accessToken.isNotEmpty && result.refreshToken.isNotEmpty) {
      await tokens.saveTokens(
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
      );
    }
    return result;
  }

  Future<Map<String, dynamic>> me() async {
    final res = await _dio.get('/users/me');
    return _ensureMap(res.data);
  }

  Future<Map<String, dynamic>> createPost({
    String? caption,
    String? mediaUrl,
  }) async {
    final res = await _dio.post(
      '/posts',
      data: jsonEncode({
        if (caption != null) 'caption': caption,
        if (mediaUrl != null) 'mediaUrl': mediaUrl,
      }),
    );
    return _ensureMap(res.data);
  }

  Future<Map<String, dynamic>> listPosts({String? cursor, int take = 20}) async {
    final q = <String, dynamic>{'take': take};
    if (cursor != null && cursor.isNotEmpty) q['cursor'] = cursor;

    final res = await _dio.get(
      '/posts',
      queryParameters: q,
      options: Options(extra: {'skipAuth': true}),
    );
    return _ensureMap(res.data);
  }

  Future<Map<String, dynamic>> presignUpload({
    required String contentType,
    required String ext,
    String kind = 'image',
  }) async {
    final res = await _dio.post(
      '/media/presign',
      data: jsonEncode({'contentType': contentType, 'ext': ext, 'kind': kind}),
    );
    return _ensureMap(res.data);
  }

  // -------------------------
  // Refresh logic
  // -------------------------

  Future<bool> _refreshIfPossible() async {
    // Avoid parallel refresh calls
    if (_refreshing != null) return _refreshing!;

    final c = Completer<bool>();
    _refreshing = c.future;

    try {
      final refresh = await tokens.getRefreshToken();
      if (refresh == null || refresh.isEmpty) {
        c.complete(false);
        return await _refreshing!;
      }

      final res = await _authDio.post(
        '/auth/refresh',
        data: jsonEncode({'refreshToken': refresh}),
        options: Options(extra: {'skipAuth': true}),
      );

      final data = _ensureMap(res.data);
      final ok = data['ok'] == true;

      if (!ok) {
        c.complete(false);
        return await _refreshing!;
      }

      final newAccess = (data['accessToken'] ?? '').toString();
      final newRefresh = (data['refreshToken'] ?? '').toString();

      if (newAccess.isEmpty || newRefresh.isEmpty) {
        c.complete(false);
        return await _refreshing!;
      }

      await tokens.saveTokens(accessToken: newAccess, refreshToken: newRefresh);
      c.complete(true);
      return await _refreshing!;
    } catch (_) {
      c.complete(false);
      return await _refreshing!;
    } finally {
      _refreshing = null;
    }
  }

  Future<void> logout() async {
    final refresh = await tokens.getRefreshToken();
    if (refresh == null || refresh.isEmpty) {
      await tokens.clear();
      return;
    }

    try {
      await _authDio.post(
        '/auth/logout',
        data: jsonEncode({'refreshToken': refresh}),
        options: Options(extra: {'skipAuth': true}),
      );
    } catch (_) {
      // ignore
    } finally {
      await tokens.clear();
    }
  }

  // -------------------------
  // Helpers (SYNC!)
  // -------------------------

  Map<String, dynamic> _ensureMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) {
      return data.map((k, v) => MapEntry(k.toString(), v));
    }
    if (data is String && data.isNotEmpty) {
      final decoded = jsonDecode(data);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
    }
    throw StateError('Invalid backend response: expected JSON object');
  }

  Future<bool>? _refreshing;
}
