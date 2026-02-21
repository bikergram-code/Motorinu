import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local profile store (per user id) for fields that are not yet fully backed by the API.
///
/// - Persists a small JSON map per user.
/// - Used by the Profile screen to remember edits (displayName/bikername/avatarUrl/bio).
class LocalProfileStore {
  static final LocalProfileStore instance = LocalProfileStore._();
  LocalProfileStore._();

  String _key(int userId) => 'bg_local_profile_$userId';

  Future<Map<String, dynamic>?> load(int userId) async {
    if (userId <= 0) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(userId));
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      // ignore parse errors
    }
    return null;
  }

  /// Saves a patch map. Null values remove keys.
  Future<void> savePatch(int userId, Map<String, dynamic?> patch) async {
    if (userId <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    final current = await load(userId) ?? <String, dynamic>{};

    for (final e in patch.entries) {
      final k = e.key;
      final v = e.value;
      if (v == null) {
        current.remove(k);
      } else {
        current[k] = v;
      }
    }

    await prefs.setString(_key(userId), jsonEncode(current));
  }

  Future<void> clear(int userId) async {
    if (userId <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(userId));
  }
}
