import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ─── OSM Speed Camera Service ─────────────────────────────────────────────────
//
// Fetches ALL stationary speed cameras in Germany from OpenStreetMap via
// Overpass API. Results are cached locally (7 days).
//
// Data source: OSM tags `highway=speed_camera` and `enforcement=maxspeed`
// License: ODbL (Open Database License) — free for use with attribution.

class OsmBlitzerService {
  OsmBlitzerService._();
  static final instance = OsmBlitzerService._();

  static const _cacheKey = 'osm_blitzer_cache_v3'; // v3: all of Germany
  static const _cacheTimestampKey = 'osm_blitzer_cache_ts_v3';
  static const _cacheDuration = Duration(days: 7); // Refresh weekly

  // Overpass API endpoint (public, rate-limited)
  static const _overpassUrl = 'https://overpass-api.de/api/interpreter';

  // Germany bounding box (lat_south, lon_west, lat_north, lon_east)
  static const _deSouth = 47.27;
  static const _deWest = 5.87;
  static const _deNorth = 55.10;
  static const _deEast = 15.04;

  /// Cached results in memory
  List<OsmSpeedCamera>? _memoryCache;
  DateTime? _lastFetch;

  /// Completer for serializing concurrent fetch requests
  Completer<List<OsmSpeedCamera>>? _fetchCompleter;

  /// Get ALL speed cameras in Germany.
  /// Returns cached data if available and fresh (< 7 days).
  /// No position filtering — caller decides what to show.
  Future<List<OsmSpeedCamera>> getAllGermany() async {
    debugPrint('[OSM] getAllGermany called, memCache=${_memoryCache?.length}');

    // If another fetch is in progress, wait for it
    if (_fetchCompleter != null) {
      debugPrint('[OSM] Waiting for in-flight fetch...');
      try {
        final result = await _fetchCompleter!.future;
        return result;
      } catch (_) {
        // Fetch failed, continue to try again or use cache
      }
    }

    // 1. Check memory cache
    if (_memoryCache != null && _lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < _cacheDuration) {
      debugPrint('[OSM] Using memory cache: ${_memoryCache!.length} cameras');
      return _memoryCache!;
    }

    // 2. Check SharedPreferences cache
    final prefs = await SharedPreferences.getInstance();
    final cachedJson = prefs.getString(_cacheKey);
    final cachedTs = prefs.getInt(_cacheTimestampKey);

    if (cachedJson != null && cachedTs != null) {
      final cacheAge = DateTime.now().difference(
          DateTime.fromMillisecondsSinceEpoch(cachedTs));
      if (cacheAge < _cacheDuration) {
        _memoryCache = _parseCache(cachedJson);
        _lastFetch = DateTime.fromMillisecondsSinceEpoch(cachedTs);
        debugPrint('[OSM] Using prefs cache: ${_memoryCache!.length} cameras, age: ${cacheAge.inHours}h');
        return _memoryCache!;
      }
    }

    // 3. Fetch fresh data from Overpass API
    _fetchCompleter = Completer<List<OsmSpeedCamera>>();
    try {
      debugPrint('[OSM] Fetching ALL speed cameras in Germany from Overpass...');
      final cameras = await _fetchAllGermany();
      _memoryCache = cameras;
      _lastFetch = DateTime.now();

      // Persist to SharedPreferences
      final json = jsonEncode(cameras.map((c) => c.toJson()).toList());
      await prefs.setString(_cacheKey, json);
      await prefs.setInt(_cacheTimestampKey, DateTime.now().millisecondsSinceEpoch);

      debugPrint('[OSM] ★ Fetched ${cameras.length} speed cameras for all of Germany');
      _fetchCompleter!.complete(cameras);
      _fetchCompleter = null;
      return cameras;
    } catch (e) {
      debugPrint('[OSM] ★ Overpass API error: $e');
      if (!_fetchCompleter!.isCompleted) {
        _fetchCompleter!.completeError(e);
      }
      _fetchCompleter = null;

      // Return stale cache if available
      if (_memoryCache != null) {
        debugPrint('[OSM] Fallback to stale memory cache: ${_memoryCache!.length}');
        return _memoryCache!;
      }
      if (cachedJson != null) {
        _memoryCache = _parseCache(cachedJson);
        debugPrint('[OSM] Fallback to stale prefs cache: ${_memoryCache!.length}');
        return _memoryCache!;
      }
      return [];
    }
  }

