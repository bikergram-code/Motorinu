import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/community.dart';
import '../providers/auth/auth_notifier.dart';
import '../providers/auth/auth_state.dart';
import '../providers/core/providers.dart';
import '../presentation/onboarding/community_selection_screen.dart';
import '../presentation/onboarding/login_screen.dart';
import '../presentation/onboarding/complete_profile_screen.dart';
import '../presentation/onboarding/register_screen.dart';
import '../presentation/onboarding/app_tour_screen.dart';
import '../presentation/shell/main_shell.dart';
import '../presentation/feed/feed_screen.dart';
import '../presentation/garage/garage_screen.dart';
import '../presentation/marketplace/marketplace_screen.dart';
import '../presentation/profile/profile_screen.dart';
import '../presentation/map/community_map_screen.dart';
import '../presentation/events/events_screen.dart';
import '../presentation/messages/messages_screen.dart';
import '../presentation/messages/chat_detail_screen.dart';
import '../presentation/notifications/notifications_screen.dart';
import '../presentation/settings/settings_screen.dart';
import '../presentation/map/map_settings_screen.dart';
import '../presentation/feed/post_detail_screen.dart';
import '../presentation/search/user_search_screen.dart';
import '../presentation/live/live_browse_screen.dart';
import '../presentation/live/live_viewer_screen.dart';
import '../presentation/live/go_live_screen.dart';
import '../presentation/profile/saved_posts_screen.dart';
import '../presentation/groups/group_detail_screen.dart';
import '../presentation/groups/group_ride_screen.dart';
import '../presentation/groups/groups_screen.dart';
import '../presentation/navigation/mapbox_nav_screen.dart';
import '../presentation/navigation/mapbox_ride_screen.dart';
import '../presentation/tracker/ride_history_screen.dart';
import '../presentation/marketplace/marketplace_detail_screen.dart';
import '../presentation/dating/dating_screen.dart';

/// Global navigator key for push notification navigation.
final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

// ---------------------------------------------------------------------------
// Motorsport-style page transition — fast diagonal slide + fade.
// Inspired by race-car HUD transitions: sharp entry from the right with
// a subtle upward shift and a quick fade. Duration: 260ms.
// ---------------------------------------------------------------------------
Page<T> _motoPage<T>({required LocalKey key, required Widget child}) {
  return CustomTransitionPage<T>(
    key: key,
    // Wrap child in black container so the transition never shows white
    child: ColoredBox(color: const Color(0xFF000000), child: child),
    opaque: true,
    barrierColor: const Color(0xFF000000),
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // Entry: slide from right + slight upward drift + fade
      final slide = Tween<Offset>(
        begin: const Offset(0.06, 0.015),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      ));

      // Exit: slide slightly left (push-off feel)
      final exitSlide = Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(-0.04, 0),
      ).animate(CurvedAnimation(
        parent: secondaryAnimation,
        curve: Curves.easeInCubic,
      ));

      // Fade starts at 0.85 — nearly opaque from start, no white flash
      final fade = Tween<double>(begin: 0.85, end: 1.0).animate(
        CurvedAnimation(
          parent: animation,
          curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
        ),
      );

      return SlideTransition(
        position: exitSlide,
        child: SlideTransition(
          position: slide,
          child: FadeTransition(
            opacity: fade,
            child: child,
          ),
        ),
      );
    },
  );
}

