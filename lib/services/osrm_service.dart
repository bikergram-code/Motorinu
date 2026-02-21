import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

// ─── Route Mode ──────────────────────────────────────────────────────────────

/// Route preference mode.
enum RouteMode {
  /// Biker-friendly: avoids motorways, prefers scenic/secondary roads.
  biker,

  /// Auto-friendly: fastest route including motorways.
  auto,
}

// ─── Data Models ────────────────────────────────────────────────────────────

/// A single turn-by-turn step.
class OsrmStep {
  final String instruction;
  final String maneuver; // "turn-left", "turn-right", "straight", etc.
  final String? roadName;
  final double distanceMeters;
  final int durationSeconds;
  final LatLng location;

  const OsrmStep({
    required this.instruction,
    required this.maneuver,
    this.roadName,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.location,
  });

  /// Human-readable distance for this step.
  String get distanceText {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }

  /// German instruction from maneuver type + road name.
  static String buildInstruction(String maneuver, String? road) {
    final roadStr = (road != null && road.isNotEmpty) ? ' auf $road' : '';
    return switch (maneuver) {
      'turn-left' => 'Links abbiegen$roadStr',
      'turn-right' => 'Rechts abbiegen$roadStr',
      'turn-slight-left' => 'Leicht links$roadStr',
      'turn-slight-right' => 'Leicht rechts$roadStr',
      'turn-sharp-left' => 'Scharf links$roadStr',
      'turn-sharp-right' => 'Scharf rechts$roadStr',
      'uturn' || 'turn-uturn' => 'Wenden$roadStr',
      'merge-left' || 'merge-right' || 'merge' => 'Einfaedeln$roadStr',
      'fork-left' => 'Links halten$roadStr',
      'fork-right' => 'Rechts halten$roadStr',
      'ramp-left' || 'off-ramp-left' || 'on-ramp-left' =>
        'Abfahrt links$roadStr',
      'ramp-right' || 'off-ramp-right' || 'on-ramp-right' =>
        'Abfahrt rechts$roadStr',
      'roundabout' || 'rotary' => 'Kreisverkehr$roadStr',
      'depart' => 'Start$roadStr',
      'arrive' => 'Ziel erreicht',
      'continue' || 'new-name' || 'straight' => 'Geradeaus$roadStr',
      'ferry' => 'Fähre nehmen$roadStr',
      'notification' => 'Hinweis$roadStr',
      _ => 'Weiter$roadStr',
    };
  }
}

/// A complete route result.
class OsrmRoute {
  final List<LatLng> polylinePoints;
  final double distanceKm;
  final int durationSeconds;
  final List<OsrmStep> steps;

  const OsrmRoute({
    required this.polylinePoints,
    required this.distanceKm,
    required this.durationSeconds,
    required this.steps,
  });

  /// Human-readable duration (e.g. "1 Std. 23 Min.").
  String get durationText {
    final h = durationSeconds ~/ 3600;
    final m = (durationSeconds % 3600) ~/ 60;
    if (h > 0) return '$h Std. $m Min.';
    return '$m Min.';
  }

  /// Human-readable distance (e.g. "42,3 km").
  String get distanceText {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()} m';
    }
    return '${distanceKm.toStringAsFixed(1)} km';
  }
}

// ─── Service ────────────────────────────────────────────────────────────────

/// OSRM routing service — 100% kostenlos, kein API-Key noetig.
class OsrmService {
  static const _baseUrl = 'https://router.project-osrm.org';

  /// Calculate route from origin to destination.
  Future<OsrmRoute?> getRoute(
    LatLng origin,
    LatLng destination, {
    RouteMode mode = RouteMode.auto,
  }) async {
    return getRouteWithWaypoints([origin, destination], mode: mode);
  }

  /// OSRM profile name for each route mode.
  /// Both modes use 'driving' profile since OSRM public server has no motorcycle profile.
  /// The Biker mode requests alternative routes and picks the longest (scenic) one,
  /// while Auto mode picks the shortest (fastest) route.
  static String _profileForMode(RouteMode mode) => 'driving';

  /// Calculate route through multiple waypoints.
  Future<OsrmRoute?> getRouteWithWaypoints(
    List<LatLng> waypoints, {
    RouteMode mode = RouteMode.auto,
  }) async {
    if (waypoints.length < 2) return null;

    return _fetchRoute(waypoints, mode);
  }

