import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../data/repositories/blitzer_repository.dart';
import '../../services/alert_audio_service.dart';
import '../../services/app_mode_controller.dart';
import '../../services/blitzer_alert_service.dart';
import '../../services/kalman_filter.dart';
import 'map_settings_provider.dart';
import 'country_policy_provider.dart';

// ─── Providers ───────────────────────────────────────────────────────────────

/// Singleton alert service.
final blitzerAlertServiceProvider =
    Provider<BlitzerAlertService>((ref) => BlitzerAlertService());

/// Driving mode state.
final drivingModeProvider =
    NotifierProvider<DrivingModeNotifier, DrivingModeState>(
        DrivingModeNotifier.new);

// ─── State ───────────────────────────────────────────────────────────────────

class DrivingModeState {
  /// Whether driving mode is active (auto-follows GPS, shows HUD).
  final bool isActive;

  /// Follow mode: camera tracks user position.
  final bool isFollowing;

  /// User manually panned the map — temporarily disable follow.
  final bool userPannedMap;

  /// Current GPS position (raw, for backward compat).
  final Position? currentPosition;

  /// Smoothed GPS position (Kalman-filtered).
  final SmoothedPosition? smoothedPosition;

  /// Current speed in km/h (smoothed if Kalman active).
  final double speedKmh;

  /// Current heading (degrees, 0 = North, smoothed).
  final double heading;

  /// Active blitzer alerts (sorted by distance).
  final List<BlitzerAlert> activeAlerts;

  /// Most urgent alert (closest/highest stage).
  final BlitzerAlert? primaryAlert;

  /// Time since last re-center prompt (after user panned).
  final DateTime? lastPanTime;

  /// Blitzer reports nearby (legacy field, kept for compat).
  final List<BlitzerReport> blitzerOnRoute;

  /// Whether screen should stay on.
  final bool keepScreenOn;

  /// GPS signal quality.
  final LocationQuality locationQuality;

  /// Speed limit from nearest blitzer with known limit (km/h, null if none).
  final int? nearestSpeedLimit;

  const DrivingModeState({
    this.isActive = false,
    this.isFollowing = true,
    this.userPannedMap = false,
    this.currentPosition,
    this.smoothedPosition,
    this.speedKmh = 0,
    this.heading = 0,
    this.activeAlerts = const [],
    this.primaryAlert,
    this.lastPanTime,
    this.blitzerOnRoute = const [],
    this.keepScreenOn = true,
    this.locationQuality = LocationQuality.good,
    this.nearestSpeedLimit,
  });

  DrivingModeState copyWith({
    bool? isActive,
    bool? isFollowing,
    bool? userPannedMap,
    Position? currentPosition,
    SmoothedPosition? smoothedPosition,
    double? speedKmh,
    double? heading,
    List<BlitzerAlert>? activeAlerts,
    BlitzerAlert? primaryAlert,
    bool clearPrimaryAlert = false,
    DateTime? lastPanTime,
    List<BlitzerReport>? blitzerOnRoute,
    bool? keepScreenOn,
    LocationQuality? locationQuality,
    int? nearestSpeedLimit,
    bool clearSpeedLimit = false,
  }) {
    return DrivingModeState(
      isActive: isActive ?? this.isActive,
      isFollowing: isFollowing ?? this.isFollowing,
      userPannedMap: userPannedMap ?? this.userPannedMap,
      currentPosition: currentPosition ?? this.currentPosition,
      smoothedPosition: smoothedPosition ?? this.smoothedPosition,
      speedKmh: speedKmh ?? this.speedKmh,
      heading: heading ?? this.heading,
      activeAlerts: activeAlerts ?? this.activeAlerts,
      primaryAlert: clearPrimaryAlert ? null : (primaryAlert ?? this.primaryAlert),
      lastPanTime: lastPanTime ?? this.lastPanTime,
      blitzerOnRoute: blitzerOnRoute ?? this.blitzerOnRoute,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      locationQuality: locationQuality ?? this.locationQuality,
      nearestSpeedLimit: clearSpeedLimit ? null : (nearestSpeedLimit ?? this.nearestSpeedLimit),
    );
  }

  /// Human-readable speed.
  String get speedText => '${speedKmh.round()}';

  /// Whether there's an active blitzer warning to display.
  bool get hasWarning => primaryAlert != null;

  /// Whether GPS is lost (tunnel, no signal).
  bool get isGpsLost => locationQuality == LocationQuality.lost;

  /// Whether GPS is degraded but usable.
  bool get isGpsDegraded => locationQuality == LocationQuality.degraded;
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class DrivingModeNotifier extends Notifier<DrivingModeState> {
  Timer? _reCenterTimer;

  @override
  DrivingModeState build() => const DrivingModeState();

  /// Activate driving mode.
  void activate({bool keepScreenOn = true}) {
    if (state.isActive) return;

    state = state.copyWith(
      isActive: true,
      isFollowing: true,
      userPannedMap: false,
      keepScreenOn: keepScreenOn,
    );

    // Keep screen on
    if (keepScreenOn) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }

    debugPrint('[DrivingMode] Activated');
  }

  /// Deactivate driving mode.
  void deactivate() {
    if (!state.isActive) return;

    _reCenterTimer?.cancel();
    _reCenterTimer = null;

    // Reset alert service
    ref.read(blitzerAlertServiceProvider).reset();

    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    state = const DrivingModeState();
    debugPrint('[DrivingMode] Deactivated');
  }

