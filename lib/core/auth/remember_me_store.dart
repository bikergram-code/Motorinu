import 'package:shared_preferences/shared_preferences.dart';

/// Simple "Remember login" store (email + password).
///
/// NOTE: This stores the password in SharedPreferences (plain text).
/// For production, consider flutter_secure_storage or platform keychain/keystore.
class RememberMeStore {
  RememberMeStore._();

  static final RememberMeStore instance = RememberMeStore._();

  static const _kEnabled = 'bg_remember_enabled';
  static const _kEmail = 'bg_remember_email';
  static const _kPassword = 'bg_remember_password';

  Future<bool> isEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kEnabled) ?? true;
  }

  Future<RememberedCredentials?> load() async {
    final p = await SharedPreferences.getInstance();
    final enabled = p.getBool(_kEnabled) ?? true;
    if (!enabled) return null;

    final email = p.getString(_kEmail);
    final pwd = p.getString(_kPassword);
    if (email == null || email.trim().isEmpty) return null;
    if (pwd == null || pwd.isEmpty) return null;

    return RememberedCredentials(email: email, password: pwd);
  }

  Future<void> save({
    required bool enabled,
    required String email,
    required String password,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kEnabled, enabled);

    if (!enabled) {
      await p.remove(_kEmail);
      await p.remove(_kPassword);
      return;
    }

    await p.setString(_kEmail, email.trim());
    await p.setString(_kPassword, password);
  }

  Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kEnabled, false);
    await p.remove(_kEmail);
    await p.remove(_kPassword);
  }
}

class RememberedCredentials {
  final String email;
  final String password;

  const RememberedCredentials({
    required this.email,
    required this.password,
  });
}
