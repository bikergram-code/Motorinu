import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/post.dart';
import '../../core/like_rate_limiter.dart';
import '../../core/video_cache_service.dart';
import '../../data/repositories/feed_repository.dart';
import '../auth/auth_notifier.dart';
import '../auth/auth_state.dart';
import '../core/providers.dart';

/// State for the Reels (video-only) feed.
class ReelsState {
  const ReelsState({
    this.reels = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.page = 1,
    this.error,
  });

  final List<Post> reels;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int page;
  final String? error;

  ReelsState copyWith({
    List<Post>? reels,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? page,
    String? error,
  }) {
    return ReelsState(
      reels: reels ?? this.reels,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      error: error,
    );
  }
}

class ReelsNotifier extends Notifier<ReelsState> {
  late FeedRepository _repo;
  String? _community;

  @override
  ReelsState build() {
    _repo = ref.watch(feedRepositoryProvider);
    _community = ref.watch(communityProvider)?.name ?? 'bikergram';
    return const ReelsState();
  }

  /// Load first page of reels.
  Future<void> loadReels() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _repo.getFollowingReelsFeed(page: 1, community: _community);
      state = ReelsState(
        reels: result.posts,
        hasMore: result.hasMore,
        page: 1,
      );

      // Prefetch first 3 reels for instant playback
      final urls = result.posts
          .take(3)
          .where((p) => p.videoUrl != null && p.videoUrl!.isNotEmpty)
          .map((p) => p.videoUrl!)
          .toList();
      if (urls.isNotEmpty) {
        VideoCacheService.instance.prefetchList(urls);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Load next page of reels.
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final nextPage = state.page + 1;
      final result = await _repo.getFollowingReelsFeed(
        page: nextPage,
        community: _community,
      );
      final allReels = [...state.reels, ...result.posts];
      state = state.copyWith(
        reels: allReels.length > 100 ? allReels.sublist(allReels.length - 100) : allReels,
        hasMore: result.hasMore,
        page: nextPage,
        isLoadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  /// Toggle a specific reaction on a reel (long-press on like).
  Future<void> toggleReaction(int postId, String? reactionType) async {
    final idx = state.reels.indexWhere((p) => p.id == postId);
    if (idx == -1) return;

    final post = state.reels[idx];
    final hadReaction = post.likedByMe || post.myReaction != null;
    final sameReaction = post.myReaction == reactionType;

    final bool newLiked;
    final String? newReaction;
    final int newCount;

    if (hadReaction && sameReaction) {
      newLiked = false;
      newReaction = null;
      newCount = post.likeCount - 1;
    } else if (hadReaction) {
      newLiked = true;
      newReaction = reactionType;
      newCount = post.likeCount;
    } else {
      newLiked = true;
      newReaction = reactionType;
      newCount = post.likeCount + 1;
    }

    final updated = post.copyWith(
      likedByMe: newLiked,
      myReaction: newReaction,
      likeCount: newCount.clamp(0, 999999),
    );
    final newReels = List<Post>.from(state.reels);
    newReels[idx] = updated;
    state = state.copyWith(reels: newReels);

    try {
      await _repo.toggleReaction(postId, reactionType: reactionType);
    } catch (_) {
      newReels[idx] = post;
      state = state.copyWith(reels: List.from(newReels));
    }
  }

  /// Optimistic like toggle with notification + Anti-Spam.
  /// Gibt die verbleibenden Sperr-Sekunden zurück, oder null wenn OK.
  Future<int?> toggleLike(int postId) async {
    // Anti-Spam: 3x hintereinander → 90s Sperre
    final lockSecs = LikeRateLimiter.instance.recordToggle(postId);
    if (lockSecs != null) return lockSecs;

    final idx = state.reels.indexWhere((p) => p.id == postId);
    if (idx == -1) return null;

    final post = state.reels[idx];
    final newLiked = !post.likedByMe;
    final newCount = post.likeCount + (newLiked ? 1 : -1);

    final updated = post.copyWith(likedByMe: newLiked, likeCount: newCount);
    final newReels = List<Post>.from(state.reels);
    newReels[idx] = updated;
    state = state.copyWith(reels: newReels);

    try {
      await _repo.toggleLike(postId);
      // Create notification when liking (not unliking, not own post)
      if (newLiked && post.userId.isNotEmpty) {
        final authState = ref.read(authNotifierProvider);
        final myId = authState is Authenticated ? authState.user.id : '';
        final myName = authState is Authenticated
            ? (authState.user.displayName ?? authState.user.username)
            : '';
        if (post.userId != myId) {
          final notifRepo = ref.read(notificationRepositoryProvider);
          notifRepo.createNotification(
            targetUserId: post.userId,
            type: 'like',
            title: '$myName hat dein Reel geliked',
            data: {'post_id': postId, 'actor_id': myId},
            community: _community,
          );
        }
      }
    } catch (_) {
      newReels[idx] = post;
      state = state.copyWith(reels: List.from(newReels));
    }
    return null;
  }

  /// Optimistic save toggle.
  Future<void> toggleSave(int postId) async {
    final idx = state.reels.indexWhere((p) => p.id == postId);
    if (idx == -1) return;

    final post = state.reels[idx];
    final newSaved = !post.savedByMe;

    final updated = post.copyWith(savedByMe: newSaved);
    final newReels = List<Post>.from(state.reels);
    newReels[idx] = updated;
    state = state.copyWith(reels: newReels);

    try {
      await _repo.toggleSave(postId);
    } catch (e) {
      debugPrint('[ReelsNotifier] toggleSave error: $e');
      newReels[idx] = post;
      state = state.copyWith(reels: List.from(newReels));
      rethrow;
    }
  }

  /// Update comment count for a reel after commenting.
  void updateCommentCount(int postId, int delta) {
    final idx = state.reels.indexWhere((p) => p.id == postId);
    if (idx == -1) return;
    final post = state.reels[idx];
    final newReels = List<Post>.from(state.reels);
    newReels[idx] = post.copyWith(
        commentCount: (post.commentCount + delta).clamp(0, 999999));
    state = state.copyWith(reels: newReels);
  }
}

final reelsNotifierProvider =
    NotifierProvider<ReelsNotifier, ReelsState>(ReelsNotifier.new);
