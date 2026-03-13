import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/community.dart';
import '../../data/repositories/feed_repository.dart';
import '../../domain/models/post.dart';
import '../../providers/core/providers.dart';
import '../../providers/feed/feed_notifier.dart';
import '../../theme/app_theme.dart';
import '../feed/widgets/comments_sheet.dart';
import '../feed/widgets/post_card.dart';

/// Screen that shows all posts the current user has saved/bookmarked.
class SavedPostsScreen extends ConsumerStatefulWidget {
  const SavedPostsScreen({super.key});

  @override
  ConsumerState<SavedPostsScreen> createState() => _SavedPostsScreenState();
}

class _SavedPostsScreenState extends ConsumerState<SavedPostsScreen> {
  final _scrollController = ScrollController();
  List<Post> _posts = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _loadSavedPosts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadSavedPosts() async {
    setState(() {
      _isLoading = true;
      _page = 1;
    });

    try {
      final repo = ref.read(feedRepositoryProvider);
      final result = await repo.getSavedPosts(page: 1);
      if (!mounted) return;
      setState(() {
        _posts = result.posts;
        _hasMore = result.hasMore;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[SavedPosts] Load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    try {
      final repo = ref.read(feedRepositoryProvider);
      final nextPage = _page + 1;
      final result = await repo.getSavedPosts(page: nextPage);
      if (!mounted) return;
      setState(() {
        _posts = [..._posts, ...result.posts];
        _hasMore = result.hasMore;
        _page = nextPage;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _handleUnsave(int postId) async {
    try {
      final repo = ref.read(feedRepositoryProvider);
      await repo.toggleSave(postId);
      if (!mounted) return;
      setState(() {
        _posts = _posts.where((p) => p.id != postId).toList();
      });
      // Also update feed state if the post is in the feed
      ref.read(feedNotifierProvider.notifier).toggleSave(postId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final community = ref.watch(communityProvider);
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final accentColor = community?.accentColor ?? AppTheme.accentDark;

    return Scaffold(
      backgroundColor: community?.scaffoldFor(brightness) ??
          (isDark ? Colors.black : const Color(0xFFF5F5F5)),
      appBar: AppBar(
        backgroundColor: community?.scaffoldFor(brightness) ??
            (isDark ? Colors.black : const Color(0xFFF5F5F5)),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back_rounded,
              color: community?.textColor(brightness) ??
                  (isDark ? Colors.white : const Color(0xFF1A1A1A))),
        ),
        title: Text(
          'Gespeicherte Beitr\u00e4ge',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: community?.textColor(brightness) ??
                (isDark ? Colors.white : const Color(0xFF1A1A1A)),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : _posts.isEmpty
              ? _buildEmptyState(accentColor, isDark)
              : RefreshIndicator(
                  color: accentColor,
                  onRefresh: _loadSavedPosts,
                  child: ListView.builder(
                    controller: _scrollController,
                    physics: const ClampingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    cacheExtent: 800,
                    padding: EdgeInsets.zero,
                    itemCount: _posts.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _posts.length) {
                        return Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: accentColor,
                              ),
                            ),
                          ),
                        );
                      }

                      final post = _posts[index];
                      return PostCard(
                        key: ValueKey(post.id),
                        post: post,
                        accentColor: accentColor,
                        communityName: community?.name,
                        onLike: () => _handleLike(post.id),
                        onSave: () => _handleUnsave(post.id),
                        onComment: () => CommentsSheet.show(
                          context,
                          post.id,
                          postUserId: post.userId,
                        ),
                        onEdit: () {},
                        onDelete: () {},
                      );
                    },
                  ),
                ),
    );
  }

  void _handleLike(int postId) async {
    final lockSecs = await ref.read(feedNotifierProvider.notifier).toggleLike(postId);
    if (lockSecs != null && mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bitte warte $lockSecs Sekunden bevor du erneut likest'),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }
    // Update local state
    final idx = _posts.indexWhere((p) => p.id == postId);
    if (idx != -1) {
      final post = _posts[idx];
      setState(() {
        _posts[idx] = post.copyWith(
          likedByMe: !post.likedByMe,
          likeCount: post.likeCount + (post.likedByMe ? -1 : 1),
        );
      });
    }
  }

  Widget _buildEmptyState(Color accentColor, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bookmark_border_rounded,
            size: 64,
            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.15),
          ),
          const SizedBox(height: 16),
          Text(
            'Keine gespeicherten Beitr\u00e4ge',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.5)
                  : const Color(0xFF6C757D),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tippe auf das Lesezeichen-Icon, um Beitr\u00e4ge zu speichern',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.3)
                  : const Color(0xFF6C757D),
            ),
          ),
        ],
      ),
    );
  }
}
