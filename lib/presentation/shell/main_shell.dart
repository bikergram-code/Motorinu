import 'dart:async';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:permission_handler/permission_handler.dart';

import '../../core/community.dart';
import '../../services/online_status_service.dart';
import '../../services/push_notification_service.dart';
import '../../providers/auth/auth_notifier.dart';
import '../../providers/auth/auth_state.dart';
import '../../providers/map/map_settings_provider.dart';
import '../../providers/core/providers.dart';
import '../../providers/core/speed_dial_provider.dart';
import '../../providers/map/live_location_provider.dart';
import '../../providers/messages/incoming_message_provider.dart';
import '../../providers/messages/unread_messages_notifier.dart';
import '../../providers/notifications/incoming_notification_provider.dart';
import '../../providers/notifications/notification_notifier.dart';
import '../../providers/navigation_state.dart';
import '../../services/osrm_service.dart';
import '../../services/live_location_service.dart';
import '../../services/tts_alert_service.dart';
import '../../services/vosk_wake_word_service.dart';
import '../../theme/app_theme.dart';
import '../widgets/community_switcher.dart';
import '../widgets/message_notification_toast.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // 3 tabs — Home, Karte, Profil/Garage (combined)
  static const _allTabs = [
    ('/feed', Icons.home_rounded, Icons.home_outlined),
    ('/map', Icons.map_rounded, Icons.map_outlined),
    ('/profile', Icons.person_rounded, Icons.person_outlined),
  ];

  // Tab title mapping (for TopBar)
  static const _tabTitles = {
    '/feed': 'Feed',
    '/map': 'Karte',
    '/profile': 'Profil',
    '/garage': 'Meine Garage',
    '/market': 'Marktplatz',
  };

  StreamSubscription<IncomingMessage>? _messageSub;
  StreamSubscription<IncomingNotification>? _notifSub;
  StreamSubscription<Map<String, LiveUserPosition>>? _globalLiveSub;
  ProviderSubscription? _settingsListenSub;
  ProviderSubscription? _communityListenSub;

  // Speed-Dial animation
  late AnimationController _speedDialAnimController;
  late Animation<double> _speedDialAnim;

  @override
  void initState() {
    super.initState();
    debugPrint('[MainShell] initState() called (hashCode=$hashCode)');
    WidgetsBinding.instance.addObserver(this);
    NavigationState.instance.addListener(_onNavStateChanged);

    _speedDialAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _speedDialAnim = CurvedAnimation(
      parent: _speedDialAnimController,
      curve: Curves.easeOutCubic,
    );

    // ── Set initial route mode based on community ──
    final initCommunity = ref.read(communityProvider);
    if (initCommunity == Community.cargram) {
      NavigationState.instance.setRouteMode(RouteMode.auto);
    }

    // ── Initialize online users pipeline (ValueNotifier, no Riverpod) ──
    _initOnlineUsers();

    // ── Community switch: restart live + reload following list on community change ──
    _communityListenSub = ref.listenManual<dynamic>(communityProvider, (prev, next) {
      if (prev == null || next == null) return;
      if (prev == next) return;
      debugPrint('[MainShell] Community switched: ${prev.name} → ${next.name}');
      _onCommunityChanged();
    });

    // ── Global Live GPS: Auto-start broadcasting when app opens ──
    _autoStartGlobalLive();
    // Subscribe to live user updates globally (so all tabs see live users)
    _startGlobalLiveListener();

    // ── Request notification permission (Android 13+) ──
    _requestNotificationPermission();

    // ── Re-save FCM token now that user is logged in ──
    PushNotificationService.instance.saveFcmToken();

    // ── Process pending push notification navigation (cold start) ──
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushNotificationService.processPendingNavigation();
    });

    // Voice banner stays visible — directListenMode always on for tab nav

    // ── Start Vosk for voice tab navigation ──
    _initVoskForTabs();

    // Listen to incoming message events via the global bus.
    _messageSub = IncomingMessageBus.instance.stream.listen((message) {
      if (!mounted) return;

      // Don't show toast if on messages screen
      final location = GoRouterState.of(context).matchedLocation;
      if (location.startsWith('/messages')) return;

      final community = ref.read(communityProvider);
      final accentColor = community?.accentColor ?? AppTheme.accentDark;

      // Haptic + sound
      HapticFeedback.mediumImpact();
      _playNotifSound();

      InAppToast.showMessage(
        context,
        message: message,
        accentColor: accentColor,
        onTap: () {
          context.push('/messages/${message.conversationId}');
        },
      );
    });

    // Listen to incoming notification events via the global bus.
    _notifSub = IncomingNotificationBus.instance.stream.listen((notif) {
      if (!mounted) return;

      // Don't show toast if on notifications screen
      final location = GoRouterState.of(context).matchedLocation;
      if (location.startsWith('/notifications')) return;

      final community = ref.read(communityProvider);
      final accentColor = community?.accentColor ?? AppTheme.accentDark;

      // Haptic + sound
      HapticFeedback.lightImpact();
      _playNotifSound();

      InAppToast.showNotification(
        context,
        notification: notif,
        accentColor: accentColor,
        onTap: () {
          // Smart navigation based on notification type
          final type = notif.type;
          final dataMap = notif.data;

          if ((type == 'like' || type == 'comment' || type == 'mention') &&
              dataMap['post_id'] != null) {
            final postId = dataMap['post_id'];
            final id = postId is int ? postId : int.tryParse('$postId');
            if (id != null) {
              context.push('/post/$id');
            } else {
              context.push('/notifications');
            }
          } else if (type == 'follow' && dataMap['follower_id'] != null) {
            context.push('/profile/${dataMap['follower_id']}');
          } else if (type == 'system' && dataMap['group_id'] != null) {
            final gId = dataMap['group_id'];
            final id = gId is int ? gId : int.tryParse('$gId');
            if (id != null) {
              context.push('/group/$id');
            } else {
              context.push('/notifications');
            }
          } else {
            context.push('/notifications');
          }
        },
      );
    });
  }

  void _playNotifSound() {
    SystemSound.play(SystemSoundType.click);
  }

  // ── Vosk Tab Navigation ──
  // Tab name → route mapping for voice commands
  /// Tab voice matching — each route has multiple Vosk variants.
  /// Vosk German model often mishears short words, so we add fuzzy matches.
  static const _voiceTabRoutes = <String, String>{
    // Home / Feed
    'home': '/feed',
    'feed': '/feed',
    'feet': '/feed',
    'fied': '/feed',
    'fiet': '/feed',
    'fieb': '/feed',
    'feat': '/feed',
    // Karte
    'karte': '/map',
    'karten': '/map',
    'kater': '/map',
    'karat': '/map',
    'carte': '/map',
    // Profil / Garage
    'profil': '/profile',
    'profile': '/profile',
    'profiel': '/profile',
    'garage': '/profile',
  };

  bool _voskTabActive = false;

  Future<void> _initVoskForTabs() async {
    final ok = await VoskWakeWordService.instance.init();
    if (!ok || !mounted) return;

    // Set handler — when user enters a ride, GroupRideScreen overrides this
    VoskWakeWordService.instance.onEvent = (event, text) {
      if (!mounted) return;
      switch (event) {
        case VoskWakeEvent.wakeWordDetected:
          debugPrint('[MainShell] Wake word detected!');
          HapticFeedback.heavyImpact();
          TtsAlertService.instance.clearQueue();
          TtsAlertService.instance.stop();
          VoskWakeWordService.instance.setPaused(true);
          TtsAlertService.instance.speakText('Ja?').then((_) async {
            await Future.delayed(const Duration(milliseconds: 800));
            if (mounted) VoskWakeWordService.instance.setPaused(false);
          });
          break;

        case VoskWakeEvent.commandRecognized:
          debugPrint('[MainShell] Voice command: "$text"');
          _handleVoiceTabNavigation(text);
          break;

        case VoskWakeEvent.commandTimeout:
          break;
      }
    };

    if (!VoskWakeWordService.instance.isListening) {
      await VoskWakeWordService.instance.startListening();
      _voskTabActive = true;
      debugPrint('[MainShell] Vosk started for tab navigation');
    }

    // Wake word required — "Hi Moto" first, then tab name
    VoskWakeWordService.instance.directListenMode = false;
  }

  DateTime? _lastVoiceMiss;

  void _handleVoiceTabNavigation(String text) {
    final lower = text.toLowerCase().trim();
    // Skip very short noise (< 3 chars)
    if (lower.length < 3) return;

    // Split into words and check each against tab routes
    final words = lower.split(RegExp(r'\s+'));
    for (final word in words) {
      final route = _voiceTabRoutes[word];
      if (route != null) {
        debugPrint('[MainShell] ✓ "$word" → $route');
        HapticFeedback.mediumImpact();
        if (mounted) context.go(route);
        return;
      }
    }

    // Also try full text match (for multi-word like "markt platz")
    for (final entry in _voiceTabRoutes.entries) {
      if (lower == entry.key) {
        debugPrint('[MainShell] ✓ full match "$lower" → ${entry.value}');
        HapticFeedback.mediumImpact();
        if (mounted) context.go(entry.value);
        return;
      }
    }

    // No match — just log, don't speak (background noise causes constant TTS)
    debugPrint('[MainShell] ✗ "$lower" (ignored)');
  }

  /// Request POST_NOTIFICATIONS permission on Android 13+ (API 33).
  Future<void> _requestNotificationPermission() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final status = await Permission.notification.status;
    if (!status.isGranted) {
      await Permission.notification.request();
    }
  }

  void _onNavStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    debugPrint('[MainShell] dispose() called');
    NavigationState.instance.removeListener(_onNavStateChanged);
    WidgetsBinding.instance.removeObserver(this);
    _messageSub?.cancel();
    _notifSub?.cancel();
    _globalLiveSub?.cancel();
    _settingsListenSub?.close();
    _communityListenSub?.close();
    _speedDialAnimController.dispose();
    super.dispose();
  }

  /// Called by the OS when the app lifecycle changes.
  /// On detached (app killed) or paused (backgrounded), go offline immediately
  /// so other users see us disappear right away — no 30s grace period needed.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.detached) {
      // App killed — go fully offline so other users see us disappear.
      debugPrint('[MainShell] App lifecycle: detached — going offline');
      globalOnlineStatusService.stop();
      final service = ref.read(liveLocationServiceProvider);
      if (service.isLive) {
        service.goOffline();
        isLiveNotifier.value = false;
      }
    } else if (state == AppLifecycleState.paused) {
      // App backgrounded (screen off, app switch) — pause GPS but keep
      // heartbeat alive so we stay "online" on other users' maps.
      debugPrint('[MainShell] App lifecycle: paused — pausing GPS (staying online)');
      final service = ref.read(liveLocationServiceProvider);
      if (service.isLive) {
        service.pauseGps();
      }
      PushNotificationService.instance.updateBadge();
    } else if (state == AppLifecycleState.resumed) {
      debugPrint('[MainShell] App lifecycle: resumed — resuming GPS');
      globalOnlineStatusService.start();
      final service = ref.read(liveLocationServiceProvider);
      if (service.isLive) {
        service.resumeGps();
      }
      PushNotificationService.instance.updateBadge();
      // Re-start live if it wasn't active (e.g. after detached → reopen)
      _autoStartGlobalLive();
    }
  }

  // ─── Online Users Init ───────────────────────────────────────────────

  void _initOnlineUsers() {
    debugPrint('[MainShell] _initOnlineUsers called');
    final service = ref.read(liveLocationServiceProvider);
    final profileRepo = ref.read(profileRepositoryProvider);
    final community = ref.read(communityProvider);
    initOnlineUsers(
      service: service,
      profileRepo: profileRepo,
      community: community?.name ?? 'bikergram',
    );
  }

  /// Called when the user switches community (e.g. Bikergram → Cars).
  /// 1. Goes offline on the old community channel.
  /// 2. Restarts live with the new community key.
  /// 3. Reloads the following list for the new community.
  Future<void> _onCommunityChanged() async {
    if (!mounted) return;
    final service = ref.read(liveLocationServiceProvider);
    final wasLive = service.isLive;

    // Go offline — sends goodbye payload to old channel
    if (wasLive) {
      await service.goOffline();
      isLiveNotifier.value = false;
    }

    // Sync route mode with community: Bikergram → Biker, Cargram → Auto
    final community = ref.read(communityProvider);
    final newMode = community == Community.cargram ? RouteMode.auto : RouteMode.biker;
    debugPrint('[MainShell] Community → $community, setting RouteMode → $newMode');
    NavigationState.instance.setRouteMode(newMode);

    // Reload online users with new community filter
    _initOnlineUsers();

    // Restart live on new community if it was active before
    if (wasLive) {
      _autoStartGlobalLive();
    }
  }

  // ─── Global Live GPS ──────────────────────────────────────────────────

  /// Auto-start live broadcasting when the app opens (if liveOnMap setting is true).
  /// This runs globally — not just on the Blitzer tab.
  void _autoStartGlobalLive() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // Wait for settings to load
      final settingsAsync = ref.read(blitzerSettingsProvider);
      BlitzerSettings? settings = settingsAsync.value;

      if (settings == null) {
        // Settings still loading — listen for when they become available
        _settingsListenSub?.close();
        _settingsListenSub = ref.listenManual(blitzerSettingsProvider, (prev, next) async {
          if (!mounted) return;
          final s = next.value;
          if (s == null || !s.liveOnMap) return;
          _settingsListenSub?.close(); // Only need to trigger once
          await _doAutoStartLive();
        });
        return;
      }

      if (!settings.liveOnMap) {
        debugPrint('[GlobalLive] Auto-start skipped (liveOnMap=false)');
        return;
      }

      await _doAutoStartLive();
    });
  }

  Future<void> _doAutoStartLive() async {
    if (!mounted) return;
    final service = ref.read(liveLocationServiceProvider);
    if (service.isLive) return;

    final authState = ref.read(authNotifierProvider);
    if (authState is! Authenticated) {
      debugPrint('[GlobalLive] Auto-start skipped (not authenticated)');
      return;
    }

    final user = authState.user;
    debugPrint('[GlobalLive] Auto-starting live for ${user.displayName ?? user.username}...');

    // Load follower count + total likes
    int followers = user.followerCount;
    int totalLikes = 0;
    try {
      final profileRepo = ref.read(profileRepositoryProvider);
      final results = await Future.wait([
        profileRepo.getFollowerCount(user.id),
        profileRepo.getTotalLikes(user.id),
      ]);
      followers = results[0];
      totalLikes = results[1];
    } catch (_) {}

    if (!mounted) return;

    final community = ref.read(communityProvider);

    await service.goLive(
      userId: user.id,
      displayName: user.displayName ?? user.bikername ?? user.username,
      avatarUrl: user.avatarUrl,
      plzRegion: user.postalCode,
      xpTotal: user.xpTotal ?? 0,
      bikeName: user.bikername,
      followerCount: followers,
      totalLikes: totalLikes,
      community: community?.name ?? 'bikergram',
    );

    if (!mounted) return;
    ref.read(isLiveProvider.notifier).set(true);
    debugPrint('[GlobalLive] Auto-started live (community=${community?.name ?? 'bikergram'})');
  }

  /// Start listening to live user updates globally.
  void _startGlobalLiveListener() {
    final service = ref.read(liveLocationServiceProvider);
    _globalLiveSub = service.nearbyUsersStream.listen((_) {
      // The stream is already processed by the service.
      // Individual screens (CommunityMapScreen) listen to the same service.
      // This just ensures the service is active and the provider reflects the state.
    });
  }

  // ─── Online Users Sheet (Stack overlay — no Navigator route) ────────────

  bool _onlineSheetVisible = false;

  void _openOnlineSheet() => setState(() => _onlineSheetVisible = true);
  void _closeOnlineSheet() => setState(() => _onlineSheetVisible = false);

  // ─── Speed-Dial ─────────────────────────────────────────────────────────

  bool _speedDialBusy = false; // Prevent double-tap race condition

  void _openSpeedDial() {
    if (_speedDialBusy) return;
    _speedDialBusy = true;
    ref.read(blitzerSpeedDialProvider.notifier).open();
    _speedDialAnimController.forward().then((_) => _speedDialBusy = false);
  }

  void _closeSpeedDial() {
    if (!ref.read(blitzerSpeedDialProvider)) return; // Already closed
    _speedDialBusy = true;
    ref.read(blitzerSpeedDialProvider.notifier).close();
    _speedDialAnimController.reverse().then((_) {
      _speedDialBusy = false;
    });
  }

  void _toggleSpeedDial() {
    if (_speedDialBusy) return; // Animation in progress — ignore
    final isOpen = ref.read(blitzerSpeedDialProvider);
    if (isOpen) {
      _closeSpeedDial();
    } else {
      _openSpeedDial();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final community = ref.watch(communityProvider);
    final brightness = Theme.of(context).brightness;
    final accentColor = community?.accentColor ?? AppTheme.accentDark;

    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex =
        _allTabs.indexWhere((t) => location.startsWith(t.$1));

    final isSpeedDialOpen = ref.watch(blitzerSpeedDialProvider);

    // Speed-Dial items from active tab screen
    final speedDialItems = ref.watch(speedDialItemsProvider);

    // Tab title
    final tabTitle = _tabTitles[location] ?? community?.displayName ?? '';

    // Wrap the entire Scaffold in a Stack so the Speed-Dial overlay
    // covers EVERYTHING (including the BottomNavigationBar).
    return Stack(
      children: [
        Scaffold(
      body: Stack(
        children: [
          // ── Tab content ──
          // On web: constrain feed/profile/etc to mobile-like width (like Instagram Web).
          // Map stays full-width.
          kIsWeb && !location.startsWith('/map')
              ? Center(child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: widget.child,
                ))
              : widget.child,

          // ── Global Top Bar (animated slide for feed scroll, instant for navigation) ──
          // IMPORTANT: Positioned MUST be a direct child of Stack.
          // Wrapping it inside AnimatedSlide/AnimatedOpacity causes
          // "ParentData is not a subtype of StackParentData" → grey overlay in release.
          Positioned(
            top: 0, left: 0, right: 0,
            child: AnimatedSlide(
              offset: NavigationState.instance.barsVisible ? Offset.zero : const Offset(0, -1),
              duration: NavigationState.instance.feedScrolling || !NavigationState.instance.barsVisible
                  ? const Duration(milliseconds: 200)
                  : const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: NavigationState.instance.barsVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: _buildGlobalTopBar(
                  community: community,
                  brightness: brightness,
                  accentColor: accentColor,
                  title: tabTitle,
                  location: location,
                ),
              ),
            ),
          ),
        ],
      ),
    ), // end Scaffold — no bottomNavigationBar (moved to Stack)

          // ── Bottom Nav Bar (in Stack, slides down completely on scroll) ──
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: AnimatedSlide(
              offset: NavigationState.instance.barsVisible ? Offset.zero : const Offset(0, 1),
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: NavigationState.instance.barsVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Material(
                  color: community?.navBarFor(brightness) ?? (brightness == Brightness.dark ? const Color(0xFF0D0D0D) : const Color(0xFFF5F5F5)),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: community?.accentGlow ?? Colors.white.withValues(alpha: 0.06),
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewPadding.bottom,
                      ),
                      child: SizedBox(
                        height: kIsWeb ? 48 : 34,
                        child: Row(
                          children: [
                            for (int i = 0; i < _allTabs.length; i++)
                              _buildTab(
                                context,
                                tab: _allTabs[i],
                                isActive: i == currentIndex,
                                accentColor: accentColor,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

        // ── Speed-Dial Overlay (full-screen, covers BottomNav too) ──
        if (isSpeedDialOpen && speedDialItems.isNotEmpty)
          _buildSpeedDialOverlay(
            items: speedDialItems,
            accentColor: accentColor,
            brightness: brightness,
          ),

        // ── Online Users Overlay (no Navigator route — no grey flash) ──
        if (_onlineSheetVisible)
          _buildOnlineUsersOverlay(accentColor: accentColor, brightness: brightness),
      ], // end outer Stack children
    ); // end outer Stack
  }

  // ─── Global Top Bar ─────────────────────────────────────────────────────

  Widget _buildGlobalTopBar({
    required Community? community,
    required Brightness brightness,
    required Color accentColor,
    required String title,
    required String location,
  }) {
    final textColor = community?.textColor(brightness) ??
        (brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A));
    final iconColor = brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.7)
        : const Color(0xFF6C757D);

    // On map screen: transparent (map shows through). On other tabs: scaffold bg.
    final isMapScreen = location == '/map' || location == '/events';
    final isDark = brightness == Brightness.dark;
    final bgColor = isMapScreen
        ? (isDark ? const Color(0xFF0D0D0D) : Colors.white.withValues(alpha: 0.85))
        : (community?.scaffoldFor(brightness) ??
            (isDark ? Colors.black : const Color(0xFFF5F5F5)));

    // Im Karten-Tab: Icons brauchen guten Kontrast gegen die Karte.
    final mapIconColor = isDark
        ? Colors.white.withValues(alpha: 0.9)
        : const Color(0xFF1A1A1A);
    final effectiveIconColor = isMapScreen ? mapIconColor : iconColor;

    final mapBoxColor = isDark
        ? const Color(0xFF0D0D0D)
        : Colors.white.withValues(alpha: 0.85);

    Widget iconRow = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 0,
      children: [
        // Live Online badge
        _buildLiveOnlineBadge(accentColor, location),
        _buildNotificationIcon(accentColor, effectiveIconColor),
        _buildMessageIcon(accentColor, effectiveIconColor),
        IconButton(
          onPressed: () => context.push('/search'),
          icon: Icon(Icons.search_rounded, color: effectiveIconColor, size: kIsWeb ? 22 : 16),
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(minWidth: kIsWeb ? 36 : 24, minHeight: kIsWeb ? 44 : 34),
        ),
        if (location == '/profile')
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: Icon(Icons.settings_outlined, color: effectiveIconColor, size: kIsWeb ? 22 : 16),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(minWidth: kIsWeb ? 36 : 24, minHeight: kIsWeb ? 44 : 34),
          )
        else
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.go('/profile'),
            child: _buildProfileAvatar(accentColor),
          ),
      ],
    );

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: SizedBox(
          height: kIsWeb ? 48 : 38,
          child: Row(
            children: [
              const CommunitySwitcher(),
              const Spacer(),
              iconRow,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationIcon(Color accentColor, Color iconColor) {
    final notifState = ref.watch(notificationNotifierProvider);
    final unreadCount = notifState.unreadCount;

    return IconButton(
      onPressed: () => context.push('/notifications'),
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(minWidth: kIsWeb ? 36 : 24, minHeight: kIsWeb ? 44 : 34),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(Icons.notifications_outlined, color: iconColor, size: kIsWeb ? 22 : 16),
          if (unreadCount > 0)
            Positioned(
              right: -4, top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: Colors.black, width: 1),
                ),
                child: Center(
                  child: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    style: GoogleFonts.inter(fontSize: 7, fontWeight: FontWeight.w700, color: Colors.white, height: 1),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageIcon(Color accentColor, Color iconColor) {
    final unreadCount = ref.watch(unreadMessagesProvider);

    return IconButton(
      onPressed: () => context.push('/messages'),
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(minWidth: kIsWeb ? 36 : 24, minHeight: kIsWeb ? 44 : 34),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(Icons.chat_bubble_outline_rounded, color: iconColor, size: kIsWeb ? 22 : 16),
          if (unreadCount > 0)
            Positioned(
              right: -4, top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: Colors.black, width: 1),
                ),
                child: Center(
                  child: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    style: GoogleFonts.inter(fontSize: 7, fontWeight: FontWeight.w700, color: Colors.white, height: 1),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProfileAvatar(Color accentColor) {
    final authState = ref.watch(authNotifierProvider);
    final community = ref.watch(communityProvider);
    final user = authState is Authenticated ? authState.user : null;
    final initial = (user?.displayName ?? user?.username ?? 'U')
        .characters.first.toUpperCase();

    final avatarUrl = community == Community.cargram
        ? (user?.avatarUrlCargram ?? user?.avatarUrl)
        : user?.avatarUrl;

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      final avatarSize = kIsWeb ? 34.0 : 28.0;
      return Container(
        width: avatarSize, height: avatarSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: accentColor, width: 2),
        ),
        child: ClipOval(
          child: Image.network(avatarUrl, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildInitialAvatar(initial, accentColor)),
        ),
      );
    }
    return _buildInitialAvatar(initial, accentColor);
  }

  Widget _buildInitialAvatar(String initial, Color accentColor) {
    final avatarSize = kIsWeb ? 34.0 : 28.0;
    return Container(
      width: avatarSize, height: avatarSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [accentColor, accentColor.withValues(alpha: 0.6)]),
      ),
      child: Center(
        child: Text(initial, style: GoogleFonts.inter(fontSize: kIsWeb ? 15 : 13, fontWeight: FontWeight.w700, color: Colors.white)),
      ),
    );
  }

  // ─── Speed-Dial Overlay ─────────────────────────────────────────────────

  Widget _buildSpeedDialOverlay({
    required List<SpeedDialItem> items,
    required Color accentColor,
    required Brightness brightness,
  }) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    // BottomNav height: 60 + safe area bottom + top border
    final bottomNavHeight = 60.0 + bottomPad + 1;

    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: Stack(children: [
          // Backdrop — covers ENTIRE screen (incl. BottomNav area)
          Positioned.fill(child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _closeSpeedDial,
            child: Container(color: Colors.black.withValues(alpha: 0.4)),
          )),
          // Speed-Dial Items — positioned above the BottomNav
          Positioned(
            bottom: bottomNavHeight + 12, left: 0, right: 0,
            child: AnimatedBuilder(
              animation: _speedDialAnim,
              builder: (context, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = items.length - 1; i >= 0; i--)
                    _buildSpeedDialItemWidget(
                      item: items[i],
                      index: items.length - 1 - i,
                      total: items.length,
                      brightness: brightness,
                    ),
                ],
              ),
            ),
          ),
          // Floating Close Button (× icon at BottomNav center position)
          Positioned(
            bottom: bottomPad + 10,
            left: 0, right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _closeSpeedDial,
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [accentColor, accentColor.withValues(alpha: 0.7)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: accentColor.withValues(alpha: 0.5), blurRadius: 14, offset: const Offset(0, 4))],
                  ),
                  child: const AnimatedRotation(
                    turns: 0.125,
                    duration: Duration(milliseconds: 250),
                    child: Icon(Icons.add_rounded, color: Colors.white, size: 24),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildSpeedDialItemWidget({
    required SpeedDialItem item,
    required int index,
    required int total,
    required Brightness brightness,
  }) {
    final staggerStart = (index / total) * 0.4;
    final staggerEnd = (staggerStart + 0.6).clamp(0.0, 1.0);
    final itemAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _speedDialAnimController,
        curve: Interval(staggerStart.clamp(0.0, 1.0), staggerEnd, curve: Curves.easeOutCubic),
      ),
    );

    return AnimatedBuilder(
      animation: itemAnim,
      builder: (context, child) {
        final v = itemAnim.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: v,
          child: Transform.translate(offset: Offset(0, 30 * (1 - v)), child: child),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: GestureDetector(
          onTap: () {
            final callback = item.onTap;
            _closeSpeedDial();
            // Delay the callback so Flutter can finish the close-rebuild
            // before the item action (which may call setState on a child widget).
            Future.microtask(() {
              if (!mounted) return;
              callback();
            });
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Text(item.label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: brightness == Brightness.dark ? Colors.white : Colors.black87)),
              ),
              const SizedBox(width: 10),
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: item.color,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: item.color.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 3))],
                ),
                child: Icon(item.icon, color: Colors.white, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Tab Button ─────────────────────────────────────────────────────────

  /// Combined Profil/Garage icon — person silhouette with small car badge
  Widget _buildProfileGarageIcon(bool isActive, Color accentColor) {
    final inactiveColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.4)
        : const Color(0xFF6C757D);
    final color = isActive ? accentColor : inactiveColor;

    return SizedBox(
      key: ValueKey('profile_garage_$isActive'),
      width: kIsWeb ? 40 : 32,
      height: kIsWeb ? 34 : 28,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Main person icon
          Positioned(
            left: 0,
            top: 0,
            child: Icon(
              isActive ? Icons.person_rounded : Icons.person_outlined,
              color: color,
              size: kIsWeb ? 32 : 26,
            ),
          ),
          // Small car badge bottom-right
          Positioned(
            right: -2,
            bottom: -2,
            child: Icon(
              Icons.directions_car_rounded,
              color: color,
              size: kIsWeb ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(
    BuildContext context, {
    required (String, IconData, IconData) tab,
    required bool isActive,
    required Color accentColor,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () {
          if (!isActive) {
            // Reset immersive scroll when switching tabs
            NavigationState.instance.setFeedScrolling(false);
            if (ref.read(blitzerSpeedDialProvider)) _closeSpeedDial();
            if (_onlineSheetVisible) {
              _closeOnlineSheet();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) context.go(tab.$1);
              });
            } else {
              context.go(tab.$1);
            }
          }
        },
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: tab.$1 == '/profile'
                ? _buildProfileGarageIcon(isActive, accentColor)
                : Icon(
                    isActive ? tab.$2 : tab.$3,
                    key: ValueKey('${tab.$1}_$isActive'),
                    color: isActive
                        ? accentColor
                        : (Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.4) : const Color(0xFF6C757D)),
                    size: kIsWeb ? 32 : 26,
                  ),
          ),
        ),
      ),
    );
  }

  // ─── Live Online Badge ─────────────────────────────────────────────────

  Widget _buildLiveOnlineBadge(Color accentColor, String location) {
    // Uses a dedicated stateless widget so Flutter's element reconciliation
    // can detect "same widget, same key" and skip re-rendering on parent rebuilds
    // (e.g. keyboard open/close). Only the ValueNotifier changes trigger updates.
    return _LiveOnlineBadgeWidget(onTap: _openOnlineSheet);
  }

  /// Online users overlay — rendered directly in the Stack, NO Navigator route.
  /// This prevents the "grey flash/curtain" that occurs when a ModalBottomSheet
  /// route is in the stack during a GoRouter tab navigation.
  Widget _buildOnlineUsersOverlay({
    required Color accentColor,
    required Brightness brightness,
  }) {
    final isDark = brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF111111) : const Color(0xFFF8F9FA);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final mutedColor = isDark ? Colors.white60 : const Color(0xFF6C757D);

    return ValueListenableBuilder<Map<String, LiveUserPosition>>(
      valueListenable: onlineUsersNotifier,
      builder: (context, onlineUsersMap, _) {
        final users = onlineUsersMap.values.toList()
          ..sort((a, b) => b.speed.compareTo(a.speed));

        return Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _closeOnlineSheet,
            child: Container(
              color: Colors.black.withValues(alpha: 0.4),
              alignment: Alignment.bottomCenter,
              child: GestureDetector(
                onTap: () {}, // absorb taps on sheet itself
                child: Material(
                  type: MaterialType.transparency,
                  child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.65,
                  ),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const SizedBox(height: 12),
                    Center(child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: mutedColor.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    )),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(children: [
                        Container(
                          width: 12, height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF00E676),
                            boxShadow: [
                              BoxShadow(color: const Color(0xFF00E676).withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 2),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${users.length} Biker online',
                          style: GoogleFonts.inter(
                            fontSize: 20, fontWeight: FontWeight.w800, color: textColor,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00C853).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('ONLINE', style: GoogleFonts.inter(
                            fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF00E676),
                            letterSpacing: 1.2,
                          )),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: users.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.two_wheeler_rounded, size: 48, color: mutedColor.withValues(alpha: 0.3)),
                              const SizedBox(height: 12),
                              Text('Keine Biker online', style: GoogleFonts.inter(
                                fontSize: 15, fontWeight: FontWeight.w500, color: mutedColor,
                              )),
                              const SizedBox(height: 4),
                              Text('Deine gefolgten Rider erscheinen hier', style: GoogleFonts.inter(
                                fontSize: 12, color: mutedColor.withValues(alpha: 0.7),
                              )),
                            ]),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            itemCount: users.length,
                            itemBuilder: (_, i) {
                              final u = users[i];
                              final hasSpeed = u.speed > 1;
                              final hasBike = u.bikeName != null && u.bikeName!.isNotEmpty;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () {
                                      _closeOnlineSheet();
                                      context.push('/profile/${u.userId}');
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: cardColor,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: isDark
                                              ? Colors.white.withValues(alpha: 0.06)
                                              : Colors.black.withValues(alpha: 0.06),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(children: [
                                        Container(
                                          width: 48, height: 48,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(color: const Color(0xFF00E676), width: 2.5),
                                            boxShadow: [BoxShadow(color: const Color(0xFF00E676).withValues(alpha: 0.3), blurRadius: 8)],
                                          ),
                                          child: CircleAvatar(
                                            radius: 21,
                                            backgroundColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0),
                                            backgroundImage: u.avatarUrl != null && u.avatarUrl!.isNotEmpty
                                                ? NetworkImage(u.avatarUrl!) : null,
                                            child: u.avatarUrl == null || u.avatarUrl!.isEmpty
                                                ? Text(
                                                    u.displayName.isNotEmpty ? u.displayName[0].toUpperCase() : '?',
                                                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: accentColor),
                                                  )
                                                : null,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(u.displayName, style: GoogleFonts.inter(
                                              fontSize: 15, fontWeight: FontWeight.w700, color: textColor, letterSpacing: -0.2,
                                            ), maxLines: 1, overflow: TextOverflow.ellipsis),
                                            const SizedBox(height: 4),
                                            Row(children: [
                                              if (hasSpeed) ...[
                                                _buildInfoChip(icon: Icons.speed_rounded, text: '${u.speed.toStringAsFixed(0)} km/h', color: accentColor, isDark: isDark),
                                                const SizedBox(width: 6),
                                              ],
                                              if (hasBike)
                                                Flexible(child: _buildInfoChip(icon: Icons.two_wheeler_rounded, text: u.bikeName!, color: mutedColor, isDark: isDark)),
                                              if (!hasSpeed && !hasBike)
                                                _buildInfoChip(icon: Icons.location_on_rounded, text: 'Unterwegs', color: mutedColor, isDark: isDark),
                                            ]),
                                          ],
                                        )),
                                        Container(
                                          width: 32, height: 32,
                                          decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                                          child: Icon(Icons.navigation_rounded, size: 16, color: accentColor),
                                        ),
                                      ]),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                    ),
                  ]),
                ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Small info chip used in the online users sheet.
  Widget _buildInfoChip({
    required IconData icon,
    required String text,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        Flexible(child: Text(text, style: GoogleFonts.inter(
          fontSize: 11, fontWeight: FontWeight.w600, color: color,
        ), maxLines: 1, overflow: TextOverflow.ellipsis)),
      ]),
    );
  }

}

/// Standalone widget for the live online badge.
/// By being its own widget class with a stable identity in the tree,
/// Flutter's element reconciliation won't recreate it on parent rebuilds
/// (keyboard open/close, tab switch, etc.). Only ValueNotifier changes trigger repaints.
class _LiveOnlineBadgeWidget extends StatelessWidget {
  const _LiveOnlineBadgeWidget({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, LiveUserPosition>>(
      valueListenable: onlineUsersNotifier,
      builder: (context, onlineUsers, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: isLiveNotifier,
          builder: (context, isLive, _) {
            // Nur gefolgte User zählen — sich selbst NICHT mitzählen
            final liveCount = onlineUsers.length;
            // Badge ist IMMER sichtbar neben der Glocke

            final isDark = Theme.of(context).brightness == Brightness.dark;

            return GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '$liveCount',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                  ),
                ]),
              ),
            );
          },
        );
      },
    );
  }
}
