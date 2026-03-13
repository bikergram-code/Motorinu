import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ─── Speed Limit Service ─────────────────────────────────────────────────────
//
// Queries OSM Overpass API for the current road's speed limit (`maxspeed` tag).
// Used during navigation to show a speed limit sign and warn on speeding.
//
// Caching strategy:
//   - Results cached per ~200m grid cell (3 decimal places)
//   - Only queries if position moved >150m from last query
//   - Rate-limited: max 1 query per 5 seconds
//
// Free API, no key needed. ODbL license.

class SpeedLimitResult {
  final int? limitKmh;       // null = unknown / no maxspeed tag
  final String? roadName;    // Name of the road
  final String? roadType;    // highway=* value (motorway, primary, etc.)

  const SpeedLimitResult({this.limitKmh, this.roadName, this.roadType});

  static const unknown = SpeedLimitResult();

  bool get hasLimit => limitKmh != null;

  /// Default speed limits in Germany when no maxspeed tag exists.
  int get effectiveLimitKmh {
    if (limitKmh != null) return limitKmh!;
    // German defaults based on road type
    switch (roadType) {
      case 'motorway':
        return 0; // 0 = no limit (Autobahn)
      case 'trunk':
      case 'primary':
        return 100;
      case 'residential':
      case 'living_street':
        return 30;
      default:
        return 50; // innerorts default
    }
  }

  /// Whether this is an unlimited section (Autobahn ohne Limit).
  bool get isUnlimited => effectiveLimitKmh == 0;
}

class SpeedLimitService {
  SpeedLimitService._();
  static final instance = SpeedLimitService._();

  static const _overpassUrl = 'https://overpass-api.de/api/interpreter';

  // Cache: grid key → result
  final Map<String, SpeedLimitResult> _cache = {};

  // Rate limiting
  double? _lastQueryLat;
  double? _lastQueryLon;
  DateTime? _lastQueryTime;
  SpeedLimitResult _lastResult = SpeedLimitResult.unknown;

  /// Get speed limit for current position.
  /// Returns cached result if position hasn't moved much.
  Future<SpeedLimitResult> getSpeedLimit(double lat, double lon) async {
    // Check grid cache first
    final key = '${lat.toStringAsFixed(3)},${lon.toStringAsFixed(3)}';
    if (_cache.containsKey(key)) {
      _lastResult = _cache[key]!;
      return _lastResult;
    }

    // Rate limit: don't query if less than 5s since last query
    final now = DateTime.now();
    if (_lastQueryTime != null &&
        now.difference(_lastQueryTime!) < const Duration(seconds: 5)) {
      return _lastResult;
    }

    // Distance check: don't query if moved < 150m
    if (_lastQueryLat != null && _lastQueryLon != null) {
      final dist = _distanceMeters(_lastQueryLat!, _lastQueryLon!, lat, lon);
      if (dist < 150) return _lastResult;
    }

    // Query Overpass
    _lastQueryLat = lat;
    _lastQueryLon = lon;
    _lastQueryTime = now;

    try {
      final result = await _queryOverpass(lat, lon);
      _cache[key] = result;
      _lastResult = result;
      debugPrint('[SpeedLimit] ${result.limitKmh ?? "?"} km/h on ${result.roadName ?? "?"} (${result.roadType})');
      return result;
    } catch (e) {
      debugPrint('[SpeedLimit] Query error: $e');
      return _lastResult; // Return last known
    }
  }

  Future<SpeedLimitResult> _queryOverpass(double lat, double lon) async {
    // Find nearest road (`way` with `highway` tag) and get its maxspeed
    // `around:30` = within 30m of position → should find the current road
    final query = '[out:json][timeout:5];'
        'way["highway"~"motorway|trunk|primary|secondary|tertiary|residential|living_street|unclassified"](around:30,$lat,$lon);'
        'out tags 1;'; // Only 1 result, tags only (fast)

    final response = await http.post(
      Uri.parse(_overpassUrl),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: 'data=${Uri.encodeComponent(query)}',
    ).timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) {
      debugPrint('[SpeedLimit] HTTP ${response.statusCode}');
      return SpeedLimitResult.unknown;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final elements = data['elements'] as List<dynamic>? ?? [];

    if (elements.isEmpty) return SpeedLimitResult.unknown;

    // Take first result (closest road)
    final el = elements.first as Map<String, dynamic>;
    final tags = el['tags'] as Map<String, dynamic>? ?? {};

    final highway = tags['highway'] as String?;
    final name = tags['name'] as String? ?? tags['ref'] as String?;

    // Parse maxspeed
    int? maxspeed;
    final ms = tags['maxspeed']?.toString();
    if (ms != null) {
      if (ms == 'none' || ms == 'signals') {
        maxspeed = 0; // Unlimited
      } else {
        maxspeed = int.tryParse(ms.replaceAll(RegExp(r'[^0-9]'), ''));
      }
    }

    return SpeedLimitResult(
      limitKmh: maxspeed,
      roadName: name,
      roadType: highway,
    );
  }

  static double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    final dx = (lat2 - lat1) * 111320;
    final dy = (lon2 - lon1) * 111320 * math.cos(lat1 * math.pi / 180);
    return math.sqrt(dx * dx + dy * dy);
  }

  void clearCache() {
    _cache.clear();
    _lastQueryLat = null;
    _lastQueryLon = null;
    _lastResult = SpeedLimitResult.unknown;
  }
}
