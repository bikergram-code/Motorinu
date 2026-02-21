import 'package:supabase_flutter/supabase_flutter.dart';

class Comment {
  final int id;
  final int postId;
  final String userId;
  final String username;
  final String? avatarUrl;
  final String body;
  final DateTime? createdAt;
  final bool isMine;

  const Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.username,
    this.avatarUrl,
    required this.body,
    this.createdAt,
    this.isMine = false,
  });

  factory Comment.fromJson(Map<String, dynamic> json, {String? currentUserId}) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    final userId = '${json['user_id']}';

    return Comment(
      id: json['id'] as int,
      postId: json['post_id'] as int,
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

class CommentRepository {
  SupabaseClient get _supabase => Supabase.instance.client;
  String? get _currentUserId => _supabase.auth.currentUser?.id;

  Future<List<Comment>> getComments(int postId, {int limit = 50, int offset = 0}) async {
    final data = await _supabase
        .from('comments')
        .select('*, profiles!inner(username, avatar_url)')
        .eq('post_id', postId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return data.map<Comment>((json) =>
        Comment.fromJson(json, currentUserId: _currentUserId)).toList();
  }

  Future<Comment> addComment(int postId, String body) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('Nicht eingeloggt');

    final data = await _supabase
        .from('comments')
        .insert({
          'post_id': postId,
          'user_id': userId,
          'body': body,
        })
        .select('*, profiles!inner(username, avatar_url)')
        .single();

    // Update comment count on the post
    final post = await _supabase
        .from('posts')
        .select('comment_count')
        .eq('id', postId)
        .single();
    await _supabase
        .from('posts')
        .update({'comment_count': (post['comment_count'] as int) + 1})
        .eq('id', postId);

    return Comment.fromJson(data, currentUserId: _currentUserId);
  }

  /// Batch-fetch the latest 2 comments for each given post ID.
  /// Returns a Map: postId → list of {username, body} previews.
  Future<Map<int, List<Map<String, String>>>> getCommentPreviews(List<int> postIds) async {
    if (postIds.isEmpty) return {};

    final data = await _supabase
        .from('comments')
        .select('post_id, body, profiles!inner(username)')
        .inFilter('post_id', postIds)
        .order('created_at', ascending: false)
        .limit(postIds.length * 3); // fetch a few extra to ensure 2 per post

    final result = <int, List<Map<String, String>>>{};
    for (final row in data) {
      final postId = row['post_id'] as int;
      final existing = result[postId] ?? [];
      if (existing.length >= 2) continue; // max 2 per post
      final profile = row['profiles'] as Map<String, dynamic>?;
      existing.add({
        'username': profile?['username'] as String? ?? 'user',
        'body': row['body'] as String? ?? '',
      });
      result[postId] = existing;
    }
    return result;
  }

  Future<void> deleteComment(int commentId, int postId) async {
    await _supabase.from('comments').delete().eq('id', commentId);

    // Decrement comment count
    final post = await _supabase
        .from('posts')
        .select('comment_count')
        .eq('id', postId)
        .single();
    final newCount = ((post['comment_count'] as int) - 1).clamp(0, 999999);
    await _supabase
        .from('posts')
        .update({'comment_count': newCount})
        .eq('id', postId);
  }
}
