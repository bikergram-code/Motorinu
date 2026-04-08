import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/osrm_service.dart';
import '../services/tts_alert_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  NAV ENGINE — Pure navigation logic, no UI
// ═══════════════════════════════════════════════════════════════════════════════
//
//  Usage:
//    final engine = NavEngine(osrmService: OsrmService());
//    engine.setRoute(route);
//    engine.start();
//    // On each GPS fix:
//    engine.updateGps(latLng, speedKmh, headingDeg);
//    // Read state:
//    engine.state  → NavState (immutable snapshot)
//    engine.onStateChanged  → Stream<NavState>
//    engine.dispose();
//
// ═══════════════════════════════════════════════════════════════════════════════

/// Immutable navigation state — UI reads this, never writes.
class NavState {
  final bool isNavigating;
  final OsrmRoute? route;
  final LatLng? snappedPos;       // Position snapped to route polyline
  final double smoothBearing;     // Camera bearing (dead-zone smoothed)
  final double displaySpeed;      // km/h (asymmetric EMA)
  final double rawSpeed;          // km/h raw from GPS
  final OsrmStep? nextTurn;       // Next upcoming turn
  final double nextTurnDistM;     // Distance to it (along route)
  final OsrmStep? afterNextTurn;  // "Danach:" preview
  final bool isOffRoute;
  final bool isRerouting;
  final bool hasArrived;

  const NavState({
    this.isNavigating = false,
    this.route,
    this.snappedPos,
    this.smoothBearing = 0,
    this.displaySpeed = 0,
    this.rawSpeed = 0,
    this.nextTurn,
    this.nextTurnDistM = 0,
    this.afterNextTurn,
    this.isOffRoute = false,
    this.isRerouting = false,
    this.hasArrived = false,
  });

  /// Distance text for turn banner (e.g. "200 m" or "1.5 km")
  String get nextTurnDistText {
    if (nextTurnDistM < 1000) return '${nextTurnDistM.round()} m';
    return '${(nextTurnDistM / 1000).toStringAsFixed(1)} km';
  }

  /// Remaining distance/time from route
  String get remainingDistText {
    if (route == null) return '';
    return route!.distanceText;
  }

  String get remainingTimeText {
    if (route == null) return '';
    return route!.durationText;
  }

  /// ETA as wall clock string
  String get etaText {
    if (route == null) return '--:--';
    final secs = route!.durationSeconds;
    final arrival = DateTime.now().add(Duration(seconds: secs));
    return '${arrival.hour.toString().padLeft(2, '0')}:${arrival.minute.toString().padLeft(2, '0')}';
  }
}

/// Callback for re-route (UI needs to handle setState for route change)
typedef RerouteCallback = Future<OsrmRoute?> Function(LatLng from, LatLng to);

class NavEngine {
  NavEngine({required OsrmService osrmService}) : _osrm = osrmService;

  final OsrmService _osrm;

  // ── Public state ──
  NavState get state => _state;
  NavState _state = const NavState();

  /// Stream of state changes (UI listens to this)
  Stream<NavState> get onStateChanged => _stateController.stream;
  final _stateController = StreamController<NavState>.broadcast();

  // ── Route ──
  OsrmRoute? _route;
  RouteMode _routeMode = RouteMode.biker;
  LatLng? _destination;

  // ── GPS state ──
  LatLng? _rawGps;
  double _rawSpeedKmh = 0;
  double _rawHeading = 0;
  double _displaySpeed = 0;
  bool _hasEverDriven = false;

  // ── Snap to route ──
  int _lastSnapSegIdx = 0;
  LatLng? _lastSnapInput;
  LatLng? _lastSnapResult;
  double _lastSnapDist = double.infinity;

  // ── OSRM map matching ──
  final List<LatLng> _matchBuffer = [];
  final List<int> _matchTimestamps = [];
  int _matchTickCounter = 0;
  LatLng? _osrmMatchedPos;
  bool _matchInFlight = false;

  // ── Camera bearing (Waze dead-zone) ──
  double _committedBearing = 0;
  double _smoothBearing = 0;