// ---------------------------------------------------------------------------
// GoRouter refresh notifier — listens to auth & community changes and
// notifies GoRouter to re-evaluate its redirect WITHOUT recreating the
// entire router (and destroying the widget tree).
// ---------------------------------------------------------------------------
class _GoRouterRefreshNotifier extends ChangeNotifier {
  _GoRouterRefreshNotifier(Ref ref) {
    // Listen to auth state changes — trigger redirect re-evaluation
    ref.listen<AuthState>(authNotifierProvider, (_, __) {
      debugPrint('[Router] Auth changed — triggering redirect');
      notifyListeners();
    });

    // Listen to community changes — trigger redirect re-evaluation
    ref.listen<Community?>(communityProvider, (_, __) {
      debugPrint('[Router] Community changed — triggering redirect');
      notifyListeners();
    });
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  // Create the refresh notifier that listens to auth & community changes.
  // This calls notifyListeners() when auth/community change, which tells
  // GoRouter to re-run its redirect — WITHOUT destroying the router itself.
  final refreshNotifier = _GoRouterRefreshNotifier(ref);

  ref.onDispose(() {
    refreshNotifier.dispose();
  });

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      // Read the CURRENT values each time redirect runs.
      // Using ref.read() here (not ref.watch()) so we don't create
      // a dependency that would recreate the entire provider.
      final authState = ref.read(authNotifierProvider);
      final community = ref.read(communityProvider);

      final loc = state.matchedLocation;

      // No community selected → go to selection
      if (community == null) {
        if (loc == '/') return null;
        return '/';
      }

      final isAuthRoute =
          loc == '/' || loc == '/login' || loc == '/register';
      final isOnboarding = loc == '/complete-profile';
      final isAppTour = loc == '/app-tour';

      // Still checking auth on startup → don't redirect.
      // IMPORTANT: Don't redirect away from the current page during a
      // profile refresh (e.g. after editing). The user should stay where
      // they are while auth re-checks in the background.
      if (authState is AuthInitial || authState is AuthLoading) {
        return null;
      }

      // Definitively not authenticated → go to login
      if (authState is Unauthenticated || authState is AuthError) {
        if (!isAuthRoute && !isOnboarding && !isAppTour) return '/login';
        return null;
      }

      // Authenticated → check if profile is complete
      if (authState is Authenticated) {
        final needsOnboarding = authState.user.birthYear == null;

        // App tour is always allowed for authenticated users
        if (isAppTour) return null;

        // On auth route (login/register/community) → go to onboarding or feed
        if (isAuthRoute) {
          return needsOnboarding ? '/complete-profile' : '/feed';
        }
        // On onboarding page but profile is already complete → go to feed
        if (isOnboarding && !needsOnboarding) {
          return '/feed';
        }
        // All other routes: allow navigation normally.
        // Onboarding is non-blocking — user can complete profile later.
      }

      return null;
    },
    routes: [
      // Community selection (first launch)
      GoRoute(
        path: '/',
        builder: (_, __) => const CommunitySelectionScreen(),
      ),

      // Auth routes
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (_, __) => const RegisterScreen(),
      ),

      // App tour after registration
      GoRoute(
        path: '/app-tour',
        builder: (_, __) => const AppTourScreen(),
      ),

      // Complete profile after social sign-in
      GoRoute(
        path: '/complete-profile',
        builder: (_, __) => const CompleteProfileScreen(),
      ),

