import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ─── OSM Speed Camera Service ─────────────────────────────────────────────────
//
// Fetches stationary speed cameras from OpenStreetMap via Overpass API.
// Results are cached locally to avoid hammering the API.
//
// Data source: OSM tags `highway=speed_camera` and `enforcement=maxspeed`
// License: ODbL (Open Database License) — free for use with attribution.

class OsmBlitzerService {
  OsmBlitzerService._();
  static final instance = OsmBlitzerService._();

  static const _cacheKey = 'osm_blitzer_cache';
  static const _cacheTimestampKey = 'osm_blitzer_cache_ts';
  static const _cacheDuration = Duration(hours: 24); // Refresh daily

  // Overpass API endpoint (public, rate-limited)
  static const _overpassUrl = 'https://overpass-api.de/api/interpreter';

  /// Cached results in memory (avoid re-parsing JSON on every call)
  List<OsmSpeedCamera>? _memoryCache;
  DateTime? _lastFetch;

  /// Fetch speed cameras near a position.
  /// Returns cached data if available and fresh (< 24h).
  /// [radiusMeters] defaults to 50km (50000m).
  Future<List<OsmSpeedCamera>> getNearby({
    required double latitude,
    required double longitude,
    int radiusMeters = 50000,
  }) async {
    // 1. Check memory cache (fastest)
    if (_memoryCache != null && _lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < _cacheDuration) {
      return _filterByRadius(_memoryCache!, latitude, longitude, radiusMeters);
    }

    // 2. Check SharedPreferences cache (survives app restart)
    final prefs = await SharedPreferences.getInstance();
    final cachedJson = prefs.getString(_cacheKey);
    final cachedTs = prefs.getInt(_cacheTimestampKey);

    if (cachedJson != null && cachedTs != null) {
      final cacheAge = DateTime.now().difference(
          DateTime.fromMillisecondsSinceEpoch(cachedTs));
      if (cacheAge < _cacheDuration) {
        _memoryCache = _parseCache(cachedJson);
        _lastFetch = DateTime.fromMillisecondsSinceEpoch(cachedTs);
        debugPrint('[OSM] Using cached data (${_memoryCache!.length} cameras, age: ${cacheAge.inHours}h)');
        return _filterByRadius(_memoryCache!, latitude, longitude, radiusMeters);
      }
    }

    // 3. Fetch fresh data from Overpass API
    try {
      final cameras = await _fetchFromOverpass(latitude, longitude, radiusMeters);
      _memoryCache = cameras;
      _lastFetch = DateTime.now();

      // Persist to SharedPreferences
      final json = jsonEncode(cameras.map((c) => c.toJson()).toList());
      await prefs.setString(_cacheKey, json);
      await prefs.setInt(_cacheTimestampKey, DateTime.now().millisecondsSinceEpoch);

      debugPrint('[OSM] Fetched ${cameras.length} speed cameras from Overpass API');
      return cameras;
    } catch (e) {
      debugPrint('[OSM] Overpass API error: $e');
      // Return stale cache if available
      if (_memoryCache != null) return _filterByRadius(_memoryCache!, latitude, longitude, radiusMeters);
      if (cachedJson != null) {
        _memoryCache = _parseCache(cachedJson);
        return _filterByRadius(_memoryCache!, latitude, longitude, radiusMeters);
      }
      return [];
    }
  }

