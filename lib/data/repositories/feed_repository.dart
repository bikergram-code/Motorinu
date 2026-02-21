import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/post.dart';

class FeedRepository {
  FeedRepository();

  SupabaseClient get _supabase => Supabase.instance.client;

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  // ═══════════════════════════════════════════════════
  //  FOLLOWING FEED — posts from followed users only
  // ═══════════════════════════════════════════════════

  /// Fetch paginated Following feed: only posts from users the viewer follows
  /// within the given community. Newest-first with lightweight quality boost.
  Future<FeedPage> getFollowingFeed({
    int page = 1,
    int limit = 20,
    String? community,
  }) async {
    final userId = _currentUserId;
    if (userId == null) {
      return const FeedPage(posts: [], hasMore: false);
    }

    final offset = (page - 1) * limit;
    final communityFilter = community ?? 'bikergram';

    // Step 1: Get the list of user IDs the viewer follows in this community
    final followData = await _supabase
        .from('follows')
        .select('following_id')
        .eq('follower_id', userId)
        .eq('community', communityFilter);

    final followingIds = followData
        .map<String>((f) => f['following_id'] as String)
        .toList();

    // Include own posts in following feed
    followingIds.add(userId);

    if (followingIds.isEmpty) {
      return const FeedPage(posts: [], hasMore: false);
    }

    // Step 2: Get blocked user IDs
    final blockedIds = await _getBlockedUserIds(userId);

    // Step 3: Query posts from followed users, excluding blocked
    var effectiveIds = followingIds
        .where((id) => !blockedIds.contains(id))
        .toList();

    if (effectiveIds.isEmpty) {
      return const FeedPage(posts: [], hasMore: false);
    }

    final data = await _supabase
        .from('posts')
        .select('*, profiles!inner(username, display_name, avatar_url, bikername)')
        .inFilter('user_id', effectiveIds)
        .eq('community', communityFilter)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return _buildFeedPage(data, limit);
  }

  // ═══════════════════════════════════════════════════
  //  FOR YOU FEED — discovery beyond follow graph
  // ═══════════════════════════════════════════════════

  /// Fetch paginated For You feed: all community posts (discovery),
  /// excluding blocked users. Ordered by created_at desc (heuristic
  /// scoring is done client-side for MVP).
  Future<FeedPage> getForYouFeed({
    int page = 1,
    int limit = 20,
    String? community,
  }) async {
    final userId = _currentUserId;
    final offset = (page - 1) * limit;
    final communityFilter = community ?? 'bikergram';

    // Get blocked user IDs
    final blockedIds = userId != null
        ? await _getBlockedUserIds(userId)
        : <String>[];

    // Get muted user IDs (per-community)
    final mutedIds = userId != null
        ? await _getMutedUserIds(userId, communityFilter)
        : <String>[];

    final excludeIds = {...blockedIds, ...mutedIds}.toList();

    // Query all community posts, excluding blocked/muted users
    var query = _supabase
        .from('posts')
        .select('*, profiles!inner(username, display_name, avatar_url, bikername)');

    query = query.eq('community', communityFilter);

    final data = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    // Filter out blocked/muted users client-side
    // (Supabase doesn't support NOT IN directly on queries easily)
    final filteredData = excludeIds.isEmpty
        ? data
        : data.where((p) => !excludeIds.contains(p['user_id'])).toList();

    return _buildFeedPage(filteredData, limit);
  }

  // ═══════════════════════════════════════════════════
  //  LEGACY getFeed (backward compat, maps to ForYou)
  // ═══════════════════════════════════════════════════

  /// Fetch paginated feed posts with joined profile data.
  Future<FeedPage> getFeed({int page = 1, int limit = 20, String? community}) async {
    return getForYouFeed(page: page, limit: limit, community: community);
  }

  // ═══════════════════════════════════════════════════
  //  SHARED HELPERS
  // ═══════════════════════════════════════════════════

