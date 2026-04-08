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

  /// Pedestrian: walking routes, no motorways.
  pedestrian,

  /// Bicycle: cycling routes, bike paths preferred.
  bicycle,
}

// ─── Data Models ────────────────────────────────────────────────────────────

/// A single turn-by-turn step.
class OsrmStep {
  final String instruction;
  final String maneuver; // "turn-left", "turn-right", "straight", etc.
  final String? roadName;
  final String? ref;          // Road reference ("A 3", "B 229", "L 188")
  final String? destinations; // Exit destinations ("Köln, Bonn")
  final String? exitNumber;   // Exit number for off-ramps
  final double distanceMeters;
  final int durationSeconds;
  final LatLng location;
  final int? maxspeedKmh;     // Speed limit from OSRM annotations (null = unknown, 0 = unlimited)

  const OsrmStep({
    required this.instruction,
    required this.maneuver,
    this.roadName,
    this.ref,
    this.destinations,
    this.exitNumber,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.location,
    this.maxspeedKmh,
  });

  /// Human-readable distance for this step.
  String get distanceText {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }

  /// German instruction from maneuver type + road name.
  static String buildInstruction(String maneuver, String? road, {String? exitNumber}) {
    final roadStr = (road != null && road.isNotEmpty) ? ' auf $road' : '';

    // Kreisverkehr mit Ausfahrt-Nummer
    if (maneuver == 'roundabout' ||
        maneuver == 'rotary' ||
        maneuver.startsWith('roundabout-') ||
        maneuver.startsWith('rotary-')) {
      final exit = int.tryParse(exitNumber ?? '');
      if (exit != null && exit > 0) {
        final ord = switch (exit) {
          1 => 'erste',
          2 => 'zweite',
          3 => 'dritte',
          4 => 'vierte',
          5 => 'fünfte',
          6 => 'sechste',
          _ => '$exit.',
        };
        return 'Im Kreisverkehr $ord Ausfahrt$roadStr';
      }
      return 'Kreisverkehr$roadStr';
    }

    return switch (maneuver) {
      'turn-left' => 'Links abbiegen$roadStr',
      'turn-right' => 'Rechts abbiegen$roadStr',
      'turn-slight-left' => 'Leicht links$roadStr',
      'turn-slight-right' => 'Leicht rechts$roadStr',
      'turn-sharp-left' => 'Scharf links$roadStr',
      'turn-sharp-right' => 'Scharf rechts$roadStr',
      'uturn' || 'turn-uturn' => 'Wenden$roadStr',
      'merge-left' || 'merge-right' || 'merge' => 'Einfädeln$roadStr',
      'fork-left' => 'Links halten$roadStr',
      'fork-right' => 'Rechts halten$roadStr',
      'ramp-left' || 'off-ramp-left' || 'on-ramp-left' =>
        'Abfahrt links$roadStr',
      'ramp-right' || 'off-ramp-right' || 'on-ramp-right' =>
        'Abfahrt rechts$roadStr',
      'depart' => 'Start$roadStr',
      'arrive' => 'Ziel erreicht',
      'new-name' => 'Weiter$roadStr',
      'continue' || 'straight' => roadStr.isNotEmpty ? 'Weiter$roadStr' : 'Geradeaus weiter',
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
  // Own OSRM server with motorcycle profile (NRW data, Autobahn penalty, Landstrassen bonus)
  static const _ownUrl = 'http://152.53.255.4';
  // Public fallback for routes outside NRW
  static const _publicUrl = 'https://router.project-osrm.org';
  // Active base URL — tries own server first, falls back to public
  static String _baseUrl = _ownUrl;

  /// Calculate route from origin to destination.
  Future<OsrmRoute?> getRoute(
    LatLng origin,
    LatLng destination, {
    RouteMode mode = RouteMode.auto,
  }) async {
    return getRouteWithWaypoints([origin, destination], mode: mode);
  }

  /// OSRM profile name for URL path.
  static String _profileForMode(RouteMode mode) {
    switch (mode) {
      case RouteMode.pedestrian:
        return 'walking';
      case RouteMode.bicycle:
        return 'cycling';
      default:
        return 'driving';
    }
  }

  // Route avoidance options (set by caller before route request)
  bool avoidFerries = false;
  bool avoidMotorways = false;

  /// Build OSRM exclude parameter from current avoid settings.
  String get _excludeParam {
    final excludes = <String>[
      if (avoidFerries) 'ferry',
      if (avoidMotorways) 'motorway',
    ];
    if (excludes.isEmpty) return '';
    return '&exclude=${excludes.join(',')}';
  }

  /// Base URL for the given mode.
  /// Foot routing runs on our own server under /foot/ (separate OSRM instance).
  /// Motorcycle/Auto run on the default endpoint.
  // Nginx on port 80 proxies /foot/ → port 8081 (foot OSRM container)
  static const _nginxUrl = 'http://152.53.255.4';

  static String _baseUrlForMode(RouteMode mode) {
    if (mode == RouteMode.pedestrian) {
      return '$_nginxUrl/foot'; // Nginx proxies /foot/ → foot OSRM on 8081
    }
    if (mode == RouteMode.bicycle) {
      return '$_nginxUrl/bicycle'; // Nginx proxies /bicycle/ → bicycle OSRM on 8082
    }
    return _ownUrl;
  }

  /// Try own OSRM server first; on any error or waypoint snap >30km, fallback to public.
  Future<http.Response> _getWithFallback(String path, {RouteMode mode = RouteMode.auto}) async {
    final baseUrl = _baseUrlForMode(mode);
    // For foot: try own server (Nginx:80/foot/ → 8081), fallback to public OSRM
    if (mode == RouteMode.pedestrian) {
      try {
        debugPrint('[OSRM] Foot route: $baseUrl$path');
        final resp = await http.get(
          Uri.parse('$baseUrl$path'),
          headers: {'User-Agent': 'Bikergram/1.0'},
        ).timeout(const Duration(seconds: 8));
        if (resp.statusCode == 200) {
          final json = jsonDecode(resp.body) as Map<String, dynamic>;
          if (json['code'] == 'Ok') {
            // Check snap distance (outside NRW?)
            final waypoints = json['waypoints'] as List?;
            if (waypoints != null && waypoints.isNotEmpty) {
              final snapDist = ((waypoints.last as Map)['distance'] as num?)?.toDouble() ?? 0;
              if (snapDist <= 30000) return resp;
              debugPrint('[OSRM] Foot: snapped ${(snapDist/1000).toStringAsFixed(0)}km — public fallback');
            } else {
              return resp;
            }
          }
        }
      } catch (e) {
        debugPrint('[OSRM] Foot server error: $e — trying public fallback');
      }
      // Fallback: public OSRM foot profile — strip exclude (not supported)
      var footPath = path.replaceFirst('/route/v1/walking/', '/route/v1/foot/');
      footPath = footPath.replaceFirst(RegExp(r'&exclude=[^&]*'), '');
      debugPrint('[OSRM] Foot public fallback: $_publicUrl$footPath');
      return http.get(
        Uri.parse('$_publicUrl$footPath'),
        headers: {'User-Agent': 'Bikergram/1.0'},
      ).timeout(const Duration(seconds: 30));
    }
    // For bicycle: try own server, fallback to public OSRM bicycle profile
    if (mode == RouteMode.bicycle) {
      try {
        debugPrint('[OSRM] Bicycle route: $baseUrl$path');
        final resp = await http.get(
          Uri.parse('$baseUrl$path'),
          headers: {'User-Agent': 'Bikergram/1.0'},
        ).timeout(const Duration(seconds: 8));
        if (resp.statusCode == 200) {
          final json = jsonDecode(resp.body) as Map<String, dynamic>;
          if (json['code'] == 'Ok') {
            final waypoints = json['waypoints'] as List?;
            if (waypoints != null && waypoints.isNotEmpty) {
              final snapDist = ((waypoints.last as Map)['distance'] as num?)?.toDouble() ?? 0;
              if (snapDist <= 30000) return resp;
              debugPrint('[OSRM] Bicycle: snapped ${(snapDist/1000).toStringAsFixed(0)}km — public fallback');
            } else {
              return resp;
            }
          }
        }
      } catch (e) {
        debugPrint('[OSRM] Bicycle server error: $e — trying public fallback');
      }
      // Fallback: public OSRM bicycle profile
      var bikePath = path.replaceFirst('/route/v1/cycling/', '/route/v1/bicycle/');
      bikePath = bikePath.replaceFirst(RegExp(r'&exclude=[^&]*'), '');
      debugPrint('[OSRM] Bicycle public fallback: $_publicUrl$bikePath');
      return http.get(
        Uri.parse('$_publicUrl$bikePath'),
        headers: {'User-Agent': 'Bikergram/1.0'},
      ).timeout(const Duration(seconds: 30));
    }
    // Try own server first (motorcycle profile, Germany data)
    try {
      final resp = await http.get(
        Uri.parse('$_ownUrl$path'),
        headers: {'User-Agent': 'Bikergram/1.0'},
      ).timeout(const Duration(seconds: 3));
      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        if (json['code'] == 'Ok') {
          // Check if OSRM snapped waypoints far from requested coordinates.
          // This happens when destination is outside loaded map data (e.g. NRW only).
          final waypoints = json['waypoints'] as List?;
          if (waypoints != null && waypoints.isNotEmpty) {
            final lastWp = waypoints.last as Map<String, dynamic>;
            final snapDist = (lastWp['distance'] as num?)?.toDouble() ?? 0;
            if (snapDist > 30000) {
              // Waypoint snapped >30km from requested location = outside map data
              debugPrint('[OSRM] Destination snapped ${(snapDist/1000).toStringAsFixed(0)}km — outside NRW, using public fallback');
            } else {
              return resp;
            }
          } else {
            return resp;
          }
        }
      }
      debugPrint('[OSRM] Own server failed (${resp.statusCode}), trying public...');
    } catch (e) {
      debugPrint('[OSRM] Own server error: $e — trying public fallback...');
    }
    // Fallback to public OSRM — strip alternatives AND exclude (public doesn't support exclude)
    var fallbackPath = path;
    fallbackPath = fallbackPath.replaceFirst(RegExp(r'&?alternatives=\d+'), '&alternatives=false');
    fallbackPath = fallbackPath.replaceFirst(RegExp(r'&exclude=[^&]*'), ''); // public OSRM has no exclude support
    debugPrint('[OSRM] Public fallback: $_publicUrl$fallbackPath');
    return http.get(
      Uri.parse('$_publicUrl$fallbackPath'),
      headers: {'User-Agent': 'Bikergram/1.0'},
    ).timeout(const Duration(seconds: 30));
  }

  /// Calculate route through multiple waypoints.
  Future<OsrmRoute?> getRouteWithWaypoints(
    List<LatLng> waypoints, {
    RouteMode mode = RouteMode.auto,
  }) async {
    if (waypoints.length < 2) return null;

    return _fetchRoute(waypoints, mode);
  }

  /// Get all route alternatives (up to 3), sorted by duration.
  /// Returns primary + alternatives for Waze-style multi-route display.
  Future<List<OsrmRoute>> getAllRoutes(
    LatLng origin,
    LatLng destination, {
    RouteMode mode = RouteMode.auto,
  }) async {
    if (origin == destination) return [];

    final coords = '${origin.longitude},${origin.latitude};'
        '${destination.longitude},${destination.latitude}';

    final profile = _profileForMode(mode);
    final path = '/route/v1/$profile/$coords'
        '?overview=full&geometries=polyline&steps=true&alternatives=3$_excludeParam';

    try {
      final response = await _getWithFallback(path, mode: mode);
      if (response.statusCode != 200) return [];

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['code'] != 'Ok') return [];

      final routes = json['routes'] as List?;
      if (routes == null || routes.isEmpty) return [];

      final result = <OsrmRoute>[];
      for (final routeData in routes) {
        final r = routeData as Map<String, dynamic>;
        final parsed = _parseRouteJson(r);
        if (parsed != null) result.add(parsed);
      }

      // Sort by duration (fastest first)
      result.sort((a, b) => a.durationSeconds.compareTo(b.durationSeconds));
      return result;
    } catch (e) {
      debugPrint('[OSRM] getAllRoutes error: $e');
      return [];
    }
  }

