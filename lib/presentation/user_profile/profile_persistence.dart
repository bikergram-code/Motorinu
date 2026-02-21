import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local-only profile persistence.
///
/// The draft submit endpoint already persists the profile server-side.
/// We keep this class strictly local to avoid extra network calls and noisy 404 logs.
class ProfilePersistence {
  static const String _kProfileKey = 'bikergram_profile_json';

  static Future<void> saveProfile(
    Map<String, dynamic> profile, {
    String? token,
    bool syncToServer = false,
  }) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kProfileKey, jsonEncode(profile));

    // Intentionally no server sync here.
    // If you want server-side updates later, implement a dedicated endpoint
    // (e.g. /api/profile/update.php) and wire it up explicitly.
    (token, syncToServer); // keep params to avoid breaking callers
  }

  static Future<Map<String, dynamic>?> loadProfile() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kProfileKey);
    if (raw == null || raw.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.map((k, v) => MapEntry(k.toString(), v));
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearProfile() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kProfileKey);
  }
}
