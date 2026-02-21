import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/live_stream.dart';

/// Repository for live streaming sessions.
class LiveRepository {
  LiveRepository();

  SupabaseClient get _supabase => Supabase.instance.client;
  String? get _currentUserId => _supabase.auth.currentUser?.id;

  static const _profileSelect =
      '*, profiles!inner(username, display_name, avatar_url)';

  // ═══════════════════════════════════════════════════
  //  BROWSE / DISCOVERY
  // ═══════════════════════════════════════════════════

  /// Get active live streams for a community, ordered by viewer count.
  Future<List<LiveStream>> getActiveStreams({
    String? community,
    int limit = 20,
    int offset = 0,
  }) async {
    final communityFilter = community ?? 'bikergram';

    final data = await _supabase
        .from('live_sessions')
        .select(_profileSelect)
        .eq('community', communityFilter)
        .eq('status', 'live')
        .order('viewer_count', ascending: false)
        .order('started_at', ascending: false)
        .range(offset, offset + limit - 1);

    return data.map<LiveStream>(
      (d) => LiveStream.fromSupabase(d as Map<String, dynamic>),
    ).toList();
  }

  /// Get a single live stream by ID.
  Future<LiveStream?> getStreamById(String sessionId) async {
    final data = await _supabase
        .from('live_sessions')
        .select(_profileSelect)
        .eq('id', sessionId)
        .maybeSingle();

    if (data == null) return null;
    return LiveStream.fromSupabase(data);
  }

  // ═══════════════════════════════════════════════════
  //  GO LIVE (CREATE + START + END)
  // ═══════════════════════════════════════════════════

  /// Create a new live session (status = 'preparing').
  Future<LiveStream> createSession({
    required String title,
    int? topicId,
    String? community,
  }) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('Not authenticated');

    final data = await _supabase
        .from('live_sessions')
        .insert({
          'host_user_id': userId,
          'title': title,
          'community': community ?? 'bikergram',
          if (topicId != null) 'topic_id': topicId,
          'status': 'preparing',
        })
        .select(_profileSelect)
        .single();

    return LiveStream.fromSupabase(data);
  }

  /// Start a live session (set status to 'live').
  Future<LiveStream> startSession(String sessionId) async {
    final data = await _supabase
        .from('live_sessions')
        .update({
          'status': 'live',
          'started_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', sessionId)
        .select(_profileSelect)
        .single();

    return LiveStream.fromSupabase(data);
  }

  /// End a live session.
  Future<void> endSession(String sessionId) async {
    await _supabase.from('live_sessions').update({
      'status': 'ended',
      'ended_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', sessionId);
  }

  // ═══════════════════════════════════════════════════
  //  VIEWER TRACKING
  // ═══════════════════════════════════════════════════

  /// Join a live session as a viewer.
  Future<void> joinSession(String sessionId) async {
    final userId = _currentUserId;
    if (userId == null) return;

    try {
      await _supabase.from('live_viewer_sessions').insert({
        'live_session_id': sessionId,
        'user_id': userId,
        'joined_at': DateTime.now().toUtc().toIso8601String(),
      });

      // Increment viewer count
      await _supabase.rpc('increment_live_viewer_count', params: {
        'session_id': sessionId,
      }).catchError((_) async {
        // Fallback: manual increment
        final session = await _supabase
            .from('live_sessions')
            .select('viewer_count, peak_viewer_count, total_unique_viewers')
            .eq('id', sessionId)
            .maybeSingle();
        if (session != null) {
          final current = (session['viewer_count'] as num?)?.toInt() ?? 0;
          final peak = (session['peak_viewer_count'] as num?)?.toInt() ?? 0;
          final newCount = current + 1;
          await _supabase.from('live_sessions').update({
            'viewer_count': newCount,
            if (newCount > peak) 'peak_viewer_count': newCount,
            'total_unique_viewers': (session['total_unique_viewers'] as num?)!.toInt() + 1,
          }).eq('id', sessionId);
        }
      });
    } catch (e) {
      debugPrint('[LiveRepo] Join error: $e');
    }
  }

  /// Leave a live session as a viewer.
  Future<void> leaveSession(String sessionId) async {
    final userId = _currentUserId;
    if (userId == null) return;

    try {
      // Update viewer session with leave time
      await _supabase
          .from('live_viewer_sessions')
          .update({
            'left_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('live_session_id', sessionId)
          .eq('user_id', userId)
          .isFilter('left_at', null);

      // Decrement viewer count
      final session = await _supabase
          .from('live_sessions')
          .select('viewer_count')
          .eq('id', sessionId)
          .maybeSingle();
      if (session != null) {
        final current = (session['viewer_count'] as num?)?.toInt() ?? 0;
        await _supabase.from('live_sessions').update({
          'viewer_count': (current - 1).clamp(0, 999999),
        }).eq('id', sessionId);
      }
    } catch (e) {
      debugPrint('[LiveRepo] Leave error: $e');
    }
  }

  // ═══════════════════════════════════════════════════
  //  CHAT
  // ═══════════════════════════════════════════════════

  /// Send a chat message to a live session.
  Future<LiveChatMessage> sendChatMessage({
    required String sessionId,
    required String message,
  }) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('Not authenticated');

    final data = await _supabase
        .from('live_chat_messages')
        .insert({
          'live_session_id': sessionId,
          'user_id': userId,
          'message': message,
        })
        .select('*, profiles!inner(username, display_name, avatar_url)')
        .single();

    // Increment chat message count
    try {
      await _supabase.rpc('increment_counter', params: {
        'row_id': sessionId,
        'table_name': 'live_sessions',
        'column_name': 'total_chat_messages',
      });
    } catch (_) {}

    return LiveChatMessage.fromSupabase(data);
  }

  /// Get recent chat messages for a live session.
  Future<List<LiveChatMessage>> getChatMessages({
    required String sessionId,
    int limit = 50,
  }) async {
    final data = await _supabase
        .from('live_chat_messages')
        .select('*, profiles!inner(username, display_name, avatar_url)')
        .eq('live_session_id', sessionId)
        .eq('moderation_state', 'visible')
        .order('created_at', ascending: true)
        .limit(limit);

    return data.map<LiveChatMessage>(
      (d) => LiveChatMessage.fromSupabase(d as Map<String, dynamic>),
    ).toList();
  }

  /// Delete a chat message (moderation).
  Future<void> deleteChatMessage(int messageId) async {
    await _supabase.from('live_chat_messages').update({
      'moderation_state': 'deleted',
    }).eq('id', messageId);
  }

  // ═══════════════════════════════════════════════════
  //  MODERATION
  // ═══════════════════════════════════════════════════

  /// Report a live stream.
  Future<void> reportStream(String sessionId, String reason) async {
    final userId = _currentUserId;
    if (userId == null) return;

    await _supabase.from('reports').insert({
      'reporter_id': userId,
      'target_type': 'live_session',
      'target_id': sessionId,
      'reason': reason,
    });
  }
}
