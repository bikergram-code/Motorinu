import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../services/destination_info_service.dart';
import '../../services/geocoding_service.dart';
import '../../services/osrm_service.dart';

// ─── Providers ──────────────────────────────────────────────────────────────

/// Singleton OSRM routing service.
final osrmServiceProvider = Provider<OsrmService>((ref) => OsrmService());

/// Singleton destination info enrichment service.
final destinationInfoServiceProvider =
    Provider<DestinationInfoService>((ref) => DestinationInfoService());

/// Singleton Geocoding service.
final geocodingServiceProvider =
    Provider<GeocodingService>((ref) => GeocodingService());

/// Speed-Dial open/close state (global, used by MainShell).
final blitzerSpeedDialProvider =
    NotifierProvider<SpeedDialNotifier, bool>(SpeedDialNotifier.new);

/// Navigation state notifier.
final navigationProvider =
    NotifierProvider<NavigationNotifier, NavigationState>(
        NavigationNotifier.new);

/// Simple notifier for Speed-Dial toggle.
class SpeedDialNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
  void open() => state = true;
  void close() => state = false;
}

// ─── Speed-Dial action items (registered per-tab) ───────────────────────────

/// A single Speed-Dial action item.
class SpeedDialItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const SpeedDialItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

/// Holds the current list of Speed-Dial items for the active tab.
/// Each tab screen registers its items in initState and clears in dispose.
final speedDialItemsProvider =
    NotifierProvider<SpeedDialItemsNotifier, List<SpeedDialItem>>(
        SpeedDialItemsNotifier.new);

class SpeedDialItemsNotifier extends Notifier<List<SpeedDialItem>> {
  @override
  List<SpeedDialItem> build() => [];

  void register(List<SpeedDialItem> items) => state = items;
  void clear() => state = [];
}

// ─── State ──────────────────────────────────────────────────────────────────

class NavigationState {
  final OsrmRoute? route;
  final LatLng? destination;
  final String? destinationName;
  final bool isNavigating;
  final bool isCalculating;
  final int currentStepIndex;
  final double remainingKm;
  final int remainingSeconds;
  final List<GeocodingResult> searchResults;
  final bool isSearching;
  final String? error;

  // ── Real-time navigation fields ──
  final double distanceToNextStep; // meters to next turn
  final double currentSpeed; // km/h
  final bool isOffRoute; // > 50m from polyline

  // ── Destination Enrichment ──
  final DestinationInfo? destinationInfo; // Enriched info (POIs, Wikipedia, Population)
  final bool isLoadingInfo; // Whether enrichment data is being fetched

  // ── Route Mode (Biker vs Auto) ──
  final RouteMode routeMode; // Current routing preference

  // ── Re-Route Cooldown ──
  final DateTime? lastReRouteTime; // Letzter Re-Route-Zeitpunkt
  final int reRouteCount; // Wie oft re-routed (pro Nav-Session)
  final bool reRouteExhausted; // true nach 3 fehlgeschlagenen Re-Routes

  const NavigationState({
    this.route,
    this.destination,
    this.destinationName,
    this.isNavigating = false,
    this.isCalculating = false,
    this.currentStepIndex = 0,
    this.remainingKm = 0,
    this.remainingSeconds = 0,
    this.searchResults = const [],
    this.isSearching = false,
    this.error,
    this.distanceToNextStep = 0,
    this.currentSpeed = 0,
    this.isOffRoute = false,
    this.destinationInfo,
    this.isLoadingInfo = false,
    this.routeMode = RouteMode.biker,
    this.lastReRouteTime,
    this.reRouteCount = 0,
    this.reRouteExhausted = false,
  });

