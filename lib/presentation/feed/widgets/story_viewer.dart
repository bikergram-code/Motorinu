import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../../providers/auth/auth_notifier.dart';
import '../../../providers/auth/auth_state.dart';
import '../../../providers/core/providers.dart';
import 'story_bar.dart';
import 'story_comments_sheet.dart';

// ---------------------------------------------------------------------------
// Data classes
// ---------------------------------------------------------------------------

/// A single story item for the viewer.
class StoryItem {
  const StoryItem({
    required this.id,
    required this.mediaUrl,
    this.caption,
    required this.createdAt,
  });

  final int id;
  final String mediaUrl;
  final String? caption;
  final DateTime createdAt;
}

/// A group of stories from one user.
class StoryGroup {
  const StoryGroup({
    required this.userId,
    required this.username,
    this.avatarUrl,
    required this.stories,
    this.isOwn = false,
  });

  final String userId;
  final String username;
  final String? avatarUrl;
  final List<StoryItem> stories;
  final bool isOwn;
}

// ---------------------------------------------------------------------------
// StoryViewer — Facebook-style with 3D Cube Effect + Rounded Cards
// ---------------------------------------------------------------------------

/// Fullscreen story viewer with cube transition between user groups.
///
/// Usage:
/// ```dart
/// StoryViewer.show(context, groups: [...], initialGroupIndex: 0);
/// ```
class StoryViewer extends ConsumerStatefulWidget {
  const StoryViewer({
    super.key,
    required this.groups,
    this.initialGroupIndex = 0,
    required this.accentColor,
  });

  final List<StoryGroup> groups;
  final int initialGroupIndex;
  final Color accentColor;