  // ── TTS announcements ──
  int _lastAnnouncedStepIdx = -1;
  final Set<String> _announcedPairs = {};
  DateTime? _lastStraightAnnounce; // last "weiter geradeaus" time

  // ── Next turn tracking ──
  OsrmStep? _nextTurn;
  double _nextTurnDistM = 0;
  OsrmStep? _afterNextTurn;

  // ── Off-route detection ──
  int _offRouteCount = 0;
  bool _offRouteTriggered = false;
  bool _isRerouting = false;

  // ── Timers ──
  Timer? _cameraTimer;  // 30fps bearing interpolation
  Timer? _navTimer;     // 1Hz announcements + off-route

  // ── Callbacks ──
  RerouteCallback? onReroute;
  VoidCallback? onArrived;
  VoidCallback? onStateChangedSync; // For setState() in widget

  // ═════════════════════════════════════════════════════════════════════════════
  //  PUBLIC API
  // ═════════════════════════════════════════════════════════════════════════════

  /// Set the active route and destination.
  void setRoute(OsrmRoute route, {LatLng? destination, RouteMode mode = RouteMode.biker}) {
    _route = route;
    _destination = destination ?? (route.polylinePoints.isNotEmpty ? route.polylinePoints.last : null);
    _routeMode = mode;
    _resetTracking();
    _emit();
  }

  /// Start turn-by-turn navigation.
  void start({LatLng? currentPos}) {
    if (_route == null) return;
    _resetTracking();
    _startTimers();

    // Use provided position or fallback to last known
    final pos = currentPos ?? _rawGps;
    if (pos != null) {
      _rawGps = pos;
      _updateNextTurn(pos);
    }

    // Don't announce here — group_ride_screen handles nav start TTS
    _emit(isNavigating: true);
  }

  /// Stop navigation.
  void stop() {
    _stopTimers();
    _route = null;
    _destination = null;
    _resetTracking();
    _emit(isNavigating: false);
  }

  /// Feed a GPS fix. Call this on every location update (~1Hz).
  void updateGps(LatLng pos, double speedKmh, double headingDeg) {
    _rawGps = pos;
    _rawSpeedKmh = speedKmh;
    if (speedKmh > 5) {
      _rawHeading = headingDeg;
      _hasEverDriven = true;
    }

    // Invalidate snap cache
    _lastSnapInput = null;

    // Speed: asymmetric EMA (fast up, slow down)
    final target = speedKmh < 5 ? 0.0 : speedKmh;
    final lerp = target > _displaySpeed ? 0.7 : 0.35;
    _displaySpeed += (target - _displaySpeed) * lerp;
    if (_displaySpeed < 1) _displaySpeed = 0;

    // OSRM map matching
    if (_state.isNavigating) {
      _feedMatchBuffer(pos);
    }

    // Update turn distance (real-time for banner)
    if (_nextTurn != null && _state.isNavigating) {
      _nextTurnDistM = _distAlongRoute(pos, _nextTurn!.location);
    }

    // Mark camera dirty
    _cameraDirty = true;

    _emit(isNavigating: _state.isNavigating);
  }

  /// Dispose — call in widget dispose().
  void dispose() {
    _stopTimers();
    _stateController.close();
  }

  // ═════════════════════════════════════════════════════════════════════════════
  //  INTERNAL: State emission
  // ═════════════════════════════════════════════════════════════════════════════

  void _emit({bool? isNavigating}) {
    final snapped = _rawGps != null && _route != null
        ? _snapToRoute(_rawGps!)
        : _rawGps;

    _state = NavState(
      isNavigating: isNavigating ?? _state.isNavigating,
      route: _route,
      snappedPos: snapped,
      smoothBearing: _smoothBearing,
      displaySpeed: _displaySpeed,
      rawSpeed: _rawSpeedKmh,
      nextTurn: _nextTurn,
      nextTurnDistM: _nextTurnDistM,
      afterNextTurn: _afterNextTurn,
      isOffRoute: _offRouteCount >= 3,
      isRerouting: _isRerouting,
      hasArrived: false,
    );
    if (!_stateController.isClosed) _stateController.add(_state);
    onStateChangedSync?.call();
  }

