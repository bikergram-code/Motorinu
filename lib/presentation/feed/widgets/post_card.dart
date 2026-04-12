import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/repositories/message_repository.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../domain/models/post.dart';
import '../../widgets/online_status_avatar.dart';
import 'double_tap_like_overlay.dart';
import 'fullscreen_image_viewer.dart';
import 'likers_sheet.dart';
import 'post_carousel_viewer.dart';
import 'post_video_player.dart';
import 'reaction_picker.dart';
import 'report_sheet.dart';
import 'repost_sheet.dart';
import 'user_moderation_sheet.dart';
import '../../marketplace/widgets/create_listing_sheet.dart';

/// Data class for comment previews displayed below posts.
class CommentPreview {
  const CommentPreview({required this.username, required this.body});
  final String username;
  final String body;
}

/// Instagram-style post card for the feed.
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.accentColor,
    required this.onLike,
    required this.onSave,
    required this.onComment,
    required this.onEdit,
    required this.onDelete,
    this.communityName,
    this.commentPreviews = const [],
    this.onVideoPlay,
    this.onVideoComplete,
    this.onReaction,
  });

  final Post post;
  final Color accentColor;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final VoidCallback onComment;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String? communityName;
  final List<CommentPreview> commentPreviews;
  final VoidCallback? onVideoPlay;
  final VoidCallback? onVideoComplete;
  /// Called with reaction type when user selects a reaction via long-press.
  final void Function(String? reactionType)? onReaction;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final mutedColor = isDark
        ? Colors.white.withValues(alpha: 0.45)
        : const Color(0xFF495057);

    return Container(
      color: isDark ? Colors.black : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── A) Header ──
          _buildHeader(context, textColor, mutedColor, isDark),

          // ── B) Media (edge-to-edge) ──
          _buildMedia(context),

          // ── C) Action Bar ──
          _buildActionBar(context, mutedColor),

          // ── D) Like Count (tappable → shows who liked) ──
          if (post.likeCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: GestureDetector(
                onTap: () => LikersSheet.show(context, post.id, accentColor: accentColor),
                child: Text(
                  post.likeCount == 1
                      ? 'Gef\u00e4llt 1 Person'
                      : 'Gef\u00e4llt ${post.likeCount} Personen',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
              ),
            ),

          // ── E) Caption (username bold + text) ──
          if (post.body != null && post.body!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${post.displayName ?? post.username} ',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => GoRouter.of(context).push('/profile/${post.userId}'),
                    ),
                    TextSpan(
                      text: post.body!,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: textColor,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          // ── F) Comment Previews ──
          if (commentPreviews.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: commentPreviews.take(2).map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(
                        text: '${c.username} ',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      TextSpan(
                        text: c.body,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: textColor.withValues(alpha: 0.7),
                        ),
                      ),
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                )).toList(),
              ),
            ),

          // ── G) "Alle Kommentare ansehen" ──
          if (post.commentCount > 2)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: GestureDetector(
                onTap: onComment,
                child: Text(
                  'Alle ${post.commentCount} Kommentare ansehen',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: mutedColor,
                  ),
                ),
              ),
            )
          else if (post.commentCount > 0 && post.commentCount <= 2)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: GestureDetector(
                onTap: onComment,
                child: Text(
                  post.commentCount == 1
                      ? '1 Kommentar ansehen'
                      : '${post.commentCount} Kommentare ansehen',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: mutedColor,
                  ),
                ),
              ),
            ),

          // ── H) Timestamp ──
          if (post.createdAt != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
              child: Text(
                _timeAgo(post.createdAt!),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: mutedColor,
                  letterSpacing: 0.2,
                ),
              ),
            )
          else
            const SizedBox(height: 14),

          // Divider between posts
          Divider(
            height: 0.5,
            thickness: 0.5,
            color: isDark
                ? Colors.white.withValues(alpha: 0.09)
                : Colors.black.withValues(alpha: 0.08),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, Color textColor, Color mutedColor, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
      child: Row(
        children: [
          // Avatar — tappable
          GestureDetector(
            onTap: () => _showUserActions(context),
            child: OnlineStatusAvatar(
              userId: post.userId,
              avatarUrl: post.avatarUrl,
              size: 42,
              backgroundColor: isDark ? Colors.black : Colors.white,
              fallbackIcon: _buildAvatarFallback(textColor),
            ),
          ),
          const SizedBox(width: 12),

          // Username — tap goes directly to profile
          Expanded(
            child: GestureDetector(
              onTap: () => GoRouter.of(context).push('/profile/${post.userId}'),
              child: Text(
                post.displayName ?? post.username,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          // 3-dot menu
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'edit') onEdit();
              if (v == 'delete') onDelete();
              if (v == 'report_post') {
                ReportSheet.show(
                  context,
                  targetType: 'post',
                  targetId: post.id.toString(),
                  community: communityName,
                  accentColor: accentColor,
                );
              }
              if (v == 'moderation') {
                UserModerationSheet.show(
                  context,
                  userId: post.userId,
                  username: post.username,
                  community: communityName,
                  accentColor: accentColor,
                );
              }
            },
            icon: Icon(
              Icons.more_horiz_rounded,
              color: mutedColor,
              size: 22,
            ),
            color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            itemBuilder: (_) => [
              if (post.isMine) ...[
                PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    Icon(Icons.edit_rounded, size: 18, color: isDark ? Colors.white.withValues(alpha: 0.7) : Colors.black54),
                    const SizedBox(width: 10),
                    Text('Bearbeiten', style: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
                  ]),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                    const SizedBox(width: 10),
                    Text('L\u00f6schen', style: GoogleFonts.inter(fontSize: 14, color: Colors.red)),
                  ]),
                ),
              ] else ...[
                PopupMenuItem(
                  value: 'report_post',
                  child: Row(children: [
                    Icon(Icons.flag_outlined, size: 18, color: Colors.red.withValues(alpha: 0.8)),
                    const SizedBox(width: 10),
                    Text('Beitrag melden', style: GoogleFonts.inter(fontSize: 14, color: Colors.red.withValues(alpha: 0.8))),
                  ]),
                ),
                PopupMenuItem(
                  value: 'moderation',
                  child: Row(children: [
                    Icon(Icons.person_off_rounded, size: 18, color: Colors.orange.withValues(alpha: 0.8)),
                    const SizedBox(width: 10),
                    Text('Nutzer blockieren/muten', style: GoogleFonts.inter(fontSize: 14, color: Colors.orange.withValues(alpha: 0.8))),
                  ]),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarFallback(Color textColor) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [accentColor, accentColor.withValues(alpha: 0.6)],
        ),
      ),
      child: Center(
        child: Text(
          (post.username.isNotEmpty ? post.username[0] : '?').toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // ── Media ─────────────────────────────────────────────────────────────

  Widget _buildMedia(BuildContext context) {
    final hasVideo = post.videoUrl != null && post.videoUrl!.isNotEmpty;
    final hasImage = post.imageUrl != null && post.imageUrl!.isNotEmpty;
    final isCarousel = post.mediaType == 'carousel' && post.attachmentUrls.length > 1;

    if (!hasVideo && !hasImage && !isCarousel) return const SizedBox.shrink();

    // Carousel — swipeable multi-image (tap opens fullscreen)
    if (isCarousel) {
      return DoubleTapLikeOverlay(
        onDoubleTap: onLike,
        child: PostCarouselViewer(
          imageUrls: post.attachmentUrls,
          onDoubleTap: onLike,
          onTap: (index) => FullscreenImageViewer.show(
            context,
            imageUrls: post.attachmentUrls,
            post: post,
            accentColor: accentColor,
            onLike: onLike,
            onSave: onSave,
            initialIndex: index,
            communityName: communityName,
          ),
        ),
      );
    }

    if (hasVideo) {
      return DoubleTapLikeOverlay(
        onDoubleTap: onLike,
        child: PostVideoPlayer(
          videoUrl: post.videoUrl!,
          postId: post.id,
          thumbnailUrl: post.thumbnailUrl,
          onDoubleTap: onLike,
          onPlayStarted: onVideoPlay,
          onPlayCompleted: onVideoComplete,
        ),
      );
    }

    // Single image — edge-to-edge, natural aspect ratio (tap opens fullscreen)
    return GestureDetector(
      onTap: () => FullscreenImageViewer.show(
        context,
        imageUrls: [post.imageUrl!],
        post: post,
        accentColor: accentColor,
        onLike: onLike,
        onSave: onSave,
        communityName: communityName,
      ),
      child: DoubleTapLikeOverlay(
        onDoubleTap: onLike,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 500),
          child: CachedNetworkImage(
            imageUrl: post.imageUrl!,
            width: double.infinity,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              height: 300,
              color: Colors.white.withValues(alpha: 0.05),
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            errorWidget: (_, __, ___) => Container(
              height: 200,
              color: Colors.white.withValues(alpha: 0.05),
              child: Center(
                child: Icon(
                  Icons.image_outlined,
                  size: 40,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Action Bar (Instagram-style) ──────────────────────────────────────

  Widget _buildActionBar(BuildContext context, Color mutedColor) {
    // Determine like icon based on reaction type
    final hasReaction = post.likedByMe && post.myReaction != null;
    final likeIcon = post.likedByMe
        ? Icons.favorite_rounded
        : Icons.favorite_border_rounded;
    final likeColor = hasReaction
        ? reactionColor(post.myReaction)
        : (post.likedByMe ? Colors.red : mutedColor);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          // Like + Reaction (tap = like, long-press = reaction picker)
          _ReactionLikeButton(
            icon: likeIcon,
            color: likeColor,
            emoji: hasReaction ? reactionEmoji(post.myReaction) : null,
            onTap: onLike,
            onLongPress: onReaction != null
                ? (position) {
                    HapticFeedback.mediumImpact();
                    ReactionPicker.show(
                      context,
                      anchorPosition: position,
                      accentColor: accentColor,
                      currentReaction: post.myReaction,
                      onSelected: (type) => onReaction!(type),
                    );
                  }
                : null,
          ),
          const SizedBox(width: 16),

          // Comment — filled + accent color when there are comments
          _ActionIcon(
            icon: post.commentCount > 0
                ? Icons.chat_bubble_rounded
                : Icons.chat_bubble_outline_rounded,
            color: post.commentCount > 0 ? accentColor : mutedColor,
            onTap: onComment,
            label: post.commentCount > 0 ? '${post.commentCount}' : null,
          ),
          const SizedBox(width: 16),

          // Repost
          _ActionIcon(
            icon: Icons.repeat_rounded,
            color: mutedColor,
            onTap: () => RepostSheet.show(context, post),
          ),
          const SizedBox(width: 16),

          // Share (paper plane)
          _ActionIcon(
            icon: Icons.send_rounded,
            color: mutedColor,
            onTap: () => _sharePost(context),
            rotationAngle: -0.5, // Slight rotation like Instagram
          ),

          const Spacer(),

          // Bookmark — with bounce animation
          _AnimatedBookmark(
            saved: post.savedByMe,
            activeColor: accentColor,
            inactiveColor: mutedColor,
            onTap: onSave,
          ),
        ],
      ),
    );
  }

  // ── User Actions Bottom Sheet ─────────────────────────────────────────

  void _showUserActions(BuildContext context) {
    final displayName = post.displayName ?? post.username;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isOwnPost = currentUserId == post.userId;
    final name = communityName ?? 'Motorgram';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),

                // User info header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: post.avatarUrl == null
                              ? LinearGradient(
                                  colors: [accentColor, accentColor.withValues(alpha: 0.6)],
                                )
                              : null,
                        ),
                        child: ClipOval(
                          child: post.avatarUrl != null && post.avatarUrl!.isNotEmpty
                              ? Image.network(
                                  post.avatarUrl!,
                                  width: 48, height: 48,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Center(
                                    child: Text(
                                      displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                                      style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                                    ),
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                                    style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                            Text(
                              '@${post.username}',
                              style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withValues(alpha: 0.4)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
                const SizedBox(height: 8),

                // Actions
                _UserActionItem(
                  icon: Icons.person_outline_rounded,
                  label: isOwnPost ? 'Mein Profil' : 'Profil ansehen',
                  color: accentColor,
                  onTap: () {
                    Navigator.pop(ctx);
                    if (isOwnPost) {
                      GoRouter.of(context).go('/profile');
                    } else {
                      GoRouter.of(context).push('/profile/${post.userId}');
                    }
                  },
                ),
                if (!isOwnPost)
                  _UserActionItem(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Nachricht senden',
                    color: accentColor,
                    onTap: () async {
                      final navigator = GoRouter.of(context);
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(ctx);
                      try {
                        final repo = MessageRepository();
                        final convId = await repo.getOrCreateConversation(post.userId, community: communityName);
                        navigator.push('/messages/$convId');
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Fehler: $e'),
                            backgroundColor: Colors.red.shade800,
                          ),
                        );
                      }
                    },
                  ),
                _UserActionItem(
                  icon: Icons.location_on_outlined,
                  label: 'Standort',
                  color: accentColor,
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      final repo = ProfileRepository();
                      final profile = await repo.getProfile(post.userId);
                      final postalCode = profile['postal_code'] as String?;
                      if (context.mounted) {
                        if (postalCode != null && postalCode.isNotEmpty) {
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.transparent,
                            builder: (innerCtx) => SafeArea(
                              child: Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 20),
                                      width: 36, height: 4,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    Icon(Icons.location_on_rounded, color: accentColor, size: 40),
                                    const SizedBox(height: 12),
                                    Text(
                                      displayName,
                                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'PLZ: $postalCode',
                                      style: GoogleFonts.inter(fontSize: 16, color: Colors.white.withValues(alpha: 0.6)),
                                    ),
                                    const SizedBox(height: 20),
                                  ],
                                ),
                              ),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('$displayName hat keinen Standort angegeben'),
                              backgroundColor: const Color(0xFF2A2A2A),
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Standort konnte nicht geladen werden'),
                            backgroundColor: Colors.red.shade800,
                          ),
                        );
                      }
                    }
                  },
                ),
                if (isOwnPost)
                  _UserActionItem(
                    icon: Icons.storefront_rounded,
                    label: 'Als Artikel verkaufen',
                    color: accentColor,
                    onTap: () {
                      Navigator.pop(ctx);
                      CreateListingSheet.showFromPost(
                        context,
                        body: post.body,
                        imageUrl: post.imageUrl,
                        attachmentUrls: post.attachmentUrls,
                      );
                    },
                  ),
                if (!isOwnPost)
                  _UserActionItem(
                    icon: Icons.flag_outlined,
                    label: 'Melden',
                    color: Colors.red.withValues(alpha: 0.8),
                    onTap: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Nutzer wurde gemeldet'),
                          backgroundColor: Color(0xFF2A2A2A),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Share ──────────────────────────────────────────────────────────────

  void _sharePost(BuildContext context) {
    final name = communityName ?? 'Motorgram';
    final buffer = StringBuffer();
    buffer.writeln('${post.displayName ?? post.username} auf $name:');
    if (post.body != null && post.body!.isNotEmpty) {
      buffer.writeln(post.body);
    }
    if (post.imageUrl != null && post.imageUrl!.isNotEmpty) {
      buffer.writeln(post.imageUrl);
    }
    Share.share(buffer.toString());
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Gerade eben';
    if (diff.inMinutes < 60) return 'vor ${diff.inMinutes} Min';
    if (diff.inHours < 24) return 'vor ${diff.inHours} Std';
    if (diff.inDays < 7) return 'vor ${diff.inDays} Tagen';
    return '${date.day}.${date.month}.${date.year}';
  }
}

// ── Action Icon with haptic feedback ─────────────────────────────────────

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.color,
    required this.onTap,
    this.rotationAngle = 0,
    this.label,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double rotationAngle;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final iconWidget = rotationAngle != 0
        ? Transform.rotate(
            angle: rotationAngle,
            child: Icon(icon, size: 28, color: color),
          )
        : Icon(icon, size: 28, color: color);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: label != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  iconWidget,
                  const SizedBox(width: 4),
                  Text(
                    label!,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              )
            : iconWidget,
      ),
    );
  }
}

