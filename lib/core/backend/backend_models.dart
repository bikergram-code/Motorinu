/// Core models for Bikergram backend responses.
///
/// This file contains both:
/// - Legacy models (BackendAuthResult) kept for backwards compatibility.
/// - New "Bikergram*" models used by the PHP API MVP (register/login/me).
///
/// The PHP API returns (example):
/// { "ok": true, "data": { "user": {...}, "tokens": { "accessToken": "...", "refreshToken": "...", ... } } }
///
/// These models are intentionally tolerant: they accept either the root object
/// or the nested `data` object.
class BackendAuthResult {
  final String accessToken;
  final String refreshToken;
  final Map<String, dynamic> user;

  const BackendAuthResult({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  factory BackendAuthResult.fromJson(Map<String, dynamic> json) {
    return BackendAuthResult(
      accessToken: (json['accessToken'] ?? '').toString(),
      refreshToken: (json['refreshToken'] ?? '').toString(),
      user: (json['user'] is Map) ? Map<String, dynamic>.from(json['user'] as Map) : const <String, dynamic>{},
    );
  }
}

/// Tokens returned by the Bikergram PHP API.
class BikergramAuthTokens {
  final String accessToken;
  final String refreshToken;
  final String? accessExpiresAt;
  final String? refreshExpiresAt;

  const BikergramAuthTokens({
    required this.accessToken,
    required this.refreshToken,
    this.accessExpiresAt,
    this.refreshExpiresAt,
  });

  factory BikergramAuthTokens.fromJson(Map<String, dynamic> json) {
    return BikergramAuthTokens(
      accessToken: (json['accessToken'] ?? json['access_token'] ?? '').toString(),
      refreshToken: (json['refreshToken'] ?? json['refresh_token'] ?? '').toString(),
      accessExpiresAt: (json['accessExpiresAt'] ?? json['access_expires_at'])?.toString(),
      refreshExpiresAt: (json['refreshExpiresAt'] ?? json['refresh_expires_at'])?.toString(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        if (accessExpiresAt != null) 'accessExpiresAt': accessExpiresAt,
        if (refreshExpiresAt != null) 'refreshExpiresAt': refreshExpiresAt,
      };

  bool get isValid => accessToken.trim().isNotEmpty && refreshToken.trim().isNotEmpty;
}

/// Auth response used in the registration wizard.
/// Exposes `.tokens` exactly as your wizard expects.
class BikergramAuthResponse {
  final Map<String, dynamic> user;
  final BikergramAuthTokens tokens;

  const BikergramAuthResponse({
    required this.user,
    required this.tokens,
  });

  factory BikergramAuthResponse.fromJson(Map<String, dynamic> json) {
    // tolerate both {data:{...}} and plain {...}
    final root = (json['data'] is Map) ? Map<String, dynamic>.from(json['data'] as Map) : json;

    final user = (root['user'] is Map) ? Map<String, dynamic>.from(root['user'] as Map) : const <String, dynamic>{};
    final tokensJson = (root['tokens'] is Map)
        ? Map<String, dynamic>.from(root['tokens'] as Map)
        : (root['data'] is Map)
            ? Map<String, dynamic>.from((root['data'] as Map))
            : const <String, dynamic>{};

    return BikergramAuthResponse(
      user: user,
      tokens: BikergramAuthTokens.fromJson(tokensJson),
    );
  }
}
