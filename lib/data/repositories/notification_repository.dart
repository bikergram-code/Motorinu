import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationRepository {
  SupabaseClient get _supabase => Supabase.instance.client;
  String? get _currentUserId => _supabase.auth.currentUser?.id;

  /// Load all notifications for the current user, newest first.
  /// Optionally filtered by [community].
  Future<List<Map<String, dynamic>>> getNotifications({
    int limit = 50,
    String? community,
  }) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('Nicht eingeloggt');

    var query = _supabase
        .from('notifications')
        .select()
        .eq('user_id', userId);

    // Strict community filter: only show notifications for this community
    if (community != null) {
      query = query.eq('community', community);
    }

    final data = await query
        .order('created_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(data);
  }

  /// Mark a single notification as read.
  Future<void> markAsRead(int notificationId) async {
    final userId = _currentUserId;
    if (userId == null) return;

    await _supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId)
        .eq('user_id', userId);
  }

  /// Mark ALL unread notifications as read.
  /// Scoped to [community] if provided.
  Future<void> markAllAsRead({String? community}) async {
    final userId = _currentUserId;
    if (userId == null) return;

    var query = _supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);

    // Strict: only mark this community's notifications
    if (community != null) {
      query = query.eq('community', community);
    }

    await query;
  }

  /// Get total unread notification count.
  /// Strictly filtered by [community].
  Future<int> getUnreadCount({String? community}) async {
    final userId = _currentUserId;
    if (userId == null) return 0;

    try {
      var query = _supabase
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false);

      if (community != null) {
        query = query.eq('community', community);
      }

      final data = await query;
      return data.length;
    } catch (e) {
      debugPrint('Error getting unread notification count: $e');
      return 0;
    }
  }

  /// Create a notification for another user.
  /// Tries RPC first (bypasses RLS), falls back to direct insert.
  /// [community] scopes the notification to a specific community.
  Future<bool> createNotification({
    required String targetUserId,
    required String type,
    required String title,
    String? body,
    Map<String, dynamic>? data,
    String? community,
  }) async {
    final userId = _currentUserId;
    if (userId == null) {
      debugPrint('[Notif] Not logged in, skipping');
      return false;
    }
    if (userId == targetUserId) {
      debugPrint('[Notif] Self-notification, skipping');
      return false;
    }

    // IMPORTANT: Never send null — always default to 'bikergram'
    final effectiveCommunity = community ?? 'bikergram';
    debugPrint('[Notif] Creating: type=$type target=$targetUserId community=$effectiveCommunity');

    // Try RPC first (bypasses RLS via SECURITY DEFINER)
    try {
      final params = <String, dynamic>{
        'p_target_user_id': targetUserId,
        'p_type': type,
        'p_title': title,
        'p_body': body,
        'p_data': data ?? {},
        'p_community': effectiveCommunity,
      };

      await _supabase.rpc('create_notification', params: params);
      debugPrint('[Notif] ✓ Created via RPC: $type → $targetUserId');
      return true;
    } catch (e) {
      debugPrint('[Notif] ✗ RPC failed: $e');
    }

    // Fallback: direct insert (needs INSERT policy on notifications table)
    try {
      final insertData = <String, dynamic>{
        'user_id': targetUserId,
        'type': type,
        'title': title,
        'data': data ?? {},
        'community': community ?? 'bikergram',  // Always set community
      };
      if (body != null) insertData['body'] = body;

      await _supabase.from('notifications').insert(insertData);
      debugPrint('[Notif] ✓ Created via insert: $type → $targetUserId');
      return true;
    } catch (e) {
      debugPrint('[Notif] ✗ Insert also failed: $e');
      return false;
    }
  }

  /// Subscribe to new notifications in real-time.
  RealtimeChannel subscribeToNotifications(
    void Function(Map<String, dynamic> notification) onNotification,
  ) {
    final userId = _currentUserId;

    return _supabase
        .channel('notifications:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: userId != null
              ? PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'user_id',
                  value: userId,
                )
              : null,
          callback: (payload) {
            onNotification(payload.newRecord);
          },
        )
        .subscribe();
  }
}
