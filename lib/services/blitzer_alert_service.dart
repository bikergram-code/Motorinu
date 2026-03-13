import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../data/repositories/blitzer_repository.dart';
import '../providers/map/map_settings_provider.dart';

// ─── Blitzer Alert Service ───────────────────────────────────────────────────
//
// Intelligent alert engine:
// - Time-to-camera based alerts (not just distance)
// - Direction-sensitive: only warns if you're heading toward the blitzer
// - Multi-stage warnings: early → approach → immediate
// - Cooldown per blitzer to prevent spam
// - Speed-based alert thresholds

/// Alert severity levels — fixed distance thresholds.
enum AlertStage {
  early,      // 800m — first warning
  approach,   // 200m — second warning, slow down!
  immediate,  // < 50m — blitzer directly ahead (passed through)
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
      AlertStage.early => '⚠️ $typeLabel in $distanceText',
      AlertStage.approach => '🚨 $typeLabel in $distanceText!',
      AlertStage.immediate => '🚨 $typeLabel direkt voraus!',
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

  /// Clear cooldown + stage tracking for a specific blitzer (e.g., newly added report).
  void clearCooldown(int reportId) {
    _cooldowns.remove(reportId);
    _lastStagePerBlitzer.remove(reportId);
  }

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

      // ── Fixed distance thresholds: 800m first warning, 200m second warning ──
      const firstWarnDist = 800.0;  // meters — "Achtung, Blitzer in 800 Meter"
      const secondWarnDist = 200.0; // meters — "Blitzer voraus, 200 Meter!"

      // Skip if too far away (1.5km buffer for early detection)
      if (dist > 1500) {
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

      // At low speed (< 15 km/h): GPS heading is UNRELIABLE (random at standstill)
      // → Skip heading check entirely, warn based on distance only
      // At medium/high speed: use direction-sensitive filtering
      final bool isHeadingToward;
      if (currentSpeedKmh < 15) {
        // Standstill/walking: always warn within range (heading meaningless)
        isHeadingToward = true;
      } else {
        // Heading tolerance: speed-adaptive
        // Slower in city → wider tolerance, faster on highway → narrower
        final headingTolerance = 60.0 + (currentSpeedKmh > 60 ? 0 : (60 - currentSpeedKmh) * 0.5);
        // At close range (< 300m), always alert regardless of heading
        isHeadingToward = angleDiff < headingTolerance || dist < 300;
      }

      if (!isHeadingToward) {
        debugPrint(
          '[BlitzerAlert] SKIP ${report.typeLabel} dist=${dist.round()}m '
          'angle=${angleDiff.round()}° speed=${currentSpeedKmh.round()} — not heading toward',
        );
        continue;
      }

      // ── Time-to-camera calculation ──
      final timeToReach = dist / speedMs; // seconds

      // ── Determine alert stage (fixed: 800m + 200m) ──
      AlertStage? stage;
      if (dist <= secondWarnDist && settings.immediateWarningEnabled) {
        stage = AlertStage.approach;  // 200m — "Blitzer voraus!"
      } else if (dist <= firstWarnDist && settings.earlyWarningEnabled) {
        stage = AlertStage.early;     // 800m — "Achtung, Blitzer in 800m"
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