  /// Build and execute Overpass API query.
  Future<List<OsmSpeedCamera>> _fetchFromOverpass(
      double lat, double lon, int radiusMeters) async {
    // Query: nodes AND ways tagged as speed cameras within radius
    // Also include enforcement=maxspeed nodes (newer OSM tagging)
    final query = '''
[out:json][timeout:30];
(
  node["highway"="speed_camera"](around:$radiusMeters,$lat,$lon);
  node["enforcement"="maxspeed"](around:$radiusMeters,$lat,$lon);
);
out body;
''';

    final response = await http.post(
      Uri.parse(_overpassUrl),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: 'data=${Uri.encodeComponent(query)}',
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('Overpass API returned ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final elements = data['elements'] as List<dynamic>? ?? [];

    // Deduplicate by proximity (OSM can have overlapping nodes)
    final cameras = <OsmSpeedCamera>[];
    for (final el in elements) {
      if (el['type'] != 'node') continue;
      final camera = OsmSpeedCamera.fromOverpassElement(el as Map<String, dynamic>);

      // Skip if too close to an existing camera (< 20m = likely duplicate)
      final isDuplicate = cameras.any((c) =>
          _distanceApprox(c.latitude, c.longitude, camera.latitude, camera.longitude) < 20);
      if (!isDuplicate) {
        cameras.add(camera);
      }
    }

    return cameras;
  }

  /// Filter cameras by radius from a center point.
  List<OsmSpeedCamera> _filterByRadius(
      List<OsmSpeedCamera> cameras, double lat, double lon, int radiusMeters) {
    return cameras.where((c) =>
        _distanceApprox(c.latitude, c.longitude, lat, lon) <= radiusMeters).toList();
  }

  /// Parse JSON cache string into camera list.
  List<OsmSpeedCamera> _parseCache(String json) {
    final list = jsonDecode(json) as List<dynamic>;
    return list.map((e) => OsmSpeedCamera.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Approximate distance in meters (Haversine simplified).
  static double _distanceApprox(double lat1, double lon1, double lat2, double lon2) {
    const degToRad = 0.0174532925;
    const earthRadius = 6371000.0; // meters
    final dLat = (lat2 - lat1) * degToRad;
    final dLon = (lon2 - lon1) * degToRad;
    final a = dLat * dLat + dLon * dLon * _cos(lat1 * degToRad) * _cos(lat2 * degToRad);
    return earthRadius * 2 * _asin(_sqrt(a < 0 ? 0 : (a > 4 ? 4 : a)) / 2);
  }

  // Fast math helpers (avoid dart:math import overhead in hot paths)
  static double _cos(double x) {
    // Taylor series approx good enough for distance calc
    x = x % (2 * 3.14159265359);
    return 1 - x * x / 2 + x * x * x * x / 24;
  }

  static double _sqrt(double x) {
    if (x <= 0) return 0;
    double guess = x / 2;
    for (int i = 0; i < 10; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }

  static double _asin(double x) {
    // Taylor series approx
    if (x >= 1) return 3.14159265359 / 2;
    if (x <= -1) return -3.14159265359 / 2;
    return x + x * x * x / 6 + 3 * x * x * x * x * x / 40;
  }

  /// Clear all cached data.
  Future<void> clearCache() async {
    _memoryCache = null;
    _lastFetch = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    await prefs.remove(_cacheTimestampKey);
  }
}

// ─── OSM Speed Camera Model ──────────────────────────────────────────────────

class OsmSpeedCamera {
  final int osmId;
  final double latitude;
  final double longitude;
  final int? maxspeed; // Speed limit in km/h (from OSM tag)
  final String? direction; // Direction the camera faces (from OSM tag)
  final String? ref; // Reference name/number

  const OsmSpeedCamera({
    required this.osmId,
    required this.latitude,
    required this.longitude,
    this.maxspeed,
    this.direction,
    this.ref,
  });

  factory OsmSpeedCamera.fromOverpassElement(Map<String, dynamic> el) {
    final tags = el['tags'] as Map<String, dynamic>? ?? {};

    // Parse maxspeed (can be "50", "50 km/h", or absent)
    int? maxspeed;
    final ms = tags['maxspeed']?.toString();
    if (ms != null) {
      maxspeed = int.tryParse(ms.replaceAll(RegExp(r'[^0-9]'), ''));
    }

    return OsmSpeedCamera(
      osmId: el['id'] as int,
      latitude: (el['lat'] as num).toDouble(),
      longitude: (el['lon'] as num).toDouble(),
      maxspeed: maxspeed,
      direction: tags['direction']?.toString(),
      ref: tags['ref']?.toString() ?? tags['name']?.toString(),
    );
  }

  factory OsmSpeedCamera.fromJson(Map<String, dynamic> json) {
    return OsmSpeedCamera(
      osmId: json['osmId'] as int,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      maxspeed: json['maxspeed'] as int?,
      direction: json['direction'] as String?,
      ref: json['ref'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'osmId': osmId,
    'latitude': latitude,
    'longitude': longitude,
    if (maxspeed != null) 'maxspeed': maxspeed,
    if (direction != null) 'direction': direction,
    if (ref != null) 'ref': ref,
  };
}
