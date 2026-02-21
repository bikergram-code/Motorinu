import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../data/repositories/blitzer_repository.dart';
import '../providers/blitzer/blitzer_settings_provider.dart';

// ─── Blitzer Alert Service ───────────────────────────────────────────────────
//
// Intelligent alert engine:
// - Time-to-camera based alerts (not just distance)
// - Direction-sensitive: only warns if you're heading toward the blitzer
// - Multi-stage warnings: early → approach → immediate
// - Cooldown per blitzer to prevent spam
// - Speed-based alert thresholds

/// Alert severity levels.
enum AlertStage {
  early,      // 1000m+ at current speed → ~20s away
  approach,   // 500m+ at current speed → ~10s away
  immediate,  // 200m+ → < 5s away
}

/// A single blitzer alert event.
class BlitzerAlert {
  final BlitzerReport report;
  final AlertStage stage;
  final double distanceMeters;
  final double timeToReachSeconds; // Estimated time to reach blitzer
  final double bearingToBlitzer;   // Bearing from user to blitzer (degrees)

  const BlitzerAlert({
    required this.report,
    required this.stage,
    required this.distanceMeters,
    required this.timeToReachSeconds,
    required this.bearingToBlitzer,
  });

  /// Human-readable distance.
  String get distanceText => distanceMeters < 1000
      ? '${distanceMeters.round()} m'
      : '${(distanceMeters / 1000).toStringAsFixed(1)} km';

  /// Human-readable time.
  String get timeText {
    if (timeToReachSeconds < 60) return '${timeToReachSeconds.round()} Sek.';
    return '${(timeToReachSeconds / 60).toStringAsFixed(1)} Min.';
  }

  /// Warning text for UI banner.
  String get warningText {
    final typeLabel = switch (report.type) {
      'fixed' => 'Fester Blitzer',
      'mobile' => 'Mobiler Blitzer',
      'police' => 'Polizeikontrolle',
      'construction' => 'Baustelle',
      'accident' => 'Unfall',
      _ => 'Warnung',
    };
    return switch (stage) {
      AlertStage.early => '$typeLabel in $distanceText (~$timeText)',
      AlertStage.approach => '⚠️ $typeLabel in $distanceText!',
      AlertStage.immediate => '🚨 $typeLabel voraus! $distanceText',
    };
  }
}

/// Result of checking all blitzers against current position.
class AlertCheckResult {
  final List<BlitzerAlert> newAlerts;
  final List<BlitzerAlert> activeAlerts; // Currently in range
  final List<int> passedBlitzerIds;       // Just passed (for cooldown)

  const AlertCheckResult({
    this.newAlerts = const [],
    this.activeAlerts = const [],
    this.passedBlitzerIds = const [],
  });
}

class BlitzerAlertService {
  // Cooldown: don't re-alert the same blitzer within 60 seconds
  final Map<int, DateTime> _cooldowns = {};
  static const _cooldownDuration = Duration(seconds: 60);

  // Track last stage per blitzer to only fire NEW stage transitions
  final Map<int, AlertStage> _lastStagePerBlitzer = {};

