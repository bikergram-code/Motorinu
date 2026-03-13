import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/video_cache_service.dart';
import '../../../domain/models/post.dart';
import 'post_video_player.dart' show globalMuteNotifier;
import 'reaction_picker.dart';
import 'reel_video_player.dart';

/// A single fullscreen reel: video + overlays (like, comment, save, user info).
class ReelCard extends StatefulWidget {
  const ReelCard({
    super.key,
    required this.post,
    required this.isActive,
    required this.accentColor,
    required this.onLike,
    required this.onSave,
    required this.onComment,
    this.onReaction,
  });

  final Post post;
  final bool isActive;
  final Color accentColor;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final VoidCallback onComment;
  final void Function(String? reactionType)? onReaction;

  @override
  State<ReelCard> createState() => _ReelCardState();
}

class _ReelCardState extends State<ReelCard> {
  double _progress = 0;
  bool _showHeartAnimation = false;
  bool _captionExpanded = false;

  void _onDoubleTap() {
    if (!widget.post.likedByMe) {
      widget.onLike();
    }
    setState(() => _showHeartAnimation = true);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showHeartAnimation = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Video player
        ReelVideoPlayer(
          videoUrl: post.videoUrl ?? '',
          isActive: widget.isActive,
          postId: post.id,
          thumbnailUrl: post.thumbnailUrl,
          onDoubleTap: _onDoubleTap,
          onProgressChanged: (p) {
            if (mounted) setState(() => _progress = p);
          },
        ),

        // Gradient overlay at bottom for readability
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 200,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.7),
                ],
              ),
            ),
          ),
        ),

        // Double-tap heart animation
        if (_showHeartAnimation)
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.5, end: 1.0),
              duration: const Duration(milliseconds: 400),
              curve: Curves.elasticOut,
              builder: (_, scale, __) => Transform.scale(
                scale: scale,
                child: Icon(Icons.favorite_rounded,
                    color: Colors.white.withValues(alpha: 0.9), size: 100),
              ),
            ),
          ),

        // Right side action buttons
        Positioned(
          right: 12,
          bottom: 100 + bottomPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Like (tap = like, long-press = reaction picker)
              _ReelLikeButton(
                post: post,
                accentColor: widget.accentColor,
                onLike: widget.onLike,
                onReaction: widget.onReaction,
                label: _formatCount(post.likeCount),
              ),
              const SizedBox(height: 20),
              // Comment — filled + accent color when comments exist
              _ActionButton(
                icon: post.commentCount > 0
                    ? Icons.chat_bubble_rounded
                    : Icons.chat_bubble_outline_rounded,
                label: _formatCount(post.commentCount),
                color: post.commentCount > 0
                    ? widget.accentColor
                    : Colors.white,
                onTap: widget.onComment,
              ),
              const SizedBox(height: 20),
              // Save
              _ActionButton(
                icon: post.savedByMe
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                label: 'Speichern',
                color: post.savedByMe ? widget.accentColor : Colors.white,
                onTap: widget.onSave,
              ),
              const SizedBox(height: 20),
              // Mute toggle
              ValueListenableBuilder<bool>(
                valueListenable: globalMuteNotifier,
                builder: (_, isMuted, __) => _ActionButton(
                  icon: isMuted
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  label: isMuted ? 'Stumm' : 'Ton',
                  color: Colors.white,
                  onTap: () =>
                      globalMuteNotifier.value = !globalMuteNotifier.value,
                ),
              ),
            ],
          ),
        ),

        // Bottom left: user info + caption
        Positioned(
          left: 14,
          right: 72,
          bottom: 24 + bottomPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Username row
              GestureDetector(
                onTap: () =>
                    GoRouter.of(context).push('/profile/${post.userId}'),
                child: Row(
                  children: [
                    // Avatar
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      backgroundImage: post.avatarUrl != null &&
                              post.avatarUrl!.isNotEmpty
                          ? NetworkImage(post.avatarUrl!)
                          : null,
                      child: post.avatarUrl == null || post.avatarUrl!.isEmpty
                          ? Text(
                              (post.username.isNotEmpty
                                      ? post.username[0]
                                      : '?')
                                  .toUpperCase(),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600),
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      post.displayName ?? post.username,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        shadows: [
                          Shadow(
                            blurRadius: 4,
                            color: Colors.black.withValues(alpha: 0.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Caption
              if (post.body != null && post.body!.isNotEmpty) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () =>
                      setState(() => _captionExpanded = !_captionExpanded),
                  child: Text(
                    post.body!,
                    maxLines: _captionExpanded ? 10 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                      height: 1.3,
                      shadows: [
                        Shadow(
                          blurRadius: 4,
                          color: Colors.black.withValues(alpha: 0.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Progress bar at very bottom
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SizedBox(
            height: 2,
            child: LinearProgressIndicator(
              value: _progress,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(widget.accentColor),
            ),
          ),
        ),
      ],
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}

/// Like button for reels with reaction picker support (long-press).
class _ReelLikeButton extends StatelessWidget {
  const _ReelLikeButton({
    required this.post,
    required this.accentColor,
    required this.onLike,
    this.onReaction,
    required this.label,
  });

  final Post post;
  final Color accentColor;
  final VoidCallback onLike;
  final void Function(String? reactionType)? onReaction;
  final String label;

  @override
  Widget build(BuildContext context) {
    final hasReaction = post.likedByMe && post.myReaction != null;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onLike();
      },
      onLongPressStart: onReaction != null
          ? (details) {
              HapticFeedback.mediumImpact();
              ReactionPicker.show(
                context,
                anchorPosition: details.globalPosition,
                accentColor: accentColor,
                currentReaction: post.myReaction,
                onSelected: (type) => onReaction!(type),
              );
            }
          : null,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          hasReaction
              ? Text(
                  reactionEmoji(post.myReaction),
                  style: const TextStyle(
                    fontSize: 26,
                    shadows: [
                      Shadow(blurRadius: 6, color: Colors.black54),
                    ],
                  ),
                )
              : Icon(
                  post.likedByMe
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: post.likedByMe ? Colors.red : Colors.white,
                  size: 28,
                  shadows: [
                    Shadow(
                      blurRadius: 6,
                      color: Colors.black.withValues(alpha: 0.5),
                    ),
                  ],
                ),
          const SizedBox(height: 3),
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              shadows: [
                Shadow(
                  blurRadius: 4,
                  color: Colors.black.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Small action button for the right sidebar (comment, save, mute).
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 28,
              shadows: [
                Shadow(
                  blurRadius: 6,
                  color: Colors.black.withValues(alpha: 0.5),
                ),
              ]),
          const SizedBox(height: 3),
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              shadows: [
                Shadow(
                  blurRadius: 4,
                  color: Colors.black.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Vertical PageView that hosts multiple [ReelCard] widgets.
/// Manages which reel is currently active for play/pause control.
class ReelsPageView extends StatefulWidget {
  const ReelsPageView({
    super.key,
    required this.reels,
    required this.accentColor,
    required this.onLoadMore,
    required this.onLike,
    required this.onSave,
    required this.onComment,
    this.onReaction,
  });

  final List<Post> reels;
  final Color accentColor;
  final VoidCallback onLoadMore;
  final void Function(int postId) onLike;
  final void Function(int postId) onSave;
  final void Function(int postId, String userId) onComment;
  final void Function(int postId, String? reactionType)? onReaction;

  @override
  State<ReelsPageView> createState() => _ReelsPageViewState();
}

class _ReelsPageViewState extends State<ReelsPageView> {
  int _currentIndex = 0;

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    // Load more when near the end
    if (index >= widget.reels.length - 3) {
      widget.onLoadMore();
    }

    // Prefetch next 2 reels' videos for instant switching
    final prefetchUrls = <String>[];
    for (int i = 1; i <= 2; i++) {
      final nextIdx = index + i;
      if (nextIdx < widget.reels.length) {
        final url = widget.reels[nextIdx].videoUrl;
        if (url != null && url.isNotEmpty) prefetchUrls.add(url);
      }
    }
    if (prefetchUrls.isNotEmpty) {
      VideoCacheService.instance.prefetchList(prefetchUrls);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // On tablets (width > 600), constrain reels to phone-like aspect ratio
    final isTablet = screenWidth > 600;
    final reelMaxWidth = isTablet ? 640.0 : screenWidth;

    return Container(
      color: Colors.black,
      child: Center(
        child: SizedBox(
          width: reelMaxWidth,
          child: PageView.builder(
            scrollDirection: Axis.vertical,
            itemCount: widget.reels.length,
            onPageChanged: _onPageChanged,
            allowImplicitScrolling: true, // Preload adjacent reels for fast switching
            itemBuilder: (context, index) {
              final post = widget.reels[index];
              return ClipRect(
                child: ReelCard(
                  key: ValueKey(post.id),
                  post: post,
                  isActive: index == _currentIndex,
                  accentColor: widget.accentColor,
                  onLike: () => widget.onLike(post.id),
                  onSave: () => widget.onSave(post.id),
                  onComment: () => widget.onComment(post.id, post.userId),
                  onReaction: widget.onReaction != null
                      ? (type) => widget.onReaction!(post.id, type)
                      : null,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
