import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'kalman_filter.dart';

// ─── App Mode State Machine ──────────────────────────────────────────────────
//
// Formal state machine for the app's driving/navigation lifecycle.
// Replaces scattered boolean flags with clear, validated transitions.
//
// States:
//   idle        → User is browsing the map normally
//   driving     → Driving mode active (follow GPS, show speed, alerts armed)
//   navigating  → Active turn-by-turn navigation with route
//   routePreview → Route calculated, reviewing before starting navigation
//
// Camera modes:
//   follow → Camera tracks user position
//   browse → User is panning/zooming manually

/// Primary app mode for the blitzer/navigation screen.
enum AppMode {
  /// Default: user browsing the map, no active tracking
  idle,
  /// Driving mode: GPS follow, speed display, alerts active
  driving,
  /// Active navigation: route + turn-by-turn + alerts
  navigating,
  /// Route preview: route shown, user deciding whether to start nav
  routePreview,
}

/// Camera follow behavior.
enum CameraMode {
  /// Camera auto-follows user position
  follow,
  /// User manually controls the camera (panning/zooming)
  browse,
}

/// Complete app mode state.
class AppModeState {
  final AppMode mode;
  final CameraMode cameraMode;
  final LocationQuality locationQuality;
  final DateTime? lastBrowseTime; // When user started browsing (for auto-return)

  const AppModeState({
    this.mode = AppMode.idle,
    this.cameraMode = CameraMode.follow,
    this.locationQuality = LocationQuality.good,
    this.lastBrowseTime,
  });

  AppModeState copyWith({
    AppMode? mode,
    CameraMode? cameraMode,
    LocationQuality? locationQuality,
    DateTime? lastBrowseTime,
    bool clearLastBrowseTime = false,
  }) {
    return AppModeState(
      mode: mode ?? this.mode,
      cameraMode: cameraMode ?? this.cameraMode,
      locationQuality: locationQuality ?? this.locationQuality,
      lastBrowseTime: clearLastBrowseTime ? null : (lastBrowseTime ?? this.lastBrowseTime),
    );
  }

  // ── Convenience getters ──

  bool get isIdle => mode == AppMode.idle;
  bool get isDriving => mode == AppMode.driving;
  bool get isNavigating => mode == AppMode.navigating;
  bool get isRoutePreview => mode == AppMode.routePreview;
  bool get isFollowing => cameraMode == CameraMode.follow;
  bool get isBrowsing => cameraMode == CameraMode.browse;
  bool get isGpsGood => locationQuality == LocationQuality.good;
  bool get isGpsDegraded => locationQuality == LocationQuality.degraded;
  bool get isGpsLost => locationQuality == LocationQuality.lost;

  /// Whether driving/navigating (= GPS tracking active, alerts armed).
  bool get isTracking => isDriving || isNavigating;

  @override
  String toString() =>
      'AppModeState(mode=$mode, camera=$cameraMode, gps=$locationQuality)';
}

// ─── Provider ────────────────────────────────────────────────────────────────

final appModeProvider =
    NotifierProvider<AppModeController, AppModeState>(AppModeController.new);

// ─── Controller ──────────────────────────────────────────────────────────────

class AppModeController extends Notifier<AppModeState> {
  @override
  AppModeState build() => const AppModeState();

  // ── Mode Transitions ──

  /// idle → driving
  void enterDriving() {
    if (state.mode != AppMode.idle) {
      debugPrint('[AppMode] enterDriving ignored (current: ${state.mode})');
      return;
    }
    state = state.copyWith(
      mode: AppMode.driving,
      cameraMode: CameraMode.follow,
      clearLastBrowseTime: true,
    );
    debugPrint('[AppMode] → driving');
  }

  /// idle/driving → routePreview
  void enterRoutePreview() {
    if (state.mode != AppMode.idle && state.mode != AppMode.driving) {
      debugPrint('[AppMode] enterRoutePreview ignored (current: ${state.mode})');
      return;
    }
    state = state.copyWith(
      mode: AppMode.routePreview,
      cameraMode: CameraMode.browse, // User reviews route freely
    );
    debugPrint('[AppMode] → routePreview');
  }

  /// routePreview/driving/idle → navigating
  void enterNavigation() {
    state = state.copyWith(
      mode: AppMode.navigating,
      cameraMode: CameraMode.follow,
      clearLastBrowseTime: true,
    );
    debugPrint('[AppMode] → navigating');
  }

  /// navigating → driving (stop nav but keep driving mode)
  void exitNavigation() {
    if (state.mode != AppMode.navigating) {
      debugPrint('[AppMode] exitNavigation ignored (current: ${state.mode})');
      return;
    }
    state = state.copyWith(
      mode: AppMode.driving,
      cameraMode: CameraMode.follow,
      clearLastBrowseTime: true,
    );
    debugPrint('[AppMode] navigating → driving');
  }

  /// any → idle (full reset)
  void exitToIdle() {
    state = const AppModeState();
    debugPrint('[AppMode] → idle');
  }

  // ── Camera Mode ──

  /// User manually panned/zoomed the map → switch to browse.
  void onUserPan() {
    if (!state.isTracking) return; // Only relevant in driving/navigating
    if (state.isBrowsing) return; // Already browsing

    state = state.copyWith(
      cameraMode: CameraMode.browse,
      lastBrowseTime: DateTime.now(),
    );
    debugPrint('[AppMode] Camera → browse');
  }

  /// Re-center camera to follow user position.
  void reCenter() {
    if (state.isFollowing) return;

    state = state.copyWith(
      cameraMode: CameraMode.follow,
      clearLastBrowseTime: true,
    );
    debugPrint('[AppMode] Camera → follow');
  }

  // ── Quality Updates ──

  /// Update the GPS signal quality.
  void onQualityChange(LocationQuality quality) {
    if (state.locationQuality == quality) return;
    state = state.copyWith(locationQuality: quality);
  }
}
