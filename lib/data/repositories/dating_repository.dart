import 'package:supabase_flutter/supabase_flutter.dart';

class DatingRepository {
  SupabaseClient get _supabase => Supabase.instance.client;
  String? get _currentUserId => _supabase.auth.currentUser?.id;

  /// Fetch dating candidates for the current user, filtered by community,
  /// gender preferences, blocks, and already-swiped profiles.
  Future<List<Map<String, dynamic>>> getCandidates({
    required String community,
    int limit = 20,
  }) async {
    final res = await _supabase.rpc('get_dating_candidates', params: {
      'p_community': community,
      'p_limit': limit,
    });
    final list = List<Map<String, dynamic>>.from(res as List);
    // Dedupe by id — the SQL function can return duplicates if a candidate
    // has multiple vehicles/photos and the JOIN isn't DISTINCT.
    final seen = <Object?>{};
    return list.where((c) => seen.add(c['id'])).toList();
  }

  /// Record a swipe (like or nope). Returns match info if mutual like.
  Future<Map<String, dynamic>> recordSwipe({
    required String swipedId,
    required bool isLike,
    required String community,
  }) async {
    final res = await _supabase.rpc('record_swipe', params: {
      'p_swiped_id': swipedId,
      'p_is_like': isLike,
      'p_community': community,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  /// Get all matches for the current user in a community.
  Future<List<Map<String, dynamic>>> getMatches({
    required String community,
  }) async {
    final userId = _currentUserId;
    if (userId == null) return [];

    final res = await _supabase
        .from('matches')
        .select('''
          id, community, conversation_id, created_at,
          user1:profiles!matches_user1_id_fkey(id, username, display_name, avatar_url, avatar_url_cargram),
          user2:profiles!matches_user2_id_fkey(id, username, display_name, avatar_url, avatar_url_cargram)
        ''')
        .eq('community', community)
        .or('user1_id.eq.$userId,user2_id.eq.$userId')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(res as List);
  }
}
