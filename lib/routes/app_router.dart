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
import '../presentation/shell/main_shell.dart';
import '../presentation/feed/feed_screen.dart';
import '../presentation/garage/garage_screen.dart';
import '../presentation/marketplace/marketplace_screen.dart';
import '../presentation/profile/profile_screen.dart';
import '../presentation/blitzer/blitzer_map_screen.dart';
import '../presentation/map/user_map_screen.dart';
import '../presentation/events/events_screen.dart';
import '../presentation/messages/messages_screen.dart';
import '../presentation/messages/chat_detail_screen.dart';
import '../presentation/notifications/notifications_screen.dart';
import '../presentation/settings/settings_screen.dart';
import '../presentation/blitzer/blitzer_settings_screen.dart';
import '../presentation/blitzer/navigation_settings_screen.dart';
import '../presentation/feed/post_detail_screen.dart';
import '../presentation/search/user_search_screen.dart';
import '../presentation/live/live_browse_screen.dart';
import '../presentation/live/live_viewer_screen.dart';
import '../presentation/live/go_live_screen.dart';

// ---------------------------------------------------------------------------
// Motorsport-style page transition — fast diagonal slide + fade.
// Inspired by race-car HUD transitions: sharp entry from the right with
// a subtle upward shift and a quick fade. Duration: 260ms.
// ---------------------------------------------------------------------------
Page<T> _motoPage<T>({required LocalKey key, required Widget child}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    opaque: true,
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

      // Fade starts at 0.6 to avoid grey flash through opaque background
      final fade = Tween<double>(begin: 0.6, end: 1.0).animate(
        CurvedAnimation(
          parent: animation,
          curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
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

      // Still checking auth on startup → don't redirect.
      // IMPORTANT: Don't redirect away from the current page during a
      // profile refresh (e.g. after editing). The user should stay where
      // they are while auth re-checks in the background.
      if (authState is AuthInitial || authState is AuthLoading) {
        return null;
      }

      // Definitively not authenticated → go to login
      if (authState is Unauthenticated || authState is AuthError) {
        if (!isAuthRoute && !isOnboarding) return '/login';
        return null;
      }

      // Authenticated → check if profile is complete
      if (authState is Authenticated) {
        final needsOnboarding = authState.user.birthYear == null;

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

      // Complete profile after social sign-in
      GoRoute(
        path: '/complete-profile',
        builder: (_, __) => const CompleteProfileScreen(),
      ),

      // Main app with bottom navigation shell
      ShellRoute(
        builder: (_, __, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/feed',
            pageBuilder: (_, __) => const NoTransitionPage(
              child: FeedScreen(),
            ),
          ),
          GoRoute(
            path: '/garage',
            pageBuilder: (_, __) => const NoTransitionPage(
              child: GarageScreen(),
            ),
          ),
          GoRoute(
            path: '/blitzer',
            pageBuilder: (_, __) => const NoTransitionPage(
              child: BlitzerMapScreen(),
            ),
          ),
          GoRoute(
            path: '/map',
            pageBuilder: (_, __) => const NoTransitionPage(
              child: UserMapScreen(),
            ),
          ),
          GoRoute(
            path: '/live',
            pageBuilder: (_, __) => const NoTransitionPage(
              child: LiveBrowseScreen(),
            ),
          ),
          GoRoute(
            path: '/events',
            pageBuilder: (_, __) => const NoTransitionPage(
              child: EventsScreen(),
            ),
          ),
          GoRoute(
            path: '/market',
            pageBuilder: (_, __) => const NoTransitionPage(
              child: MarketplaceScreen(),
            ),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (_, __) => const NoTransitionPage(
              child: ProfileScreen(),
            ),
          ),
        ],
      ),

      // Full-screen routes (no bottom nav) — motorsport transition
      GoRoute(
        path: '/messages',
        pageBuilder: (_, state) => _motoPage(
          key: state.pageKey,
          child: const MessagesScreen(),
        ),
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
        path: '/profile/:userId',
        pageBuilder: (_, state) {
          final userId = state.pathParameters['userId']!;
          return _motoPage(
            key: state.pageKey,
            child: ProfileScreen(userId: userId),
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
        path: '/blitzer-settings',
        pageBuilder: (_, state) => _motoPage(
          key: state.pageKey,
          child: const BlitzerSettingsScreen(),
        ),
      ),
      GoRoute(
        path: '/navigation-settings',
        pageBuilder: (_, state) => _motoPage(
          key: state.pageKey,
          child: const NavigationSettingsScreen(),
        ),
      ),
    ],
  );
});
