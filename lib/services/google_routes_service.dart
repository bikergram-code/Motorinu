import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../core/api_config.dart';
import 'osrm_service.dart';

/// Google Routes API v2 service — returns [OsrmRoute]/[OsrmStep] so NavEngine
/// needs zero changes.
///
/// Provides higher-quality turn-by-turn instructions (pre-formatted German),
/// traffic-aware routing, and a built-in TWO_WHEELER mode for motorcycles.
///
/// Falls back gracefully: if API key is empty, [isAvailable] returns false
/// and callers should use [OsrmService] instead.
class GoogleRoutesService {
  static const _endpoint =
      'https://routes.googleapis.com/directions/v2:computeRoutes';

  /// Whether the Google Routes API is configured (API key present).
  static bool get isAvailable => ApiConfig.googleRoutesApiKey.isNotEmpty;

  // ─── Public API ─────────────────────────────────────────────────────────────

  /// Calculate a single route (e.g. for rerouting).
  Future<OsrmRoute?> getRoute(
    LatLng origin,
    LatLng destination, {
    RouteMode mode = RouteMode.auto,
  }) async {
    final routes = await _fetchRoutes(
      origin: origin,
      destination: destination,
      mode: mode,
      alternatives: false,
    );
    return routes.isNotEmpty ? routes.first : null;
  }

  /// Calculate up to 3 route alternatives (for route preview).
  Future<List<OsrmRoute>> getAllRoutes(
    LatLng origin,
    LatLng destination, {
    RouteMode mode = RouteMode.auto,
  }) async {
    return _fetchRoutes(
      origin: origin,
      destination: destination,
      mode: mode,
      alternatives: true,
    );
  }

  // ─── Internal ───────────────────────────────────────────────────────────────

