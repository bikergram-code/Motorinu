import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'token_pair.dart';

/// TokenStore (SSOT / Single Source of Truth)
///
/// Web goal:
/// - store tokens atomically as a pair in ONE key:
///     bikergram_tokens_v1  -> JSON {accessToken, refreshToken}
/// - legacy keys (bg_access_token/bg_refresh_token/auth_token) are:
///     - read for migration
///     - optionally purged to keep LocalStorage clean
///
/// NOTE (Flutter Web):
/// SharedPreferences keys appear in LocalStorage with prefix "flutter.",
/// e.g. bikergram_tokens_v1 -> flutter.bikergram_tokens_v1
class TokenStore {
  static const _kAccess = 'bg_access_token';
  static const _kRefresh = 'bg_refresh_token';
  static const _kAuthToken = 'auth_token';
  static const _kTokens = 'bikergram_tokens_v1';

  /// If true, we keep writing legacy keys for older code paths.
  /// Default: false (clean).
  static const bool writeLegacyKeys = bool.fromEnvironment(
    'BG_WRITE_LEGACY_TOKEN_KEYS',
    defaultValue: false,
  );

  /// If true and [writeLegacyKeys]==false, we delete legacy keys on every write/read
  /// once SSOT exists. Default: true (clean).
  static const bool purgeLegacyOnWrite = bool.fromEnvironment(
    'BG_PURGE_LEGACY_TOKEN_KEYS',
    defaultValue: true,
  );

  Future<TokenPair?> read() async {
    final sp = await SharedPreferences.getInstance();

    // MIGRATION: clean up wrong prefixed keys like `flutter.bg_access_token`
    await _migrateWrongPrefixedKeys(sp);

    // 1) SSOT first
    final raw = sp.getString(_kTokens);
    if (raw != null && raw.trim().isNotEmpty) {
      final fromJson = TokenPair.tryParse(raw);
      if (fromJson != null) {
        if (!writeLegacyKeys && purgeLegacyOnWrite) {
          await _removeLegacyKeysOnly(sp);
        }
        return fromJson;
      }

      // Corrupt JSON => wipe to avoid weird states
      await _removeAllTokenKeys(sp);
      return null;
    }

    // 2) migrate from legacy (must be full pair)
    final at = (sp.getString(_kAccess) ?? sp.getString(_kAuthToken) ?? '').trim();
    final rt = (sp.getString(_kRefresh) ?? '').trim();

    if (at.isNotEmpty && rt.isNotEmpty) {
      final pair = TokenPair(accessToken: at, refreshToken: rt);
      await write(pair, reason: 'migrate_legacy_pair');
      return pair;
    }

    // 3) legacy HALF state => remove (old bug case)
    if (at.isNotEmpty || rt.isNotEmpty) {
      await _removeLegacyKeysOnly(sp);
    }

    return null;
  }

  Future<void> write(TokenPair pair, {String reason = 'unknown'}) async {
    final sp = await SharedPreferences.getInstance();
    await _migrateWrongPrefixedKeys(sp);

    final trace = const bool.fromEnvironment('BG_TRACE_TOKEN_WRITES');
    if (trace) {
      debugPrint('[TokenStore.write] reason=$reason at=${_short(pair.accessToken)} rt=${_short(pair.refreshToken)}');
      debugPrint(StackTrace.current.toString());
    }

    // canonical JSON (SSOT)
    await sp.setString(_kTokens, pair.toJsonString());

    if (writeLegacyKeys) {
      await sp.setString(_kAccess, pair.accessToken);
      await sp.setString(_kAuthToken, pair.accessToken);
      await sp.setString(_kRefresh, pair.refreshToken);
    } else if (purgeLegacyOnWrite) {
      await _removeLegacyKeysOnly(sp);
    }
  }

  Future<void> clear({String reason = 'unknown'}) async {
    final sp = await SharedPreferences.getInstance();
    await _migrateWrongPrefixedKeys(sp);

    final trace = const bool.fromEnvironment('BG_TRACE_TOKEN_WRITES');
    if (trace) {
      debugPrint('[TokenStore.clear] reason=$reason');
      debugPrint(StackTrace.current.toString());
    }

    await _removeAllTokenKeys(sp);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _short(String s) => s.length <= 12 ? s : '${s.substring(0, 10)}...';

  Future<void> _removeLegacyKeysOnly(SharedPreferences sp) async {
    await sp.remove(_kAccess);
    await sp.remove(_kAuthToken);
    await sp.remove(_kRefresh);
  }

  Future<void> _removeAllTokenKeys(SharedPreferences sp) async {
    await sp.remove(_kTokens);
    await _removeLegacyKeysOnly(sp);
  }

  Future<void> _migrateWrongPrefixedKeys(SharedPreferences sp) async {
    final wrong = <String, String>{
      'flutter.$_kTokens': _kTokens,
      'flutter.$_kAccess': _kAccess,
      'flutter.$_kAuthToken': _kAuthToken,
      'flutter.$_kRefresh': _kRefresh,
    };

    bool changed = false;

    for (final entry in wrong.entries) {
      final wrongKey = entry.key;
      final correctKey = entry.value;

      final v = sp.getString(wrongKey);
      if (v == null) continue;

      if (correctKey == _kTokens) {
        final parsed = TokenPair.tryParse(v);
        if (parsed != null) {
          await sp.setString(_kTokens, parsed.toJsonString());
          if (writeLegacyKeys) {
            await sp.setString(_kAccess, parsed.accessToken);
            await sp.setString(_kAuthToken, parsed.accessToken);
            await sp.setString(_kRefresh, parsed.refreshToken);
          }
        } else {
          await sp.setString(_kTokens, v);
        }
      } else {
        await sp.setString(correctKey, v);
      }

      await sp.remove(wrongKey);
      changed = true;
    }

    // Also handle the case where bikergram_tokens_v1 isn't present yet but legacy pair exists
    final rawTokens = sp.getString(_kTokens);
    if (rawTokens == null || rawTokens.trim().isEmpty) {
      final at = (sp.getString(_kAccess) ?? sp.getString(_kAuthToken) ?? '').trim();
      final rt = (sp.getString(_kRefresh) ?? '').trim();
      if (at.isNotEmpty && rt.isNotEmpty) {
        await sp.setString(_kTokens, jsonEncode({'accessToken': at, 'refreshToken': rt}));
        changed = true;
      }
    }

    if (changed && const bool.fromEnvironment('BG_TRACE_TOKEN_WRITES')) {
      debugPrint('[TokenStore] migrated wrong prefixed keys (flutter.*)');
    }

    // If SSOT exists -> optional cleanup
    if (!writeLegacyKeys && purgeLegacyOnWrite) {
      final hasSSOT = (sp.getString(_kTokens) ?? '').trim().isNotEmpty;
      if (hasSSOT) {
        await _removeLegacyKeysOnly(sp);
      }
    }
  }
}
