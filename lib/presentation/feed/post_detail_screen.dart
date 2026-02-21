import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/community.dart';
import '../../data/repositories/feed_repository.dart';
import '../../domain/models/post.dart';
import '../../providers/core/providers.dart';
import '../../providers/feed/feed_notifier.dart';
import '../../theme/app_theme.dart';
import 'widgets/comments_sheet.dart';

/// Screen that shows a single post in detail.
/// Navigated to from notification taps (like, comment).
class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({super.key, required this.postId});
  final int postId;

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  Post? _post;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPost();
  }

  Future<void> _loadPost() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = FeedRepository();
      final post = await repo.getPostById(widget.postId);
      if (!mounted) return;
      setState(() {
        _post = post;
        _isLoading = false;
        if (post == null) _error = 'Post nicht gefunden';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Fehler beim Laden: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final community = ref.watch(communityProvider);
    final brightness = Theme.of(context).brightness;
    final accentColor = community?.accentColor ?? AppTheme.accentDark;
    final cardColor = community?.cardFor(brightness) ?? (brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white);

    return Scaffold(
      backgroundColor: community?.scaffoldFor(brightness) ?? (brightness == Brightness.dark ? Colors.black : const Color(0xFFF5F5F5)),
      appBar: AppBar(
        backgroundColor: community?.scaffoldFor(brightness) ?? (brightness == Brightness.dark ? Colors.black : const Color(0xFFF5F5F5)),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back_rounded, color: brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A)),
        ),
        title: Text(
          'Beitrag',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A),
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: _buildBody(accentColor, cardColor),
    );
  }

  Widget _buildBody(Color accentColor, Color cardColor) {
    final brightness = Theme.of(context).brightness;
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                color: Colors.white.withValues(alpha: 0.3), size: 48),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF6C757D),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _loadPost,
              child: Text(
                'Erneut versuchen',
                style: GoogleFonts.inter(
                  color: accentColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final post = _post!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.04),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with avatar and name
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: GestureDetector(
                onTap: () => context.push('/profile/${post.userId}'),
                child: Row(
                  children: [
                    _buildAvatar(post, accentColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.displayName ?? post.username,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A),
                            ),
                          ),
                          if (post.createdAt != null)
                            Text(
                              _timeAgo(post.createdAt!),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.35) : const Color(0xFF6C757D),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Body text — no maxLines limit in detail view
            if (post.body != null && post.body!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Text(
                  post.body!,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF1A1A1A),
                    height: 1.5,
                  ),
                ),
              ),

            // Image
            if (post.imageUrl != null && post.imageUrl!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    post.imageUrl!,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 200,
                      color: Colors.white.withValues(alpha: 0.05),
                      child: Center(
                        child: Icon(Icons.image_outlined,
                            size: 40,
                            color: Colors.white.withValues(alpha: 0.15)),
                      ),
                    ),
                  ),
                ),
              ),

            // Actions row
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
              child: Row(
                children: [
                  // Like
                  _ActionChip(
                    icon: post.likedByMe
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    label: post.likeCount > 0 ? '${post.likeCount}' : null,
                    color: post.likedByMe ? Colors.red : null,
                    onTap: () => _toggleLike(post),
                  ),
                  const SizedBox(width: 4),
                  // Comment
                  _ActionChip(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: post.commentCount > 0
                        ? '${post.commentCount}'
                        : null,
                    onTap: () => _openComments(post),
                  ),
                  const SizedBox(width: 4),
                  // Share
                  _ActionChip(
                    icon: Icons.share_outlined,
                    onTap: () => _sharePost(post),
                  ),
                  const Spacer(),
                  // Bookmark
                  _ActionChip(
                    icon: post.savedByMe
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    color: post.savedByMe ? accentColor : null,
                    onTap: () => _toggleSave(post),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(Post post, Color accentColor) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: post.avatarUrl == null
            ? LinearGradient(
                colors: [accentColor, accentColor.withValues(alpha: 0.6)])
            : null,
      ),
      child: ClipOval(
        child: post.avatarUrl != null && post.avatarUrl!.isNotEmpty
            ? Image.network(
                post.avatarUrl!,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _avatarFallback(post, accentColor),
              )
            : _avatarFallback(post, accentColor),
      ),
    );
  }

  Widget _avatarFallback(Post post, Color accentColor) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accentColor, accentColor.withValues(alpha: 0.6)],
        ),
      ),
      child: Center(
        child: Text(
          (post.username.isNotEmpty ? post.username[0] : '?').toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  void _toggleLike(Post post) {
    HapticFeedback.lightImpact();
    ref.read(feedNotifierProvider.notifier).toggleLike(post.id);
    // Reload to get fresh state
    Future.delayed(const Duration(milliseconds: 500), _loadPost);
  }

  void _toggleSave(Post post) {
    HapticFeedback.lightImpact();
    ref.read(feedNotifierProvider.notifier).toggleSave(post.id);
    Future.delayed(const Duration(milliseconds: 500), _loadPost);
  }

  void _sharePost(Post post) {
    final community = ref.read(communityProvider);
    final name = community?.displayName ?? 'Motorgram';
    final text = post.body != null && post.body!.isNotEmpty
        ? '${post.body!.length > 100 ? '${post.body!.substring(0, 100)}...' : post.body!}\n\nSchau dir diesen Beitrag auf $name an!'
        : 'Schau dir diesen Beitrag auf $name an!';
    Share.share(text);
  }

  void _openComments(Post post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, controller) => CommentsSheet(
          postId: post.id,
          postUserId: post.userId,
        ),
      ),
    );
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Gerade eben';
    if (diff.inMinutes < 60) return 'vor ${diff.inMinutes} Min';
    if (diff.inHours < 24) {
      return diff.inHours == 1 ? 'vor 1 Std' : 'vor ${diff.inHours} Std';
    }
    if (diff.inDays == 1) return 'Gestern';
    if (diff.inDays < 7) return 'vor ${diff.inDays} Tagen';
    return '${time.day}.${time.month}.${time.year}';
  }
}

// ── Small action chip for like/comment/save ────────────────────────────
class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    this.label,
    this.color,
    required this.onTap,
  });

  final IconData icon;
  final String? label;
  final Color? color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final defaultColor = brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.55) : const Color(0xFF6C757D);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 22,
                color: color ?? defaultColor),
            if (label != null) ...[
              const SizedBox(width: 5),
              Text(
                label!,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: color ?? defaultColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