  Future<List<OsrmRoute>> _fetchRoutes({
    required LatLng origin,
    required LatLng destination,
    required RouteMode mode,
    required bool alternatives,
  }) async {
    if (!isAvailable) return [];

    final travelMode = _travelMode(mode);

    final body = <String, dynamic>{
      'origin': {
        'location': {
          'latLng': {
            'latitude': origin.latitude,
            'longitude': origin.longitude,
          },
        },
      },
      'destination': {
        'location': {
          'latLng': {
            'latitude': destination.latitude,
            'longitude': destination.longitude,
          },
        },
      },
      'travelMode': travelMode,
      'languageCode': 'de-DE',
      'units': 'METRIC',
    };

    // WALK doesn't support TRAFFIC_AWARE or alternatives
    if (travelMode != 'WALK') {
      body['routingPreference'] = 'TRAFFIC_AWARE';
      if (alternatives) {
        body['computeAlternativeRoutes'] = true;
      }
    }

    final fieldMask = [
      'routes.distanceMeters',
      'routes.duration',
      'routes.polyline.encodedPolyline',
      'routes.legs.steps.navigationInstruction',
      'routes.legs.steps.startLocation',
      'routes.legs.steps.endLocation',
      'routes.legs.steps.distanceMeters',
      'routes.legs.steps.staticDuration',
    ].join(',');

    debugPrint('[GoogleRoutes] $travelMode ${origin.latitude.toStringAsFixed(4)},'
        '${origin.longitude.toStringAsFixed(4)} → '
        '${destination.latitude.toStringAsFixed(4)},'
        '${destination.longitude.toStringAsFixed(4)}');

    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': ApiConfig.googleRoutesApiKey,
        'X-Goog-FieldMask': fieldMask,
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      debugPrint('[GoogleRoutes] HTTP ${response.statusCode}: ${response.body}');
      throw Exception('Google Routes API error: HTTP ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    final rawRoutes = json['routes'] as List<dynamic>?;
    if (rawRoutes == null || rawRoutes.isEmpty) {
      debugPrint('[GoogleRoutes] No routes returned');
      return [];
    }

    final results = <OsrmRoute>[];
    for (final rawRoute in rawRoutes) {
      final route = _parseRoute(rawRoute as Map<String, dynamic>);
      if (route != null) results.add(route);
    }

    debugPrint('[GoogleRoutes] ${results.length} routes parsed');
    return results;
  }

  OsrmRoute? _parseRoute(Map<String, dynamic> raw) {
    try {
      final encodedPoly = raw['polyline']?['encodedPolyline'] as String?;
      if (encodedPoly == null || encodedPoly.isEmpty) return null;

      final points = OsrmService.decodePolyline(encodedPoly);
      if (points.isEmpty) return null;

      final distanceMeters = (raw['distanceMeters'] as num?)?.toDouble() ?? 0;
      final durationStr = (raw['duration'] as String?) ?? '0s';
      final durationSeconds = _parseDuration(durationStr);

      final legs = (raw['legs'] as List<dynamic>?) ?? [];
      final steps = <OsrmStep>[];

      for (final leg in legs) {
        final rawSteps =
            ((leg as Map<String, dynamic>)['steps'] as List<dynamic>?) ?? [];

        for (final rawStep in rawSteps) {
          final step = _parseStep(rawStep as Map<String, dynamic>);
          if (step != null) steps.add(step);
        }
      }

      return OsrmRoute(
        polylinePoints: points,
        distanceKm: distanceMeters / 1000,
        durationSeconds: durationSeconds,
        steps: steps,
      );
    } catch (e) {
      debugPrint('[GoogleRoutes] Parse error: $e');
      return null;
    }
  }

  OsrmStep? _parseStep(Map<String, dynamic> raw) {
    try {
      final navInstr =
          (raw['navigationInstruction'] as Map<String, dynamic>?) ?? {};

      final instruction =
          (navInstr['instructions'] as String?)?.replaceAll('\n', ' ').trim() ??
              'Weiter fahren';

      final googleManeuver = (navInstr['maneuver'] as String?) ?? '';
      final osrmManeuver = _mapManeuver(googleManeuver);

      final startLoc = raw['startLocation']?['latLng'] as Map<String, dynamic>?;
      if (startLoc == null) return null;

      final lat = (startLoc['latitude'] as num?)?.toDouble();
      final lng = (startLoc['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) return null;

      final distanceMeters =
          (raw['distanceMeters'] as num?)?.toDouble() ?? 0;
      final durationStr = (raw['staticDuration'] as String?) ?? '0s';
      final durationSeconds = _parseDuration(durationStr);

      // Extract road name from instruction text: "Rechts auf B7 abbiegen"
      final roadName = _extractRoadName(instruction);

      return OsrmStep(
        instruction: instruction.isEmpty ? 'Weiter fahren' : instruction,
        maneuver: osrmManeuver,
        roadName: roadName,
        distanceMeters: distanceMeters,
        durationSeconds: durationSeconds,
        location: LatLng(lat, lng),
      );
    } catch (e) {
      debugPrint('[GoogleRoutes] Step parse error: $e');
      return null;
    }
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  /// Parse Google duration string "1234s" or "1234.5s" → seconds.
  static int _parseDuration(String duration) {
    final cleaned = duration.replaceAll('s', '');
    return double.tryParse(cleaned)?.toInt() ?? 0;
  }

  /// Map RouteMode → Google travelMode string.
  static String _travelMode(RouteMode mode) {
    return switch (mode) {
      RouteMode.biker => 'TWO_WHEELER',
      RouteMode.auto => 'DRIVE',
      RouteMode.bicycle => 'BICYCLE',
      RouteMode.pedestrian => 'WALK',
    };
  }

  /// Extract road name from German instruction text.
  /// "Rechts auf B7 abbiegen" → "B7"
  /// "Links auf Hauptstraße halten" → "Hauptstraße"
  static String? _extractRoadName(String instruction) {
    final match = RegExp(
      r'auf\s+(.+?)\s+(?:abbiegen|halten|fahren|einfädeln|einfahren|einordnen|weiterfahren)',
      caseSensitive: false,
    ).firstMatch(instruction);
    if (match != null) return match.group(1);

    // Fallback: "Weiter auf B7" pattern
    final match2 = RegExp(
      r'(?:Weiter|weiter)\s+auf\s+(.+?)$',
      caseSensitive: false,
    ).firstMatch(instruction);
    if (match2 != null) return match2.group(1)?.trim();

    return null;
  }

  /// Map Google Routes maneuver to OSRM-style maneuver string.
  /// NavEngine uses these for icon mapping.
  static String _mapManeuver(String googleManeuver) {
    return switch (googleManeuver) {
      'TURN_LEFT' => 'turn-left',
      'TURN_RIGHT' => 'turn-right',
      'TURN_SLIGHT_LEFT' => 'turn-slight-left',
      'TURN_SLIGHT_RIGHT' => 'turn-slight-right',
      'TURN_SHARP_LEFT' => 'turn-sharp-left',
      'TURN_SHARP_RIGHT' => 'turn-sharp-right',
      'UTURN_LEFT' || 'UTURN_RIGHT' => 'uturn',
      'STRAIGHT' => 'straight',
      'MERGE_LEFT' => 'merge-left',
      'MERGE_RIGHT' => 'merge-right',
      'MERGE_UNSPECIFIED' || 'MERGE' => 'merge',
      'FORK_LEFT' => 'fork-left',
      'FORK_RIGHT' => 'fork-right',
      'ON_RAMP_LEFT' => 'on-ramp-left',
      'ON_RAMP_RIGHT' => 'on-ramp-right',
      'ON_RAMP_UNSPECIFIED' => 'on-ramp-right',
      'OFF_RAMP_LEFT' => 'off-ramp-left',
      'OFF_RAMP_RIGHT' => 'off-ramp-right',
      'OFF_RAMP_UNSPECIFIED' => 'off-ramp-right',
      'ROUNDABOUT_LEFT' || 'ROUNDABOUT_RIGHT' ||
      'ROUNDABOUT_CLOCKWISE' || 'ROUNDABOUT_COUNTERCLOCKWISE' =>
        'roundabout',
      'DEPART' => 'depart',
      'NAME_CHANGE' => 'new-name',
      'FERRY_BOAT' || 'FERRY_TRAIN' => 'ferry',
      'MANEUVER_UNSPECIFIED' || '' => 'straight',
      _ => 'straight',
    };
  }
}
