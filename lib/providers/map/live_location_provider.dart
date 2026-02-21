import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../data/repositories/profile_repository.dart';
import '../../providers/core/providers.dart';
import '../../services/live_location_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// LiveLocationService — TRUE SINGLETON (not managed by Riverpod)
//
// Previously this was a Riverpod Provider which could be disposed/re-created
// during provider chain re-evaluation. Now it's a plain Dart singleton that
// lives for the entire app lifetime. No framework can reset it.
// ═══════════════════════════════════════════════════════════════════════════════

/// The one and only LiveLocationService instance for the entire app.
final LiveLocationService _globalLiveLocationService = LiveLocationService();

/// Riverpod provider that exposes the singleton.
/// It NEVER creates a new instance — always returns the same one.
/// The ref.onDispose is a no-op because the singleton lives forever.
final liveLocationServiceProvider = Provider<LiveLocationService>((ref) {
  // Always return the same singleton. Do NOT dispose it — it must survive
  // all provider chain re-evaluations, widget rebuilds, and tab switches.
  return _globalLiveLocationService;
});

// ═══════════════════════════════════════════════════════════════════════════════
// ONLINE USERS — Global ValueNotifier (100% outside Riverpod)
//
// Why not Riverpod?
// Every Riverpod provider's build() can be re-invoked during tab switches,
// widget rebuilds, or dependency chain re-evaluation. Each re-invocation
// returns a new initial value (usually empty), causing a brief flicker to 0.
//
// ValueNotifier is a single long-lived object. Its value is NEVER reset
// unless we explicitly set it. Widgets listen via ValueListenableBuilder,
// which does NOT trigger framework-level rebuilds of the surrounding tree.
// ═══════════════════════════════════════════════════════════════════════════════

/// Global singleton holding online users the current user follows.
/// Only users in the current user's following list are shown (badge + map).
/// Lives forever — never reset by provider rebuilds.
final onlineUsersNotifier = ValueNotifier<Map<String, LiveUserPosition>>({});

/// Global singleton: is the current user broadcasting GPS?
final isLiveNotifier = ValueNotifier<bool>(false);

/// Internal subscription to the service's stream.
StreamSubscription<Map<String, LiveUserPosition>>? _liveStreamSub;

/// Internal subscription to intentional logout events from the service.
StreamSubscription<String>? _goingOfflineSub;

/// Last known snapshot from the service stream (all users, before filter).
Map<String, LiveUserPosition> _lastAllUsers = {};

/// IDs of users that the current user follows.
/// Only these users are shown on the badge and map.
Set<String> _followingIds = {};

/// Current community key (e.g. 'bikergram', 'cars').
/// Only users from the same community are shown.
String _currentCommunity = 'bikergram';

/// Debounce timer: delays setting badge to 0 by 30s to absorb
/// brief Supabase Realtime reconnects / GPS pauses.
/// NOT used for intentional logouts (going_offline=true).
Timer? _zeroBadgeDebounce;

/// Initialize the online users pipeline.
/// Call once from MainShell.initState(). Safe to call multiple times.
Future<void> initOnlineUsers({
  required LiveLocationService service,
  required ProfileRepository profileRepo,
  String community = 'bikergram',
}) async {
  debugPrint('[OnlineUsers] initOnlineUsers called (community=$community, sub=${_liveStreamSub != null})');

  // 0. Store current community for filtering
  _currentCommunity = community;

  // 1. Load following IDs (users the current user follows)
  await refreshFollowingIds(profileRepo);

  // 2. Set initial value from current service snapshot (filtered)
  final snapshot = service.nearbyUsers;
  debugPrint('[OnlineUsers] Initial snapshot: ${snapshot.length} users');
  _lastAllUsers = Map.from(snapshot);
  if (snapshot.isNotEmpty) {
    onlineUsersNotifier.value = _filterByFollowing(snapshot);
  }

  // 3. Subscribe to stream (only once — guarded by null check)
  if (_liveStreamSub == null) {
    debugPrint('[OnlineUsers] Creating stream subscription');
    _liveStreamSub = service.nearbyUsersStream.listen(
      (allUsers) {
        _lastAllUsers = Map.from(allUsers);
        _applyFilter(allUsers);
      },
      onError: (e) {
        debugPrint('[OnlineUsers] Stream error: $e');
      },
      onDone: () {
        debugPrint('[OnlineUsers] ⚠️ Stream DONE — this should never happen!');
        _liveStreamSub = null;
        _liveStreamSub = service.nearbyUsersStream.listen((allUsers) {
          _lastAllUsers = Map.from(allUsers);
          _applyFilter(allUsers);
        });
      },
    );
  }

  // 4. Subscribe to intentional logout events (only once).
  // When a user sends going_offline=true, bypass the 30s debounce.
  _goingOfflineSub ??= service.userGoingOfflineStream.listen((uid) {
    debugPrint('[OnlineUsers] User $uid intentionally went offline — clearing immediately');
    _zeroBadgeDebounce?.cancel();
    _zeroBadgeDebounce = null;
    _applyFilterImmediate(_lastAllUsers);
  });
}

