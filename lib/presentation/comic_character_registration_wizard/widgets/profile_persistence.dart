import 'dart:async';
import 'dart:convert';

import '../../../core/netcup/bikername_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/netcup/api_client.dart';

/// Firebase-freier Ersatz, gleiche öffentliche API.
/// - speichert lokal (SharedPreferences) für Offline/Start
/// - kann optional an Netcup senden, falls Endpoint existiert
class ProfilePersistence {
  static const _kProfileCache = 'bg_profile_cache_json';

  static final StreamController<Map<String, dynamic>?> _controller =
      StreamController<Map<String, dynamic>?>.broadcast();

  static Future<Map<String, dynamic>?> loadProfile() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kProfileCache);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return decoded.map((k, v) => MapEntry('$k', v));
    } catch (_) {}
    return null;
  }

  static Future<void> saveProfile(Map<String, dynamic> profile) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kProfileCache, jsonEncode(profile));
    _controller.add(profile);

    // Optional: wenn du später einen Endpoint hast (z.B. /profile/update)
    // wird er hier automatisch versucht – Fehler werden ignoriert.
    try {
      await ApiClient.instance.postJson('/profile/update', body: profile);
    } catch (_) {}
  }

  static Future<void> updateFields(Map<String, dynamic> fields) async {
    final current = await loadProfile() ?? <String, dynamic>{};
    current.addAll(fields);
    await saveProfile(current);
  }

  static Future<void> releaseNameReservation(String name) async {
    try {
      final token = await BikernameService.clientToken;
      try {
        await ApiClient.instance.postJson('/bikername_release.php', body: {
        'name': name,
        'client_token': token,
        });
      } catch (_) {
        await ApiClient.instance.postJson('/api/bikername_release.php', body: {
        'name': name,
        'client_token': token,
        });
      }
    } catch (_) {}
  }

  static Stream<Map<String, dynamic>?> profileStream() async* {
    // zuerst Cache pushen
    yield await loadProfile();
    yield* _controller.stream;
  }
}
