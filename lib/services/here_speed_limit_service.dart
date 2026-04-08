import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/api_config.dart';

/// HERE Speed Limit API service — automotive-grade speed limit data.
///
/// Used as fallback when OSRM route annotations don't have maxspeed.
/// Free Tier: 1,000 requests/day.
///
/// Endpoint: HERE Route Matching / Speed Limit Layer
/// Docs: https://developer.here.com/documentation/speed-limit
class HereSpeedLimitService {
  HereSpeedLimitService._();
  static final instance = HereSpeedLimitService._();

  // Rate limiting
  DateTime? _lastQueryTime;
  double? _lastLat, _lastLon;
  int? _lastResult;
  int _dailyCount = 0;
  DateTime? _dailyReset;

  /// Get speed limit at position from HERE API.
  /// Returns km/h, 0 for unlimited, null if unknown/error.
  Future<int?> getSpeedLimit(double lat, double lon, {double? heading}) async {
    final apiKey = ApiConfig.hereApiKey;
    if (apiKey.isEmpty) return null;

    // Daily limit check (1,000 requests)
    final now = DateTime.now();
    if (_dailyReset == null || now.day != _dailyReset!.day) {
      _dailyCount = 0;
      _dailyReset = now;
    }
    if (_dailyCount >= 950) {
      debugPrint('[HERE] Daily limit approaching ($_dailyCount/1000), skipping');
      return _lastResult;
    }

    // Don't query if less than 3s since last
    if (_lastQueryTime != null &&
        now.difference(_lastQueryTime!) < const Duration(seconds: 3)) {
      return _lastResult;
    }

    // Distance check: skip if moved < 100m
    if (_lastLat != null && _lastLon != null) {
      final dist = _distanceMeters(_lastLat!, _lastLon!, lat, lon);
      if (dist < 100) return _lastResult;
    }

    _lastQueryTime = now;
    _lastLat = lat;
    _lastLon = lon;
    _dailyCount++;

    try {
      // HERE Reverse Geocode + Speed Limit via Route Match
      // Using the simpler "discover" endpoint to get road info with speed limit
      final headingParam = heading != null ? '&heading=${heading.round()}' : '';
      final url = 'https://revgeocode.search.hereapi.com/v1/revgeocode'
          '?at=$lat,$lon'
          '&lang=de'
          '&apiKey=$apiKey'
          '$headingParam';

      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode != 200) {
        debugPrint('[HERE] HTTP ${response.statusCode}');
        return _lastResult;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final items = data['items'] as List?;
      if (items == null || items.isEmpty) return _lastResult;

      final item = items.first as Map<String, dynamic>;
      final address = item['address'] as Map<String, dynamic>?;

      // HERE reverse geocode doesn't directly return speed limits.
      // For speed limits we need the Fleet Telematics API or Route Matching.
      // Let's use the Route Matching endpoint instead.
      final speedLimit = await _queryRouteMatch(lat, lon, heading, apiKey);
      if (speedLimit != null) {
        _lastResult = speedLimit;
        debugPrint('[HERE] Speed limit: $speedLimit km/h at ${address?['street'] ?? '?'}');
      }

      return _lastResult;
    } catch (e) {
      debugPrint('[HERE] Error: $e');
      return _lastResult;
    }
  }

  /// Query HERE Route Matching for speed limit on current road segment.
  Future<int?> _queryRouteMatch(double lat, double lon, double? heading, String apiKey) async {
    try {
      // Use HERE "calculateroute" with speedLimit data
      // Single-point query: from current pos to a point 50m ahead
      final headRad = (heading ?? 0) * math.pi / 180;
      final aheadLat = lat + 0.0005 * math.cos(headRad);
      final aheadLon = lon + 0.0005 * math.sin(headRad);

      final url = 'https://router.hereapi.com/v8/routes'
          '?transportMode=car'
          '&origin=$lat,$lon'
          '&destination=$aheadLat,$aheadLon'
          '&spans=speedLimit'
          '&return=polyline,summary'
          '&apiKey=$apiKey';

      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode != 200) {
        debugPrint('[HERE] Route match HTTP ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;

      final route = routes.first as Map<String, dynamic>;
      final sections = route['sections'] as List?;
      if (sections == null || sections.isEmpty) return null;

      final section = sections.first as Map<String, dynamic>;
      final spans = section['spans'] as List?;
      if (spans == null || spans.isEmpty) return null;

      // Get speed limit from first span
      final span = spans.first as Map<String, dynamic>;
      final speedLimit = span['speedLimit'] as num?;
      if (speedLimit != null) {
        // HERE returns speed in m/s — convert to km/h
        return (speedLimit.toDouble() * 3.6).round();
      }

      return null;
    } catch (e) {
      debugPrint('[HERE] Route match error: $e');
      return null;
    }
  }

  static double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    final dx = (lat2 - lat1) * 111320;
    final dy = (lon2 - lon1) * 111320 * math.cos(lat1 * math.pi / 180);
    return math.sqrt(dx * dx + dy * dy);
  }

  void clearCache() {
    _lastLat = null;
    _lastLon = null;
    _lastResult = null;
  }
}