/// Reload the following list and re-apply the filter.
/// Call after the user follows/unfollows someone or switches community.
Future<void> refreshFollowingIds(ProfileRepository profileRepo) async {
  try {
    final ids = await profileRepo.getFollowingIds(
      community: _currentCommunity.isNotEmpty ? _currentCommunity : null,
    );
    _followingIds = ids;
    debugPrint('[OnlineUsers] Following IDs loaded: ${ids.length} (community=$_currentCommunity)');
    // Re-apply filter with new following list
    _applyFilterImmediate(_lastAllUsers);
  } catch (e) {
    debugPrint('[OnlineUsers] Failed to load following IDs: $e');
  }
}

/// Keep only users that:
///   1. Are in the same community as the current user
///   2. Are in the current user's following list
Map<String, LiveUserPosition> _filterByFollowing(
    Map<String, LiveUserPosition> allUsers) {
  if (_followingIds.isEmpty) return {};
  return Map.fromEntries(
    allUsers.entries.where((e) =>
        _followingIds.contains(e.key) &&
        e.value.community == _currentCommunity),
  );
}

/// Apply immediately — no debounce, for intentional logouts and filter changes.
void _applyFilterImmediate(Map<String, LiveUserPosition> allUsers) {
  final filtered = _filterByFollowing(allUsers);
  debugPrint('[OnlineUsers] _applyFilterImmediate: ${allUsers.length} total → ${filtered.length} followed');
  onlineUsersNotifier.value = filtered;
}

/// Update the badge with followed online users, with debounce for network flickers.
void _applyFilter(Map<String, LiveUserPosition> allUsers) {
  final filtered = _filterByFollowing(allUsers);
  final oldCount = onlineUsersNotifier.value.length;
  final newCount = filtered.length;

  if (oldCount != newCount) {
    debugPrint('[OnlineUsers] _applyFilter: $oldCount→$newCount followed users online');
  }

  if (oldCount > 0 && newCount == 0) {
    // Debounce to absorb brief Supabase Realtime reconnects.
    if (_zeroBadgeDebounce?.isActive == true) return;
    debugPrint('[OnlineUsers] ⚠️ count→0, debouncing 30s before hiding badge');
    _zeroBadgeDebounce = Timer(const Duration(seconds: 30), () {
      debugPrint('[OnlineUsers] Debounce fired: recheck=${_lastAllUsers.length} users');
      onlineUsersNotifier.value = _filterByFollowing(_lastAllUsers);
    });
    return;
  }

  if (newCount > 0 && _zeroBadgeDebounce?.isActive == true) {
    _zeroBadgeDebounce!.cancel();
    debugPrint('[OnlineUsers] Debounce cancelled — users back online');
  }

  onlineUsersNotifier.value = filtered;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Riverpod providers that are still needed by other screens
// (isLiveProvider is used by blitzer_map_screen, navigation_settings, etc.)
// ═══════════════════════════════════════════════════════════════════════════════

/// Whether the current user is broadcasting live GPS.
/// Still a Riverpod provider because it's used in many ref.watch() calls
/// across the app — but it never flickers because it's a simple bool.
final isLiveProvider =
    NotifierProvider<IsLiveNotifier, bool>(IsLiveNotifier.new);

class IsLiveNotifier extends Notifier<bool> {
  @override
  bool build() => isLiveNotifier.value;

  void set(bool value) {
    isLiveNotifier.value = value;
    state = value;
  }
}

/// Reactive provider for nearby live users count + data.
/// Used by blitzer_map_screen for map markers — filtered to following list.
/// Uses the global singleton service — ref.read (not watch) to avoid re-evaluation.
final liveUsersProvider =
    NotifierProvider<LiveUsersNotifier, Map<String, LiveUserPosition>>(
        LiveUsersNotifier.new);

class LiveUsersNotifier extends Notifier<Map<String, LiveUserPosition>> {
  StreamSubscription<Map<String, LiveUserPosition>>? _sub;

  @override
  Map<String, LiveUserPosition> build() {
    // Use the global singleton directly — NOT ref.watch which would cause
    // re-evaluation and lose the subscription.
    final service = _globalLiveLocationService;

    // Start with whatever the service currently has (filtered to following)
    final initial = _filterByFollowing(
        Map<String, LiveUserPosition>.from(service.nearbyUsers));

    // Subscribe to future changes
    _sub?.cancel();
    _sub = service.nearbyUsersStream.listen((users) {
      state = _filterByFollowing(Map<String, LiveUserPosition>.from(users));
    });

    ref.onDispose(() {
      _sub?.cancel();
    });

    return initial;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Focus Map Target (used by online sheet → Blitzer map)
// ═══════════════════════════════════════════════════════════════════════════════

class FocusMapTarget {
  final LatLng position;
  final String? userId;
  final String? displayName;
  final double zoom;

  const FocusMapTarget({
    required this.position,
    this.userId,
    this.displayName,
    this.zoom = 15,
  });
}

final focusMapTargetProvider =
    NotifierProvider<FocusMapTargetNotifier, FocusMapTarget?>(
        FocusMapTargetNotifier.new);

class FocusMapTargetNotifier extends Notifier<FocusMapTarget?> {
  @override
  FocusMapTarget? build() => null;

  void focusOn(FocusMapTarget target) => state = target;

  /// Clear after consuming
  void clear() => state = null;
}