  /// Parse a single route JSON object into OsrmRoute.
  OsrmRoute? _parseRouteJson(Map<String, dynamic> route) {
    try {
      final geometry = route['geometry'] as String;
      final distanceMeters = (route['distance'] as num).toDouble();
      final durationSecs = (route['duration'] as num).toInt();
      final points = decodePolyline(geometry);

      final steps = <OsrmStep>[];
      final legs = route['legs'] as List?;
      if (legs != null) {
        for (final leg in legs) {
          final legMap = leg as Map<String, dynamic>;
          final legSteps = legMap['steps'] as List?;
          if (legSteps == null) continue;

          final annotation = legMap['annotation'] as Map<String, dynamic>?;
          final maxspeeds = annotation?['maxspeed'] as List?;
          int segmentIdx = 0;

          for (final step in legSteps) {
            final s = step as Map<String, dynamic>;
            final maneuverData = s['maneuver'] as Map<String, dynamic>?;
            if (maneuverData == null) continue;
            final type = maneuverData['type'] as String? ?? 'straight';
            final modifier = maneuverData['modifier'] as String?;
            final maneuverKey = modifier != null ? '$type-$modifier' : type;
            final loc = maneuverData['location'] as List;
            final name = s['name'] as String?;
            final ref = s['ref'] as String?;
            final destinations = s['destinations'] as String?;
            final exitNum = maneuverData['exit']?.toString();
            final roadName = (name != null && name.isNotEmpty)
                ? (ref != null && ref.isNotEmpty ? '$ref / $name' : name)
                : ref;

            int? stepMaxspeed;
            if (maxspeeds != null && segmentIdx < maxspeeds.length) {
              final ms = maxspeeds[segmentIdx];
              if (ms is Map) {
                if (ms['none'] == true) {
                  stepMaxspeed = 0;
                } else {
                  final speed = ms['speed'];
                  if (speed is num) {
                    stepMaxspeed = speed.toInt();
                    if (ms['unit'] == 'mph') {
                      stepMaxspeed = (stepMaxspeed! * 1.60934).round();
                    }
                  }
                }
              }
            }
            final intersections = s['intersections'] as List?;
            if (intersections != null && intersections.isNotEmpty) {
              segmentIdx += intersections.length - 1;
            } else {
              segmentIdx += 1;
            }

            // Merge "continue on same street" steps into the previous one
            // — prevents "Weiter auf Kölner Str → Weiter auf Kölner Str" spam.
            final isContinue = type == 'continue' || type == 'straight';
            if (isContinue && steps.isNotEmpty) {
              final prev = steps.last;
              if (prev.roadName != null &&
                  roadName != null &&
                  prev.roadName!.toLowerCase() == roadName.toLowerCase()) {
                // Extend previous step
                steps[steps.length - 1] = OsrmStep(
                  instruction: prev.instruction,
                  maneuver: prev.maneuver,
                  roadName: prev.roadName,
                  ref: prev.ref,
                  destinations: prev.destinations,
                  exitNumber: prev.exitNumber,
                  distanceMeters: prev.distanceMeters +
                      ((s['distance'] as num?)?.toDouble() ?? 0),
                  durationSeconds: prev.durationSeconds +
                      ((s['duration'] as num?)?.toInt() ?? 0),
                  location: prev.location,
                  maxspeedKmh: prev.maxspeedKmh ?? stepMaxspeed,
                );
                continue;
              }
            }

            steps.add(OsrmStep(
              instruction: OsrmStep.buildInstruction(maneuverKey, roadName, exitNumber: exitNum),
              maneuver: maneuverKey,
              roadName: roadName,
              ref: ref,
              destinations: destinations,
              exitNumber: exitNum,
              distanceMeters: (s['distance'] as num?)?.toDouble() ?? 0,
              durationSeconds: (s['duration'] as num?)?.toInt() ?? 0,
              location: LatLng((loc[1] as num).toDouble(), (loc[0] as num).toDouble()),
              maxspeedKmh: stepMaxspeed,
            ));
          }
        }
      }


      return OsrmRoute(
        polylinePoints: points,
        distanceKm: distanceMeters / 1000,
        durationSeconds: durationSecs,
        steps: steps,
      );
    } catch (e) {
      debugPrint('[OSRM] Parse route error: $e');
      return null;
    }
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
    final path = '/route/v1/$profile/$coords'
        '?overview=full&geometries=polyline&steps=true$alternativesParam$_excludeParam';

    try {
      final modeLabel = mode == RouteMode.biker ? 'Biker' : (mode == RouteMode.pedestrian ? 'Fußgänger' : 'Auto');
      debugPrint('[OSRM] Requesting route ($modeLabel/$profile): ${_baseUrlForMode(mode)}$path');
      final response = await _getWithFallback(path, mode: mode);

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
      final points = decodePolyline(geometry);

      // Parse steps with maxspeed annotations
      final steps = <OsrmStep>[];
      final legs = route['legs'] as List?;
      if (legs != null) {
        for (final leg in legs) {
          final legMap = leg as Map<String, dynamic>;
          final legSteps = legMap['steps'] as List?;
          if (legSteps == null) continue;

          // Extract maxspeed annotations for this leg
          // OSRM returns maxspeed per segment (between coordinates)
          // Each entry: {"speed": 50, "unit": "km/h"} or {"none": true}
          final annotation = legMap['annotation'] as Map<String, dynamic>?;
          final maxspeeds = annotation?['maxspeed'] as List?;

          int segmentIdx = 0; // Track which segment we're on

          for (final step in legSteps) {
            final s = step as Map<String, dynamic>;
            final maneuverData = s['maneuver'] as Map<String, dynamic>?;
            if (maneuverData == null) continue;

            final type = maneuverData['type'] as String? ?? 'straight';
            final modifier = maneuverData['modifier'] as String?;
            final maneuverKey =
                modifier != null ? '$type-$modifier' : type;

            final loc = maneuverData['location'] as List;
            final name = s['name'] as String?;
            final ref = s['ref'] as String?;
            final roadName = (name != null && name.isNotEmpty)
                ? (ref != null && ref.isNotEmpty ? '$ref / $name' : name)
                : ref;
            final exitNum = maneuverData['exit']?.toString();
            final instruction =
                OsrmStep.buildInstruction(maneuverKey, roadName, exitNumber: exitNum);

            // Get maxspeed for this step's first segment
            int? stepMaxspeed;
            if (maxspeeds != null && segmentIdx < maxspeeds.length) {
              final ms = maxspeeds[segmentIdx];
              if (ms is Map) {
                if (ms['none'] == true) {
                  stepMaxspeed = 0; // Unlimited (Autobahn)
                } else {
                  final speed = ms['speed'];
                  if (speed is num) {
                    stepMaxspeed = speed.toInt();
                    // Convert mph to km/h if needed
                    if (ms['unit'] == 'mph') {
                      stepMaxspeed = (stepMaxspeed! * 1.60934).round();
                    }
                  }
                }
              }
            }

            // Advance segment index by number of geometry points in this step
            // Each step has an 'intersections' array — segments = intersections.length
            final intersections = s['intersections'] as List?;
            if (intersections != null && intersections.isNotEmpty) {
              segmentIdx += intersections.length - 1;
            } else {
              segmentIdx += 1;
            }

            // Merge "continue on same street" steps (no double "Weiter auf X")
            final isContinue = type == 'continue' || type == 'straight';
            if (isContinue && steps.isNotEmpty) {
              final prev = steps.last;
              if (prev.roadName != null &&
                  roadName != null &&
                  prev.roadName!.toLowerCase() == roadName.toLowerCase()) {
                steps[steps.length - 1] = OsrmStep(
                  instruction: prev.instruction,
                  maneuver: prev.maneuver,
                  roadName: prev.roadName,
                  distanceMeters: prev.distanceMeters +
                      ((s['distance'] as num?)?.toDouble() ?? 0),
                  durationSeconds: prev.durationSeconds +
                      ((s['duration'] as num?)?.toInt() ?? 0),
                  location: prev.location,
                  maxspeedKmh: prev.maxspeedKmh ?? stepMaxspeed,
                );
                continue;
              }
            }

            steps.add(OsrmStep(
              instruction: instruction,
              maneuver: maneuverKey,
              roadName: roadName,
              distanceMeters: (s['distance'] as num?)?.toDouble() ?? 0,
              durationSeconds: (s['duration'] as num?)?.toInt() ?? 0,
              location: LatLng(
                  (loc[1] as num).toDouble(), (loc[0] as num).toDouble()),
              maxspeedKmh: stepMaxspeed,
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

  // ─── Map Matching (HMM-based GPS snap to road) ──────────────────────────

  /// Result of an OSRM /match call — the matched (snapped) position on the road.
  /// Returns null if matching fails or no road nearby.

  /// Match a sequence of GPS points to the road network using OSRM's
  /// Hidden Markov Model map-matching algorithm.
  ///
  /// This is MUCH more accurate than simple nearest-point snapping because
  /// it considers the sequence of points, road topology, and turn restrictions.
  ///
  /// [gpsPoints] — at least 2 GPS points (ideally 5-10 recent positions)
  /// [timestamps] — optional Unix timestamps for each point (improves accuracy)
  /// [radiuses] — search radius per point in meters (default 15m each)
  ///
  /// Returns the matched LatLng for the LAST point (current position),
  /// or null if matching fails.
  Future<LatLng?> matchPosition(
    List<LatLng> gpsPoints, {
    List<int>? timestamps,
    double radius = 15.0,
  }) async {
    if (gpsPoints.length < 2) return null;

    // OSRM expects lng,lat
    final coords =
        gpsPoints.map((p) => '${p.longitude},${p.latitude}').join(';');

    // Radiuses for each point
    final radiuses = List.filled(gpsPoints.length, radius.toStringAsFixed(0)).join(';');

    // Timestamps improve matching accuracy (speed/direction inference)
    final tsParam = timestamps != null && timestamps.length == gpsPoints.length
        ? '&timestamps=${timestamps.join(';')}'
        : '';

    final path = '/match/v1/driving/$coords'
        '?overview=false&geometries=polyline&radiuses=$radiuses$tsParam';

    try {
      // Only use own server (has NRW data with motorcycle profile)
      final resp = await http.get(
        Uri.parse('$_ownUrl$path'),
        headers: {'User-Agent': 'Bikergram/1.0'},
      ).timeout(const Duration(seconds: 2)); // Fast timeout — this runs every GPS tick

      if (resp.statusCode != 200) return null;

      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      if (json['code'] != 'Ok') return null;

      // matchings[].tracepoints[] contains the snapped positions
      final tracepoints = json['tracepoints'] as List?;
      if (tracepoints == null || tracepoints.isEmpty) return null;

      // Get the LAST matched tracepoint (= current position)
      // Tracepoints can be null if a point couldn't be matched
      for (int i = tracepoints.length - 1; i >= 0; i--) {
        final tp = tracepoints[i];
        if (tp == null) continue;
        final loc = (tp as Map<String, dynamic>)['location'] as List?;
        if (loc == null || loc.length < 2) continue;
        return LatLng(
          (loc[1] as num).toDouble(),
          (loc[0] as num).toDouble(),
        );
      }
      return null;
    } catch (e) {
      debugPrint('[OSRM] Match error: $e');
      return null;
    }
  }

  /// Decode Google-encoded polyline string into LatLng list.
  /// OSRM uses the same encoding as Google Maps (precision 5).
  /// Decode a Google-encoded polyline string (precision 5) to LatLng list.
  /// Public so GoogleRoutesService can reuse it.
  static List<LatLng> decodePolyline(String encoded) {
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
