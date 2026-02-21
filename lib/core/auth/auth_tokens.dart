class AuthTokens {
  final String accessToken;
  final DateTime accessExpiresAt;
  final String refreshToken;
  final DateTime refreshExpiresAt;

  const AuthTokens({
    required this.accessToken,
    required this.accessExpiresAt,
    required this.refreshToken,
    required this.refreshExpiresAt,
  });

  bool get isAccessExpired {
    // Small safety margin.
    return DateTime.now().toUtc().isAfter(accessExpiresAt.toUtc().subtract(const Duration(seconds: 10)));
  }

  bool get isRefreshExpired {
    return DateTime.now().toUtc().isAfter(refreshExpiresAt.toUtc().subtract(const Duration(seconds: 10)));
  }
}
