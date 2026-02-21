import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository for moderation actions: block, mute, report.
/// - Blocks are global (all communities).
/// - Mutes are per-community.
/// - Reports store reason + metadata.
class ModerationRepository {
  SupabaseClient get _supabase => Supabase.instance.client;
  String? get _currentUserId => _supabase.auth.currentUser?.id;

  // ═══════════════════════════════════════════════════
  //  BLOCK (global)
  // ═══════════════════════════════════════════════════

  /// Block a user globally (hides all their content everywhere).
  Future<void> blockUser(String targetUserId) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('Nicht eingeloggt');
    if (userId == targetUserId) return;

    try {
      await _supabase.from('blocks').upsert({
        'blocker_id': userId,
        'blocked_id': targetUserId,
      }, onConflict: 'blocker_id,blocked_id');
      debugPrint('[Moderation] Blocked user: $targetUserId');
    } catch (e) {
      debugPrint('[Moderation] Block error: $e');
      rethrow;
    }
  }

  /// Unblock a user.
  Future<void> unblockUser(String targetUserId) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('Nicht eingeloggt');

    await _supabase
        .from('blocks')
        .delete()
        .eq('blocker_id', userId)
        .eq('blocked_id', targetUserId);
    debugPrint('[Moderation] Unblocked user: $targetUserId');
  }

  /// Check if a user is blocked.
  Future<bool> isBlocked(String targetUserId) async {
    final userId = _currentUserId;
    if (userId == null) return false;

    final data = await _supabase
        .from('blocks')
        .select('id')
        .eq('blocker_id', userId)
        .eq('blocked_id', targetUserId)
        .maybeSingle();

    return data != null;
  }

  /// Get all blocked user IDs.
  Future<Set<String>> getBlockedUserIds() async {
    final userId = _currentUserId;
    if (userId == null) return {};

    try {
      final data = await _supabase
          .from('blocks')
          .select('blocked_id')
          .eq('blocker_id', userId);
      return data.map<String>((b) => b['blocked_id'] as String).toSet();
    } catch (_) {
      return {};
    }
  }

  /// Get list of blocked users with profile info.
  Future<List<Map<String, dynamic>>> getBlockedUsers() async {
    final userId = _currentUserId;
    if (userId == null) return [];

    try {
      final data = await _supabase
          .from('blocks')
          .select('blocked_id, created_at, profiles!blocks_blocked_id_fkey(username, display_name, avatar_url)')
          .eq('blocker_id', userId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      // Fallback without profile join
      debugPrint('[Moderation] getBlockedUsers join error: $e');
      final data = await _supabase
          .from('blocks')
          .select('blocked_id, created_at')
          .eq('blocker_id', userId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    }
  }

  // ═══════════════════════════════════════════════════
  //  MUTE (per-community)
  // ═══════════════════════════════════════════════════

  /// Mute a user in a specific community (hide from feed only).
  Future<void> muteUser(String targetUserId, {required String community}) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('Nicht eingeloggt');
    if (userId == targetUserId) return;

    try {
      await _supabase.from('mutes').upsert({
        'muter_id': userId,
        'muted_id': targetUserId,
        'community': community,
      }, onConflict: 'muter_id,muted_id,community');
      debugPrint('[Moderation] Muted user: $targetUserId in $community');
    } catch (e) {
      debugPrint('[Moderation] Mute error: $e');
      rethrow;
    }
  }

  /// Unmute a user in a community.
  Future<void> unmuteUser(String targetUserId, {required String community}) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('Nicht eingeloggt');

    await _supabase
        .from('mutes')
        .delete()
        .eq('muter_id', userId)
        .eq('muted_id', targetUserId)
        .eq('community', community);
    debugPrint('[Moderation] Unmuted user: $targetUserId in $community');
  }

  /// Check if a user is muted in a community.
  Future<bool> isMuted(String targetUserId, {required String community}) async {
    final userId = _currentUserId;
    if (userId == null) return false;

    final data = await _supabase
        .from('mutes')
        .select('id')
        .eq('muter_id', userId)
        .eq('muted_id', targetUserId)
        .eq('community', community)
        .maybeSingle();

    return data != null;
  }

  /// Get all muted user IDs in a community.
  Future<Set<String>> getMutedUserIds({required String community}) async {
    final userId = _currentUserId;
    if (userId == null) return {};

    try {
      final data = await _supabase
          .from('mutes')
          .select('muted_id')
          .eq('muter_id', userId)
          .eq('community', community);
      return data.map<String>((m) => m['muted_id'] as String).toSet();
    } catch (_) {
      return {};
    }
  }

  // ═══════════════════════════════════════════════════
  //  REPORT (post / user / comment)
  // ═══════════════════════════════════════════════════

  /// Report a post.
  Future<void> reportPost({
    required int postId,
    required String reason,
    String? details,
    String? community,
  }) async {
    await _createReport(
      targetType: 'post',
      targetId: postId.toString(),
      reason: reason,
      details: details,
      community: community,
    );
  }

  /// Report a user.
  Future<void> reportUser({
    required String targetUserId,
    required String reason,
    String? details,
    String? community,
  }) async {
    await _createReport(
      targetType: 'user',
      targetId: targetUserId,
      reason: reason,
      details: details,
      community: community,
    );
  }

  /// Report a comment.
  Future<void> reportComment({
    required int commentId,
    required String reason,
    String? details,
    String? community,
  }) async {
    await _createReport(
      targetType: 'comment',
      targetId: commentId.toString(),
      reason: reason,
      details: details,
      community: community,
    );
  }

  /// Generic report creation.
  Future<void> _createReport({
    required String targetType,
    required String targetId,
    required String reason,
    String? details,
    String? community,
  }) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('Nicht eingeloggt');

    try {
      await _supabase.from('reports').insert({
        'reporter_id': userId,
        'target_type': targetType,
        'target_id': targetId,
        'reason': reason,
        if (details != null) 'details': details,
        'community': community ?? 'bikergram',
        'status': 'pending',
      });
      debugPrint('[Moderation] Report created: $targetType/$targetId reason=$reason');
    } catch (e) {
      debugPrint('[Moderation] Report error: $e');
      // Try without community column (table might not have it)
      try {
        await _supabase.from('reports').insert({
          'reporter_id': userId,
          'target_type': targetType,
          'target_id': targetId,
          'reason': reason,
          if (details != null) 'details': details,
          'status': 'pending',
        });
      } catch (e2) {
        debugPrint('[Moderation] Report fallback error: $e2');
        rethrow;
      }
    }
  }
}