  /// Called when user manually pans/zooms the map.
  void onUserPannedMap() {
    if (!state.isActive) return;

    state = state.copyWith(
      isFollowing: false,
      userPannedMap: true,
      lastPanTime: DateTime.now(),
    );

    // Auto re-center after 5 seconds of no interaction
    _reCenterTimer?.cancel();
    _reCenterTimer = Timer(const Duration(seconds: 5), () {
      if (state.isActive && state.userPannedMap) {
        reCenter();
      }
    });
  }

  /// Re-center the camera to follow the user again.
  void reCenter() {
    if (!state.isActive) return;

    _reCenterTimer?.cancel();
    state = state.copyWith(
      isFollowing: true,
      userPannedMap: false,
    );
    debugPrint('[DrivingMode] Re-centered');
  }

  /// Process a new GPS position update (legacy: raw Position).
  ///
  /// Returns the camera update to apply (if following mode is active).
  /// Also checks blitzer proximity and fires alerts.
  CameraPosition? processGpsUpdate({
    required Position pos,
    required List<BlitzerReport> reports,
  }) {
    if (!state.isActive) return null;

    // Speed in km/h
    final speed = (pos.speed >= 0 ? pos.speed : 0.0) * 3.6;
    final heading = pos.heading;

    // Update position state
    state = state.copyWith(
      currentPosition: pos,
      speedKmh: speed,
      heading: heading,
    );

    return _runAlertCheck(
      lat: pos.latitude,
      lng: pos.longitude,
      speed: speed,
      heading: heading,
      reports: reports,
    );
  }

  /// Process a Kalman-smoothed GPS position update (new pipeline).
  ///
  /// Returns the camera update to apply (if following mode is active).
  /// Uses smoothed lat/lng/speed/heading for stable camera and accurate alerts.
  CameraPosition? processSmoothedUpdate({
    required SmoothedPosition smoothed,
    required Position rawPos,
    required List<BlitzerReport> reports,
  }) {
    if (!state.isActive) return null;

    // Update state with both raw and smoothed
    state = state.copyWith(
      currentPosition: rawPos,
      smoothedPosition: smoothed,
      speedKmh: smoothed.smoothedSpeed,
      heading: smoothed.smoothedHeading,
      locationQuality: smoothed.quality,
    );

    // Update app mode quality if available
    try {
      ref.read(appModeProvider.notifier).onQualityChange(smoothed.quality);
    } catch (_) {
      // appModeProvider might not be initialized yet
    }

    return _runAlertCheck(
      lat: smoothed.smoothedLat,
      lng: smoothed.smoothedLng,
      speed: smoothed.smoothedSpeed,
      heading: smoothed.smoothedHeading,
      reports: reports,
    );
  }

  /// Internal: run alert check and return camera position.
  CameraPosition? _runAlertCheck({
    required double lat,
    required double lng,
    required double speed,
    required double heading,
    required List<BlitzerReport> reports,
  }) {
    final settings = ref.read(blitzerSettingsProvider).value ??
        const BlitzerSettings();
    final alertService = ref.read(blitzerAlertServiceProvider);

    // Create a synthetic Position for alert service (uses lat/lng/speed/heading)
    final syntheticPos = Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime.now(),
      accuracy: 10,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: heading,
      headingAccuracy: 0,
      speed: speed / 3.6, // Convert back to m/s for alert service
      speedAccuracy: 0,
    );

    final result = alertService.checkAlerts(
      pos: syntheticPos,
      reports: reports,
      settings: settings,
      currentSpeedKmh: speed,
    );

    // Extract speed limit from nearest blitzer with known limit
    int? nearestLimit;
    for (final alert in result.activeAlerts) {
      if (alert.report.speedLimit != null) {
        nearestLimit = alert.report.speedLimit;
        break; // Closest first (already sorted by distance)
      }
    }

    // Update active alerts + speed limit
    state = state.copyWith(
      activeAlerts: result.activeAlerts,
      primaryAlert: result.activeAlerts.isNotEmpty
          ? result.activeAlerts.first
          : null,
      clearPrimaryAlert: result.activeAlerts.isEmpty,
      nearestSpeedLimit: nearestLimit,
      clearSpeedLimit: nearestLimit == null,
    );

    // Fire audio/haptic for NEW alerts (gated by country policy)
    final countryPolicy = ref.read(countryPolicyProvider).policy;
    final audioAllowed = countryPolicy?.allowAudioAlerts ?? true;
    for (final alert in result.newAlerts) {
      AlertAudioService.instance.playAlert(
        stage: alert.stage,
        audioEnabled: audioAllowed && settings.audioAlertsEnabled && settings.warningSoundEnabled,
        volume: settings.audioVolume,
        soundType: settings.alertSoundType,
        hapticEnabled: settings.hapticAlertsEnabled,
        hapticIntensity: settings.hapticIntensity,
      );
    }

    // Camera position
    if (!state.isFollowing) return null;

    return CameraPosition(
      target: LatLng(lat, lng),
      zoom: settings.followZoom,
      tilt: settings.headingRotation ? settings.followTilt : 0,
      bearing: settings.headingRotation ? heading : 0,
    );
  }

  /// Dismiss the primary alert banner.
  void dismissAlert() {
    state = state.copyWith(clearPrimaryAlert: true);
  }
}
