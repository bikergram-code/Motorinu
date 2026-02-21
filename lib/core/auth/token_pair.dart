import 'dart:convert';

class TokenPair {
  final String accessToken;
  final String refreshToken;

  const TokenPair({
    required this.accessToken,
    required this.refreshToken,
  });

  bool get isValid => accessToken.isNotEmpty && refreshToken.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        'refreshToken': refreshToken,
      };

  String toJsonString() => jsonEncode(toJson());

  static TokenPair? tryParse(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final m = Map<String, dynamic>.from(decoded);
        final at = (m['accessToken'] ?? m['access_token'] ?? '') as String;
        final rt = (m['refreshToken'] ?? m['refresh_token'] ?? '') as String;
        if (at.isNotEmpty && rt.isNotEmpty) {
          return TokenPair(accessToken: at, refreshToken: rt);
        }
      }
    } catch (_) {}
    return null;
  }
}
