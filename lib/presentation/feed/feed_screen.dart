import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/community.dart';
import '../../providers/core/providers.dart';
import '../../providers/feed/feed_notifier.dart';
import '../../providers/blitzer/navigation_provider.dart';
import '../../theme/app_theme.dart';
import 'widgets/story_bar.dart';
import 'widgets/create_post_sheet.dart';
import 'widgets/comments_sheet.dart';
import 'widgets/edit_post_sheet.dart';
import 'widgets/post_card.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  final _forYouScrollController = ScrollController();
  final _followingScrollController = ScrollController();
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // Load feed on first build
    Future.microtask(() {
      if (!mounted) return;
      ref.read(feedNotifierProvider.notifier).loadFeed();
    });
    _forYouScrollController.addListener(_onForYouScroll);
    _followingScrollController.addListener(_onFollowingScroll);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _forYouScrollController.dispose();
    _followingScrollController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
    final mode = page == 0 ? FeedMode.forYou : FeedMode.following;
    ref.read(feedModeProvider.notifier).setMode(mode);
    ref.read(feedNotifierProvider.notifier).loadFeed();
  }

  void _switchToPage(int page) {
    if (_currentPage == page) return;
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  void _onForYouScroll() {
    if (_forYouScrollController.position.pixels >=
        _forYouScrollController.position.maxScrollExtent - 200) {
      ref.read(feedNotifierProvider.notifier).loadMore();
    }
  }

  void _onFollowingScroll() {
    if (_followingScrollController.position.pixels >=
        _followingScrollController.position.maxScrollExtent - 200) {
      ref.read(feedNotifierProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final community = ref.watch(communityProvider);
    final brightness = Theme.of(context).brightness;
    final feedState = ref.watch(feedNotifierProvider);
    final accentColor = community?.accentColor ?? AppTheme.accentDark;
    final isDark = brightness == Brightness.dark;

    // Re-register Speed-Dial items every build
    final location = GoRouterState.of(context).matchedLocation;
    if (location == '/feed') {
      Future.microtask(() {
        if (!mounted) return;
        ref.read(speedDialItemsProvider.notifier).register([
          SpeedDialItem(
            icon: Icons.photo_library_rounded,
            label: 'Foto',
            color: accentColor,
            onTap: () { if (!mounted) return; CreatePostScreen.show(context, source: PostMediaSource.photo); },
          ),
          SpeedDialItem(
            icon: Icons.videocam_rounded,
            label: 'Video',
            color: const Color(0xFFE040FB),
            onTap: () { if (!mounted) return; CreatePostScreen.show(context, source: PostMediaSource.video); },
          ),
          SpeedDialItem(
            icon: Icons.camera_alt_rounded,
            label: 'Kamera',
            color: const Color(0xFF00E676),
            onTap: () { if (!mounted) return; CreatePostScreen.show(context, source: PostMediaSource.camera); },
          ),
          SpeedDialItem(
            icon: Icons.edit_note_rounded,
            label: 'Nur Text',
            color: Colors.deepPurple,
            onTap: () { if (!mounted) return; CreatePostScreen.show(context, source: PostMediaSource.textOnly); },
          ),
        ]);
      });
    }

    final scaffoldBg = community?.scaffoldFor(brightness) ??
        (isDark ? Colors.black : const Color(0xFFF5F5F5));

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Column(
        children: [
          // Spacer for global top bar
          SizedBox(height: MediaQuery.of(context).padding.top + 52),

          // Story bar
          const StoryBar(),

          // ── Swipeable tab indicator ──
          _buildTabIndicator(accentColor, brightness, isDark, community),

          Divider(
            height: 0.5,
            thickness: 0.5,
            color: community?.faintColor(brightness) ??
                Colors.white.withValues(alpha: 0.06),
          ),

          // ── PageView — swipeable feed ──
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              physics: const BouncingScrollPhysics(),
              children: [
                // Page 0: For You
                RefreshIndicator(
                  color: accentColor,
                  backgroundColor: community?.cardFor(brightness) ?? (isDark ? const Color(0xFF1A1A1A) : Colors.white),
                  onRefresh: () => ref.read(feedNotifierProvider.notifier).loadFeed(),
                  child: feedState.isLoading && feedState.posts.isEmpty
                      ? _buildLoadingState()
                      : feedState.posts.isEmpty
                          ? _buildEmptyState(accentColor, FeedMode.forYou)
                          : _buildPostList(feedState, accentColor, _forYouScrollController),
                ),
                // Page 1: Following
                RefreshIndicator(
                  color: accentColor,
                  backgroundColor: community?.cardFor(brightness) ?? (isDark ? const Color(0xFF1A1A1A) : Colors.white),
                  onRefresh: () => ref.read(feedNotifierProvider.notifier).loadFeed(),
                  child: feedState.isLoading && feedState.posts.isEmpty
                      ? _buildLoadingState()
                      : feedState.posts.isEmpty
                          ? _buildEmptyState(accentColor, FeedMode.following)
                          : _buildPostList(feedState, accentColor, _followingScrollController),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Minimal pill-style tab indicator — tap or swipe to switch.
  Widget _buildTabIndicator(Color accentColor, Brightness brightness, bool isDark, Community? community) {
    final mutedColor = community?.textMutedColor(brightness) ??
        (isDark ? Colors.white.withValues(alpha: 0.4) : const Color(0xFF9E9E9E));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildTabLabel(
            label: 'For You',
            isActive: _currentPage == 0,
            accentColor: accentColor,
            mutedColor: mutedColor,
            isDark: isDark,
            onTap: () => _switchToPage(0),
          ),
          const SizedBox(width: 28),
          _buildTabLabel(
            label: 'Following',
            isActive: _currentPage == 1,
            accentColor: accentColor,
            mutedColor: mutedColor,
            isDark: isDark,
            onTap: () => _switchToPage(1),
          ),
        ],
      ),
    );
  }

  Widget _buildTabLabel({
    required String label,
    required bool isActive,
    required Color accentColor,
    required Color mutedColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive
                    ? (isDark ? Colors.white : const Color(0xFF1A1A1A))
                    : mutedColor,
              ),
              child: Text(label),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isActive ? 24 : 0,
              height: 3,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: EdgeInsets.zero,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      itemCount: 5,
      itemBuilder: (_, __) => _buildShimmerCard(),
    );
  }

  Widget _buildShimmerCard() {
    final community = ref.read(communityProvider);
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    return Container(
      color: isDark ? Colors.black : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header shimmer
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 120, height: 14,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          // Media shimmer
          Container(
            width: double.infinity, height: 300,
            color: Colors.white.withValues(alpha: 0.03),
          ),
          // Actions shimmer
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              children: List.generate(3, (_) => Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              )),
            ),
          ),
          // Caption shimmer
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: Container(
              width: 200, height: 14,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Divider(height: 0.5, thickness: 0.5, color: Colors.white.withValues(alpha: 0.06)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Color accentColor, FeedMode mode) {
    final community = ref.read(communityProvider);
    final brightness = Theme.of(context).brightness;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            mode == FeedMode.following
                ? Icons.people_outline_rounded
                : Icons.explore_outlined,
            size: 64,
            color: Colors.white.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 16),
          Text(
            mode == FeedMode.following
                ? 'Noch keine Beiträge von Leuten, denen du folgst'
                : 'Noch keine Beiträge',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: community?.textMutedColor(brightness) ?? (brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF6C757D)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            mode == FeedMode.following
                ? 'Folge anderen, um ihren Content hier zu sehen!'
                : 'Erstelle den ersten Beitrag!',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: community?.textMutedColor(brightness) ?? (brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.3) : const Color(0xFF6C757D)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostList(FeedState feedState, Color accentColor, ScrollController scrollController) {
    return ListView.builder(
      controller: scrollController,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: EdgeInsets.zero,
      itemCount: feedState.posts.length + (feedState.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == feedState.posts.length) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: accentColor,
                ),
              ),
            ),
          );
        }

        final post = feedState.posts[index];

        // Build comment previews for this post
        final rawPreviews = feedState.commentPreviews[post.id] ?? [];
        final previews = rawPreviews
            .map((c) => CommentPreview(
                  username: c['username'] ?? 'user',
                  body: c['body'] ?? '',
                ))
            .toList();

        return PostCard(
          post: post,
          accentColor: accentColor,
          communityName: ref.read(communityProvider)?.name,
          commentPreviews: previews,
          onLike: () => ref.read(feedNotifierProvider.notifier).toggleLike(post.id),
          onSave: () => ref.read(feedNotifierProvider.notifier).toggleSave(post.id),
          onComment: () => CommentsSheet.show(context, post.id, postUserId: post.userId),
          onEdit: () => EditPostSheet.show(context, post),
          onVideoPlay: () => ref.read(feedNotifierProvider.notifier).trackVideoPlay(post.id),
          onVideoComplete: () => ref.read(feedNotifierProvider.notifier).trackVideoComplete(post.id),
          onDelete: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) {
                final dlgBrightness = Theme.of(ctx).brightness;
                return AlertDialog(
                  backgroundColor: ref.read(communityProvider)?.cardFor(dlgBrightness) ?? (dlgBrightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white),
                  title: Text('Beitrag löschen?',
                      style: TextStyle(color: ref.read(communityProvider)?.textColor(dlgBrightness) ?? (dlgBrightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A)))),
                  content: Text('Dieser Beitrag wird unwiderruflich gelöscht.',
                      style: TextStyle(
                          color: ref.read(communityProvider)?.textMutedColor(dlgBrightness) ?? (dlgBrightness == Brightness.dark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF6C757D)))),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Abbrechen'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Löschen',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                );
              },
            );
            if (confirm == true) {
              ref.read(feedNotifierProvider.notifier).deletePost(post.id);
            }
          },
        );
      },
    );
  }
}