  /// Show the viewer as a fullscreen page with a fade transition.
  static Future<void> show(
    BuildContext context, {
    required List<StoryGroup> groups,
    int initialGroupIndex = 0,
    required Color accentColor,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => StoryViewer(
          groups: groups,
          initialGroupIndex: initialGroupIndex,
          accentColor: accentColor,
        ),
        transitionsBuilder: (_, anim, __, child) {
          return FadeTransition(opacity: anim, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  @override
  ConsumerState<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends ConsumerState<StoryViewer> {
  // ── PageView for cube transitions between groups ──
  late PageController _pageController;
  double _currentPageValue = 0.0;

  // ── Per-group story index tracking ──
  final Map<int, int> _storyIndices = {};

  // ── Progress animation (Timer-based, immune to animator_duration_scale) ──
  double _progress = 0.0;
  Timer? _progressTimer;
  bool _isPaused = false;
  static const _tickInterval = Duration(milliseconds: 16); // ~60fps

  // ── Like state ──
  bool _liked = false;
  int _likeCount = 0;

  static const _storyDuration = Duration(seconds: 5);

  // ── Computed getters ──
  int get _groupIndex =>
      _pageController.hasClients
          ? (_pageController.page?.round() ?? _pageController.initialPage)
          : _pageController.initialPage;

  int get _storyIndex => _storyIndices[_groupIndex] ?? 0;
  set _storyIndex(int value) => _storyIndices[_groupIndex] = value;

  StoryGroup get _currentGroup => widget.groups[_groupIndex];
  StoryItem get _currentStory => _currentGroup.stories[_storyIndex];

  @override
  void initState() {
    super.initState();

    final initialGroup =
        widget.initialGroupIndex.clamp(0, widget.groups.length - 1);

    _pageController = PageController(initialPage: initialGroup);
    _currentPageValue = initialGroup.toDouble();
    _pageController.addListener(_onPageScroll);

    // Initialize all story indices to 0
    for (int i = 0; i < widget.groups.length; i++) {
      _storyIndices[i] = 0;
    }

    _progressNotifier = ValueNotifier<double>(0.0);

    _lastPageIndex = initialGroup;

    // Delay start so it doesn't collide with onPageChanged from initial page settle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _startStory();
    });
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    _progressTimer?.cancel();
    _progressNotifier.dispose();
    super.dispose();
  }

  // ── PageView scroll listener (drives cube animation) ──────────────────────

  void _onPageScroll() {
    final page = _pageController.page ?? _currentPageValue;
    setState(() {
      _currentPageValue = page;
    });

    // Progress is managed by _startStory / _onPageChanged only.
    // No pause/resume here — cube animation doesn't affect timer.
  }

  int _lastPageIndex = -1;

  void _onPageChanged(int pageIndex) {
    // Skip if this is the same page (initial settle or duplicate call)
    if (pageIndex == _lastPageIndex) return;
    _lastPageIndex = pageIndex;

    // Reset like state when switching to a new group
    setState(() {
      _liked = false;
      _likeCount = 0;
    });
    _startStory();
  }

  // ── Story navigation ────────────────────────────────────────────────────

  late ValueNotifier<double> _progressNotifier;

  void _startStory() {
    _lastStoryStartTime = DateTime.now();
    _progressTimer?.cancel();
    _progress = 0.0;
    _progressNotifier.value = 0.0;
    debugPrint('[STORY] _startStory called, group=$_groupIndex story=$_storyIndex');
    _progressTimer = Timer.periodic(_tickInterval, _onProgressTick);

    // Load like info only for other users' stories
    if (!_currentGroup.isOwn) {
      _loadLikeInfo();
    }
  }

  void _onProgressTick(Timer timer) {
    if (_isPaused || !mounted) return;
    _progress += _tickInterval.inMilliseconds / _storyDuration.inMilliseconds;
    if (_progress >= 1.0) {
      _progress = 1.0;
      _progressNotifier.value = 1.0;
      timer.cancel();
      _nextStory();
    } else {
      _progressNotifier.value = _progress;
    }
  }

  void _nextStory() {
    debugPrint('[STORY] _nextStory called, group=$_groupIndex story=$_storyIndex');
    final groupIdx = _groupIndex;
    final currentStoryIdx = _storyIndices[groupIdx] ?? 0;
    final group = widget.groups[groupIdx];

    if (currentStoryIdx < group.stories.length - 1) {
      // Next story in same group
      setState(() => _storyIndices[groupIdx] = currentStoryIdx + 1);
      _startStory();
    } else if (groupIdx < widget.groups.length - 1) {
      // Next user group → cube animation
      _storyIndices[groupIdx + 1] = 0;
      _pageController.animateToPage(
        groupIdx + 1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      // All done
      Navigator.of(context).pop();
    }
  }

  void _prevStory() {
    final groupIdx = _groupIndex;
    final currentStoryIdx = _storyIndices[groupIdx] ?? 0;

    if (currentStoryIdx > 0) {
      setState(() => _storyIndices[groupIdx] = currentStoryIdx - 1);
      _startStory();
    } else if (groupIdx > 0) {
      // Previous user group → cube animation
      final prevGroup = widget.groups[groupIdx - 1];
      _storyIndices[groupIdx - 1] = prevGroup.stories.length - 1;
      _pageController.animateToPage(
        groupIdx - 1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      // Already at very first story, restart it
      _startStory();
    }
  }

  DateTime _lastStoryStartTime = DateTime.now();

  void _onTapUp(TapUpDetails details) {
    // Ignore taps within 500ms of story start to prevent accidental skips
    if (DateTime.now().difference(_lastStoryStartTime).inMilliseconds < 500) return;

    final screenWidth = MediaQuery.of(context).size.width;
    if (details.globalPosition.dx < screenWidth * 0.3) {
      _prevStory();
    } else {
      _nextStory();
    }
  }

  void _onLongPressStart(LongPressStartDetails _) {
    _isPaused = true;
  }

  void _onLongPressEnd(LongPressEndDetails _) {
    _isPaused = false;
  }

  // ── Like helpers ────────────────────────────────────────────────────────

  Future<void> _loadLikeInfo() async {
    try {
      final info = await ref
          .read(storyRepositoryProvider)
          .getStoryLikeInfo(_currentStory.id);
      if (mounted) {
        setState(() {
          _liked = info.likedByMe;
          _likeCount = info.count;
        });
      }
    } catch (_) {
      // Silently ignore — non-critical
    }
  }

  Future<void> _toggleLike() async {
    final storyId = _currentStory.id;
    final wasLiked = _liked;

    // Optimistic update
    setState(() {
      _liked = !wasLiked;
      _likeCount += wasLiked ? -1 : 1;
      if (_likeCount < 0) _likeCount = 0;
    });

    try {
      await ref.read(storyRepositoryProvider).toggleStoryLike(storyId);

      // Send notification when liking (not un-liking)
      if (!wasLiked) {
        final authState = ref.read(authNotifierProvider);
        final myName = authState is Authenticated
            ? (authState.user.displayName ?? authState.user.username)
            : '';
        final myId = authState is Authenticated ? authState.user.id : '';
        final community = ref.read(communityProvider);
        ref.read(notificationRepositoryProvider).createNotification(
              targetUserId: _currentGroup.userId,
              type: 'like',
              title: '$myName hat deine Story geliked',
              data: {'story_id': storyId, 'actor_id': myId},
              community: community?.name,
            );
      }
    } catch (_) {
      // Revert on error
      if (mounted) {
        setState(() {
          _liked = wasLiked;
          _likeCount += wasLiked ? 1 : -1;
          if (_likeCount < 0) _likeCount = 0;
        });
      }
    }
  }

  // ── Comment ─────────────────────────────────────────────────────────────

  Future<void> _openComments() async {
    _isPaused = true;
    await StoryCommentsSheet.show(
      context,
      storyId: _currentStory.id,
      storyUserId: _currentGroup.userId,
    );
    if (mounted) _isPaused = false;
  }

  // ── Share ───────────────────────────────────────────────────────────────

  void _shareStory() {
    Share.share('Schau dir diese Story an! \u{1F3CD}');
  }

  // ── Delete (own stories) ────────────────────────────────────────────────

  Future<void> _deleteStory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Story l\u00f6schen?',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Diese Story wird unwiderruflich gel\u00f6scht.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Abbrechen', style: GoogleFonts.inter()),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'L\u00f6schen',
              style: GoogleFonts.inter(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref
          .read(storyRepositoryProvider)
          .deleteStory(_currentStory.id);
      ref.invalidate(storyUsersProvider);

      if (!mounted) return;

      final groupIdx = _groupIndex;
      final currentStoryIdx = _storyIndices[groupIdx] ?? 0;
      final group = widget.groups[groupIdx];

      if (currentStoryIdx < group.stories.length - 1) {
        setState(() => _storyIndices[groupIdx] = currentStoryIdx + 1);
        _startStory();
      } else if (groupIdx < widget.groups.length - 1) {
        _storyIndices[groupIdx + 1] = 0;
        _pageController.animateToPage(
          groupIdx + 1,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      } else {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim L\u00f6schen: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'gerade eben';
    if (diff.inMinutes < 60) return 'vor ${diff.inMinutes} Min.';
    if (diff.inHours < 24) return 'vor ${diff.inHours} Std.';
    return 'vor ${diff.inDays} T.';
  }

  // ── Cube Transform ────────────────────────────────────────────────────

  Widget _buildCubeTransform({required int index, required Widget child}) {
    final double pageOffset = index - _currentPageValue;

    // Don't render pages that are too far off-screen
    if (pageOffset.abs() > 1.5) return const SizedBox.shrink();

    final double clampedOffset = pageOffset.clamp(-1.0, 1.0);
    final double angle = clampedOffset * pi / 2;

    return Transform(
      alignment: clampedOffset <= 0
          ? Alignment.centerRight // Left page pivots on its right edge
          : Alignment.centerLeft, // Right page pivots on its left edge
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001) // Perspective
        ..rotateY(angle),
      child: child,
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.groups.length,
        onPageChanged: _onPageChanged,
        physics: const ClampingScrollPhysics(),
        itemBuilder: (context, index) {
          return _buildCubeTransform(
            index: index,
            child: _buildStoryPage(index),
          );
        },
      ),
    );
  }

  // ── Story Page (one user's story group) ───────────────────────────────

  Widget _buildStoryPage(int groupIndex) {
    final group = widget.groups[groupIndex];
    final storyIdx =
        (_storyIndices[groupIndex] ?? 0).clamp(0, group.stories.length - 1);
    final story = group.stories[storyIdx];
    final isActive = groupIndex == _groupIndex;

    return Padding(
      padding: EdgeInsets.only(
        left: 6,
        right: 6,
        top: MediaQuery.of(context).padding.top + 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          color: const Color(0xFF1A1A1A),
          child: GestureDetector(
            onTapUp: _onTapUp,
            onLongPressStart: _onLongPressStart,
            onLongPressEnd: _onLongPressEnd,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── Story Image ──
                Image.network(
                  story.mediaUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  loadingBuilder: (_, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        color: widget.accentColor,
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image_rounded,
                            color: Colors.white.withValues(alpha: 0.3),
                            size: 64),
                        const SizedBox(height: 12),
                        Text('Bild konnte nicht geladen werden',
                            style: GoogleFonts.inter(
                                color: Colors.white.withValues(alpha: 0.4),
                                fontSize: 14)),
                      ],
                    ),
                  ),
                ),

                // ── Top Gradient ──
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 140,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Bottom Gradient ──
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: group.isOwn ? 160 : 200,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.8),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Progress Bars (only on active page) ──
                if (isActive)
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: Row(
                      children: List.generate(group.stories.length, (i) {
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                                right: i < group.stories.length - 1 ? 4 : 0),
                            child: _ProgressBar(
                              progressNotifier: i == storyIdx
                                  ? _progressNotifier
                                  : null,
                              filled: i < storyIdx,
                              accentColor: widget.accentColor,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),

                // ── User Info Row ──
                Positioned(
                  top: 28,
                  left: 12,
                  right: 4,
                  child: _buildUserInfoRow(group, story),
                ),

                // ── Caption ──
                if (story.caption != null && story.caption!.isNotEmpty)
                  Positioned(
                    bottom: group.isOwn ? 24 : 72,
                    left: 20,
                    right: 20,
                    child: Text(
                      story.caption!,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            blurRadius: 8,
                            color: Colors.black.withValues(alpha: 0.6),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                // ── Action Bar (other users' stories only) ──
                if (!group.isOwn && isActive)
                  Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: _buildActionBar(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── User Info Row ─────────────────────────────────────────────────────

  Widget _buildUserInfoRow(StoryGroup group, StoryItem story) {
    final brightness = Theme.of(context).brightness;
    return Row(
      children: [
        // Avatar
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: widget.accentColor.withValues(alpha: 0.6),
                width: 1.5),
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: brightness == Brightness.dark
                    ? Colors.black
                    : Colors.white,
                width: 1.5,
              ),
            ),
            child: ClipOval(
              child: group.avatarUrl != null && group.avatarUrl!.isNotEmpty
                  ? Image.network(
                      group.avatarUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _buildInitial(group.username),
                    )
                  : _buildInitial(group.username),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Username + time
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                group.username,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                _timeAgo(story.createdAt),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),

        // Delete button (own stories only)
        if (group.isOwn)
          IconButton(
            onPressed: _deleteStory,
            icon: const Icon(Icons.delete_outline_rounded,
                color: Colors.white, size: 24),
          ),

        // Close button
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded,
              color: Colors.white, size: 26),
        ),
      ],
    );
  }

  // ── Action bar for other users' stories ─────────────────────────────────

  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Like
          GestureDetector(
            onTap: _toggleLike,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: _liked ? Colors.red : Colors.white,
                  size: 28,
                ),
                if (_likeCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '$_likeCount',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Comment
          GestureDetector(
            onTap: _openComments,
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),

          // Share
          GestureDetector(
            onTap: _shareStory,
            child: const Icon(
              Icons.share_outlined,
              color: Colors.white,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  // ── Initial avatar fallback ─────────────────────────────────────────────

  Widget _buildInitial(String name) {
    return Container(
      color: const Color(0xFF2A2A2A),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Progress bar widgets
// ---------------------------------------------------------------------------

/// A single progress bar segment.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    this.progressNotifier,
    this.filled = false,
    required this.accentColor,
  });

  final ValueNotifier<double>? progressNotifier;
  final bool filled;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 2.5,
        child: Stack(
          children: [
            // Background
            Container(color: Colors.white.withValues(alpha: 0.25)),

            // Fill
            if (filled)
              Container(color: Colors.white)
            else if (progressNotifier != null)
              ValueListenableBuilder<double>(
                valueListenable: progressNotifier!,
                builder: (_, value, __) => FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: value.clamp(0.0, 1.0),
                  child: Container(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
