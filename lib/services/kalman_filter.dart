import 'dart:math';

import 'package:geolocator/geolocator.dart';

// ─── Kalman Filter for GPS Smoothing ──────────────────────────────────────────
//
// Simplified 1D Kalman filter applied independently to latitude and longitude.
// Uses GPS accuracy as measurement noise, adapts process noise to time delta
// and estimated speed. Handles GPS jumps (>500m) by resetting.
//
// References:
// - Kalman (1960) "A New Approach to Linear Filtering"
// - Adapted for mobile GPS with variable accuracy

/// Result of Kalman filter processing a GPS position.
class SmoothedPosition {
  final double smoothedLat;
  final double smoothedLng;
  final double smoothedSpeed;   // km/h, EMA smoothed
  final double smoothedHeading; // degrees (0-360), weighted average
  final double rawLat;
  final double rawLng;
  final double rawSpeed;        // km/h
  final double rawHeading;
  final double accuracy;        // meters (from GPS)
  final LocationQuality quality;
  final DateTime timestamp;
  final double altitude;

  const SmoothedPosition({
    required this.smoothedLat,
    required this.smoothedLng,
    required this.smoothedSpeed,
    required this.smoothedHeading,
    required this.rawLat,
    required this.rawLng,
    required this.rawSpeed,
    required this.rawHeading,
    required this.accuracy,
    required this.quality,
    required this.timestamp,
    this.altitude = 0,
  });

  /// Convenience: get as LatLng for Google Maps.
  // ignore: depend_on_referenced_packages
  double get latitude => smoothedLat;
  double get longitude => smoothedLng;
  double get speed => smoothedSpeed;        // km/h
  double get heading => smoothedHeading;
}

/// GPS signal quality.
enum LocationQuality {
  /// accuracy ≤ 15m — excellent GPS lock
  good,
  /// accuracy 15-50m — usable but degraded (urban canyon, indoors)
  degraded,
  /// accuracy > 50m OR no update in >10s — unreliable
  lost,
}

// ─── 1D Kalman Filter State ──────────────────────────────────────────────────

class _Kalman1D {
  double _estimate = 0;
  double _errorEstimate = 1.0;

  /// Update with new measurement.
  ///
  /// [measurement] — the observed value (lat or lng)
  /// [measurementNoise] — GPS accuracy in degrees (higher = less trust)
  /// [processNoise] — expected change variance (speed × dt, scaled)
  double update(double measurement, double measurementNoise, double processNoise) {
    // Prediction step: estimate stays, error grows
    _errorEstimate += processNoise;

    // Update step: Kalman gain
    final gain = _errorEstimate / (_errorEstimate + measurementNoise);

    // Correction
    _estimate = _estimate + gain * (measurement - _estimate);
    _errorEstimate = (1 - gain) * _errorEstimate;

    return _estimate;
  }

  void reset(double initial) {
    _estimate = initial;
    _errorEstimate = 1.0;
  }
}

// ─── GPS Kalman Filter ───────────────────────────────────────────────────────

class KalmanFilter {
  final _latFilter = _Kalman1D();
  final _lngFilter = _Kalman1D();

  bool _initialized = false;
  DateTime? _lastTimestamp;
  double _lastSmoothedSpeed = 0;     // km/h, EMA smoothed
  double _lastSmoothedHeading = 0;   // degrees

  // Thresholds
  static const double _jumpThresholdMeters = 500;   // Reset if position jumps >500m
  static const double _speedEmaAlpha = 0.7;         // Speed smoothing — fast follow (motorcycle tacho feel)
  static const double _headingEmaAlpha = 0.25;      // Heading smoothing (lower = smoother)
  static const double _maxGapSeconds = 30;           // Reset after 30s gap
  static const double _metersPerDegree = 111_320.0;  // Approx meters per degree lat

