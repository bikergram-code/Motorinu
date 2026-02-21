import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/app_export.dart';
import '../../user_profile/user_profile.dart';

class PostCardWidget extends StatelessWidget {
  final Map<String, dynamic> post;
  final VoidCallback onLike;
  final bool likeBusy;
  final VoidCallback onComment;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final VoidCallback onOptions;
  final VoidCallback? onViewLikes;

  const PostCardWidget({
    super.key,
    required this.post,
    required this.onLike,
    required this.onComment,
    required this.onSave,
    required this.onShare,
    required this.onOptions,
    this.onViewLikes,
    this.likeBusy = false,
  });


  void _openProfilePage(BuildContext context, {bool openMe = false}) {
  final mine = post['isMine'] == true;

  // Own profile: open the full "Me" profile (loads /me.php), no preview card.
  if (openMe || mine) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const UserProfile()),
    );
    return;
  }

  final raw = post['userId'];
  final uid = raw is int ? raw : int.tryParse('${raw ?? ''}');
  if (uid == null) return;

  final username = (post['username'] ?? '').toString();
  final avatar = (post['userAvatar'] ?? '').toString();

  final preview = <String, dynamic>{
    'id': uid,
    'username': username,
    'displayName': username,
    'avatarUrl': avatar,
  };

  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => UserProfile(
        userId: uid,
        username: username.isEmpty ? null : username,
        avatarUrl: avatar.isEmpty ? null : avatar,
        preview: preview,
      ),
    ),
  );
}


  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return 'vor ${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return 'vor ${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return 'vor ${difference.inDays}d';
    } else {
      return 'vor ${(difference.inDays / 7).floor()}w';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLiked = post["isLiked"] as bool? ?? false;
    final isSaved = post["isSaved"] as bool? ?? false;
    final isMine = post["isMine"] == true;
    final isEdited = post["isEdited"] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
				InkWell(onTap: () => _openProfilePage(context, openMe: isMine), child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.secondary,
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: CustomImageWidget(
                      imageUrl: post["userAvatar"] as String? ?? "",
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                      semanticLabel:
                          post["userAvatarLabel"] as String? ?? "User avatar",
                    ),
                  ),
                ),),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
						child: InkWell(
				      onTap: () => _openProfilePage(context, openMe: isMine),
				      child: Text(
                              post["username"] as String? ?? "",
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                          ),
                          if (isMine) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                "Du",
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _formatTimestamp(
                                post["timestamp"] as DateTime? ?? DateTime.now(),
                              ),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isEdited)
                            Text(
                              " · bearbeitet",
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: CustomIconWidget(
                    iconName: 'more_vert',
                    color: theme.colorScheme.onSurface,
                    size: 24,
                  ),
                  onPressed: onOptions,
                  tooltip: 'Optionen',
                ),
              ],
            ),
          ),
          // ── Media: Image or Video ──
          _PostMediaSection(
            post: post,
            onDoubleTapLike: onLike,
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: CustomIconWidget(
                    iconName: isLiked ? 'favorite' : 'favorite_border',
                    color: isLiked
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurface,
                    size: 28,
                  ),
                  onPressed: likeBusy ? null : onLike,
                  tooltip: 'Gefällt mir',
                ),
                IconButton(
                  icon: CustomIconWidget(
                    iconName: 'chat_bubble_outline',
                    color: theme.colorScheme.onSurface,
                    size: 26,
                  ),
                  onPressed: onComment,
                  tooltip: 'Kommentieren',
                ),
                IconButton(
                  icon: CustomIconWidget(
                    iconName: 'share_outlined',
                    color: theme.colorScheme.onSurface,
                    size: 26,
                  ),
                  onPressed: onShare,
                  tooltip: 'Teilen',
                ),
                const Spacer(),
                IconButton(
                  icon: CustomIconWidget(
                    iconName: isSaved ? 'bookmark' : 'bookmark_border',
                    color: theme.colorScheme.onSurface,
                    size: 28,
                  ),
                  onPressed: onSave,
                  tooltip: 'Speichern',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: onViewLikes,
                  child: Text(
                    '${post["likes"]} Gefällt mir',
                    style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: theme.textTheme.bodyMedium,
                    children: [
                      TextSpan(
                        text: '${post["username"]} ',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      TextSpan(text: post["caption"] as String? ?? ""),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                if ((post["comments"] as int? ?? 0) > 0)
                  GestureDetector(
                    onTap: onComment,
                    child: Text(
                      'Alle ${post["comments"]} Kommentare ansehen',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Post Media Section (Image or Video) ──

class _PostMediaSection extends StatefulWidget {
  const _PostMediaSection({
    required this.post,
    required this.onDoubleTapLike,
  });

  final Map<String, dynamic> post;
  final VoidCallback onDoubleTapLike;

  @override
  State<_PostMediaSection> createState() => _PostMediaSectionState();
}

class _PostMediaSectionState extends State<_PostMediaSection> {
  VideoPlayerController? _videoController;
  bool _videoInitialized = false;
  bool _isPlaying = false;

  String get _videoUrl => (widget.post['postVideo'] ?? '').toString();
  String get _imageUrl => (widget.post['postImage'] ?? '').toString();
  bool get _hasVideo => _videoUrl.isNotEmpty;
  bool get _hasImage => _imageUrl.isNotEmpty;

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  void _initVideo() {
    if (_videoController != null) return;
    final uri = Uri.tryParse(_videoUrl);
    if (uri == null) return;

    _videoController = VideoPlayerController.networkUrl(uri)
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _videoInitialized = true);
        }
      })
      ..setLooping(true);
  }

  void _togglePlayPause() {
    if (_videoController == null) return;
    setState(() {
      if (_videoController!.value.isPlaying) {
        _videoController!.pause();
        _isPlaying = false;
      } else {
        _videoController!.play();
        _isPlaying = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hasVideo) {
      _initVideo();
      return GestureDetector(
        onDoubleTap: widget.onDoubleTapLike,
        onTap: _togglePlayPause,
        child: Container(
          constraints: const BoxConstraints(maxHeight: 400),
          color: Colors.black,
          width: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_videoInitialized && _videoController != null)
                AspectRatio(
                  aspectRatio: _videoController!.value.aspectRatio,
                  child: VideoPlayer(_videoController!),
                )
              else
                const SizedBox(
                  height: 250,
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),

              // Play/Pause overlay
              if (_videoInitialized && !_isPlaying)
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.5),
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 36),
                ),

              // Video badge
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.videocam_rounded,
                          color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text('Video',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_hasImage) {
      return GestureDetector(
        onDoubleTap: widget.onDoubleTapLike,
        child: CustomImageWidget(
          imageUrl: _imageUrl,
          width: double.infinity,
          height: 400,
          fit: BoxFit.cover,
          semanticLabel:
              widget.post["postImageLabel"] as String? ?? "Post image",
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