  /// Internal: fetch route with a specific profile.
  /// For biker mode: requests alternatives and picks the longest (most scenic) route.
  /// For auto mode: picks the shortest (fastest) route.
  Future<OsrmRoute?> _fetchRoute(List<LatLng> waypoints, RouteMode mode) async {
    // OSRM expects lng,lat (NOT lat,lng!)
    final coords =
        waypoints.map((w) => '${w.longitude},${w.latitude}').join(';');

    final profile = _profileForMode(mode);
    // Biker mode: request alternative routes to find scenic/longer options
    final alternativesParam = mode == RouteMode.biker ? '&alternatives=3' : '';
    final url = Uri.parse(
      '$_baseUrl/route/v1/$profile/$coords'
      '?overview=full&geometries=polyline&steps=true$alternativesParam',
    );

    try {
      final modeLabel = mode == RouteMode.biker ? 'Biker' : 'Auto';
      debugPrint('[OSRM] Requesting route ($modeLabel/$profile): $url');
      final response = await http.get(url, headers: {
        'User-Agent': 'Bikergram/1.0',
      });

      if (response.statusCode != 200) {
        debugPrint('[OSRM] HTTP ${response.statusCode}');
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['code'] != 'Ok') {
        debugPrint('[OSRM] API error: ${json['code']}');
        return null;
      }

      final routes = json['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;

      // Biker mode: pick a scenic alternative (not the shortest, not the longest)
      // Auto mode: pick the shortest route (fastest = first from OSRM)
      Map<String, dynamic> route;
      if (mode == RouteMode.biker && routes.length > 1) {
        // Sort by distance ascending (shortest first)
        final sorted = List<Map<String, dynamic>>.from(
          routes.map((r) => r as Map<String, dynamic>),
        )..sort((a, b) => ((a['distance'] as num).toDouble())
            .compareTo((b['distance'] as num).toDouble()));
        // Pick middle route (scenic but not absurdly long)
        // 2 routes → pick 2nd (index 1), 3+ routes → pick 2nd (index 1)
        final pickIdx = sorted.length >= 3 ? 1 : (sorted.length - 1);
        route = sorted[pickIdx];
        debugPrint('[OSRM] Biker: picked route ${pickIdx + 1} of ${routes.length} alternatives '
            '(${((route['distance'] as num).toDouble() / 1000).toStringAsFixed(1)} km)');
      } else {
        route = routes[0] as Map<String, dynamic>;
      }
      final geometry = route['geometry'] as String;
      final distanceMeters = (route['distance'] as num).toDouble();
      final durationSecs = (route['duration'] as num).toInt();

      // Decode polyline
      final points = _decodePolyline(geometry);

      // Parse steps
      final steps = <OsrmStep>[];
      final legs = route['legs'] as List?;
      if (legs != null) {
        for (final leg in legs) {
          final legSteps = (leg as Map<String, dynamic>)['steps'] as List?;
          if (legSteps == null) continue;

          for (final step in legSteps) {
            final s = step as Map<String, dynamic>;
            final maneuverData = s['maneuver'] as Map<String, dynamic>?;
            if (maneuverData == null) continue;

            final type = maneuverData['type'] as String? ?? 'straight';
            final modifier = maneuverData['modifier'] as String?;
            final maneuverKey =
                modifier != null ? '$type-$modifier' : type;

            final loc = maneuverData['location'] as List;
            final roadName = s['name'] as String?;
            final instruction =
                OsrmStep.buildInstruction(maneuverKey, roadName);

            steps.add(OsrmStep(
              instruction: instruction,
              maneuver: maneuverKey,
              roadName: roadName,
              distanceMeters: (s['distance'] as num?)?.toDouble() ?? 0,
              durationSeconds: (s['duration'] as num?)?.toInt() ?? 0,
              location: LatLng(
                  (loc[1] as num).toDouble(), (loc[0] as num).toDouble()),
            ));
          }
        }
      }

      debugPrint(
          '[OSRM] Route ($modeLabel/$profile): ${(distanceMeters / 1000).toStringAsFixed(1)} km, '
          '${durationSecs ~/ 60} min, ${steps.length} steps, '
          '${points.length} polyline points');

      return OsrmRoute(
        polylinePoints: points,
        distanceKm: distanceMeters / 1000,
        durationSeconds: durationSecs,
        steps: steps,
      );
    } catch (e) {
      debugPrint('[OSRM] Error: $e');
      return null;
    }
  }

  /// Decode Google-encoded polyline string into LatLng list.
  /// OSRM uses the same encoding as Google Maps (precision 5).
  static List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      // Decode latitude
      int shift = 0;
      int result = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      // Decode longitude
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return points;
  }
}