  /// Process a raw GPS position and return a smoothed result.
  SmoothedPosition update(Position raw) {
    final now = DateTime.now();
    final rawLat = raw.latitude;
    final rawLng = raw.longitude;
    final rawAccuracy = raw.accuracy.clamp(1.0, 500.0); // meters
    final rawSpeedKmh = (raw.speed >= 0 ? raw.speed : 0.0) * 3.6;
    final rawHeading = raw.heading >= 0 ? raw.heading : 0.0;

    // Determine quality
    final quality = _assessQuality(rawAccuracy, now);

    // ── First measurement: initialize ──
    if (!_initialized) {
      _latFilter.reset(rawLat);
      _lngFilter.reset(rawLng);
      _lastTimestamp = now;
      _lastSmoothedSpeed = rawSpeedKmh;
      _lastSmoothedHeading = rawHeading;
      _initialized = true;

      return SmoothedPosition(
        smoothedLat: rawLat,
        smoothedLng: rawLng,
        smoothedSpeed: rawSpeedKmh,
        smoothedHeading: rawHeading,
        rawLat: rawLat,
        rawLng: rawLng,
        rawSpeed: rawSpeedKmh,
        rawHeading: rawHeading,
        accuracy: rawAccuracy,
        quality: quality,
        timestamp: now,
        altitude: raw.altitude,
      );
    }

    // ── Time delta ──
    final dt = _lastTimestamp != null
        ? now.difference(_lastTimestamp!).inMilliseconds / 1000.0
        : 1.0;

    // ── Gap detection: reset after long pause ──
    if (dt > _maxGapSeconds) {
      reset();
      return update(raw); // Re-process as first measurement
    }

    // ── Jump detection ──
    final jumpDist = Geolocator.distanceBetween(
      _latFilter._estimate, _lngFilter._estimate, rawLat, rawLng,
    );

    // Hard reset: teleport > 500m (new location entirely)
    if (jumpDist > _jumpThresholdMeters) {
      reset();
      return update(raw);
    }

    // Speed-based plausibility: ignore GPS spikes that exceed max plausible movement
    // maxPlausible = max(currentSpeed * dt * 2.5, 30m) — generous enough for acceleration
    final maxPlausibleMeters = max(_lastSmoothedSpeed / 3.6 * dt * 2.5, 30.0);
    if (jumpDist > maxPlausibleMeters) {
      // GPS spike — keep old estimate, just update timestamp
      _lastTimestamp = now;
      return SmoothedPosition(
        smoothedLat: _latFilter._estimate,
        smoothedLng: _lngFilter._estimate,
        smoothedSpeed: _lastSmoothedSpeed,
        smoothedHeading: _lastSmoothedHeading,
        rawLat: rawLat,
        rawLng: rawLng,
        rawSpeed: rawSpeedKmh,
        rawHeading: rawHeading,
        accuracy: rawAccuracy,
        quality: quality,
        timestamp: now,
        altitude: raw.altitude,
      );
    }

    // ── Convert accuracy from meters to degrees ──
    final accuracyDeg = rawAccuracy / _metersPerDegree;
    // Measurement noise: square of accuracy in degrees
    // Lower accuracy (higher meters) = higher noise = less trust
    final measurementNoise = accuracyDeg * accuracyDeg;

    // ── Process noise: based on speed and time delta ──
    // Higher speed = position changes more = more process noise
    final speedMs = rawSpeedKmh / 3.6;
    final expectedMoveDeg = (speedMs * dt) / _metersPerDegree;
    // Process noise is proportional to expected movement squared
    final processNoise = max(expectedMoveDeg * expectedMoveDeg, 1e-10);

    // ── Apply Kalman filter ──
    final smoothedLat = _latFilter.update(rawLat, measurementNoise, processNoise);
    final smoothedLng = _lngFilter.update(rawLng, measurementNoise, processNoise);

    // ── Speed smoothing (EMA) ──
    _lastSmoothedSpeed = _lastSmoothedSpeed * (1 - _speedEmaAlpha) +
        rawSpeedKmh * _speedEmaAlpha;
    // Clamp near-zero speeds to 0 (avoid jitter when standing)
    if (_lastSmoothedSpeed < 2.0 && rawSpeedKmh < 3.0) {
      _lastSmoothedSpeed = 0;
    }

    // ── Heading smoothing (circular EMA) ──
    _lastSmoothedHeading = _circularEma(
      _lastSmoothedHeading, rawHeading, _headingEmaAlpha,
    );

    _lastTimestamp = now;

    return SmoothedPosition(
      smoothedLat: smoothedLat,
      smoothedLng: smoothedLng,
      smoothedSpeed: _lastSmoothedSpeed,
      smoothedHeading: _lastSmoothedHeading,
      rawLat: rawLat,
      rawLng: rawLng,
      rawSpeed: rawSpeedKmh,
      rawHeading: rawHeading,
      accuracy: rawAccuracy,
      quality: quality,
      timestamp: now,
      altitude: raw.altitude,
    );
  }

  /// Reset filter state (e.g., after long pause or GPS jump).
  void reset() {
    _initialized = false;
    _lastTimestamp = null;
    _lastSmoothedSpeed = 0;
    _lastSmoothedHeading = 0;
  }

  /// Assess GPS quality from accuracy and timing.
  LocationQuality _assessQuality(double accuracyMeters, DateTime now) {
    // Check time gap first
    if (_lastTimestamp != null) {
      final gap = now.difference(_lastTimestamp!).inSeconds;
      if (gap > 10) return LocationQuality.lost;
    }

    if (accuracyMeters <= 15) return LocationQuality.good;
    if (accuracyMeters <= 50) return LocationQuality.degraded;
    return LocationQuality.lost;
  }

  /// Circular exponential moving average for heading (handles 0°/360° wrap).
  double _circularEma(double current, double target, double alpha) {
    // Convert to radians
    final curRad = current * pi / 180;
    final tarRad = target * pi / 180;

    // Weighted average in component space
    final x = cos(curRad) * (1 - alpha) + cos(tarRad) * alpha;
    final y = sin(curRad) * (1 - alpha) + sin(tarRad) * alpha;

    // Convert back to degrees
    var result = atan2(y, x) * 180 / pi;
    if (result < 0) result += 360;
    return result;
  }
}
