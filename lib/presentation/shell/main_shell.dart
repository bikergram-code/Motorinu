import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:permission_handler/permission_handler.dart';

import '../../core/community.dart';
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
import '../../services/live_location_service.dart';
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
  // Left tabs: Feed, Karte, Live
  static const _tabsLeft = [
    ('/feed', Icons.home_rounded, Icons.home_outlined, 'Feed'),
    ('/map', Icons.map_rounded, Icons.map_outlined, 'Karte'),
    ('/live', Icons.live_tv_rounded, Icons.live_tv_outlined, 'Live'),
  ];

  // Right tabs: Events, Markt, Garage
  static const _tabsRight = [
    ('/events', Icons.event_rounded, Icons.event_outlined, 'Events'),
    ('/market', Icons.storefront_rounded, Icons.storefront_outlined, 'Markt'),
    ('/garage', Icons.garage_rounded, Icons.garage_outlined, 'Garage'),
  ];

  // All tabs combined for index matching
  static const _allTabs = [..._tabsLeft, ..._tabsRight];

  // Tab title mapping
  static const _tabTitles = {
    '/feed': 'Feed',
    '/map': 'Karte',
    '/live': 'Live',
    '/events': 'Events',
    '/garage': 'Garage',
    '/market': 'Markt',
    '/profile': 'Profil',
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

    _speedDialAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _speedDialAnim = CurvedAnimation(
      parent: _speedDialAnimController,
      curve: Curves.easeOutCubic,
    );

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

  /// Request POST_NOTIFICATIONS permission on Android 13+ (API 33).
  Future<void> _requestNotificationPermission() async {
    if (!Platform.isAndroid) return;
    final status = await Permission.notification.status;
    if (!status.isGranted) {
      await Permission.notification.request();
    }
  }

  @override
  void dispose() {
    debugPrint('[MainShell] dispose() called');
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
    if (state == AppLifecycleState.detached ||
        state == AppLifecycleState.paused) {
      debugPrint('[MainShell] App lifecycle: $state — going offline');
      final service = ref.read(liveLocationServiceProvider);
      if (service.isLive) {
        service.goOffline();
        isLiveNotifier.value = false;
      }
    } else if (state == AppLifecycleState.resumed) {
      debugPrint('[MainShell] App lifecycle: resumed — re-checking live state');
      // Re-start live if it was active before the pause
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
    final hasSpeedDial = speedDialItems.isNotEmpty;

    // Tab title
    final tabTitle = _tabTitles[location] ?? community?.displayName ?? '';

    // Wrap the entire Scaffold in a Stack so the Speed-Dial overlay
    // covers EVERYTHING (including the BottomNavigationBar).
    return Stack(
      children: [
        Scaffold(
      body: Stack(
        children: [
          // ── Tab content (full screen) ──
          widget.child,

          // ── Global Top Bar ──
          _buildGlobalTopBar(
            community: community,
            brightness: brightness,
            accentColor: accentColor,
            title: tabTitle,
            location: location,
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: community?.navBarFor(brightness) ?? (brightness == Brightness.dark ? const Color(0xFF0D0D0D) : const Color(0xFFF5F5F5)),
          border: Border(
            top: BorderSide(
              color: community?.accentGlow ?? Colors.white.withValues(alpha: 0.06),
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 60,
            child: Row(
              children: [
                // ── Left tabs ──
                for (int i = 0; i < _tabsLeft.length; i++)
                  _buildTab(
                    context,
                    tab: _tabsLeft[i],
                    isActive: i == currentIndex,
                    accentColor: accentColor,
                  ),

                // ── Center "+" Smart Button ──
                _buildCenterButton(
                  location: location,
                  accentColor: accentColor,
                  isSpeedDialOpen: isSpeedDialOpen,
                  hasSpeedDial: hasSpeedDial,
                ),

                // ── Right tabs ──
                for (int i = 0; i < _tabsRight.length; i++)
                  _buildTab(
                    context,
                    tab: _tabsRight[i],
                    isActive: (i + _tabsLeft.length) == currentIndex,
                    accentColor: accentColor,
                  ),
              ],
            ),
          ),
        ),
      ),
    ), // end Scaffold

        // ── Speed-Dial Overlay (full-screen, covers BottomNav too) ──
        if (isSpeedDialOpen && hasSpeedDial)
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

    // On map screen use transparent bg. On other tabs use scaffold bg.
    final isMapScreen = location == '/map';
    final bgColor = isMapScreen
        ? (brightness == Brightness.dark
            ? Colors.black.withValues(alpha: 0.6)
            : Colors.white.withValues(alpha: 0.85))
        : (community?.scaffoldFor(brightness) ??
            (brightness == Brightness.dark ? Colors.black : const Color(0xFFF5F5F5)));

    // Im Karten-Tab: Icons bekommen eine Hintergrundbox für bessere Lesbarkeit.
    final mapIconColor = Colors.white.withValues(alpha: 0.9);
    final effectiveIconColor = isMapScreen ? mapIconColor : iconColor;

    final mapBoxColor = brightness == Brightness.dark
        ? Colors.black.withValues(alpha: 0.30)
        : Colors.white.withValues(alpha: 0.75);

    Widget iconRow = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 0,
      children: [
        // Live Online badge
        _buildLiveOnlineBadge(accentColor, location),
        _buildNotificationIcon(accentColor, effectiveIconColor),
        _buildMessageIcon(accentColor, effectiveIconColor),
        IconButton(
          onPressed: () => context.push('/groups'),
          icon: Icon(Icons.groups_rounded, color: effectiveIconColor, size: 16),
          tooltip: 'Gruppen',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 20, minHeight: 34),
        ),
        IconButton(
          onPressed: () => context.push('/search'),
          icon: Icon(Icons.search_rounded, color: effectiveIconColor, size: 16),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 20, minHeight: 34),
        ),
        if (location == '/profile')
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: Icon(Icons.settings_outlined, color: effectiveIconColor, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 20, minHeight: 34),
          )
        else
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.go('/profile'),
            child: _buildProfileAvatar(accentColor),
          ),
      ],
    );

    // Karten-Tab: Pill-Box um Icons
    if (isMapScreen) {
      iconRow = Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: mapBoxColor,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: iconRow,
      );
    }

    return Positioned(
      top: 0, left: 0, right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const CommunitySwitcher(),
              const SizedBox(width: 4),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: iconRow,
                ),
              ),
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
      constraints: const BoxConstraints(minWidth: 20, minHeight: 34),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(Icons.notifications_outlined, color: iconColor, size: 16),
          if (unreadCount > 0)
            Positioned(
              right: -6, top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.black, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
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
      constraints: const BoxConstraints(minWidth: 20, minHeight: 34),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(Icons.chat_bubble_outline_rounded, color: iconColor, size: 16),
          if (unreadCount > 0)
            Positioned(
              right: -6, top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.black, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
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
      return Container(
        width: 20, height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: accentColor.withValues(alpha: 0.8), width: 1.5),
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
    return Container(
      width: 20, height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [accentColor, accentColor.withValues(alpha: 0.6)]),
      ),
      child: Center(
        child: Text(initial, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
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

  // ─── Center "+" Button ─────────────────────────────────────────────────

  Widget _buildCenterButton({
    required String location,
    required Color accentColor,
    required bool isSpeedDialOpen,
    required bool hasSpeedDial,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (hasSpeedDial) {
            _toggleSpeedDial();
          }
        },
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [accentColor, accentColor.withValues(alpha: 0.7)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: AnimatedRotation(
              turns: isSpeedDialOpen ? 0.125 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Tab Button ─────────────────────────────────────────────────────────

  Widget _buildTab(
    BuildContext context, {
    required (String, IconData, IconData, String) tab,
    required bool isActive,
    required Color accentColor,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () {
          if (!isActive) {
            if (ref.read(blitzerSpeedDialProvider)) _closeSpeedDial();
            if (_onlineSheetVisible) {
              _closeOnlineSheet();
              // Wait for the setState rebuild to finish before navigating.
              // This prevents a grey frame caused by GoRouter starting
              // its transition while the overlay is still being removed.
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isActive ? tab.$2 : tab.$3,
                key: ValueKey('${tab.$4}_$isActive'),
                color: isActive
                    ? accentColor
                    : (Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.4) : const Color(0xFF6C757D)),
                size: 22,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              tab.$4,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive
                    ? accentColor
                    : (Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.4) : const Color(0xFF6C757D)),
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
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
                          '${users.length + (isLiveNotifier.value ? 1 : 0)} Biker online',
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
                                      ref.read(focusMapTargetProvider.notifier).focusOn(
                                        FocusMapTarget(
                                          position: LatLng(u.lat, u.lng),
                                          userId: u.userId,
                                          displayName: u.displayName,
                                          zoom: 15,
                                        ),
                                      );
                                      _closeOnlineSheet();
                                      context.go('/map');
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
            // Anzahl online User — immer mindestens 1 (der eigene User)
            final othersCount = onlineUsers.length;
            final liveCount = othersCount > 0 ? othersCount + 1 : 1;
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
