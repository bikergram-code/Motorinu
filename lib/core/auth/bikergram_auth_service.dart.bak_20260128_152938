// lib/core/auth/bikergram_auth_service.dart
//
// Thin auth layer for your PHP endpoints:
// - POST /login.php     -> expects to return tokens
// - POST /refresh.php   -> returns new access token (and optionally refresh token)
// - POST /logout.php    -> server-side revoke + local clear
// - GET  /me.php        -> current user (Authorization: Bearer <access>)
//
// This file is defensive about JSON shapes, so it works even if you tweak response keys.

import '../api_client.dart';
import 'bikergram_token_store.dart';

class BikergramAuthService {
  BikergramAuthService({ApiClient? client}) : _client = client ?? ApiClient.instance {
    // Allow ApiClient to lazily fetch the access token from storage if needed.
    ApiClient.setSessionTokenProvider(BikergramTokenStore.readAccessToken);
  }

  final ApiClient _client;

  /// Call at app start if you want to eagerly load the token.
  Future<void> restoreSession() async {
    final access = await BikergramTokenStore.readAccessToken();
    await _client.setToken(access);
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await _client.postJson('/login.php', body: {
      'email': email,
      'password': password,
    });

    final access = _extractToken(res, keys: const ['accessToken', 'access_token', 'token', 'jwt']);
    final refresh = _extractToken(res, keys: const ['refreshToken', 'refresh_token']);

    // Save whatever we got.
    await BikergramTokenStore.save(accessToken: access, refreshToken: refresh);

    // Make sure client uses the new access token immediately.
    await _client.setToken(access);

    return res;
  }

  Future<Map<String, dynamic>> refresh() async {
    final refreshToken = await BikergramTokenStore.readRefreshToken();
    final res = await _client.postJson('/refresh.php', body: {
      'refreshToken': refreshToken ?? '',
    });

    final access = _extractToken(res, keys: const ['accessToken', 'access_token', 'token', 'jwt']);
    final refreshNew = _extractToken(res, keys: const ['refreshToken', 'refresh_token']);

    // Update storage + client token
    await BikergramTokenStore.save(accessToken: access, refreshToken: refreshNew);
    await _client.setToken(access);

    return res;
  }

  Future<Map<String, dynamic>> logout() async {
    final refreshToken = await BikergramTokenStore.readRefreshToken();

    final res = await _client.postJson('/logout.php', body: {
      'refreshToken': refreshToken ?? '',
    });

    await BikergramTokenStore.clear();
    await _client.setToken(null);

    return res;
  }

  Future<Map<String, dynamic>> me() async {
    // ApiClient should attach bearer token if available.
    return _client.getJson('/me.php');
  }

  // -------- Helpers --------

  static String? _extractToken(
    Map<String, dynamic> json, {
    required List<String> keys,
  }) {
    // Look in top-level
    for (final k in keys) {
      final v = json[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }

    // Look in json["data"]
    final data = json['data'];
    if (data is Map) {
      final dm = Map<String, dynamic>.from(data as Map);
      for (final k in keys) {
        final v = dm[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
    }

    // Look in json["data"]["tokens"]
    if (data is Map) {
      final dm = Map<String, dynamic>.from(data as Map);
      final tokens = dm['tokens'];
      if (tokens is Map) {
        final tm = Map<String, dynamic>.from(tokens as Map);
        for (final k in keys) {
          final v = tm[k];
          if (v is String && v.trim().isNotEmpty) return v.trim();
        }
      }
    }

    return null;
  }
}