  /// Legacy API — redirects to getAllGermany() for backward compatibility.
  Future<List<OsmSpeedCamera>> getNearby({
    required double latitude,
    required double longitude,
    int radiusMeters = 50000,
  }) async {
    return getAllGermany();
  }

  /// Fetch all speed cameras in Germany using bounding box.
  Future<List<OsmSpeedCamera>> _fetchAllGermany() async {
    final query = '''
[out:json][timeout:90];
(
  node["highway"="speed_camera"]($_deSouth,$_deWest,$_deNorth,$_deEast);
  way["highway"="speed_camera"]($_deSouth,$_deWest,$_deNorth,$_deEast);
  node["enforcement"="maxspeed"]($_deSouth,$_deWest,$_deNorth,$_deEast);
  way["enforcement"="maxspeed"]($_deSouth,$_deWest,$_deNorth,$_deEast);
);
out center body;
''';

    debugPrint('[OSM] Sending Overpass request...');
    final response = await http.post(
      Uri.parse(_overpassUrl),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: 'data=${Uri.encodeComponent(query)}',
    ).timeout(const Duration(seconds: 90));

    debugPrint('[OSM] Overpass response: ${response.statusCode}, body size: ${response.body.length}');

    if (response.statusCode != 200) {
      throw Exception('Overpass API returned ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final elements = data['elements'] as List<dynamic>? ?? [];
    debugPrint('[OSM] Parsed ${elements.length} elements from Overpass');

    // Fast deduplication using grid-based hashing (~20m grid cells)
    // This is O(n) instead of O(n²)
    final seen = <String>{};
    final cameras = <OsmSpeedCamera>[];
    for (final el in elements) {
      final elType = el['type'];
      if (elType != 'node' && elType != 'way') continue;
      final camera = OsmSpeedCamera.fromOverpassElement(el as Map<String, dynamic>);
      if (camera.latitude == 0 && camera.longitude == 0) continue;

      // Grid key: round to ~20m precision (0.0002° ≈ 22m)
      final gridKey = '${(camera.latitude / 0.0002).round()}_${(camera.longitude / 0.0002).round()}';
      if (seen.add(gridKey)) {
        cameras.add(camera);
      }
    }

    debugPrint('[OSM] After dedup: ${cameras.length} unique cameras');
    return cameras;
  }

  /// Parse JSON cache string into camera list.
  List<OsmSpeedCamera> _parseCache(String json) {
    final list = jsonDecode(json) as List<dynamic>;
    return list.map((e) => OsmSpeedCamera.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Distance in meters (Haversine formula).
  static double distanceApprox(double lat1, double lon1, double lat2, double lon2) {
    return _haversine(lat1, lon1, lat2, lon2);
  }

  static double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371000.0;
    final dLat = (lat2 - lat1) * (math.pi / 180);
    final dLon = (lon2 - lon1) * (math.pi / 180);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * (math.pi / 180)) * math.cos(lat2 * (math.pi / 180)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    return earthRadius * 2 * math.asin(math.sqrt(a));
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
  final int? maxspeed;
  final String? direction;
  final String? ref;

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

    int? maxspeed;
    final ms = tags['maxspeed']?.toString();
    if (ms != null) {
      maxspeed = int.tryParse(ms.replaceAll(RegExp(r'[^0-9]'), ''));
    }

    double lat = (el['lat'] as num?)?.toDouble() ?? 0;
    double lon = (el['lon'] as num?)?.toDouble() ?? 0;
    if (lat == 0 && lon == 0) {
      final center = el['center'] as Map<String, dynamic>?;
      if (center != null) {
        lat = (center['lat'] as num?)?.toDouble() ?? 0;
        lon = (center['lon'] as num?)?.toDouble() ?? 0;
      }
    }

    return OsmSpeedCamera(
      osmId: el['id'] as int,
      latitude: lat,
      longitude: lon,
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
