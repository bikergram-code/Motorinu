import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/post.dart';
import '../../data/repositories/feed_repository.dart';
import '../../data/repositories/comment_repository.dart';
import '../auth/auth_notifier.dart';
import '../auth/auth_state.dart';
import '../core/providers.dart';

/// Which feed tab is active.
enum FeedMode { forYou, following }

/// Provider for the active feed mode (persisted across rebuilds).
final feedModeProvider =
    NotifierProvider<FeedModeNotifier, FeedMode>(FeedModeNotifier.new);

class FeedModeNotifier extends Notifier<FeedMode> {
  @override
  FeedMode build() => FeedMode.forYou;

  void setMode(FeedMode mode) => state = mode;
}

/// State for the paginated social feed.
class FeedState {
  const FeedState({
    this.posts = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.page = 1,
    this.error,
    this.commentPreviews = const {},
  });

  final List<Post> posts;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int page;
  final String? error;
  /// Map: postId → list of {username, body} for comment previews
  final Map<int, List<Map<String, String>>> commentPreviews;

  FeedState copyWith({
    List<Post>? posts,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? page,
    String? error,
    Map<int, List<Map<String, String>>>? commentPreviews,
  }) {
    return FeedState(
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      error: error,
      commentPreviews: commentPreviews ?? this.commentPreviews,
    );
  }
}

class FeedNotifier extends Notifier<FeedState> {
  late FeedRepository _repo;
  String? _community;

  @override
  FeedState build() {
    _repo = ref.watch(feedRepositoryProvider);
    // Watch community — invalidates this notifier when community changes
    _community = ref.watch(communityProvider)?.name ?? 'bikergram';
    // Watch feed mode — invalidates when tab switches
    ref.watch(feedModeProvider);
    // Auto-load when invalidated by community/mode change
    Future.microtask(loadFeed);
    return const FeedState();
  }

  /// Get the current feed mode.
  FeedMode get _mode => ref.read(feedModeProvider);

  /// Load feed based on current mode (ForYou or Following).
  Future<void> loadFeed() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = _mode == FeedMode.following
          ? await _repo.getFollowingFeed(page: 1, community: _community)
          : await _repo.getForYouFeed(page: 1, community: _community);

      // Load comment previews in background
      final previews = await _loadCommentPreviews(result.posts);

      // Track feed view event
      _trackFeedEvent('feed_view', properties: {
        'mode': _mode.name,
        'community': _community,
        'post_count': result.posts.length,
      });