  NavigationState copyWith({
    OsrmRoute? route,
    LatLng? destination,
    String? destinationName,
    bool? isNavigating,
    bool? isCalculating,
    int? currentStepIndex,
    double? remainingKm,
    int? remainingSeconds,
    List<GeocodingResult>? searchResults,
    bool? isSearching,
    String? error,
    double? distanceToNextStep,
    double? currentSpeed,
    bool? isOffRoute,
    DestinationInfo? destinationInfo,
    bool? isLoadingInfo,
    bool clearDestinationInfo = false,
    RouteMode? routeMode,
    DateTime? lastReRouteTime,
    int? reRouteCount,
    bool? reRouteExhausted,
  }) {
    return NavigationState(
      route: route ?? this.route,
      destination: destination ?? this.destination,
      destinationName: destinationName ?? this.destinationName,
      isNavigating: isNavigating ?? this.isNavigating,
      isCalculating: isCalculating ?? this.isCalculating,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      remainingKm: remainingKm ?? this.remainingKm,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      searchResults: searchResults ?? this.searchResults,
      isSearching: isSearching ?? this.isSearching,
      error: error,
      distanceToNextStep: distanceToNextStep ?? this.distanceToNextStep,
      currentSpeed: currentSpeed ?? this.currentSpeed,
      isOffRoute: isOffRoute ?? this.isOffRoute,
      destinationInfo: clearDestinationInfo ? null : (destinationInfo ?? this.destinationInfo),
      isLoadingInfo: isLoadingInfo ?? this.isLoadingInfo,
      routeMode: routeMode ?? this.routeMode,
      lastReRouteTime: lastReRouteTime ?? this.lastReRouteTime,
      reRouteCount: reRouteCount ?? this.reRouteCount,
      reRouteExhausted: reRouteExhausted ?? this.reRouteExhausted,
    );
  }

  /// Whether a route is loaded (but navigation may or may not be active).
  bool get hasRoute => route != null;

  /// Current step (or null if no route/steps).
  OsrmStep? get currentStep {
    if (route == null || route!.steps.isEmpty) return null;
    if (currentStepIndex >= route!.steps.length) return null;
    return route!.steps[currentStepIndex];
  }

  /// Next step (for preview).
  OsrmStep? get nextStep {
    if (route == null || route!.steps.isEmpty) return null;
    final nextIdx = currentStepIndex + 1;
    if (nextIdx >= route!.steps.length) return null;
    return route!.steps[nextIdx];
  }

  /// Human-readable remaining time.
  String get remainingTimeText {
    final h = remainingSeconds ~/ 3600;
    final m = (remainingSeconds % 3600) ~/ 60;
    if (h > 0) return '$h Std. $m Min.';
    return '$m Min.';
  }

  /// Human-readable remaining distance.
  String get remainingDistanceText {
    if (remainingKm < 1) {
      return '${(remainingKm * 1000).round()} m';
    }
    return '${remainingKm.toStringAsFixed(1)} km';
  }

  /// Human-readable distance to next step.
  String get distanceToNextStepText {
    if (distanceToNextStep < 1000) {
      return '${distanceToNextStep.round()} m';
    }
    return '${(distanceToNextStep / 1000).toStringAsFixed(1)} km';
  }

  /// Estimated arrival time as wall-clock string (e.g. "14:32").
  String get etaText {
    if (remainingSeconds <= 0) return '--:--';
    final arrival = DateTime.now().add(Duration(seconds: remainingSeconds));
    return '${arrival.hour.toString().padLeft(2, '0')}:${arrival.minute.toString().padLeft(2, '0')}';
  }
}

// ─── Notifier ───────────────────────────────────────────────────────────────

class NavigationNotifier extends Notifier<NavigationState> {
  @override
  NavigationState build() => const NavigationState();

  /// Search for places (cities, streets, POIs, businesses).
  Future<void> searchPlaces(String query, {LatLng? near}) async {
    if (query.trim().isEmpty) {
      state = state.copyWith(searchResults: [], isSearching: false);
      return;
    }

    state = state.copyWith(isSearching: true);
    final geocoding = ref.read(geocodingServiceProvider);
    final results = await geocoding.searchPlace(query, near: near);
    state = state.copyWith(searchResults: results, isSearching: false);
  }

  /// Set route mode and recalculate if route exists.
  void setRouteMode(RouteMode mode) {
    if (mode == state.routeMode) return;
    state = state.copyWith(routeMode: mode);
    // If there's already a destination, recalculate with new mode
    // (the UI will trigger this)
  }

