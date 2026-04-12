import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Cached online-status entry.
class _CachedStatus {
  final bool isOnline;
  final DateTime fetchedAt;
  const _CachedStatus(this.isOnline, this.fetchedAt);

  bool get isExpired => DateTime.now().difference(fetchedAt).inSeconds > 60;
}

/// In-memory cache for user online statuses.
/// Batch-fetches from `profiles` table, 60-second TTL.
/// A user is considered online if `is_online = true` AND `last_seen` < 5 min ago.
class OnlineStatusCache {
  OnlineStatusCache._();
  static final instance = OnlineStatusCache._();

  final Map<String, _CachedStatus> _cache = {};

  SupabaseClient get _supabase => Supabase.instance.client;

  /// Check if a single user is online. Returns cached value or fetches.
  Future<bool> isUserOnline(String userId) async {
    final cached = _cache[userId];
    if (cached != null && !cached.isExpired) return cached.isOnline;

    // Single fetch
    try {
      final row = await _supabase
          .from('profiles')
          .select('is_online, last_seen')
          .eq('id', userId)
          .maybeSingle();

      if (row == null) {
        _cache[userId] = _CachedStatus(false, DateTime.now());
        return false;
      }

      final online = _evaluateOnline(row);
      _cache[userId] = _CachedStatus(online, DateTime.now());
      return online;
    } catch (e) {
      debugPrint('[OnlineCache] Fetch failed for $userId: $e');
      return cached?.isOnline ?? false;
    }
  }

  /// Batch-fetch online status for multiple users at once.
  /// Efficient for list screens (feed, messages, search).
  Future<Map<String, bool>> batchFetch(List<String> userIds) async {
    if (userIds.isEmpty) return {};

    final result = <String, bool>{};
    final toFetch = <String>[];

    // Use cached values where available
    for (final id in userIds) {
      final cached = _cache[id];
      if (cached != null && !cached.isExpired) {
        result[id] = cached.isOnline;
      } else {
        toFetch.add(id);
      }
    }

    if (toFetch.isEmpty) return result;

    // Batch query
    try {
      final rows = await _supabase
          .from('profiles')
          .select('id, is_online, last_seen')
          .inFilter('id', toFetch);

      final now = DateTime.now();
      for (final row in rows) {
        final id = row['id'] as String;
        final online = _evaluateOnline(row);
        _cache[id] = _CachedStatus(online, now);
        result[id] = online;
      }

      // Mark any not-found users as offline
      for (final id in toFetch) {
        if (!result.containsKey(id)) {
          _cache[id] = _CachedStatus(false, now);
          result[id] = false;
        }
      }
    } catch (e) {
      debugPrint('[OnlineCache] Batch fetch failed: $e');
      // Fill missing with cached or false
      for (final id in toFetch) {
        result[id] = _cache[id]?.isOnline ?? false;
      }
    }

    return result;
  }

  /// Clear all cached entries.
  void clear() => _cache.clear();

  /// Evaluate: online = is_online == true AND last_seen within 5 minutes.
  bool _evaluateOnline(Map<String, dynamic> row) {
    final isOnline = row['is_online'] as bool? ?? false;
    if (!isOnline) return false;

    final lastSeenStr = row['last_seen'] as String?;
    if (lastSeenStr == null) return false;

    final lastSeen = DateTime.tryParse(lastSeenStr);
    if (lastSeen == null) return false;

    return DateTime.now().toUtc().difference(lastSeen).inMinutes < 5;
  }
}
