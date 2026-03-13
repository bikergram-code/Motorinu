import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../../domain/models/post.dart';
import 'comments_sheet.dart';
import 'double_tap_like_overlay.dart';
import 'repost_sheet.dart';

/// Full-screen image viewer with pinch-to-zoom, swipe-to-dismiss,
/// and full interaction bar (like, comment, repost, share, save).
class FullscreenImageViewer extends StatefulWidget {
  const FullscreenImageViewer({
    super.key,
    required this.imageUrls,
    required this.post,
    required this.accentColor,
    required this.onLike,
    required this.onSave,
    this.initialIndex = 0,
    this.communityName,
  });

  final List<String> imageUrls;
  final Post post;
  final Color accentColor;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final int initialIndex;
  final String? communityName;

  /// Open the fullscreen viewer as a modal route.
  static void show(
    BuildContext context, {
    required List<String> imageUrls,
    required Post post,
    required Color accentColor,
    required VoidCallback onLike,
    required VoidCallback onSave,
    int initialIndex = 0,
    String? communityName,
  }) {
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.95),
        barrierDismissible: false,
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: FullscreenImageViewer(
            imageUrls: imageUrls,
            post: post,
            accentColor: accentColor,
            onLike: onLike,
            onSave: onSave,
            initialIndex: initialIndex,
            communityName: communityName,
          ),
        ),
      ),
    );
  }

  @override
  State<FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<FullscreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;
  bool _showUI = true;

  // Swipe-to-dismiss state
  double _dragOffset = 0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    // Immersive mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _pageController.dispose();
    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggleUI() {
    setState(() => _showUI = !_showUI);
  }

  void _onVerticalDragStart(DragStartDetails details) {
    setState(() => _isDragging = true);
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    setState(() => _dragOffset += details.delta.dy);
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_dragOffset.abs() > 100 || details.velocity.pixelsPerSecond.dy.abs() > 800) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _dragOffset = 0;
        _isDragging = false;
      });
    }
  }

  void _handleLike() {
    HapticFeedback.lightImpact();
    widget.onLike();
  }

  void _handleComment() {
    CommentsSheet.show(
      context,
      widget.post.id,
      postUserId: widget.post.userId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCarousel = widget.imageUrls.length > 1;
    final post = widget.post;

    // Calculate dismiss progress (0.0 = resting, 1.0 = fully dismissed)
    final dismissProgress = (_dragOffset.abs() / 300).clamp(0.0, 1.0);
    final scale = 1.0 - (dismissProgress * 0.2);
    final bgOpacity = 1.0 - (dismissProgress * 0.6);

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: bgOpacity),
      body: GestureDetector(
        onVerticalDragStart: _onVerticalDragStart,
        onVerticalDragUpdate: _onVerticalDragUpdate,
        onVerticalDragEnd: _onVerticalDragEnd,
        child: AnimatedContainer(
          duration: _isDragging ? Duration.zero : const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          transform: Matrix4.identity()
            ..translate(0.0, _dragOffset)
            ..scale(scale),
          child: Stack(
        children: [
          // ── Image(s) with pinch-to-zoom ──
          GestureDetector(
            onTap: _toggleUI,
            child: isCarousel
                ? PageView.builder(
                    controller: _pageController,
                    itemCount: widget.imageUrls.length,
                    onPageChanged: (i) => setState(() => _currentIndex = i),
                    itemBuilder: (_, index) => _buildZoomableImage(
                      widget.imageUrls[index],
                    ),
                  )
                : _buildZoomableImage(widget.imageUrls.first),
          ),

          // ── Top bar (close, counter) ──
          if (_showUI)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      // Close button
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.5),
                          ),
                          child: const Icon(Icons.close_rounded,
                              color: Colors.white, size: 22),
                        ),
                      ),
                      const Spacer(),
                      // Page counter (carousel only)
                      if (isCarousel)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            '${_currentIndex + 1}/${widget.imageUrls.length}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Bottom bar (interactions + user info) ──
          if (_showUI)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.85),
                      Colors.black.withValues(alpha: 0.5),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 30, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // User info
                        Row(
                          children: [
                            // Avatar
                            ClipOval(
                              child: post.avatarUrl != null &&
                                      post.avatarUrl!.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: post.avatarUrl!,
                                      width: 32,
                                      height: 32,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      width: 32,
                                      height: 32,
                                      color: widget.accentColor,
                                      child: Center(
                                        child: Text(
                                          (post.username.isNotEmpty
                                                  ? post.username[0]
                                                  : '?')
                                              .toUpperCase(),
                                          style: GoogleFonts.inter(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    post.displayName ?? post.username,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (post.body != null &&
                                      post.body!.isNotEmpty)
                                    Text(
                                      post.body!,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: Colors.white
                                            .withValues(alpha: 0.7),
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // ── Action bar ──
                        Row(
                          children: [
                            // Like
                            _FullscreenAction(
                              icon: post.likedByMe
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: post.likedByMe
                                  ? Colors.red
                                  : Colors.white,
                              label: post.likeCount > 0
                                  ? '${post.likeCount}'
                                  : null,
                              onTap: _handleLike,
                            ),
                            const SizedBox(width: 20),
                            // Comment
                            _FullscreenAction(
                              icon: Icons.chat_bubble_outline_rounded,
                              color: Colors.white,
                              label: post.commentCount > 0
                                  ? '${post.commentCount}'
                                  : null,
                              onTap: _handleComment,
                            ),
                            const SizedBox(width: 20),
                            // Repost
                            _FullscreenAction(
                              icon: Icons.repeat_rounded,
                              color: Colors.white,
                              label: post.repostCount > 0
                                  ? '${post.repostCount}'
                                  : null,
                              onTap: () =>
                                  RepostSheet.show(context, post),
                            ),
                            const SizedBox(width: 20),
                            // Share
                            _FullscreenAction(
                              icon: Icons.send_rounded,
                              color: Colors.white,
                              onTap: () {
                                final name =
                                    widget.communityName ?? 'Motorgram';
                                final buffer = StringBuffer();
                                buffer.writeln(
                                    '${post.displayName ?? post.username} auf $name:');
                                if (post.body != null &&
                                    post.body!.isNotEmpty) {
                                  buffer.writeln(post.body);
                                }
                                buffer.writeln(
                                    widget.imageUrls[_currentIndex]);
                                Share.share(buffer.toString());
                              },
                              rotationAngle: -0.5,
                            ),
                            const Spacer(),
                            // Bookmark
                            _FullscreenAction(
                              icon: post.savedByMe
                                  ? Icons.bookmark_rounded
                                  : Icons.bookmark_border_rounded,
                              color: post.savedByMe
                                  ? widget.accentColor
                                  : Colors.white,
                              onTap: widget.onSave,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ── Dot indicators (carousel) ──
          if (_showUI && isCarousel && widget.imageUrls.length <= 10)
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context).padding.bottom + 120,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      widget.imageUrls.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 2.5),
                        width: i == _currentIndex ? 8 : 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: i == _currentIndex
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
        ),
      ),
    );
  }

  Widget _buildZoomableImage(String url) {
    return InteractiveViewer(
      minScale: 1.0,
      maxScale: 5.0,
      child: Center(
        child: DoubleTapLikeOverlay(
          onDoubleTap: _handleLike,
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.contain,
            width: double.infinity,
            placeholder: (_, __) => const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            errorWidget: (_, __, ___) => Center(
              child: Icon(
                Icons.broken_image_rounded,
                color: Colors.white.withValues(alpha: 0.3),
                size: 48,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Single action button for the fullscreen viewer.
class _FullscreenAction extends StatelessWidget {
  const _FullscreenAction({
    required this.icon,
    required this.color,
    required this.onTap,
    this.label,
    this.rotationAngle = 0,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? label;
  final double rotationAngle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          rotationAngle != 0
              ? Transform.rotate(
                  angle: rotationAngle,
                  child: Icon(icon, size: 26, color: color),
                )
              : Icon(icon, size: 26, color: color),
          if (label != null) ...[
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
        ],
      ),
    );
  }
}