  /// Calculate route from current position to destination.
  Future<void> calculateRoute(LatLng origin, LatLng destination,
      {String? name, RouteMode? mode}) async {
    final routeMode = mode ?? state.routeMode;
    state = state.copyWith(
      isCalculating: true,
      destination: destination,
      destinationName: name,
      routeMode: routeMode,
      error: null,
    );

    final osrm = ref.read(osrmServiceProvider);
    final route = await osrm.getRoute(origin, destination, mode: routeMode);

    if (route == null) {
      state = state.copyWith(
        isCalculating: false,
        error: 'Route konnte nicht berechnet werden',
      );
      return;
    }

    state = state.copyWith(
      route: route,
      isCalculating: false,
      remainingKm: route.distanceKm,
      remainingSeconds: route.durationSeconds,
      currentStepIndex: 0,
      searchResults: [],
      distanceToNextStep: route.steps.isNotEmpty
          ? route.steps.first.distanceMeters
          : 0,
      isOffRoute: false,
      // Erfolgreiche Route → Re-Route-Counter resetten
      reRouteCount: 0,
      reRouteExhausted: false,
    );

    // Fetch destination enrichment data in background (non-blocking)
    _fetchDestinationInfo(destination, name);
  }

  /// Start active navigation.
  void startNavigation() {
    if (state.route == null) return;
    state = state.copyWith(
      isNavigating: true,
      currentStepIndex: 0,
      distanceToNextStep: state.route!.steps.isNotEmpty
          ? state.route!.steps.first.distanceMeters
          : 0,
      isOffRoute: false,
      // Reset re-route counter bei neuem Nav-Start
      reRouteCount: 0,
      reRouteExhausted: false,
    );
  }

  /// Attempt a re-route with cooldown and max-retry logic.
  /// Returns true if re-route was initiated, false if suppressed.
  bool tryReRoute(LatLng currentPosition, LatLng destination, {String? name}) {
    final now = DateTime.now();

    // Already exhausted? (max 3 re-routes)
    if (state.reRouteExhausted) return false;

    // Cooldown: 5 seconds between re-routes
    if (state.lastReRouteTime != null &&
        now.difference(state.lastReRouteTime!) < const Duration(seconds: 5)) {
      return false;
    }

    // Max 3 re-routes
    final newCount = state.reRouteCount + 1;
    if (newCount > 3) {
      state = state.copyWith(
        reRouteExhausted: true,
        error: 'Route konnte nicht berechnet werden',
      );
      return false;
    }

    state = state.copyWith(
      lastReRouteTime: now,
      reRouteCount: newCount,
    );

    debugPrint('[Nav] Re-Route Versuch $newCount/3');
    calculateRoute(currentPosition, destination, name: name, mode: state.routeMode);
    return true;
  }

  /// Fetch destination enrichment data (non-blocking, updates state when done).
  /// Uses two-phase loading: Phase 1 (fast) returns immediately,
  /// Phase 2 (Overpass POIs) updates state later via callback.
  Future<void> _fetchDestinationInfo(LatLng destination, String? name) async {
    state = state.copyWith(isLoadingInfo: true);

    try {
      final infoService = ref.read(destinationInfoServiceProvider);
      final info = await infoService.fetchAll(
        cityName: name,
        location: destination,
        onUpdate: (updated) {
          // Phase 2 callback: Overpass POIs arrived
          if (state.hasRoute) {
            state = state.copyWith(destinationInfo: updated);
          }
        },
      );
      // Phase 1 done — update state immediately
      if (state.hasRoute) {
        state = state.copyWith(destinationInfo: info, isLoadingInfo: false);
      }
    } catch (e) {
      debugPrint('[Nav] DestinationInfo fetch error: $e');
      if (state.hasRoute) {
        state = state.copyWith(isLoadingInfo: false);
      }
    }
  }

  /// Stop navigation and clear route.
  void stopNavigation() {
    state = const NavigationState();
  }

  /// Clear only the route (keep search state).
  void clearRoute() {
    state = state.copyWith(
      route: null,
      destination: null,
      destinationName: null,
      isNavigating: false,
      isCalculating: false,
      currentStepIndex: 0,
      remainingKm: 0,
      remainingSeconds: 0,
      distanceToNextStep: 0,
      currentSpeed: 0,
      isOffRoute: false,
      clearDestinationInfo: true,
      isLoadingInfo: false,
    );
  }

  /// Clear search results.
  void clearSearch() {
    state = state.copyWith(searchResults: [], isSearching: false);
  }