  /// Build a FeedPage from raw Supabase response data.
  Future<FeedPage> _buildFeedPage(List<dynamic> data, int limit) async {
    final postIds = data.map<int>((p) => p['id'] as int).toList();

    // Batch-check likes + saves
    Set<int> likedPostIds = {};
    Set<int> savedPostIds = {};

    if (_currentUserId != null && postIds.isNotEmpty) {
      final likesFuture = _supabase
          .from('post_likes')
          .select('post_id')
          .eq('user_id', _currentUserId!)
          .inFilter('post_id', postIds);

      final savesFuture = _supabase
          .from('post_saves')
          .select('post_id')
          .eq('user_id', _currentUserId!)
          .inFilter('post_id', postIds);

      // Run in parallel
      final results = await Future.wait([
        likesFuture,
        savesFuture.catchError((_) => <Map<String, dynamic>>[]),
      ]);

      likedPostIds = (results[0] as List).map<int>((l) => l['post_id'] as int).toSet();
      savedPostIds = (results[1] as List).map<int>((s) => s['post_id'] as int).toSet();
    }

    final posts = data.map<Post>((json) {
      final post = Post.fromSupabase(json as Map<String, dynamic>, currentUserId: _currentUserId);
      return post.copyWith(
        likedByMe: likedPostIds.contains(post.id),
        savedByMe: savedPostIds.contains(post.id),
      );
    }).toList();

    return FeedPage(
      posts: posts,
      hasMore: posts.length >= limit,
    );
  }

