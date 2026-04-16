import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/community.dart';
import '../../providers/auth/auth_notifier.dart';
import '../../providers/auth/auth_state.dart';
import '../../providers/core/providers.dart';
import '../../providers/core/speed_dial_provider.dart';
import '../../providers/feed/feed_notifier.dart';
import '../../providers/feed/reels_notifier.dart';
import '../../providers/navigation_state.dart';
import '../../theme/app_theme.dart';
import '../dating/dating_screen.dart';
import '../live/live_browse_screen.dart';
import 'widgets/story_bar.dart';
import 'widgets/create_post_sheet.dart';
import 'widgets/comments_sheet.dart';
import 'widgets/edit_post_sheet.dart';
import 'widgets/post_card.dart';
import 'widgets/reel_card.dart';

const _bikerQuotes = [
  'Vier R\u00e4der bewegen den K\u00f6rper. Zwei R\u00e4der bewegen die Seele.',
  'Life is short. Ride hard.',
  'Keine Therapie ist so gut wie eine Ausfahrt.',
  'Born to ride. Forced to work.',
  'Die besten Kurven findet man nicht auf der Karte.',
  'Lean into the turn \u2014 im Leben und auf der Stra\u00dfe.',
  'Helmhaar ist der Preis der Freiheit.',
  'Es gibt kein schlechtes Wetter, nur falsche Motorradkleidung.',
  'Der Weg ist das Ziel \u2014 besonders auf zwei R\u00e4dern.',
  'Biker sein ist kein Hobby, es ist ein Lebensgef\u00fchl.',
  'Schr\u00e4glage ist eine Frage der Einstellung.',
  'Keep calm and twist the throttle.',
  'Asphalt ist die sch\u00f6nste Leinwand.',
  'Zwei R\u00e4der, ein Motor, unendliche Freiheit.',
  'Wind im Gesicht, Sorgen im R\u00fcckspiegel.',
];