  /// Update navigation state based on current GPS position.
  /// Called from the GPS stream in BlitzerMapScreen.
  /// Returns true if navigation should be stopped (arrived).
  bool updatePosition(Position pos) {
    if (!state.isNavigating || state.route == null) return false;

    final route = state.route!;
    final steps = route.steps;
    final polyline = route.polylinePoints;
    final userLat = pos.latitude;
    final userLng = pos.longitude;

    // Speed in km/h
    final speed = (pos.speed >= 0 ? pos.speed : 0.0) * 3.6;

    // Current step index
    var stepIdx = state.currentStepIndex;

    // Check if we reached the current step location (< 35m)
    if (stepIdx < steps.length) {
      final stepLoc = steps[stepIdx].location;
      final distToStep = Geolocator.distanceBetween(
        userLat, userLng, stepLoc.latitude, stepLoc.longitude,
      );

      if (distToStep < 35 && stepIdx < steps.length - 1) {
        // Advance to next step
        stepIdx++;
        debugPrint('[Nav] Step reached — advancing to step $stepIdx');
      }

      // Check if we reached the final step (arrive) < 50m
      if (stepIdx == steps.length - 1) {
        final arriveStep = steps[stepIdx];
        final distToArrive = Geolocator.distanceBetween(
          userLat, userLng,
          arriveStep.location.latitude, arriveStep.location.longitude,
        );
        if (distToArrive < 50) {
          debugPrint('[Nav] Destination reached!');
          return true; // Signal to stop navigation
        }
      }
    }

    // Distance to next step
    double distToNextStep = 0;
    if (stepIdx < steps.length) {
      final nextStepLoc = steps[stepIdx].location;
      distToNextStep = Geolocator.distanceBetween(
        userLat, userLng, nextStepLoc.latitude, nextStepLoc.longitude,
      );
    }

    // Off-route check: distance to nearest polyline segment > 50m
    final nearestDist = _nearestDistanceToPolyline(
      LatLng(userLat, userLng), polyline,
    );
    final offRoute = nearestDist > 50;

    if (offRoute && !state.isOffRoute) {
      debugPrint('[Nav] Off-route! Distance to polyline: ${nearestDist.round()}m');
    }

    // Remaining distance & time (rough estimate from current step)
    double remainingKm = 0;
    int remainingSeconds = 0;
    for (int i = stepIdx; i < steps.length; i++) {
      remainingKm += steps[i].distanceMeters / 1000;
      remainingSeconds += steps[i].durationSeconds;
    }
    // Subtract the portion of current step already covered
    if (stepIdx < steps.length) {
      final stepDist = steps[stepIdx].distanceMeters;
      if (stepDist > 0) {
        final coveredRatio = 1.0 - (distToNextStep / stepDist).clamp(0.0, 1.0);
        remainingKm -= (steps[stepIdx].distanceMeters * coveredRatio) / 1000;
        remainingSeconds -= (steps[stepIdx].durationSeconds * coveredRatio).round();
      }
    }
    remainingKm = remainingKm.clamp(0, double.infinity);
    remainingSeconds = remainingSeconds.clamp(0, 999999);

    state = state.copyWith(
      currentStepIndex: stepIdx,
      currentSpeed: speed,
      distanceToNextStep: distToNextStep,
      isOffRoute: offRoute,
      remainingKm: remainingKm,
      remainingSeconds: remainingSeconds,
    );

    return false;
  }

  /// Calculate shortest distance from a point to a polyline (list of segments).
  static double _nearestDistanceToPolyline(
      LatLng point, List<LatLng> polyline) {
    if (polyline.isEmpty) return double.infinity;
    if (polyline.length == 1) {
      return Geolocator.distanceBetween(
        point.latitude, point.longitude,
        polyline[0].latitude, polyline[0].longitude,
      );
    }

    double minDist = double.infinity;
    // Check every 5th segment for performance (polylines can have thousands of points)
    for (int i = 0; i < polyline.length - 1; i += 3) {
      final d = Geolocator.distanceBetween(
        point.latitude, point.longitude,
        polyline[i].latitude, polyline[i].longitude,
      );
      if (d < minDist) minDist = d;
    }
    // Also check the last point
    final lastD = Geolocator.distanceBetween(
      point.latitude, point.longitude,
      polyline.last.latitude, polyline.last.longitude,
    );
    if (lastD < minDist) minDist = lastD;

    return minDist;
  }
}