  /// Get IDs of users blocked by the viewer (global).
  Future<Set<String>> _getBlockedUserIds(String userId) async {
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

  /// Get IDs of users muted by the viewer in a community.
  Future<Set<String>> _getMutedUserIds(String userId, String community) async {
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
  //  SINGLE POST
  // ═══════════════════════════════════════════════════

  /// Fetch a single post by ID with profile and like/save status.
  Future<Post?> getPostById(int postId) async {
    final data = await _supabase
        .from('posts')
        .select('*, profiles!inner(username, display_name, avatar_url, bikername)')
        .eq('id', postId)
        .maybeSingle();

    if (data == null) return null;

    bool likedByMe = false;
    bool savedByMe = false;

    if (_currentUserId != null) {
      final like = await _supabase
          .from('post_likes')
          .select('id')
          .eq('user_id', _currentUserId!)
          .eq('post_id', postId)
          .maybeSingle();
      likedByMe = like != null;

      try {
        final save = await _supabase
            .from('post_saves')
            .select('id')
            .eq('user_id', _currentUserId!)
            .eq('post_id', postId)
            .maybeSingle();
        savedByMe = save != null;
      } catch (_) {}
    }

    return Post.fromSupabase(data, currentUserId: _currentUserId).copyWith(
      likedByMe: likedByMe,
      savedByMe: savedByMe,
    );
  }

  // ═══════════════════════════════════════════════════
  //  CREATE / UPDATE / DELETE
  // ═══════════════════════════════════════════════════

  /// Create a new post with optional media type, topic tags, and carousel URLs.
  Future<Post> createPost({
    String? body,
    String? imageUrl,
    String? videoUrl,
    String? community,
    String? mediaType,
    List<int>? topicIds,
    List<String>? attachmentUrls,
  }) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('Not authenticated');

    final data = await _supabase
        .from('posts')
        .insert({
          'user_id': userId,
          if (body != null) 'body': body,
          if (imageUrl != null) 'image_url': imageUrl,
          if (videoUrl != null) 'video_url': videoUrl,
          if (community != null) 'community': community,
          if (mediaType != null) 'media_type': mediaType,
          if (attachmentUrls != null) 'attachment_urls': attachmentUrls,
        })
        .select('*, profiles!inner(username, display_name, avatar_url, bikername)')
        .single();

    final post = Post.fromSupabase(data, currentUserId: _currentUserId);

    // Insert topic tags (≤3)
    if (topicIds != null && topicIds.isNotEmpty) {
      final topicRows = topicIds.take(3).map((tid) => {
        'post_id': post.id,
        'topic_id': tid,
      }).toList();
      try {
        await _supabase.from('post_topics').insert(topicRows);
      } catch (_) {
        // Non-critical — topics table may not exist yet
      }
    }

    return post;
  }

  /// Update an existing post.
  Future<Post> updatePost(int postId, {String? body, String? imageUrl}) async {
    final data = await _supabase
        .from('posts')
        .update({
          if (body != null) 'body': body,
          if (imageUrl != null) 'image_url': imageUrl,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', postId)
        .select('*, profiles!inner(username, display_name, avatar_url, bikername)')
        .single();

    return Post.fromSupabase(data, currentUserId: _currentUserId);
  }

  /// Delete a post.
  Future<void> deletePost(int postId) async {
    await _supabase.from('posts').delete().eq('id', postId);
  }

  // ═══════════════════════════════════════════════════
  //  INTERACTIONS
  // ═══════════════════════════════════════════════════

  /// Toggle like on a post using the RPC function.
  Future<bool> toggleLike(int postId) async {
    final result = await _supabase.rpc('toggle_like', params: {
      'p_post_id': postId,
    });

    return result['liked'] == true;
  }

  /// Toggle save/bookmark on a post.
  Future<bool> toggleSave(int postId) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('Not authenticated');

    final existing = await _supabase
        .from('post_saves')
        .select('id')
        .eq('user_id', userId)
        .eq('post_id', postId)
        .maybeSingle();

    if (existing != null) {
      await _supabase
          .from('post_saves')
          .delete()
          .eq('user_id', userId)
          .eq('post_id', postId);
      return false;
    } else {
      await _supabase.from('post_saves').insert({
        'user_id': userId,
        'post_id': postId,
      });
      return true;
    }
  }

  // ═══════════════════════════════════════════════════
  //  LIKERS LIST
  // ═══════════════════════════════════════════════════

  /// Get list of users who liked a post (with profile info).
  Future<List<Map<String, dynamic>>> getPostLikers(int postId, {int limit = 50}) async {
    final data = await _supabase
        .from('post_likes')
        .select('user_id, created_at, profiles(username, display_name, avatar_url)')
        .eq('post_id', postId)
        .order('created_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(data);
  }

  // ═══════════════════════════════════════════════════
  //  REPOST
  // ═══════════════════════════════════════════════════

  /// Create a repost (share to own feed with optional quote).
  Future<void> createRepost(int originalPostId, {String? quoteBody}) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('Not authenticated');

    await _supabase.from('reposts').insert({
      'user_id': userId,
      'original_post_id': originalPostId,
      if (quoteBody != null) 'quote_body': quoteBody,
    });

    // Increment repost_count on the original post
    try {
      await _supabase.rpc('increment_counter', params: {
        'row_id': originalPostId,
        'table_name': 'posts',
        'column_name': 'repost_count',
      });
    } catch (_) {
      // RPC may not exist yet, increment manually
      try {
        final post = await _supabase
            .from('posts')
            .select('repost_count')
            .eq('id', originalPostId)
            .maybeSingle();
        if (post != null) {
          final current = (post['repost_count'] as int?) ?? 0;
          await _supabase
              .from('posts')
              .update({'repost_count': current + 1})
              .eq('id', originalPostId);
        }
      } catch (_) {}
    }
  }

  /// Check if current user has reposted a given post.
  Future<bool> hasReposted(int postId) async {
    final userId = _currentUserId;
    if (userId == null) return false;

    final data = await _supabase
        .from('reposts')
        .select('id')
        .eq('user_id', userId)
        .eq('original_post_id', postId)
        .maybeSingle();

    return data != null;
  }

  /// Remove a repost.
  Future<void> removeRepost(int originalPostId) async {
    final userId = _currentUserId;
    if (userId == null) return;

    await _supabase
        .from('reposts')
        .delete()
        .eq('user_id', userId)
        .eq('original_post_id', originalPostId);
  }

  // ═══════════════════════════════════════════════════
  //  STORAGE
  // ═══════════════════════════════════════════════════

  /// Upload an image to Supabase Storage.
  Future<String> uploadImage(List<int> imageBytes, String fileName) async {
    final userId = _currentUserId ?? 'anonymous';
    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}_$fileName';

    await _supabase.storage.from('posts').uploadBinary(
      path,
      imageBytes as dynamic,
      fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
    );

    return _supabase.storage.from('posts').getPublicUrl(path);
  }
}

class FeedPage {
  const FeedPage({required this.posts, required this.hasMore});
  final List<Post> posts;
  final bool hasMore;
}
