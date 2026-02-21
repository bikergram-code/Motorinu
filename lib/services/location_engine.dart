import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'kalman_filter.dart';

// ─── Location Engine ──────────────────────────────────────────────────────────
//
// Central GPS pipeline: Raw GPS → Kalman filter → SmoothedPosition stream.
//
// Features:
// - Kalman-smoothed lat/lng (reduces GPS jitter)
// - EMA-smoothed speed (no wild jumps)
// - Circular-EMA heading (handles 360° wrap)
// - LocationQuality detection (good / degraded / lost)
// - Battery-adaptive: accuracy + distanceFilter configurable
// - Lost-signal timer: marks quality=lost after no update for 10s
// - Auto-reset after 30s gap or 500m jump

/// Riverpod provider for the LocationEngine singleton.
final locationEngineProvider = Provider<LocationEngine>((ref) {
  final engine = LocationEngine();
  ref.onDispose(() => engine.dispose());
  return engine;
});

class LocationEngine {
  final KalmanFilter _kalman = KalmanFilter();

  StreamSubscription<Position>? _gpsSub;
  Timer? _lostTimer;

  final _controller = StreamController<SmoothedPosition>.broadcast();
  SmoothedPosition? _lastPosition;
  LocationQuality _quality = LocationQuality.good;

  bool _running = false;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Stream of smoothed GPS positions. Subscribe to get continuous updates.
  Stream<SmoothedPosition> get positionStream => _controller.stream;

  /// Last known smoothed position (null if never acquired).
  SmoothedPosition? get lastPosition => _lastPosition;

  /// Current GPS signal quality.
  LocationQuality get quality => _quality;

  /// Whether the engine is actively listening to GPS.
  bool get isRunning => _running;

  /// Start listening to GPS with given accuracy and distance filter.
  ///
  /// [accuracy] — GPS accuracy level (affects battery usage)
  /// [distanceFilter] — minimum meters between updates
  Future<void> start({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 5,
  }) async {
    if (_running) return;

    // Check permissions
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      final requested = await Geolocator.requestPermission();
      if (requested == LocationPermission.denied ||
          requested == LocationPermission.deniedForever) {
        debugPrint('[LocationEngine] Permission denied');
        return;
      }
    }

    // Check if location service is enabled
    if (!await Geolocator.isLocationServiceEnabled()) {
      debugPrint('[LocationEngine] Location service disabled');
      return;
    }

    _running = true;
    debugPrint('[LocationEngine] Starting (accuracy=$accuracy, filter=${distanceFilter}m)');

    // Get initial position (fast, from cache)
    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        _processRawPosition(lastKnown);
      }
    } catch (e) {
      debugPrint('[LocationEngine] Could not get last known position: $e');
    }

    // Start continuous GPS stream
    _gpsSub = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
      ),
    ).listen(
      _processRawPosition,
      onError: (error) {
        debugPrint('[LocationEngine] GPS stream error: $error');
        _setQuality(LocationQuality.lost);
      },
    );

    // Start lost-signal timer
    _startLostTimer();
  }

  /// Stop listening to GPS. Cleans up resources.
  void stop() {
    if (!_running) return;

    _gpsSub?.cancel();
    _gpsSub = null;
    _lostTimer?.cancel();
    _lostTimer = null;
    _running = false;

    debugPrint('[LocationEngine] Stopped');
  }

  /// Change GPS accuracy on-the-fly (e.g., battery mode switch).
  /// Restarts the stream with new settings.
  Future<void> setAccuracy({
    required LocationAccuracy accuracy,
    required int distanceFilter,
  }) async {
    if (!_running) return;

    debugPrint('[LocationEngine] Changing accuracy to $accuracy, filter=${distanceFilter}m');

    // Cancel and restart with new settings
    _gpsSub?.cancel();
    _gpsSub = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
      ),
    ).listen(
      _processRawPosition,
      onError: (error) {
        debugPrint('[LocationEngine] GPS stream error: $error');
        _setQuality(LocationQuality.lost);
      },
    );
  }

  /// Reset the Kalman filter (e.g., after long pause or teleport).
  void resetFilter() {
    _kalman.reset();
    debugPrint('[LocationEngine] Kalman filter reset');
  }

  /// Clean up all resources.
  void dispose() {
    stop();
    _controller.close();
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  void _processRawPosition(Position raw) {
    // Apply Kalman filter
    final smoothed = _kalman.update(raw);

    _lastPosition = smoothed;
    _setQuality(smoothed.quality);

    // Emit to stream
    if (!_controller.isClosed) {
      _controller.add(smoothed);
    }

    // Reset lost timer (we got a valid update)
    _startLostTimer();
  }

  void _setQuality(LocationQuality q) {
    if (_quality != q) {
      _quality = q;
      debugPrint('[LocationEngine] Quality: ${q.name}');
    }
  }

  /// Reset the lost timer. If no GPS update for 10s, mark quality as lost.
  void _startLostTimer() {
    _lostTimer?.cancel();
    _lostTimer = Timer(const Duration(seconds: 10), () {
      if (_running) {
        _setQuality(LocationQuality.lost);
        // Also emit last position with lost quality
        if (_lastPosition != null) {
          final lost = SmoothedPosition(
            smoothedLat: _lastPosition!.smoothedLat,
            smoothedLng: _lastPosition!.smoothedLng,
            smoothedSpeed: 0, // No movement if lost
            smoothedHeading: _lastPosition!.smoothedHeading,
            rawLat: _lastPosition!.rawLat,
            rawLng: _lastPosition!.rawLng,
            rawSpeed: 0,
            rawHeading: _lastPosition!.rawHeading,
            accuracy: 999,
            quality: LocationQuality.lost,
            timestamp: DateTime.now(),
            altitude: _lastPosition!.altitude,
          );
          if (!_controller.isClosed) {
            _controller.add(lost);
          }
        }
      }
    });
  }
}
