import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/community.dart';
import '../../providers/core/providers.dart';
import '../../providers/core/speed_dial_provider.dart';
import '../../providers/feed/feed_notifier.dart';
import '../../providers/feed/reels_notifier.dart';
import '../../theme/app_theme.dart';
import 'widgets/story_bar.dart';
import 'widgets/create_post_sheet.dart';
import 'widgets/comments_sheet.dart';
import 'widgets/edit_post_sheet.dart';
import 'widgets/post_card.dart';
import 'widgets/reel_card.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  late PageController _pageController;
  int _currentPage = 0;

  /// Tracks the exact fractional page position for smooth indicator animation.
  double _pageOffset = 0.0;

  /// ScrollControllers for each feed tab (infinite scroll detection).
  final ScrollController _forYouScroll = ScrollController();
  final ScrollController _followingScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageController.addListener(_onPageScroll);

    _forYouScroll.addListener(_onForYouScroll);
    _followingScroll.addListener(_onFollowingScroll);

    // Load ForYou feed on first build
    Future.microtask(() {
      if (!mounted) return;
      ref.read(feedNotifierProvider.notifier).loadFeed();
    });
  }

  @override
  void dispose() {
    _infoOverlay?.remove();
    _infoOverlay = null;
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    _forYouScroll.removeListener(_onForYouScroll);
    _forYouScroll.dispose();
    _followingScroll.removeListener(_onFollowingScroll);
    _followingScroll.dispose();
    super.dispose();
  }

  /// Infinite scroll: load more when near bottom of ForYou feed.
  void _onForYouScroll() {
    if (_forYouScroll.position.pixels >=
        _forYouScroll.position.maxScrollExtent - 500) {
      ref.read(feedNotifierProvider.notifier).loadMore();
    }
  }

  /// Infinite scroll: load more when near bottom of Following feed.
  void _onFollowingScroll() {
    if (_followingScroll.position.pixels >=
        _followingScroll.position.maxScrollExtent - 500) {
      ref.read(followingFeedProvider.notifier).loadMore();
    }
  }

  /// Called continuously during page swipe — drives the indicator animation.
  void _onPageScroll() {
    if (_pageController.page != null) {
      setState(() => _pageOffset = _pageController.page!);
    }
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
    if (page == 0) {
      // Erkunden — ForYou, alle Posts
      ref.read(feedNotifierProvider.notifier).loadFeed();
    } else if (page == 1) {
      // Folge ich — nur Follower-Content
      ref.read(followingFeedProvider.notifier).loadFeed();
    } else if (page == 2) {
      // Reels — nur Follower-Reels
      ref.read(reelsNotifierProvider.notifier).loadReels();
    }
  }

  /// Tab info explanations — shown as tooltip near the tab icon.
  static const _tabTitles = ['Erkunden', 'Folge ich', 'Reels'];
  static const _tabDescs = [
    'Entdecke alle Beitr\u00e4ge der Community',
    'Beitr\u00e4ge von Leuten, denen du folgst',
    'Videos von Leuten, denen du folgst',
  ];

  OverlayEntry? _infoOverlay;

  void _switchToPage(int page) {
    // Show info tooltip when tapping the already-active tab
    if (_currentPage == page) {
      _showTabInfo(page);
      return;
    }
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _showTabInfo(int page) {
    // Dismiss any existing overlay
    _infoOverlay?.remove();
    _infoOverlay = null;

    final community = ref.read(communityProvider);
    final accentColor = community?.accentColor ?? AppTheme.accentDark;

    // Calculate position: center of the tab icon zone
    final screenWidth = MediaQuery.of(context).size.width;
    final zoneWidth = (screenWidth * 0.60).clamp(180.0, 280.0);
    final tabWidth = zoneWidth / 3;
    final zoneLeft = (screenWidth - zoneWidth) / 2;
    final tabCenterX = zoneLeft + tabWidth * page + tabWidth / 2;
    // Y position: below the tab indicator (top bar + story bar + tab bar)
    final topInset = MediaQuery.of(context).padding.top + 52; // global top bar
    const storyBarHeight = 90.0; // approximate
    const tabBarHeight = 42.0;
    final tooltipTop = topInset + storyBarHeight + tabBarHeight + 4;

    final overlay = OverlayEntry(
      builder: (ctx) => Positioned(
        top: tooltipTop,
        // Center the tooltip on the tab, but clamp to screen edges
        left: (tabCenterX - 100).clamp(12.0, screenWidth - 212.0),
        child: _TabInfoTooltip(
          title: _tabTitles[page],
          description: _tabDescs[page],
          accentColor: accentColor,
          onDismiss: () {
            _infoOverlay?.remove();
            _infoOverlay = null;
          },
        ),
      ),
    );

    _infoOverlay = overlay;
    Overlay.of(context).insert(overlay);

    // Auto-dismiss after 2.5 seconds
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (_infoOverlay == overlay) {
        overlay.remove();
        _infoOverlay = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final community = ref.watch(communityProvider);
    final brightness = Theme.of(context).brightness;
    final forYouState = ref.watch(feedNotifierProvider);
    final followingState = ref.watch(followingFeedProvider);
    final accentColor = community?.accentColor ?? AppTheme.accentDark;
    final isDark = brightness == Brightness.dark;

    // Re-register Speed-Dial items every build (depends on active tab)
    final location = GoRouterState.of(context).matchedLocation;
    if (location == '/feed') {
      Future.microtask(() {
        if (!mounted) return;
        if (_currentPage == 2) {
          // Reels tab — nur Video
          ref.read(speedDialItemsProvider.notifier).register([
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
          ]);
        } else {
          // For You / Following — alle Optionen
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
        }
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
              physics: const _TabletFriendlyPagePhysics(),
              children: [
                // Page 0: Erkunden (ForYou) — alle Posts sichtbar
                RefreshIndicator(
                  color: accentColor,
                  backgroundColor: community?.cardFor(brightness) ?? (isDark ? const Color(0xFF1A1A1A) : Colors.white),
                  onRefresh: () => ref.read(feedNotifierProvider.notifier).loadFeed(),
                  child: forYouState.isLoading && forYouState.posts.isEmpty
                      ? _buildLoadingState()
                      : forYouState.posts.isEmpty
                          ? _buildEmptyState(accentColor, FeedMode.forYou)
                          : _buildPostList(forYouState, accentColor, isFollowing: false),
                ),
                // Page 1: Folge ich — nur Follower-Content
                RefreshIndicator(
                  color: accentColor,
                  backgroundColor: community?.cardFor(brightness) ?? (isDark ? const Color(0xFF1A1A1A) : Colors.white),
                  onRefresh: () => ref.read(followingFeedProvider.notifier).loadFeed(),
                  child: followingState.isLoading && followingState.posts.isEmpty
                      ? _buildLoadingState()
                      : followingState.posts.isEmpty
                          ? _buildEmptyState(accentColor, FeedMode.following)
                          : _buildPostList(followingState, accentColor, isFollowing: true),
                ),
                // Page 2: Reels — nur Follower-Reels
                _buildReelsPage(accentColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Modern tab indicator — full-width, smooth sliding pill that follows swipe.
  Widget _buildTabIndicator(Color accentColor, Brightness brightness, bool isDark, Community? community) {
    final mutedColor = community?.textMutedColor(brightness) ??
        (isDark ? Colors.white.withValues(alpha: 0.35) : const Color(0xFF9E9E9E));
    final activeTextColor = isDark ? Colors.white : const Color(0xFF1A1A1A);

    const tabIcons = [
      Icons.explore_rounded,        // For You — Entdecken
      Icons.people_rounded,         // Following — Folge ich
      Icons.play_circle_rounded,    // Reels — Videos
    ];
    const tabCount = 3;
    // Indicator lives inside a centered zone (avoids edge-to-edge stretch)
    final screenWidth = MediaQuery.of(context).size.width;
    final zoneWidth = (screenWidth * 0.60).clamp(180.0, 280.0); // narrower for icons
    final tabWidth = zoneWidth / tabCount;
    const indicatorHeight = 3.0;
    const indicatorRadius = 1.5;

    // Indicator widths per tab (same size for icons)
    const indicatorWidths = [24.0, 24.0, 24.0];

    // Interpolate indicator position + width from _pageOffset
    final fromIdx = _pageOffset.floor().clamp(0, tabCount - 1);
    final toIdx = _pageOffset.ceil().clamp(0, tabCount - 1);
    final t = _pageOffset - fromIdx; // 0.0 … 1.0

    final fromCenter = tabWidth * fromIdx + tabWidth / 2;
    final toCenter = tabWidth * toIdx + tabWidth / 2;
    final indicatorCenter = fromCenter + (toCenter - fromCenter) * t;

    final fromW = indicatorWidths[fromIdx];
    final toW = indicatorWidths[toIdx];
    // Stretch slightly in the middle of transition for a playful effect
    final stretchFactor = 1.0 + 0.3 * (1.0 - (2 * t - 1).abs()); // peaks at t=0.5
    final indicatorW = (fromW + (toW - fromW) * t) * stretchFactor;

    final zoneLeft = (screenWidth - zoneWidth) / 2;

    return SizedBox(
      height: 42,
      child: Stack(
        children: [
          // Tab labels — centered in zone
          Positioned.fill(
            child: Center(
              child: SizedBox(
                width: zoneWidth,
                child: Row(
                  children: List.generate(tabCount, (index) {
                    final distance = (_pageOffset - index).abs().clamp(0.0, 1.0);
                    final isActive = distance < 0.5;

                    return GestureDetector(
                      onTap: () => _switchToPage(index),
                      behavior: HitTestBehavior.opaque,
                      child: SizedBox(
                        width: tabWidth,
                        height: 42,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Icon(
                              tabIcons[index],
                              size: isActive ? 26 : 23,
                              color: Color.lerp(mutedColor, activeTextColor, 1.0 - distance),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),

          // Sliding indicator pill
          Positioned(
            bottom: 0,
            left: zoneLeft + indicatorCenter - indicatorW / 2,
            child: Container(
              width: indicatorW,
              height: indicatorHeight,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(indicatorRadius),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: EdgeInsets.zero,
      physics: const ClampingScrollPhysics(
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
            mode == FeedMode.reels
                ? Icons.slow_motion_video_rounded
                : mode == FeedMode.following
                    ? Icons.people_outline_rounded
                    : Icons.explore_outlined,
            size: 64,
            color: Colors.white.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 16),
          Text(
            mode == FeedMode.reels
                ? 'Noch keine Reels'
                : mode == FeedMode.following
                    ? 'Noch keine Beitr\u00e4ge von Leuten, denen du folgst'
                    : 'Noch keine Beitr\u00e4ge',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: community?.textMutedColor(brightness) ?? (brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF6C757D)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            mode == FeedMode.reels
                ? 'Poste das erste Video!'
                : mode == FeedMode.following
                    ? 'Folge anderen, um ihren Content hier zu sehen!'
                    : 'Erstelle den ersten Beitrag!',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: community?.textMutedColor(brightness) ?? (brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.3) : const Color(0xFF6C757D)),
            ),
          ),
          if (mode == FeedMode.reels) ...[
            const SizedBox(height: 28),
            GestureDetector(
              onTap: () => CreatePostScreen.show(context, source: PostMediaSource.video),
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor,
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.4),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 36),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build a scrollable post list (Instagram-style ListView).
  /// [isFollowing] determines which provider to use for interactions.
  Widget _buildPostList(FeedState feedState, Color accentColor, {required bool isFollowing}) {
    final totalItems = feedState.posts.length + (feedState.isLoadingMore ? 1 : 0);
    final scrollCtrl = isFollowing ? _followingScroll : _forYouScroll;

    return ListView.builder(
      controller: scrollCtrl,
      padding: EdgeInsets.zero,
      physics: const ClampingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      itemCount: totalItems,
      itemBuilder: (context, index) {
        if (index == feedState.posts.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
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
          key: ValueKey(post.id),
          post: post,
          accentColor: accentColor,
          communityName: ref.read(communityProvider)?.name,
          commentPreviews: previews,
          onLike: () => _handleLike(post),
          onSave: () => _handleSave(post.id),
          onComment: () => _handleComment(post),
          onEdit: () => EditPostSheet.show(context, post),
          onVideoPlay: () => ref.read(feedNotifierProvider.notifier).trackVideoPlay(post.id),
          onVideoComplete: () => ref.read(feedNotifierProvider.notifier).trackVideoComplete(post.id),
          onReaction: (reactionType) => _handleReaction(post, reactionType),
          onDelete: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) {
                final dlgBrightness = Theme.of(ctx).brightness;
                return AlertDialog(
                  backgroundColor: ref.read(communityProvider)?.cardFor(dlgBrightness) ?? (dlgBrightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white),
                  title: Text('Beitrag l\u00f6schen?',
                      style: TextStyle(color: ref.read(communityProvider)?.textColor(dlgBrightness) ?? (dlgBrightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A)))),
                  content: Text('Dieser Beitrag wird unwiderruflich gel\u00f6scht.',
                      style: TextStyle(
                          color: ref.read(communityProvider)?.textMutedColor(dlgBrightness) ?? (dlgBrightness == Brightness.dark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF6C757D)))),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Abbrechen'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('L\u00f6schen',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                );
              },
            );
            if (confirm == true) {
              _deletePost(post.id);
            }
          },
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════
  //  INTERACTION HELPERS
  //  Route to correct provider based on _currentPage
  // ═══════════════════════════════════════════════════

  String? get _currentUserId =>
      Supabase.instance.client.auth.currentUser?.id;

  bool _isOwnPost(post) => post.userId == _currentUserId;

  void _showSelfLikeInfo() {
    final community = ref.read(communityProvider);
    final accentColor = community?.accentColor ?? Colors.blue;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Du kannst deine eigenen Beitr\u00e4ge nicht liken',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: accentColor.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showRateLimitWarning(int remainingSecs) {
    final community = ref.read(communityProvider);
    final accentColor = community?.accentColor ?? Colors.blue;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.timer_outlined, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Bitte warte $remainingSecs Sekunden bevor du erneut likest',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _handleLike(post) async {
    if (!mounted) return;
    if (_isOwnPost(post)) {
      _showSelfLikeInfo();
      return;
    }
    int? lockSecs;
    if (_currentPage == 1) {
      lockSecs = await ref.read(followingFeedProvider.notifier).toggleLike(post.id);
    } else {
      lockSecs = await ref.read(feedNotifierProvider.notifier).toggleLike(post.id);
    }
    if (lockSecs != null && mounted) _showRateLimitWarning(lockSecs);
  }

  void _handleReaction(post, String? reactionType) {
    if (!mounted) return;
    if (_isOwnPost(post)) {
      _showSelfLikeInfo();
      return;
    }
    if (_currentPage == 1) {
      ref.read(followingFeedProvider.notifier).toggleReaction(post.id, reactionType);
    } else {
      ref.read(feedNotifierProvider.notifier).toggleReaction(post.id, reactionType);
    }
  }

  Future<void> _handleSave(int postId) async {
    try {
      if (_currentPage == 1) {
        await ref.read(followingFeedProvider.notifier).toggleSave(postId);
      } else {
        await ref.read(feedNotifierProvider.notifier).toggleSave(postId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Speichern fehlgeschlagen: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _deletePost(int postId) {
    if (_currentPage == 1) {
      ref.read(followingFeedProvider.notifier).deletePost(postId);
    } else {
      ref.read(feedNotifierProvider.notifier).deletePost(postId);
    }
  }

  void _handleComment(post) {
    if (!mounted) return;
    CommentsSheet.show(
      context,
      post.id,
      postUserId: post.userId,
    );
  }

  /// Build the Reels page (3rd tab) — vertical fullscreen video PageView.
  /// Zeigt nur Reels von Leuten, denen der User folgt.
  Widget _buildReelsPage(Color accentColor) {
    final reelsState = ref.watch(reelsNotifierProvider);

    if (reelsState.isLoading && reelsState.reels.isEmpty) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
      );
    }

    if (reelsState.reels.isEmpty) {
      return _buildEmptyState(accentColor, FeedMode.reels);
    }

    return ReelsPageView(
      reels: reelsState.reels,
      accentColor: accentColor,
      onLoadMore: () => ref.read(reelsNotifierProvider.notifier).loadMore(),
      onLike: (id) async {
        final lockSecs = await ref.read(reelsNotifierProvider.notifier).toggleLike(id);
        if (lockSecs != null && mounted) _showRateLimitWarning(lockSecs);
      },
      onSave: (id) => _handleReelSave(id),
      onComment: (id, userId) => CommentsSheet.show(context, id, postUserId: userId),
      onReaction: (id, type) => ref.read(reelsNotifierProvider.notifier).toggleReaction(id, type),
    );
  }

  Future<void> _handleReelSave(int postId) async {
    try {
      await ref.read(reelsNotifierProvider.notifier).toggleSave(postId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Speichern fehlgeschlagen: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}

/// Custom PageScrollPhysics for horizontal tab swiping.
/// Slightly easier than default but NOT so aggressive that it steals
/// vertical scroll gestures from the ListView inside each tab.
class _TabletFriendlyPagePhysics extends PageScrollPhysics {
  const _TabletFriendlyPagePhysics({super.parent});

  @override
  _TabletFriendlyPagePhysics applyTo(ScrollPhysics? ancestor) {
    return _TabletFriendlyPagePhysics(parent: buildParent(ancestor));
  }

  /// Slightly lower than default (~365) so tabs are easy to swipe,
  /// but high enough to not steal vertical scroll gestures.
  @override
  double get minFlingVelocity => 200.0;

  /// Higher than before (was 3.0!) so vertical scrolling doesn't
  /// accidentally trigger a horizontal tab change on tablets.
  @override
  double get dragStartDistanceMotionThreshold => 14.0; // default ~18
}

/// Animated tooltip bubble that appears near the tab icon.
class _TabInfoTooltip extends StatefulWidget {
  const _TabInfoTooltip({
    required this.title,
    required this.description,
    required this.accentColor,
    required this.onDismiss,
  });

  final String title;
  final String description;
  final Color accentColor;
  final VoidCallback onDismiss;

  @override
  State<_TabInfoTooltip> createState() => _TabInfoTooltipState();
}

class _TabInfoTooltipState extends State<_TabInfoTooltip>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _scaleAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _opacityAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onDismiss,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, child) => Opacity(
          opacity: _opacityAnim.value,
          child: Transform.scale(
            scale: _scaleAnim.value,
            alignment: Alignment.topCenter,
            child: child,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 200,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: widget.accentColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.description,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