  void _resetTracking() {
    _lastAnnouncedStepIdx = -1;
    _announcedPairs.clear();
    _lastStraightAnnounce = null;
    _offRouteCount = 0;
    _offRouteTriggered = false;
    _isRerouting = false;
    _lastSnapInput = null;
    _lastSnapResult = null;
    _lastSnapDist = double.infinity;
    _lastSnapSegIdx = 0;
    _matchBuffer.clear();
    _matchTimestamps.clear();
    _matchTickCounter = 0;
    _osrmMatchedPos = null;
    _matchInFlight = false;
    _nextTurn = null;
    _nextTurnDistM = 0;
    _afterNextTurn = null;
  }

  // ═════════════════════════════════════════════════════════════════════════════
  //  INTERNAL: Timers
  // ═════════════════════════════════════════════════════════════════════════════

  bool _cameraDirty = false;

  void _startTimers() {
    _stopTimers();

    // 30fps camera bearing interpolation (Waze dead-zone)
    _cameraTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      _tickCamera();
    });

    // 1Hz navigation tasks (announcements, next turn)
    // Off-route check is handled by GroupRideScreen (uses Google Routes for reroute)
    _navTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_rawGps == null || !_state.isNavigating) return;
      _announceNextStep(_rawGps!);
      _updateNextTurn(_rawGps!);
    });
  }

  void _stopTimers() {
    _cameraTimer?.cancel();
    _cameraTimer = null;
    _navTimer?.cancel();
    _navTimer = null;
  }

  // ═════════════════════════════════════════════════════════════════════════════
  //  CAMERA: Waze-style dead-zone bearing
  // ═════════════════════════════════════════════════════════════════════════════

  void _tickCamera() {
    // Dead-zone: only commit new bearing when heading changes >12°
    if (_rawSpeedKmh > 5) {
      // Use route heading for predictive curves
      double targetHdg = _rawHeading;
      if (_state.isNavigating && _rawGps != null) {
        final snapped = _snapToRoute(_rawGps!);
        final routeHdg = _routeHeadingAhead(snapped);
        if (routeHdg != null) {
          // Blend route (predictive) + GPS (actual)
          targetHdg = _lerpAngle(routeHdg, _rawHeading, 0.35);
        }
      }

      double delta = (targetHdg - _committedBearing) % 360;
      if (delta > 180) delta -= 360;
      if (delta < -180) delta += 360;
      // 15° dead-zone (consistent with group_ride_screen camera loop)
      if (delta.abs() > 15) {
        _committedBearing = targetHdg;
      }
    }

    // Smooth animation toward committed bearing
    double diff = _committedBearing - _smoothBearing;
    while (diff > 180) { diff -= 360; }
    while (diff < -180) { diff += 360; }
    if (diff.abs() > 0.3) {
      _smoothBearing += diff * 0.15;
      if (_smoothBearing < 0) _smoothBearing += 360;
      if (_smoothBearing >= 360) _smoothBearing -= 360;
      _cameraDirty = false;
      _emit(isNavigating: _state.isNavigating);
    }
  }

  // ═════════════════════════════════════════════════════════════════════════════
  //  TTS ANNOUNCEMENTS: 3-threshold system (500m, 200m, Jetzt)
  // ═════════════════════════════════════════════════════════════════════════════

  void _announceNextStep(LatLng pos) {
    if (_route == null || _route!.steps.isEmpty) return;
    if (TtsAlertService.instance.isQueueActive) return;

    final steps = _route!.steps;

    for (int i = _lastAnnouncedStepIdx + 1; i < steps.length; i++) {
      final step = steps[i];
      if (step.maneuver.startsWith('depart')) continue;

      final dist = _distAlongRoute(pos, step.location);

      // Road name dedup
      final hasRoadInInstruction = step.roadName != null &&
          step.roadName!.isNotEmpty &&
          step.instruction.toLowerCase().contains(step.roadName!.toLowerCase());
      final roadInfo = (step.roadName != null &&
              step.roadName!.isNotEmpty &&
              !hasRoadInInstruction)
          ? ' auf ${step.roadName}'
          : '';

      // ── Arrival (arrive, arrive-left, arrive-right) ──
      if (step.maneuver.startsWith('arrive')) {
        // Use BOTH along-route AND straight-line distance — whichever is smaller
        // (along-route can overshoot if polyline loops past destination)
        final straightDist = _distLatLng(pos, step.location);
        final arrivalDist = dist < straightDist ? dist : straightDist;
        if (arrivalDist < 50) {
          _lastAnnouncedStepIdx = i;
          TtsAlertService.instance.clearQueue();
          TtsAlertService.instance.speakQueued(
            'Du hast dein Ziel erreicht. Viel Spaß noch!',
          );
          _emit(isNavigating: false);
          onArrived?.call();
          return;
        }
        // Don't announce arrival step as regular turn — skip it
        return;
      }

      // ── Threshold check (4 levels for motorcycle riding) ──
      // 500m: early heads-up
      // 200m: preparation
      // 100m: get ready (important for riders who can't look at screen)
      //  40m: now! execute the maneuver
      String? threshold;
      String? distText;
      if (dist <= 40) {
        threshold = 'now';
        distText = 'Jetzt';
      } else if (dist <= 100) {
        threshold = '100m';
        final rounded = (dist / 10).round() * 10;
        distText = 'In $rounded Metern';
      } else if (dist <= 200) {
        threshold = '200m';
        distText = 'In 200 Metern';
      } else if (dist <= 500) {
        threshold = '500m';
        distText = 'In 500 Metern';
      }

      if (threshold == null) {
        // Far from next turn → periodic "weiter geradeaus" every 45s
        if (dist > 800 && i == _lastAnnouncedStepIdx + 1) {
          final now = DateTime.now();
          if (_lastStraightAnnounce == null ||
              now.difference(_lastStraightAnnounce!) > const Duration(seconds: 45)) {
            _lastStraightAnnounce = now;
            final distKm = (dist / 1000).toStringAsFixed(1);
            final nextAction = step.maneuver.contains('straight') || step.maneuver.contains('continue')
                ? ''
                : ', dann ${step.instruction}$roadInfo';
            TtsAlertService.instance.speakText(
              'Weiter geradeaus für $distKm Kilometer$nextAction',
            );
          }
        }
        return; // Not close enough for threshold announcement
      }

      // Dedup
      final key = '$i:$threshold';
      if (_announcedPairs.contains(key)) {
        if (threshold == 'now') _lastAnnouncedStepIdx = i;
        return;
      }
      _announcedPairs.add(key);

      if (threshold == 'now') {
        _lastAnnouncedStepIdx = i;
        TtsAlertService.instance.speakPriority('Jetzt, ${step.instruction}$roadInfo!');
      } else {
        TtsAlertService.instance.speakPriority(
          '$distText, ${step.instruction}$roadInfo',
        );
      }
      return;
    }
  }

  // ═════════════════════════════════════════════════════════════════════════════
  //  NEXT TURN TRACKING (for banner display)
  // ═════════════════════════════════════════════════════════════════════════════

  void _updateNextTurn(LatLng pos) {
    if (_route == null || _route!.steps.isEmpty) {
      _nextTurn = null;
      _afterNextTurn = null;
      return;
    }
    final steps = _route!.steps;
    bool foundFirst = false;
    for (int i = _lastAnnouncedStepIdx + 1; i < steps.length; i++) {
      final step = steps[i];
      if (step.maneuver.startsWith('depart')) continue;
      if (!foundFirst) {
        _nextTurn = step;
        _nextTurnDistM = _distAlongRoute(pos, step.location);
        foundFirst = true;
      } else {
        if (!step.maneuver.startsWith('depart') && !step.maneuver.startsWith('arrive')) {
          _afterNextTurn = step;
        }
        return;
      }
    }
    if (!foundFirst) _nextTurn = null;
    _afterNextTurn = null;
  }

  // ═════════════════════════════════════════════════════════════════════════════
  //  OFF-ROUTE DETECTION + AUTO-REROUTE
  // ═════════════════════════════════════════════════════════════════════════════

  void _checkOffRoute(LatLng pos) {
    if (_route == null || _isRerouting) return;

    // Mode-aware thresholds: pedestrians walk on narrow sidewalks (~3m wide),
    // bikers/cars need more tolerance (GPS noise at speed).
    final offThreshold = _routeMode == RouteMode.pedestrian ? 15.0 : 35.0;
    final onThreshold = _routeMode == RouteMode.pedestrian ? 10.0 : 20.0;

    final dist = _minDistToRoute(pos);
    if (dist > offThreshold) {
      _offRouteCount++;
      if (_offRouteCount >= 3 && !_offRouteTriggered) {
        _offRouteTriggered = true;
        _offRouteCount = 0;
        debugPrint('[NavEngine] Off-route (${dist.toStringAsFixed(0)}m > ${offThreshold}m) → auto-rerouting');

        TtsAlertService.instance.clearQueue();
        TtsAlertService.instance.speakQueued('Route wird neu berechnet.');

        if (_destination != null) {
          _doReroute(pos, _destination!);
        }
      }
    } else if (dist < onThreshold) {
      // Hysteresis: only reset when clearly back on-route (lower threshold)
      // Prevents GPS noise oscillation (35m off → 25m on → 35m off)
      _offRouteCount = 0;
      _offRouteTriggered = false;
    }
  }

  Future<void> _doReroute(LatLng from, LatLng to) async {
    _isRerouting = true;
    _emit(isNavigating: true);

    try {
      OsrmRoute? newRoute;
      if (onReroute != null) {
        newRoute = await onReroute!(from, to);
      } else {
        final routes = await _osrm.getAllRoutes(from, to, mode: _routeMode);
        if (routes.isNotEmpty) {
          if (_routeMode == RouteMode.biker && routes.length > 1) {
            final sorted = List<OsrmRoute>.from(routes)
              ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
            newRoute = sorted.last;
          } else {
            newRoute = routes.first;
          }
        }
      }

      if (newRoute != null) {
        _route = newRoute;
        _resetTracking();
        debugPrint('[NavEngine] Rerouted: ${newRoute.distanceText}');
        TtsAlertService.instance.clearQueue();
        TtsAlertService.instance.speakQueued(
          'Neue Route. ${newRoute.distanceText}, ${newRoute.durationText}.',
        );
      }
    } catch (e) {
      debugPrint('[NavEngine] Reroute error: $e');
    } finally {
      _isRerouting = false;
      _offRouteTriggered = false;
      _emit(isNavigating: true);
    }
  }

  // ═════════════════════════════════════════════════════════════════════════════
  //  SNAP TO ROUTE
  // ═════════════════════════════════════════════════════════════════════════════

  LatLng _snapToRoute(LatLng gps) {
    // Cache: same input → same output
    if (_lastSnapInput != null &&
        _lastSnapInput!.latitude == gps.latitude &&
        _lastSnapInput!.longitude == gps.longitude) {
      return _lastSnapResult ?? gps;
    }

    if (_route == null || _route!.polylinePoints.length < 2) {
      _lastSnapInput = gps;
      _lastSnapResult = gps;
      _lastSnapDist = double.infinity;
      return gps;
    }

    // Prefer OSRM map-matched position
    if (_osrmMatchedPos != null) {
      final d = _distLatLng(_osrmMatchedPos!, gps);
      if (d < 30) {
        _lastSnapInput = gps;
        _lastSnapDist = d;
        _lastSnapResult = _osrmMatchedPos;
        return _lastSnapResult!;
      }
    }

    // Local polyline projection
    final pts = _route!.polylinePoints;
    double bestDistSq = double.infinity;
    LatLng bestPoint = gps;
    int bestIdx = 0;

    // Phase 1: Coarse (every 10th point)
    for (int i = 0; i < pts.length - 1; i += 10) {
      final d = _distSq(gps, pts[i]);
      if (d < bestDistSq) {
        bestDistSq = d;
        bestIdx = i;
      }
    }

    // Phase 2: Fine (±15 around best)
    bestDistSq = double.infinity;
    final start = (bestIdx - 15).clamp(0, pts.length - 2);
    final end = (bestIdx + 15).clamp(0, pts.length - 1);
    int bestSegIdx = bestIdx;
    for (int i = start; i < end; i++) {
      final snapped = _projectOnSegment(gps, pts[i], pts[i + 1]);
      final d = _distSq(gps, snapped);
      if (d < bestDistSq) {
        bestDistSq = d;
        bestPoint = snapped;
        bestSegIdx = i;
      }
    }

    final bestDist = math.sqrt(bestDistSq);
    if (bestDist < 50) _lastSnapSegIdx = bestSegIdx;

    _lastSnapInput = gps;
    _lastSnapDist = bestDist;
    _lastSnapResult = bestDist < 50 ? bestPoint : gps;
    return _lastSnapResult!;
  }

  double _minDistToRoute(LatLng gps) {
    if (_lastSnapInput != null &&
        _lastSnapInput!.latitude == gps.latitude &&
        _lastSnapInput!.longitude == gps.longitude) {
      return _lastSnapDist;
    }
    _snapToRoute(gps);
    return _lastSnapDist;
  }

  // ═════════════════════════════════════════════════════════════════════════════
  //  ROUTE HEADING (predictive, 60m look-ahead)
  // ═════════════════════════════════════════════════════════════════════════════

  double? _routeHeadingAhead(LatLng snappedPos) {
    if (_route == null || _route!.polylinePoints.length < 2) return null;
    final pts = _route!.polylinePoints;
    final segIdx = _lastSnapSegIdx.clamp(0, pts.length - 2);

    const lookAheadM = 60.0;
    double walked = 0;
    LatLng aheadPt = snappedPos;
    for (int i = segIdx; i < pts.length - 1 && walked < lookAheadM; i++) {
      final segLen = _distLatLng(pts[i], pts[i + 1]);
      if (walked + segLen >= lookAheadM) {
        final frac = segLen > 0 ? (lookAheadM - walked) / segLen : 0.0;
        aheadPt = LatLng(
          pts[i].latitude + (pts[i + 1].latitude - pts[i].latitude) * frac,
          pts[i].longitude + (pts[i + 1].longitude - pts[i].longitude) * frac,
        );
        walked = lookAheadM;
        break;
      }
      walked += segLen;
      aheadPt = pts[i + 1];
    }

    if (walked < 10) return null;

    final dLat = aheadPt.latitude - snappedPos.latitude;
    final dLng = aheadPt.longitude - snappedPos.longitude;
    if (dLat.abs() < 1e-9 && dLng.abs() < 1e-9) return null;

    final cosLat = math.cos(snappedPos.latitude * math.pi / 180);
    final bearing = math.atan2(dLng * cosLat, dLat) * 180 / math.pi;
    return (bearing + 360) % 360;
  }

  // ═════════════════════════════════════════════════════════════════════════════
  //  OSRM MAP MATCHING
  // ═════════════════════════════════════════════════════════════════════════════

  void _feedMatchBuffer(LatLng gps) {
    _matchBuffer.add(gps);
    _matchTimestamps.add(DateTime.now().millisecondsSinceEpoch ~/ 1000);
    if (_matchBuffer.length > 8) {
      _matchBuffer.removeAt(0);
      _matchTimestamps.removeAt(0);
    }

    _matchTickCounter++;
    if (_matchTickCounter < 3) return;
    _matchTickCounter = 0;
    if (_matchBuffer.length < 3 || _matchInFlight) return;

    _matchInFlight = true;
    final pts = List<LatLng>.from(_matchBuffer);
    final ts = List<int>.from(_matchTimestamps);

    _osrm.matchPosition(pts, timestamps: ts).then((matched) {
      _matchInFlight = false;
      if (matched != null) {
        final d = _distLatLng(matched, _matchBuffer.last);
        if (d < 50) {
          _osrmMatchedPos = matched;
        }
      }
    }).catchError((_) { _matchInFlight = false; });
  }

  // ═════════════════════════════════════════════════════════════════════════════
  //  DISTANCE ALONG ROUTE
  // ═════════════════════════════════════════════════════════════════════════════

  double _distAlongRoute(LatLng from, LatLng to) {
    if (_route == null || _route!.polylinePoints.length < 2) {
      return _distLatLng(from, to);
    }
    final pts = _route!.polylinePoints;

    int nearestIdx = 0;
    double nearestDist = double.infinity;
    for (int i = 0; i < pts.length; i++) {
      final d = _distLatLng(from, pts[i]);
      if (d < nearestDist) {
        nearestDist = d;
        nearestIdx = i;
      }
    }

    int targetIdx = nearestIdx;
    double targetDist = double.infinity;
    for (int i = nearestIdx; i < pts.length; i++) {
      final d = _distLatLng(to, pts[i]);
      if (d < targetDist) {
        targetDist = d;
        targetIdx = i;
      }
    }

    double total = _distLatLng(from, pts[nearestIdx]);
    for (int i = nearestIdx; i < targetIdx && i + 1 < pts.length; i++) {
      total += _distLatLng(pts[i], pts[i + 1]);
    }
    return total;
  }

  // ═════════════════════════════════════════════════════════════════════════════
  //  MATH HELPERS
  // ═════════════════════════════════════════════════════════════════════════════

  static double _lerpAngle(double a, double b, double t) {
    double diff = (b - a) % 360;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    return (a + diff * t) % 360;
  }

  /// Haversine distance in meters.
  static double _distLatLng(LatLng a, LatLng b) {
    const R = 6371000.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final sinLat = math.sin(dLat / 2);
    final sinLng = math.sin(dLng / 2);
    final h = sinLat * sinLat +
        math.cos(a.latitude * math.pi / 180) *
            math.cos(b.latitude * math.pi / 180) *
            sinLng * sinLng;
    return 2 * R * math.asin(math.sqrt(h));
  }

  /// Squared distance (for comparisons, no sqrt needed).
  static double _distSq(LatLng a, LatLng b) {
    final dLat = a.latitude - b.latitude;
    final dLng = a.longitude - b.longitude;
    return dLat * dLat + dLng * dLng;
  }

  /// Project point P onto segment AB.
  static LatLng _projectOnSegment(LatLng p, LatLng a, LatLng b) {
    final dx = b.latitude - a.latitude;
    final dy = b.longitude - a.longitude;
    if (dx == 0 && dy == 0) return a;
    var t = ((p.latitude - a.latitude) * dx + (p.longitude - a.longitude) * dy) /
        (dx * dx + dy * dy);
    t = t.clamp(0.0, 1.0);
    return LatLng(a.latitude + t * dx, a.longitude + t * dy);
  }

  // ═════════════════════════════════════════════════════════════════════════════
  //  MANEUVER → ICON (for UI)
  // ═════════════════════════════════════════════════════════════════════════════

  /// Map OSRM maneuver type to a Material icon.
  static int maneuverIconCodePoint(String maneuver) {
    if (maneuver.contains('uturn')) return 0xf07a5;     // u_turn_left
    if (maneuver.contains('roundabout') || maneuver.contains('rotary')) return 0xf07a3; // roundabout_left
    if (maneuver.contains('fork-left')) return 0xf07a0;  // fork_left
    if (maneuver.contains('fork-right')) return 0xf07a1; // fork_right
    if (maneuver.contains('ferry')) return 0xe532;       // directions_boat
    if (maneuver.contains('ramp')) return 0xf07a2;       // ramp_right
    if (maneuver.contains('merge')) return 0xf07a2;      // merge
    if (maneuver.contains('left')) return 0xf07a4;       // turn_left
    if (maneuver.contains('right')) return 0xf07a6;      // turn_right
    if (maneuver == 'arrive') return 0xe153;             // flag
    if (maneuver == 'depart') return 0xe55d;             // navigation
    return 0xeb95;                                        // straight
  }
}