      state = FeedState(
        posts: result.posts,
        hasMore: result.hasMore,
        page: 1,
        commentPreviews: previews,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);
    try {
      final nextPage = state.page + 1;
      final result = _mode == FeedMode.following
          ? await _repo.getFollowingFeed(page: nextPage, community: _community)
          : await _repo.getForYouFeed(page: nextPage, community: _community);

      // Load comment previews for new posts
      final newPreviews = await _loadCommentPreviews(result.posts);
      state = state.copyWith(
        posts: [...state.posts, ...result.posts],
        hasMore: result.hasMore,
        page: nextPage,
        isLoadingMore: false,
        commentPreviews: {...state.commentPreviews, ...newPreviews},
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  Future<Map<int, List<Map<String, String>>>> _loadCommentPreviews(List<Post> posts) async {
    try {
      final postIds = posts
          .where((p) => p.commentCount > 0)
          .map((p) => p.id)
          .toList();
      if (postIds.isEmpty) return {};
      final commentRepo = ref.read(commentRepositoryProvider);
      return await commentRepo.getCommentPreviews(postIds);
    } catch (e) {
      debugPrint('[FeedNotifier] Comment previews error: $e');
      return {};
    }
  }

  Future<void> toggleLike(int postId) async {
    final idx = state.posts.indexWhere((p) => p.id == postId);
    if (idx == -1) return;

    final post = state.posts[idx];
    final newLiked = !post.likedByMe;
    final newCount = post.likeCount + (newLiked ? 1 : -1);

    final updated = post.copyWith(likedByMe: newLiked, likeCount: newCount);
    final newPosts = List<Post>.from(state.posts);
    newPosts[idx] = updated;
    state = state.copyWith(posts: newPosts);

    // Track like event
    _trackFeedEvent(newLiked ? 'like' : 'unlike', postId: postId);

    try {
      await _repo.toggleLike(postId);
      // Create notification when liking (not unliking)
      if (newLiked && post.userId.isNotEmpty) {
        final authState = ref.read(authNotifierProvider);
        final myId = authState is Authenticated ? authState.user.id : '';
        final myName = authState is Authenticated
            ? (authState.user.displayName ?? authState.user.username)
            : '';
        final notifRepo = ref.read(notificationRepositoryProvider);
        notifRepo.createNotification(
          targetUserId: post.userId,
          type: 'like',
          title: '$myName hat deinen Beitrag geliked',
          data: {'post_id': postId, 'actor_id': myId},
          community: _community,
        );
      }
    } catch (_) {
      newPosts[idx] = post;
      state = state.copyWith(posts: List.from(newPosts));
    }
  }

  Future<void> deletePost(int postId) async {
    await _repo.deletePost(postId);
    state = state.copyWith(
      posts: state.posts.where((p) => p.id != postId).toList(),
    );
  }

  Future<void> updatePost(int postId, {String? body, String? imageUrl}) async {
    final updated = await _repo.updatePost(postId, body: body, imageUrl: imageUrl);
    final newPosts = state.posts.map((p) => p.id == postId ? updated : p).toList();
    state = state.copyWith(posts: newPosts);
  }

  void updateCommentCount(int postId, int delta) {
    final idx = state.posts.indexWhere((p) => p.id == postId);
    if (idx == -1) return;
    final post = state.posts[idx];
    final newPosts = List<Post>.from(state.posts);
    newPosts[idx] = post.copyWith(commentCount: (post.commentCount + delta).clamp(0, 999999));
    state = state.copyWith(posts: newPosts);
  }

  Future<void> toggleSave(int postId) async {
    final idx = state.posts.indexWhere((p) => p.id == postId);
    if (idx == -1) return;

    final post = state.posts[idx];
    final newSaved = !post.savedByMe;

    // Optimistic update
    final updated = post.copyWith(savedByMe: newSaved);
    final newPosts = List<Post>.from(state.posts);
    newPosts[idx] = updated;
    state = state.copyWith(posts: newPosts);

    // Track save event
    _trackFeedEvent(newSaved ? 'save' : 'unsave', postId: postId);

    try {
      await _repo.toggleSave(postId);
    } catch (_) {
      // Revert on error
      newPosts[idx] = post;
      state = state.copyWith(posts: List.from(newPosts));
    }
  }

  /// Create a repost of a post.
  Future<void> repost(int postId, {String? quoteBody}) async {
    final idx = state.posts.indexWhere((p) => p.id == postId);

    try {
      await _repo.createRepost(postId, quoteBody: quoteBody);

      // Update repost count optimistically
      if (idx != -1) {
        final post = state.posts[idx];
        final newPosts = List<Post>.from(state.posts);
        newPosts[idx] = post.copyWith(repostCount: post.repostCount + 1);
        state = state.copyWith(posts: newPosts);
      }

      // Track repost event
      _trackFeedEvent('repost', postId: postId);
    } catch (e) {
      debugPrint('[FeedNotifier] Repost error: $e');
      rethrow;
    }
  }

  void addPost(Post post) {
    state = state.copyWith(posts: [post, ...state.posts]);
  }

  // ═══════════════════════════════════════════════════
  //  FEED EVENTS (Analytics)
  // ═══════════════════════════════════════════════════

  /// Track a feed event (fire-and-forget, non-blocking).
  void _trackFeedEvent(
    String eventType, {
    int? postId,
    Map<String, dynamic>? properties,
  }) {
    final userId = _currentUserId;
    if (userId == null) return;

    // Fire and forget — don't await
    _insertFeedEvent(userId, eventType, postId, properties);
  }

  String? get _currentUserId =>
      Supabase.instance.client.auth.currentUser?.id;

  Future<void> _insertFeedEvent(
    String userId,
    String eventType,
    int? postId,
    Map<String, dynamic>? properties,
  ) async {
    try {
      await Supabase.instance.client.from('feed_events').insert({
        'user_id': userId,
        'event_type': eventType,
        if (postId != null) 'post_id': postId,
        'properties': properties ?? {},
      });
    } catch (e) {
      debugPrint('[FeedEvents] Error tracking $eventType: $e');
    }
  }

  /// Track that a post was viewed (impression). Called from UI.
  void trackPostImpression(int postId, {String? mediaType}) {
    _trackFeedEvent('post_impression', postId: postId, properties: {
      'media_type': mediaType ?? 'unknown',
      'mode': _mode.name,
      'community': _community,
    });
  }

  /// Track video playback start.
  void trackVideoPlay(int postId) {
    _trackFeedEvent('video_play', postId: postId);
  }

  /// Track video completion (watched >75%).
  void trackVideoComplete(int postId) {
    _trackFeedEvent('video_complete', postId: postId);
  }
}

final feedNotifierProvider =
    NotifierProvider<FeedNotifier, FeedState>(FeedNotifier.new);