      // Main app with bottom navigation shell — 3 tabs: Home, Karte, Profil/Garage
      ShellRoute(
        builder: (_, __, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/feed',
            pageBuilder: (_, state) => NoTransitionPage(
              key: state.pageKey,
              child: const FeedScreen(),
            ),
          ),
          GoRoute(
            path: '/map',
            pageBuilder: (_, state) => NoTransitionPage(
              key: state.pageKey,
              child: const MapboxRideScreen(), // Freie Fahrt — Mapbox statt Google Maps
            ),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (_, state) => NoTransitionPage(
              key: state.pageKey,
              child: const ProfileScreen(),
            ),
          ),
          GoRoute(
            path: '/events',
            pageBuilder: (_, state) => NoTransitionPage(
              key: state.pageKey,
              child: const EventsScreen(),
            ),
          ),
          GoRoute(
            path: '/garage',
            pageBuilder: (_, state) => NoTransitionPage(
              key: state.pageKey,
              child: const GarageScreen(),
            ),
          ),
          GoRoute(
            path: '/market',
            pageBuilder: (_, state) => NoTransitionPage(
              key: state.pageKey,
              child: const MarketplaceScreen(),
            ),
          ),
        ],
      ),

      // Full-screen routes (no bottom nav) — motorsport transition
      GoRoute(
        path: '/live',
        pageBuilder: (_, state) => _motoPage(
          key: state.pageKey,
          child: const LiveBrowseScreen(),
        ),
      ),
      GoRoute(
        path: '/garage/:userId',
        pageBuilder: (_, state) => _motoPage(
          key: state.pageKey,
          child: GarageScreen(userId: state.pathParameters['userId']),
        ),
      ),
      GoRoute(
        path: '/market/:userId',
        pageBuilder: (_, state) => _motoPage(
          key: state.pageKey,
          child: MarketplaceScreen(userId: state.pathParameters['userId']),
        ),
      ),
      GoRoute(
        path: '/listing/:id',
        pageBuilder: (_, state) {
          final id = int.parse(state.pathParameters['id']!);
          return _motoPage(
            key: state.pageKey,
            child: MarketplaceDetailScreen(listingId: id),
          );
        },
      ),
      GoRoute(
        path: '/achievements/:userId',
        pageBuilder: (_, state) => _motoPage(
          key: state.pageKey,
          child: GarageScreen(userId: state.pathParameters['userId']), // TODO: AchievementsScreen
        ),
      ),
      GoRoute(
        path: '/messages',
        pageBuilder: (_, state) {
          final filter = state.uri.queryParameters['filter'];
          return _motoPage(
            key: state.pageKey,
            child: MessagesScreen(initialFilter: filter),
          );
        },
      ),
      GoRoute(
        path: '/messages/:conversationId',
        pageBuilder: (_, state) {
          final id = int.parse(state.pathParameters['conversationId']!);
          return _motoPage(
            key: state.pageKey,
            child: ChatDetailScreen(conversationId: id),
          );
        },
      ),
      GoRoute(
        path: '/groups',
        pageBuilder: (_, state) => _motoPage(
          key: state.pageKey,
          child: const GroupsScreen(),
        ),
      ),
      GoRoute(
        path: '/group/:groupId',
        pageBuilder: (_, state) {
          final groupId = int.parse(state.pathParameters['groupId']!);
          return _motoPage(
            key: state.pageKey,
            child: GroupDetailScreen(groupId: groupId),
          );
        },
      ),
      GoRoute(
        path: '/group-ride/:groupId',
        pageBuilder: (_, state) {
          final groupId = int.parse(state.pathParameters['groupId']!);
          // Use Mapbox ride screen (native 60fps tracking)
          return _motoPage(
            key: state.pageKey,
            child: MapboxRideScreen(groupId: groupId),
          );
        },
      ),
      GoRoute(
        path: '/profile/:userId',
        pageBuilder: (_, state) {
          final userId = state.pathParameters['userId']!;
          final showDating = state.uri.queryParameters['showDating'] == 'true';
          return _motoPage(
            key: state.pageKey,
            child: ProfileScreen(userId: userId, showDatingCard: showDating),
          );
        },
      ),
      GoRoute(
        path: '/post/:postId',
        pageBuilder: (_, state) {
          final postId = int.parse(state.pathParameters['postId']!);
          return _motoPage(
            key: state.pageKey,
            child: PostDetailScreen(postId: postId),
          );
        },
      ),
      GoRoute(
        path: '/live/start',
        pageBuilder: (_, state) => _motoPage(
          key: state.pageKey,
          child: const GoLiveScreen(),
        ),
      ),
      GoRoute(
        path: '/live/:sessionId',
        pageBuilder: (_, state) {
          final sessionId = state.pathParameters['sessionId']!;
          return _motoPage(
            key: state.pageKey,
            child: LiveViewerScreen(sessionId: sessionId),
          );
        },
      ),
      GoRoute(
        path: '/saved-posts',
        pageBuilder: (_, state) => _motoPage(
          key: state.pageKey,
          child: const SavedPostsScreen(),
        ),
      ),
      GoRoute(
        path: '/search',
        pageBuilder: (_, state) => _motoPage(
          key: state.pageKey,
          child: const UserSearchScreen(),
        ),
      ),
      GoRoute(
        path: '/notifications',
        pageBuilder: (_, state) => _motoPage(
          key: state.pageKey,
          child: const NotificationsScreen(),
        ),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (_, state) => _motoPage(
          key: state.pageKey,
          child: const SettingsScreen(),
        ),
      ),
      GoRoute(
        path: '/map-settings',
        pageBuilder: (_, state) => _motoPage(
          key: state.pageKey,
          child: const MapSettingsScreen(),
        ),
      ),
      GoRoute(
        path: '/ride-history',
        pageBuilder: (_, state) => _motoPage(
          key: state.pageKey,
          child: const RideHistoryScreen(),
        ),
      ),
      GoRoute(
        path: '/mapbox-nav',
        pageBuilder: (_, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return _motoPage(
            key: state.pageKey,
            child: MapboxNavScreen(
              destLat: (extra['destLat'] as num?)?.toDouble() ?? 0,
              destLng: (extra['destLng'] as num?)?.toDouble() ?? 0,
              destName: extra['destName'] as String? ?? 'Ziel',
            ),
          );
        },
      ),
    ],
  );
});
