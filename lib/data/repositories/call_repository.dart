import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository for call signaling and persistence.
/// Uses Supabase `calls` table + Realtime for signaling.
class CallRepository {
  SupabaseClient get _supabase => Supabase.instance.client;
  String? get _currentUserId => _supabase.auth.currentUser?.id;

  // ── Create ───────────────────────────────────────────────────────────

  /// Start a new call. Returns the full call row (with generated `id`).
  Future<Map<String, dynamic>> createCall({
    required String callerId,
    String? calleeId,
    int? conversationId,
    int? groupId,
    required String callType,
  }) async {
    final row = {
      'caller_id': callerId,
      'call_type': callType,
      'status': 'ringing',
      if (calleeId != null) 'callee_id': calleeId,
      if (conversationId != null) 'conversation_id': conversationId,
      if (groupId != null) 'group_id': groupId,
    };

    final result = await _supabase
        .from('calls')
        .insert(row)
        .select()
        .single();

    // Set livekit_room based on call type:
    // - Group call: room = 'group-call-{groupId}' (all members join same room)
    // - 1-on-1:     room = 'call-{callId}' (unique per call)
    final callId = result['id'] as int;
    final roomName = groupId != null ? 'group-call-$groupId' : 'call-$callId';
    await _supabase
        .from('calls')
        .update({'livekit_room': roomName})
        .eq('id', callId);

    result['livekit_room'] = roomName;
    debugPrint('[CallRepo] Created call $callId (room=$roomName, groupId=$groupId)');
    return result;
  }

  // ── Group call helpers ───────────────────────────────────────────────

  /// Check if the current user is a member of the given group.
  /// Used to filter incoming group call events client-side.
  Future<bool> isUserInGroup(int groupId, String userId) async {
    try {
      final row = await _supabase
          .from('group_members')
          .select('group_id')
          .eq('group_id', groupId)
          .eq('user_id', userId)
          .maybeSingle();
      return row != null;
    } catch (e) {
      debugPrint('[CallRepo] isUserInGroup error: $e');
      return false;
    }
  }

  /// Fetch group info (name + avatar) for displaying incoming group calls.
  Future<Map<String, dynamic>?> getGroupInfo(int groupId) async {
    try {
      final result = await _supabase.rpc('get_group_by_id', params: {'p_group_id': groupId});
      if (result is Map) return Map<String, dynamic>.from(result);
    } catch (e) {
      debugPrint('[CallRepo] getGroupInfo error: $e');
    }
    return null;
  }

  // ── Update ───────────────────────────────────────────────────────────

  /// Update call status (accept, decline, end, missed, busy).
  Future<void> updateCallStatus(
    int callId,
    String status, {
    DateTime? startedAt,
    DateTime? endedAt,
    int? durationSeconds,
  }) async {
    final updates = <String, dynamic>{'status': status};
    if (startedAt != null) updates['started_at'] = startedAt.toIso8601String();
    if (endedAt != null) updates['ended_at'] = endedAt.toIso8601String();
    if (durationSeconds != null) updates['duration_seconds'] = durationSeconds;

    await _supabase.from('calls').update(updates).eq('id', callId);
    debugPrint('[CallRepo] Updated call $callId → status=$status');
  }

  // ── Query ────────────────────────────────────────────────────────────

  /// Check if a user is already in an active or ringing call.
  /// Only considers calls from the last 60 seconds (stale calls are ignored).
  /// Returns the call row or null.
  Future<Map<String, dynamic>?> getActiveCallForUser(String userId) async {
    final cutoff = DateTime.now().subtract(const Duration(seconds: 60)).toIso8601String();
    final result = await _supabase
        .from('calls')
        .select()
        .or('caller_id.eq.$userId,callee_id.eq.$userId')
        .inFilter('status', ['ringing', 'active'])
        .gte('created_at', cutoff)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return result;
  }

  /// Get a single call by ID.
  Future<Map<String, dynamic>?> getCall(int callId) async {
    return await _supabase
        .from('calls')
        .select()
        .eq('id', callId)
        .maybeSingle();
  }

  // ── Realtime ─────────────────────────────────────────────────────────

  /// Subscribe to changes on a specific call (for caller to detect accept/decline).
  RealtimeChannel subscribeToCall(
    int callId,
    void Function(Map<String, dynamic> record) onUpdate,
  ) {
    return _supabase
        .channel('call:$callId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'calls',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: callId,
          ),
          callback: (payload) {
            debugPrint('[CallRepo] Call $callId updated: ${payload.newRecord['status']}');
            onUpdate(payload.newRecord);
          },
        )
        .subscribe((status, [error]) {
      debugPrint('[CallRepo] call:$callId channel status=$status');
    });
  }

  /// Subscribe to incoming calls for the current user.
  /// Listens for ALL INSERT on `calls` and filters client-side
  /// (UUID filter on Realtime can be unreliable).
  RealtimeChannel subscribeToIncomingCalls(
    void Function(Map<String, dynamic> callRecord) onIncomingCall,
  ) {
    final userId = _currentUserId;
    debugPrint('[CallRepo] Subscribing to incoming calls for user=$userId');

    return _supabase
        .channel('calls:incoming')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'calls',
          callback: (payload) async {
            final record = payload.newRecord;
            final calleeId = record['callee_id']?.toString();
            final callerId = record['caller_id']?.toString();
            final status = record['status']?.toString();
            final groupId = record['group_id'];

            debugPrint('[CallRepo] New call INSERT: id=${record['id']}, callee=$calleeId, groupId=$groupId, me=$userId, status=$status');

            if (status != 'ringing') return;
            // Ignore own calls (initiator shouldn't get ring)
            if (callerId == userId) return;

            // 1-on-1: direct callee match
            if (calleeId == userId) {
              debugPrint('[CallRepo] Incoming 1-on-1 call for ME: id=${record['id']}');
              onIncomingCall(record);
              return;
            }

            // Group call: check if current user is a member of the group
            if (groupId != null && userId != null) {
              final gId = groupId is int ? groupId : int.tryParse('$groupId');
              if (gId == null) return;
              final isMember = await isUserInGroup(gId, userId);
              if (isMember) {
                debugPrint('[CallRepo] Incoming GROUP call for ME (group $gId): id=${record['id']}');
                onIncomingCall(record);
              }
            }
          },
        )
        .subscribe((status, [error]) {
      debugPrint('[CallRepo] calls:incoming channel status=$status, error=$error');
    });
  }

  /// Fetch caller profile info (name + avatar).
  Future<Map<String, dynamic>?> getCallerProfile(String callerId) async {
    return await _supabase
        .from('profiles')
        .select('id, username, display_name, avatar_url')
        .eq('id', callerId)
        .maybeSingle();
  }
}
