import 'package:shared_preferences/shared_preferences.dart';

/// Stores the user's preference for automatic GPS activation.
/// When enabled, GPS live broadcasting starts automatically when opening the map.
class GpsAutoStore {
  GpsAutoStore._();

  static const _kEnabled = 'bg_gps_auto_enabled';

  /// Returns true if the user opted in to automatic GPS activation.
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kEnabled) ?? false;
  }

  /// Save the user's preference.
  static Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, value);
  }
}