const _carQuotes = [
  'Hubraum ist durch nichts zu ersetzen \u2014 au\u00dfer durch mehr Hubraum.',
  'Life is too short for boring cars.',
  'Vier R\u00e4der, ein Traum, keine Grenzen.',
  'Stra\u00dfe frei, Kopf frei.',
  'Wer lenkt, bestimmt die Richtung.',
  'Racing is life. Everything else is just waiting.',
  'PS sind nicht alles \u2014 aber ohne PS ist alles nichts.',
  'Gib Gas, nicht auf.',
  'Die Stra\u00dfe ruft \u2014 und ich muss gehen.',
  'Kurven sind die Poesie der Stra\u00dfe.',
  'Benzin im Blut, Asphalt im Herzen.',
  'Der Motor singt, die Seele tanzt.',
  'Ein Auto ist mehr als Blech \u2014 es ist Leidenschaft.',
  'Jede Fahrt ein kleines Abenteuer.',
  'Sound ist das beste Tuning.',
];

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

  /// FAB visibility — hides on scroll, shows when idle.
  bool _fabVisible = true;

  /// Whether the user has accepted the dating TOS (cached after first check).
  bool? _datingTosAccepted;

  /// Swipe hint animation for Reels tab
  bool _showSwipeHint = false;
  Timer? _swipeHintTimer;
  int _swipeHintShownCount = 0; // Max 3x pro Session


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
    NavigationState.instance.setFeedScrolling(false);
    _swipeHintTimer?.cancel();
    try { _infoOverlay?.remove(); } catch (_) {}
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

  void _startSwipeHintTimer() {
    _swipeHintTimer?.cancel();
    if (_swipeHintShownCount >= 3) return; // Max 3x pro Session
    _swipeHintTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted || _currentPage != 2) return;
      setState(() => _showSwipeHint = true);
      _swipeHintShownCount++;
      // Auto-hide nach 4s
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted && _showSwipeHint) {
          setState(() => _showSwipeHint = false);
        }
      });
    });
  }

  /// Called continuously during page swipe — drives the indicator animation.
  void _onPageScroll() {
    if (_pageController.page != null) {
      setState(() => _pageOffset = _pageController.page!);
    }
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);

    // Reels (page 2) = Fullscreen → Bars verstecken.
    // Andere Tabs → Bars wieder einblenden.
    if (page == 2) {
      if (!NavigationState.instance.feedScrolling) {
        NavigationState.instance.setFeedScrolling(true);
      }
      // FAB bleibt auf Reels sichtbar (Post erstellen)
      setState(() => _fabVisible = true);
      // Swipe-Hint starten nach 5s Inaktivität
      _startSwipeHintTimer();
    } else {
      _swipeHintTimer?.cancel();
      if (_showSwipeHint) setState(() => _showSwipeHint = false);
      if (NavigationState.instance.feedScrolling) {
        NavigationState.instance.setFeedScrolling(false);
        setState(() => _fabVisible = true);
      }
    }

    // Refresh stories on every tab switch
    ref.invalidate(storyUsersProvider);
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

  // ── Dating Age Gate + TOS ─────────────────────────────────────────────────

  /// Returns the user's age based on birth_year, or null if unknown.
  int? _getUserAge() {
    final authState = ref.read(authNotifierProvider);
    if (authState is! Authenticated) return null;
    final birthYear = authState.user.birthYear;
    if (birthYear == null) return null;
    return DateTime.now().year - birthYear;
  }

  /// Checks age (18+) and TOS acceptance before allowing dating tab access.
  /// Returns true if access is granted.
  Future<bool> _checkDatingAccess() async {
    // 1. Age check
    final age = _getUserAge();
    if (age == null || age < 18) {
      if (!mounted) return false;
      _showUnderageDialog();
      return false;
    }

    // 2. TOS check (cached)
    if (_datingTosAccepted == true) return true;

    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return false;
      final row = await Supabase.instance.client
          .from('profiles')
          .select('dating_tos_accepted_at')
          .eq('id', uid)
          .single();
      if (row['dating_tos_accepted_at'] != null) {
        _datingTosAccepted = true;
        return true;
      }
    } catch (_) {
      // Column might not exist yet — treat as not accepted
    }

    if (!mounted) return false;
    final accepted = await _showDatingTosSheet();
    if (accepted == true) {
      _datingTosAccepted = true;
      return true;
    }
    return false;
  }

  void _showUnderageDialog() {
    final brightness = Theme.of(context).brightness;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: brightness == Brightness.dark
            ? const Color(0xFF1E1E1E)
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.block_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                'Zugang gesperrt',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Du musst mindestens 18 Jahre alt sein, um die Dating-Funktion zu nutzen.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.7)
                : const Color(0xFF6C757D),
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Verstanden',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showDatingTosSheet() {
    final brightness = Theme.of(context).brightness;
    final community = ref.read(communityProvider);
    final accentColor = community?.accentColor ?? AppTheme.accentDark;
    final isDark = brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final mutedColor = isDark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF6C757D);
    final cardBg = community?.cardFor(brightness) ??
        (isDark ? const Color(0xFF1A1A1A) : Colors.white);

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              const SizedBox(height: 12),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Icon(Icons.favorite_rounded, color: Colors.pinkAccent, size: 48),
              const SizedBox(height: 12),
              Text(
                'Dating — Nutzungsbedingungen',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Bitte lies und akzeptiere die folgenden Regeln, bevor du die Dating-Funktion nutzt.',
                  style: GoogleFonts.inter(fontSize: 13, color: mutedColor, height: 1.4),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),

              // Rules
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _tosRule(Icons.person_rounded, 'Mindestalter 18 Jahre',
                          'Du bestätigst, dass du mindestens 18 Jahre alt bist.', textColor, mutedColor),
                      _tosRule(Icons.verified_user_rounded, 'Echte Angaben',
                          'Verwende nur echte Fotos und wahrheitsgemäße Profilangaben.', textColor, mutedColor),
                      _tosRule(Icons.handshake_rounded, 'Respektvolles Verhalten',
                          'Behandle andere mit Respekt. Belästigung, Hassrede oder Diskriminierung werden nicht toleriert.', textColor, mutedColor),
                      _tosRule(Icons.no_adult_content_rounded, 'Keine expliziten Inhalte',
                          'Nacktbilder, sexuelle oder gewaltverherrlichende Inhalte sind verboten.', textColor, mutedColor),
                      _tosRule(Icons.report_rounded, 'Verstöße melden',
                          'Melde unangemessenes Verhalten. Wir behalten uns vor, Accounts zu sperren.', textColor, mutedColor),
                      _tosRule(Icons.shield_rounded, 'Datenschutz',
                          'Deine Daten werden vertraulich behandelt. Matches sehen nur dein öffentliches Profil.', textColor, mutedColor),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),

              // Accept button
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () async {
                      // Save acceptance to Supabase
                      try {
                        final uid = Supabase.instance.client.auth.currentUser?.id;
                        if (uid != null) {
                          await Supabase.instance.client
                              .from('profiles')
                              .update({'dating_tos_accepted_at': DateTime.now().toIso8601String()})
                              .eq('id', uid);
                        }
                      } catch (_) {}
                      if (ctx.mounted) Navigator.of(ctx).pop(true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Text(
                      'Ich akzeptiere und bin 18+',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
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

  Widget _tosRule(IconData icon, String title, String desc, Color textColor, Color mutedColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: Colors.pinkAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: textColor)),
                const SizedBox(height: 2),
                Text(desc, style: GoogleFonts.inter(fontSize: 12.5, color: mutedColor, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Tab info explanations — shown as tooltip near the tab icon.
  static const _tabTitles = ['Erkunden', 'Folge ich', 'Reels', 'Live', 'Dating'];
  static const _tabDescs = [
    'Entdecke alle Beitr\u00e4ge der Community',
    'Beitr\u00e4ge von Leuten, denen du folgst',
    'Videos von Leuten, denen du folgst',
    'Live-Streams von Leuten, denen du folgst',
    'Finde deinen Biker-Match',
  ];

  OverlayEntry? _infoOverlay;

  void _switchToPage(int page) {
    // Show info tooltip when tapping the already-active tab
    if (_currentPage == page) {
      _showTabInfo(page);
      return;
    }
    // Dating tab (page 4): age gate + TOS required
    if (page == 4) {
      _checkDatingAccess().then((allowed) {
        if (allowed && mounted) {
          _pageController.animateToPage(
            page,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        }
      });
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
      floatingActionButton: (_currentPage == 3 || _currentPage == 4) ? null : Padding(
        padding: EdgeInsets.only(bottom: _currentPage == 2 ? 8 : 38),
        child: AnimatedScale(
          scale: _fabVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: FloatingActionButton(
            backgroundColor: accentColor,
            onPressed: () {
              if (!mounted) return;
              if (_currentPage == 2) {
                CreatePostScreen.show(context, source: PostMediaSource.video);
              } else {
                CreatePostScreen.show(context);
              }
            },
            child: const Icon(Icons.add_rounded, color: Colors.white),
          ),
        ),
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          // Reels (page 2) = always fullscreen — ignore scroll events
          if (_currentPage == 2) return true;

          if (notification is ScrollUpdateNotification && notification.depth >= 1) {
            final delta = notification.scrollDelta ?? 0;
            if (delta > 0) {
              // Scrolling DOWN → go fullscreen
              if (!NavigationState.instance.feedScrolling) {
                NavigationState.instance.setFeedScrolling(true);
                setState(() => _fabVisible = false);
              }
            } else if (delta < -2) {
              // Scrolling UP → restore UI
              if (NavigationState.instance.feedScrolling) {
                NavigationState.instance.setFeedScrolling(false);
                setState(() => _fabVisible = true);
              }
            }
          }
          return false;
        },
        child: Column(
        children: [
          // Fullscreen pages (Reels=2): only top safe-area
          // Feed pages (0,1,3) + LOVO (4): story bar + spacer + tab indicator
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            height: (NavigationState.instance.feedScrolling || _currentPage == 2)
                ? MediaQuery.of(context).padding.top
                : MediaQuery.of(context).padding.top + 52,
          ),
          // StoryBar — hidden on Reels (2), LOVO (4) and when scrolling
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: (NavigationState.instance.feedScrolling || _currentPage == 2 || _currentPage == 4)
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const StoryBar(),
            secondChild: const SizedBox(width: double.infinity, height: 0),
            sizeCurve: Curves.easeOutCubic,
          ),

          // ── Tab indicator + divider — hidden on Reels (2) and when scrolling feed ──
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: (NavigationState.instance.feedScrolling || _currentPage == 2)
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTabIndicator(accentColor, brightness, isDark, community),
                Divider(
                  height: 0.5,
                  thickness: 0.5,
                  color: community?.faintColor(brightness) ??
                      Colors.white.withValues(alpha: 0.06),
                ),
              ],
            ),
            secondChild: const SizedBox(width: double.infinity, height: 0),
            sizeCurve: Curves.easeOutCubic,
          ),

          // ── PageView — swipeable feed ──
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              physics: const _TabletFriendlyPagePhysics(),
              children: [
                // Page 0: Erkunden (ForYou)
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
                // Page 1: Folge ich
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
                // Page 2: Reels — FAB hides on touch, shows on release + swipe hint
                Listener(
                  onPointerDown: (_) {
                    if (_fabVisible) setState(() => _fabVisible = false);
                    if (_showSwipeHint) setState(() => _showSwipeHint = false);
                    _swipeHintTimer?.cancel();
                  },
                  onPointerUp: (_) {
                    if (!_fabVisible) setState(() => _fabVisible = true);
                    _startSwipeHintTimer();
                  },
                  onPointerCancel: (_) {
                    if (!_fabVisible) setState(() => _fabVisible = true);
                    _startSwipeHintTimer();
                  },
                  child: Stack(
                    children: [
                      _buildReelsPage(accentColor),
                      // Swipe hint overlay
                      if (_showSwipeHint)
                        _buildSwipeHint(),
                    ],
                  ),
                ),
                // Page 3: Live
                const LiveBrowseScreen(),
                // Page 4: Dating
                const DatingScreen(),
              ],
            ),
          ),
        ],
      ),
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
      Icons.live_tv_rounded,        // Live — Streams
      Icons.favorite_rounded,       // Dating — Herz
    ];
    const tabCount = 5;
    // Indicator lives inside a centered zone (avoids edge-to-edge stretch)
    final screenWidth = MediaQuery.of(context).size.width;
    final zoneWidth = (screenWidth * 0.60).clamp(180.0, 280.0); // narrower for icons
    final tabWidth = zoneWidth / tabCount;
    const indicatorHeight = 3.0;
    const indicatorRadius = 1.5;

    // Indicator widths per tab (same size for icons)
    const indicatorWidths = [24.0, 24.0, 24.0, 24.0, 24.0];

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
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    // Theme-aware shimmer colors — visible on BOTH dark and light backgrounds.
    final cardBg = isDark ? Colors.black : Colors.white;
    final shimmerStrong = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);
    final shimmerMedium = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.06);
    final shimmerSoft = isDark
        ? Colors.white.withValues(alpha: 0.03)
        : Colors.black.withValues(alpha: 0.04);
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.08);
    return Container(
      color: cardBg,
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
                    color: shimmerStrong,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 120, height: 14,
                  decoration: BoxDecoration(
                    color: shimmerMedium,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          // Media shimmer
          Container(
            width: double.infinity, height: 300,
            color: shimmerSoft,
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
                    color: shimmerMedium,
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
                color: shimmerSoft,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Divider(height: 0.5, thickness: 0.5, color: dividerColor),
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
    final hasFooter = feedState.isLoadingMore || !feedState.hasMore;
    final totalItems = feedState.posts.length + (hasFooter ? 1 : 0);
    final scrollCtrl = isFollowing ? _followingScroll : _forYouScroll;
    final community = ref.read(communityProvider);
    final brightness = Theme.of(context).brightness;

    return ListView.builder(
      controller: scrollCtrl,
      padding: EdgeInsets.zero,
      cacheExtent: 800,
      physics: const ClampingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      itemCount: totalItems,
      itemBuilder: (context, index) {
        if (index == feedState.posts.length) {
          if (feedState.isLoadingMore) {
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
          // End of feed — random racer quote
          final mutedColor = community?.textMutedColor(brightness) ??
              (brightness == Brightness.dark ? Colors.white54 : const Color(0xFF9E9E9E));
          final isBiker = community == Community.bikergram;
          final quotes = isBiker ? _bikerQuotes : _carQuotes;
          final quote = quotes[Random().nextInt(quotes.length)];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Expanded(child: Divider(color: accentColor.withValues(alpha: 0.3))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(
                      isBiker ? Icons.two_wheeler_rounded : Icons.directions_car_rounded,
                      color: accentColor, size: 20,
                    ),
                  ),
                  Expanded(child: Divider(color: accentColor.withValues(alpha: 0.3))),
                ]),
                const SizedBox(height: 10),
                Text(
                  quote,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: mutedColor,
                  ),
                ),
              ],
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

  Widget _buildSwipeHint() {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: _showSwipeHint ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 400),
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOut,
              builder: (_, value, child) => Transform.scale(
                scale: 0.8 + (0.2 * value),
                child: Opacity(opacity: value, child: child),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_back_ios_rounded, color: Colors.white54, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Wischen zum Wechseln',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 18),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
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
  double get dragStartDistanceMotionThreshold => 8.0; // lower = easier horizontal swipe
}

/// Blocks swiping right (toward next page) but allows swiping left (back).
/// Used on page 3 (Live) to prevent swiping into Dating without age gate.
class _BlockRightSwipePhysics extends PageScrollPhysics {
  const _BlockRightSwipePhysics({super.parent});

  @override
  _BlockRightSwipePhysics applyTo(ScrollPhysics? ancestor) {
    return _BlockRightSwipePhysics(parent: buildParent(ancestor));
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    // Block scrolling toward a higher page (right swipe = value > pixels)
    if (value > position.pixels) {
      return value - position.pixels;
    }
    return super.applyBoundaryConditions(position, value);
  }
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
