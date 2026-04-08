import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/xp_calculator.dart';

/// Comment on a story.
class StoryComment {
  final int id;
  final int storyId;
  final String userId;
  final String username;
  final String? avatarUrl;
  final String body;
  final DateTime? createdAt;
  final bool isMine;

  const StoryComment({
    required this.id,
    required this.storyId,
    required this.userId,
    required this.username,
    this.avatarUrl,
    required this.body,
    this.createdAt,
    this.isMine = false,
  });

  factory StoryComment.fromJson(Map<String, dynamic> json,
      {String? currentUserId}) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    final userId = '${json['user_id']}';

    return StoryComment(
      id: json['id'] as int,
      storyId: json['story_id'] as int,
      userId: userId,
      username: profile?['username'] ?? 'user',
      avatarUrl: profile?['avatar_url'] as String?,
      body: json['body'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse('${json['created_at']}')
          : null,
      isMine: currentUserId != null && userId == currentUserId,
    );
  }
}

class StoryRepository {
  SupabaseClient get _supabase => Supabase.instance.client;
  String? get _currentUserId => _supabase.auth.currentUser?.id;

  // ---------------------------------------------------------------------------
  // Delete story (own only — RLS enforced)
  // ---------------------------------------------------------------------------

  Future<void> deleteStory(int storyId) async {
    // 1) Get the media_url so we can also delete from storage
    final row = await _supabase
        .from('stories')
        .select('media_url')
        .eq('id', storyId)
        .maybeSingle();

    // 2) Delete the DB row
    await _supabase.from('stories').delete().eq('id', storyId);

    // 3) Try to delete the storage file (best-effort)
    if (row != null) {
      final url = row['media_url'] as String? ?? '';
      // URL pattern: .../storage/v1/object/public/posts/stories/userId/file
      final marker = '/storage/v1/object/public/posts/';
      final idx = url.indexOf(marker);
      if (idx != -1) {
        final storagePath = url.substring(idx + marker.length);
        try {
          await _supabase.storage.from('posts').remove([storagePath]);
        } catch (_) {
          // ignore storage errors — DB row is already gone
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Like / Unlike
  // ---------------------------------------------------------------------------

  /// Toggles a like on a story. Returns `true` if now liked, `false` if unliked.
  Future<bool> toggleStoryLike(int storyId) async {
    final result =
        await _supabase.rpc('toggle_story_like', params: {'p_story_id': storyId});
    final map = result as Map<String, dynamic>;
    final liked = map['liked'] as bool;
    // +1 XP for liking a story
    if (liked) {
      final myId = _currentUserId;
      if (myId != null) {
        XpCalculator.awardXp(myId, XpCalculator.xpStoryLike, 'story_like');
      }
    }
    return liked;
  }

  /// Returns (likeCount, likedByMe) for a specific story.
  Future<({int count, bool likedByMe})> getStoryLikeInfo(int storyId) async {
    final userId = _currentUserId;

    final storyRow = await _supabase
        .from('stories')
        .select('like_count')
        .eq('id', storyId)
        .maybeSingle();

    final count = (storyRow?['like_count'] as int?) ?? 0;

    bool likedByMe = false;
    if (userId != null) {
      final like = await _supabase
          .from('story_likes')
          .select('id')
          .eq('story_id', storyId)
          .eq('user_id', userId)
          .maybeSingle();
      likedByMe = like != null;
    }

    return (count: count, likedByMe: likedByMe);
  }

  // ---------------------------------------------------------------------------
  // Comments
  // ---------------------------------------------------------------------------

  Future<List<StoryComment>> getComments(int storyId,
      {int limit = 50, int offset = 0}) async {
    final data = await _supabase
        .from('story_comments')
        .select('*, profiles!inner(username, avatar_url)')
        .eq('story_id', storyId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return data
        .map<StoryComment>(
            (json) => StoryComment.fromJson(json, currentUserId: _currentUserId))
        .toList();
  }

  Future<StoryComment> addComment(int storyId, String body) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('Nicht eingeloggt');

    final data = await _supabase
        .from('story_comments')
        .insert({
          'story_id': storyId,
          'user_id': userId,
          'body': body,
        })
        .select('*, profiles!inner(username, avatar_url)')
        .single();

    // Update comment count on the story
    final story = await _supabase
        .from('stories')
        .select('comment_count')
        .eq('id', storyId)
        .single();
    await _supabase
        .from('stories')
        .update({'comment_count': (story['comment_count'] as int) + 1})
        .eq('id', storyId);

    // +2 XP for commenting on a story
    XpCalculator.awardXp(userId, XpCalculator.xpStoryComment, 'story_comment');

    return StoryComment.fromJson(data, currentUserId: _currentUserId);
  }

  Future<void> deleteComment(int commentId, int storyId) async {
    await _supabase.from('story_comments').delete().eq('id', commentId);

    // Decrement comment count
    final story = await _supabase
        .from('stories')
        .select('comment_count')
        .eq('id', storyId)
        .single();
    final newCount = ((story['comment_count'] as int) - 1).clamp(0, 999999);
    await _supabase
        .from('stories')
        .update({'comment_count': newCount})
        .eq('id', storyId);
  }
}