  /// Check all reports against current position and heading.
  ///
  /// [pos] — current GPS position
  /// [reports] — all loaded blitzer reports
  /// [settings] — user's blitzer settings
  /// [currentSpeedKmh] — current speed in km/h (from GPS or nav state)
  AlertCheckResult checkAlerts({
    required Position pos,
    required List<BlitzerReport> reports,
    required BlitzerSettings settings,
    required double currentSpeedKmh,
  }) {
    final now = DateTime.now();
    final newAlerts = <BlitzerAlert>[];
    final activeAlerts = <BlitzerAlert>[];
    final passedIds = <int>[];

    // Clean up old cooldowns
    _cooldowns.removeWhere((_, time) => now.difference(time) > _cooldownDuration);

    // Current speed in m/s (minimum 1 m/s to avoid division by zero)
    final speedMs = max(currentSpeedKmh / 3.6, 1.0);

    for (final report in reports) {
      // Skip types user doesn't want to be warned about
      if (!settings.shouldWarn(report.type)) continue;

      // Distance to blitzer
      final dist = Geolocator.distanceBetween(
        pos.latitude, pos.longitude,
        report.latitude, report.longitude,
      );

      // Get max alert distance for this type — SPEED-ADAPTIVE
      // At 80 km/h: 1.0× base distance (reference speed)
      // At 40 km/h: 0.5× (less warning needed at low speed)
      // At 160 km/h: 2.0× (more warning needed at high speed)
      final baseAlertDist = settings.alertDistanceFor(report.type).toDouble();
      final speedFactor = (currentSpeedKmh / 80.0).clamp(0.5, 2.5);
      final maxAlertDist = baseAlertDist * speedFactor;

      // Skip if too far away (2x alert distance as early warning buffer)
      if (dist > maxAlertDist * 2.5) {
        // If we previously tracked this blitzer, it's now passed
        if (_lastStagePerBlitzer.containsKey(report.id)) {
          passedIds.add(report.id);
          _lastStagePerBlitzer.remove(report.id);
        }
        continue;
      }

      // ── Direction check: Are we heading toward the blitzer? ──
      final bearingToBlitzer = Geolocator.bearingBetween(
        pos.latitude, pos.longitude,
        report.latitude, report.longitude,
      );

      // Heading from GPS (0-360)
      final heading = pos.heading;

      // Angle difference between heading and bearing to blitzer
      double angleDiff = (bearingToBlitzer - heading).abs();
      if (angleDiff > 180) angleDiff = 360 - angleDiff;

      // Heading tolerance: speed-adaptive
      // Slower in city (curves, turns) → wider tolerance
      // Faster on highway → narrower tolerance is fine
      final headingTolerance = 60.0 + (currentSpeedKmh > 60 ? 0 : (60 - currentSpeedKmh) * 0.5);
      // At very close range (< 100m), always alert regardless of heading
      final isHeadingToward = angleDiff < headingTolerance || dist < 100;

      if (!isHeadingToward) continue;

      // ── Time-to-camera calculation ──
      final timeToReach = dist / speedMs; // seconds

      // ── Determine alert stage ──
      AlertStage? stage;
      if (dist <= 200 && settings.immediateWarningEnabled) {
        stage = AlertStage.immediate;
      } else if (dist <= maxAlertDist && settings.approachWarningEnabled) {
        stage = AlertStage.approach;
      } else if (dist <= maxAlertDist * 2 && settings.earlyWarningEnabled) {
        // Early warning only if we'll reach it within ~20 seconds
        if (timeToReach <= 25) {
          stage = AlertStage.early;
        }
      }

      if (stage == null) continue;

      final alert = BlitzerAlert(
        report: report,
        stage: stage,
        distanceMeters: dist,
        timeToReachSeconds: timeToReach,
        bearingToBlitzer: bearingToBlitzer,
      );

      activeAlerts.add(alert);

      // Check if this is a NEW alert (stage escalation or first time)
      final prevStage = _lastStagePerBlitzer[report.id];
      final isNewStage = prevStage == null || stage.index > prevStage.index;
      final isOnCooldown = _cooldowns.containsKey(report.id);

      if (isNewStage && !isOnCooldown) {
        newAlerts.add(alert);
        _lastStagePerBlitzer[report.id] = stage;

        // Set cooldown for this specific stage
        if (stage == AlertStage.immediate) {
          _cooldowns[report.id] = now;
        }

        debugPrint(
          '[BlitzerAlert] NEW ${stage.name} alert: ${report.typeLabel} '
          'dist=${dist.round()}m time=${timeToReach.round()}s '
          'heading=$heading bearing=${bearingToBlitzer.round()} '
          'angle=${angleDiff.round()}°',
        );
      }
    }

    // Sort active alerts by distance (closest first)
    activeAlerts.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));

    return AlertCheckResult(
      newAlerts: newAlerts,
      activeAlerts: activeAlerts,
      passedBlitzerIds: passedIds,
    );
  }

  /// Reset all tracking state (e.g. when navigation stops).
  void reset() {
    _cooldowns.clear();
    _lastStagePerBlitzer.clear();
  }

  /// Find all blitzer reports that are within [radiusMeters] of the route polyline.
  /// Used to show blitzer markers along the planned route.
  static List<BlitzerReport> findBlitzerOnRoute({
    required List<BlitzerReport> reports,
    required List<LatLng> polyline,
    double radiusMeters = 200,
  }) {
    if (polyline.isEmpty) return [];

    final onRoute = <BlitzerReport>[];

    for (final report in reports) {
      // Check distance to polyline (sample every 5th point for performance)
      double minDist = double.infinity;
      for (int i = 0; i < polyline.length; i += 5) {
        final d = Geolocator.distanceBetween(
          report.latitude, report.longitude,
          polyline[i].latitude, polyline[i].longitude,
        );
        if (d < minDist) minDist = d;
        if (minDist < radiusMeters) break; // Early exit
      }
      // Also check last point
      if (minDist > radiusMeters) {
        final d = Geolocator.distanceBetween(
          report.latitude, report.longitude,
          polyline.last.latitude, polyline.last.longitude,
        );
        if (d < minDist) minDist = d;
      }

      if (minDist <= radiusMeters) {
        onRoute.add(report);
      }
    }

    return onRoute;
  }
}
