// lib/core/backend/bikergram_api.dart
import '../api_client.dart';

/// Thin API layer you can call from your Wizard steps.
///
/// IMPORTANT:
/// - Replace the endpoint paths below with your real PHP endpoints.
/// - This file is safe even if endpoints don't exist yet.
class BikergramApi {
  BikergramApi({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

  /// Health/Ping (you already have it on '/')
  Future<Map<String, dynamic>> ping() => _client.getJson('/');

  /// Example: check if username is available
  /// TODO: adjust endpoint/path to your server route
  Future<Map<String, dynamic>> checkUserName(String userName) {
    return _client.postJson('/auth/check-username', body: {'userName': userName});
  }

  /// Example: check if email is available / valid
  /// TODO: adjust endpoint/path to your server route
  Future<Map<String, dynamic>> checkEmail(String email) {
    return _client.postJson('/auth/check-email', body: {'email': email});
  }

  /// Example: submit registration
  /// TODO: adjust endpoint/path to your server route
  Future<Map<String, dynamic>> register({
    required String userName,
    required String postalCode,
    required String email,
    required String password,
    Map<String, dynamic>? extra,
  }) {
    return _client.postJson(
      '/auth/register',
      body: {
        'userName': userName,
        'postalCode': postalCode,
        'email': email,
        'password': password,
        if (extra != null) ...extra,
      },
    );
  }
}
