import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/post.dart';
import '../../domain/xp_calculator.dart';

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

    // Following feed: show public + followers posts (you follow them, so you see 'followers')
    // Also always show own posts
    final filteredData = data.where((p) {
      final vis = p['visibility'] as String? ?? 'public';
      return vis == 'public' || vis == 'followers' || p['user_id'] == userId;
    }).toList();

    return _buildFeedPage(filteredData, limit);
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

    // Query posts für aktuelle Community (bikergram ODER cargram).
    // Inkludiert auch Posts mit community=null (alte Posts, fehlender Wert).
    // Erkunden = jeder sieht alle Posts der eigenen Community.
    final data = await _supabase
        .from('posts')
        .select('*, profiles(username, display_name, avatar_url, bikername)')
        .or('community.eq.$communityFilter,community.is.null')
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    // Client-side filter: only exclude blocked/muted users.
    // Erkunden zeigt ALLE Posts (kein Visibility-Filter).
    final filteredData = data.where((p) {
      return !excludeIds.contains(p['user_id']);
    }).toList();

    return _buildFeedPage(filteredData, limit);
  }

  // ═══════════════════════════════════════════════════
  //  REELS FEED — video-only posts for TikTok-style view
  // ═══════════════════════════════════════════════════

  /// Fetch paginated Reels feed: only video posts from the community.
  /// Smaller page size since videos are heavier.
  Future<FeedPage> getReelsFeed({
    int page = 1,
    int limit = 10,
    String? community,
  }) async {
    final userId = _currentUserId;
    final offset = (page - 1) * limit;
    final communityFilter = community ?? 'bikergram';

    final blockedIds = userId != null
        ? await _getBlockedUserIds(userId)
        : <String>{};

    final mutedIds = userId != null
        ? await _getMutedUserIds(userId, communityFilter)
        : <String>{};

    final excludeIds = {...blockedIds, ...mutedIds}.toList();

    final data = await _supabase
        .from('posts')
        .select('*, profiles!inner(username, display_name, avatar_url, bikername)')
        .eq('community', communityFilter)
        .eq('media_type', 'video')
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    // Reels: blocked/muted + visibility (public + own)
    final filteredData = data.where((p) {
      if (excludeIds.contains(p['user_id'])) return false;
      final vis = p['visibility'] as String? ?? 'public';
      return vis == 'public' || p['user_id'] == userId;
    }).toList();

    return _buildFeedPage(filteredData, limit);
  }

  // ═══════════════════════════════════════════════════
  //  FOLLOWING REELS — video-only from followed users
  // ═══════════════════════════════════════════════════

  /// Fetch paginated Reels feed from followed users only.
  Future<FeedPage> getFollowingReelsFeed({
    int page = 1,
    int limit = 10,
    String? community,
  }) async {
    final userId = _currentUserId;
    if (userId == null) {
      return const FeedPage(posts: [], hasMore: false);
    }

    final offset = (page - 1) * limit;
    final communityFilter = community ?? 'bikergram';

    // Step 1: Get the list of user IDs the viewer follows
    final followData = await _supabase
        .from('follows')
        .select('following_id')
        .eq('follower_id', userId)
        .eq('community', communityFilter);

    final followingIds = followData
        .map<String>((f) => f['following_id'] as String)
        .toList();

    // Include own posts
    followingIds.add(userId);

    if (followingIds.isEmpty) {
      return const FeedPage(posts: [], hasMore: false);
    }

    // Step 2: Get blocked user IDs
    final blockedIds = await _getBlockedUserIds(userId);

    final effectiveIds = followingIds
        .where((id) => !blockedIds.contains(id))
        .toList();

    if (effectiveIds.isEmpty) {
      return const FeedPage(posts: [], hasMore: false);
    }

    // Step 3: Query video-only posts from followed users
    final data = await _supabase
        .from('posts')
        .select('*, profiles!inner(username, display_name, avatar_url, bikername)')
        .inFilter('user_id', effectiveIds)
        .eq('community', communityFilter)
        .eq('media_type', 'video')
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    // Show public + followers-visibility posts (you follow them)
    final filteredData = data.where((p) {
      final vis = p['visibility'] as String? ?? 'public';
      return vis == 'public' || vis == 'followers' || p['user_id'] == userId;
    }).toList();

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

    // Batch-check likes + saves + actual comment counts
    Set<int> likedPostIds = {};
    Set<int> savedPostIds = {};
    Map<int, String?> reactionByPost = {};
    Map<int, int> commentCounts = {};

    if (_currentUserId != null && postIds.isNotEmpty) {
      // Likes query: try with reaction_type first, fallback to post_id only
      // (reaction_type column may not exist until migration is run)
      final likesFuture = _supabase
          .from('post_likes')
          .select('post_id, reaction_type')
          .eq('user_id', _currentUserId!)
          .inFilter('post_id', postIds)
          .catchError((_) async {
        // Fallback: reaction_type column doesn't exist yet
        return await _supabase
            .from('post_likes')
            .select('post_id')
            .eq('user_id', _currentUserId!)
            .inFilter('post_id', postIds);
      });

      final savesFuture = _supabase
          .from('post_saves')
          .select('post_id')
          .eq('user_id', _currentUserId!)
          .inFilter('post_id', postIds);

      // Batch-count actual comments per post
      // (comment_count column in posts may be stale/unset for older posts)
      final commentsFuture = _supabase
          .from('comments')
          .select('post_id')
          .inFilter('post_id', postIds);

      // Run all three in parallel
      final results = await Future.wait([
        likesFuture,
        savesFuture.catchError((_) => <Map<String, dynamic>>[]),
        commentsFuture.catchError((_) => <Map<String, dynamic>>[]),
      ]);

      for (final like in results[0] as List) {
        final postId = like['post_id'] as int;
        likedPostIds.add(postId);
        // reaction_type may not be present in fallback query
        if (like is Map && like.containsKey('reaction_type')) {
          reactionByPost[postId] = like['reaction_type'] as String?;
        }
      }
      savedPostIds = (results[1] as List).map<int>((s) => s['post_id'] as int).toSet();

      // Count comments per post from actual comments table
      for (final row in results[2] as List) {
        final pid = row['post_id'] as int;
        commentCounts[pid] = (commentCounts[pid] ?? 0) + 1;
      }
    } else if (postIds.isNotEmpty) {
      // Not logged in — still count comments for display
      try {
        final commentData = await _supabase
            .from('comments')
            .select('post_id')
            .inFilter('post_id', postIds);
        for (final row in commentData) {
          final pid = row['post_id'] as int;
          commentCounts[pid] = (commentCounts[pid] ?? 0) + 1;
        }
      } catch (_) {}
    }

    final posts = data.map<Post>((json) {
      final post = Post.fromSupabase(json as Map<String, dynamic>, currentUserId: _currentUserId);
      return post.copyWith(
        likedByMe: likedPostIds.contains(post.id),
        myReaction: reactionByPost[post.id],
        savedByMe: savedPostIds.contains(post.id),
        commentCount: commentCounts.containsKey(post.id)
            ? commentCounts[post.id]!
            : post.commentCount,
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
    String? myReaction;

    if (_currentUserId != null) {
      // Fetch like with reaction_type (fallback to id-only if column missing)
      try {
        final like = await _supabase
            .from('post_likes')
            .select('id, reaction_type')
            .eq('user_id', _currentUserId!)
            .eq('post_id', postId)
            .maybeSingle();
        likedByMe = like != null;
        if (like != null && like.containsKey('reaction_type')) {
          myReaction = like['reaction_type'] as String?;
        }
      } catch (_) {
        // Fallback: reaction_type column may not exist
        final like = await _supabase
            .from('post_likes')
            .select('id')
            .eq('user_id', _currentUserId!)
            .eq('post_id', postId)
            .maybeSingle();
        likedByMe = like != null;
      }

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
      myReaction: myReaction,
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
    String? thumbnailUrl,
    String? community,
    String? mediaType,
    List<int>? topicIds,
    List<String>? attachmentUrls,
    String visibility = 'public',
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
          if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
          if (community != null) 'community': community,
          if (mediaType != null) 'media_type': mediaType,
          if (attachmentUrls != null) 'attachment_urls': attachmentUrls,
          'visibility': visibility,
        })
        .select('*, profiles!inner(username, display_name, avatar_url, bikername)')
        .single();

    final post = Post.fromSupabase(data, currentUserId: _currentUserId);

    // Award +5 XP for posting (via central method)
    XpCalculator.awardXp(userId, XpCalculator.xpPostCreated, 'post_created');

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
  /// Awards XP: +1 to liker, +2 to post owner (on like only, not unlike).
  Future<bool> toggleLike(int postId) async {
    final result = await _supabase.rpc('toggle_like', params: {
      'p_post_id': postId,
    });

    final liked = result['liked'] == true;
    if (liked) {
      final myId = _currentUserId;
      if (myId != null) {
        // +1 XP for giving a like
        XpCalculator.awardXp(myId, XpCalculator.xpLikeGiven, 'like_given');
        // +2 XP for the post owner (receiving a like)
        try {
          final post = await _supabase
              .from('posts')
              .select('user_id')
              .eq('id', postId)
              .single();
          final ownerId = post['user_id'] as String?;
          if (ownerId != null && ownerId != myId) {
            XpCalculator.awardXp(ownerId, XpCalculator.xpLikeReceived, 'like_received');
          }
        } catch (_) {}
      }
    }
    return liked;
  }

  /// Toggle a reaction on a post. Returns {liked: bool, reaction: String?}.
  /// Pass null reactionType for regular like.
  Future<Map<String, dynamic>> toggleReaction(int postId, {String? reactionType}) async {
    try {
      final result = await _supabase.rpc('toggle_reaction', params: {
        'p_post_id': postId,
        'p_reaction': reactionType,
      });
      return Map<String, dynamic>.from(result as Map);
    } catch (_) {
      // Fallback: toggle_reaction RPC may not exist yet → use toggle_like
      final liked = await toggleLike(postId);
      return {'liked': liked, 'reaction': null};
    }
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

  // ═══════════════════════════════════════════════════
  //  SAVED POSTS
  // ═══════════════════════════════════════════════════

  /// Fetch all posts saved/bookmarked by the current user.
  Future<FeedPage> getSavedPosts({int page = 1, int limit = 20}) async {
    final userId = _currentUserId;
    if (userId == null) return const FeedPage(posts: [], hasMore: false);

    final offset = (page - 1) * limit;

    // 1. Get saved post IDs (newest saves first)
    final savesData = await _supabase
        .from('post_saves')
        .select('post_id')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    if (savesData.isEmpty) {
      return const FeedPage(posts: [], hasMore: false);
    }

    final savedPostIds =
        savesData.map<int>((s) => s['post_id'] as int).toList();

    // 2. Fetch full post data for those IDs
    final data = await _supabase
        .from('posts')
        .select('*, profiles!inner(username, display_name, avatar_url, bikername)')
        .inFilter('id', savedPostIds);

    // 3. Build feed page with like/save status
    final page_ = await _buildFeedPage(data, limit);

    // 4. Re-sort to match save order (newest save first)
    final orderMap = {for (var i = 0; i < savedPostIds.length; i++) savedPostIds[i]: i};
    final sorted = List<Post>.from(page_.posts)
      ..sort((a, b) => (orderMap[a.id] ?? 999).compareTo(orderMap[b.id] ?? 999));

    return FeedPage(
      posts: sorted,
      hasMore: savesData.length >= limit,
    );
  }

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
