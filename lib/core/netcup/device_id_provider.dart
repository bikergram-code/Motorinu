import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Stable per-install device id without extra plugins.
///
/// We store a random id in SharedPreferences so it survives app restarts.
class DeviceIdProvider {
  static const _key = 'bikergram_device_id_v1';

  static Future<String> get() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_key);
    if (existing != null && existing.trim().isNotEmpty) return existing;

    final id = _generate();
    await prefs.setString(_key, id);
    return id;
  }

  static String _generate() {
    final rnd = Random.secure();
    const hex = '0123456789abcdef';
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    final b = StringBuffer('dev-');
    for (final v in bytes) {
      b.write(hex[(v >> 4) & 0xF]);
      b.write(hex[v & 0xF]);
    }
    return b.toString();
  }
}