// ── Reaction Like Button with scale-pop animation ─────────────────────────

class _ReactionLikeButton extends StatefulWidget {
  const _ReactionLikeButton({
    required this.icon,
    required this.color,
    this.emoji,
    required this.onTap,
    this.onLongPress,
  });

  final IconData icon;
  final Color color;
  final String? emoji;
  final VoidCallback onTap;
  final void Function(Offset position)? onLongPress;

  @override
  State<_ReactionLikeButton> createState() => _ReactionLikeButtonState();
}

class _ReactionLikeButtonState extends State<_ReactionLikeButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 0.9), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    _controller.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      onLongPressStart: widget.onLongPress != null
          ? (details) => widget.onLongPress!(details.globalPosition)
          : null,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (_, child) => Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          ),
          child: widget.emoji != null
              ? Text(widget.emoji!, style: const TextStyle(fontSize: 26))
              : Icon(widget.icon, size: 28, color: widget.color),
        ),
      ),
    );
  }
}

// ── Animated Bookmark with bounce ──────────────────────────────────────────

class _AnimatedBookmark extends StatefulWidget {
  const _AnimatedBookmark({
    required this.saved,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  final bool saved;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  @override
  State<_AnimatedBookmark> createState() => _AnimatedBookmarkState();
}

class _AnimatedBookmarkState extends State<_AnimatedBookmark>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 0.85), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.85, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _AnimatedBookmark oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.saved != widget.saved) {
      _controller.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (_, child) => Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          ),
          child: Icon(
            widget.saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            size: 28,
            color: widget.saved ? widget.activeColor : widget.inactiveColor,
          ),
        ),
      ),
    );
  }
}

// ── User Action Item for Bottom Sheet ───────────────────────────────────

class _UserActionItem extends StatelessWidget {
  const _UserActionItem({
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: color.withValues(alpha: 0.12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.2),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
