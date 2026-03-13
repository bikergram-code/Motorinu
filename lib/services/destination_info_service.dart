import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

// ─── Destination Info Service ────────────────────────────────────────────────
//
// Fetches enrichment data for a navigation destination — FAST version.
//
// Phase 1 (schnell, ~1s):
//   - Nominatim Reverse Geocoding → Population via extratags
//   - Wikipedia REST API → Beschreibung + Thumbnail
//
// Phase 2 (etwas langsamer, ~2-5s, läuft parallel):
//   - Overpass API → Tankstellen + Werkstätten (5km Radius)
//
// All APIs are FREE, kein API-Key nötig.
// Results are cached in memory by rounded lat/lng (1km precision).

// ─── Data Models ─────────────────────────────────────────────────────────────

/// Enriched destination information.
class DestinationInfo {
  final int? population;
  final String? description;
  final String? thumbnailUrl;
  final int? fuelStationCount;
  final int? repairShopCount;
  final String? country;
  final String? countryCode; // ISO 2-letter code (e.g. "DE", "AT", "IT")
  final String? cityName; // City/town name from Nominatim reverse geocoding
  final String? postalCode; // PLZ from Nominatim
  final int? bikerCount; // Registered bikes in the area (from Supabase)
  final int? autoCount; // Registered autos in the area (from Supabase)
  final WeatherInfo? weather;

  const DestinationInfo({
    this.population,
    this.description,
    this.thumbnailUrl,
    this.fuelStationCount,
    this.repairShopCount,
    this.country,
    this.countryCode,
    this.cityName,
    this.postalCode,
    this.bikerCount,
    this.autoCount,
    this.weather,
  });

  /// Country flag emoji from ISO 2-letter code (e.g. "DE" → "🇩🇪").
  String? get countryFlag {
    if (countryCode == null || countryCode!.length != 2) return null;
    final codes = countryCode!.toUpperCase().codeUnits;
    // Regional indicator symbols: 0x1F1E6 + (code - 0x41)
    return String.fromCharCodes([
      0x1F1E6 + (codes[0] - 0x41),
      0x1F1E6 + (codes[1] - 0x41),
    ]);
  }

  /// Whether any enrichment data is available.
  bool get hasData =>
      population != null ||
      description != null ||
      fuelStationCount != null ||
      repairShopCount != null ||
      weather != null;

  /// Create a copy with additional fields filled in (for two-phase loading).
  DestinationInfo merge(DestinationInfo other) => DestinationInfo(
    population: other.population ?? population,
    description: other.description ?? description,
    thumbnailUrl: other.thumbnailUrl ?? thumbnailUrl,
    fuelStationCount: other.fuelStationCount ?? fuelStationCount,
    repairShopCount: other.repairShopCount ?? repairShopCount,
    country: other.country ?? country,
    countryCode: other.countryCode ?? countryCode,
    cityName: other.cityName ?? cityName,
    postalCode: other.postalCode ?? postalCode,
    bikerCount: other.bikerCount ?? bikerCount,
    autoCount: other.autoCount ?? autoCount,
    weather: other.weather ?? weather,
  );

  /// Formatted population (German style: "1,2 Mio." or "45.320").
  String? get populationText {
    if (population == null) return null;
    if (population! >= 1000000) {
      return '${(population! / 1000000).toStringAsFixed(1)} Mio.';
    }
    // German number formatting with dots as thousands separator
    final str = population.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }
}

/// Weather data (for future OpenWeatherMap integration).
class WeatherInfo {
  final double tempCelsius;
  final String description;
  final String iconCode;
  final int humidity;
  final double windSpeedKmh;

  const WeatherInfo({
    required this.tempCelsius,
    required this.description,
    required this.iconCode,
    required this.humidity,
    required this.windSpeedKmh,
  });

  /// OpenWeatherMap icon URL.
  String get iconUrl => 'https://openweathermap.org/img/wn/$iconCode@2x.png';

  /// Formatted temperature.
  String get tempText => '${tempCelsius.round()}°C';
}

/// Single POI along a route.
class RoutePoi {
  final double lat, lon;
  final String name;
  const RoutePoi({required this.lat, required this.lon, required this.name});
}

/// All POIs found along a route, with positions for map markers.
class RoutePois {
  final List<RoutePoi> fuel;
  final List<RoutePoi> bikerShops;
  final List<RoutePoi> workshops;

  const RoutePois({
    required this.fuel,
    required this.bikerShops,
    required this.workshops,
  });

  factory RoutePois.empty() => const RoutePois(fuel: [], bikerShops: [], workshops: []);

  bool get isEmpty => fuel.isEmpty && bikerShops.isEmpty && workshops.isEmpty;
  int get totalCount => fuel.length + bikerShops.length + workshops.length;
}

// ─── Service ─────────────────────────────────────────────────────────────────

class DestinationInfoService {
  static const _overpassUrl = 'https://overpass-api.de/api/interpreter';

  // In-memory cache: key = "lat,lng" rounded to 2 decimals (~1km precision)
  final Map<String, DestinationInfo> _cache = {};

  String _cacheKey(LatLng loc) =>
      '${loc.latitude.toStringAsFixed(2)},${loc.longitude.toStringAsFixed(2)}';

  /// Fetch all enrichment data — fast two-phase approach.
  /// Phase 1: Nominatim (Population) + Wikipedia (Beschreibung) — ~1s
  /// Phase 2: Overpass (POIs) — ~2-5s, updates via [onUpdate] callback
  ///
  /// [cityName] is used for Wikipedia lookup.
  /// [location] is used for Nominatim + Overpass.
  /// [onUpdate] is called when Phase 2 data arrives (optional).
  Future<DestinationInfo> fetchAll({
    required String? cityName,
    required LatLng location,
    void Function(DestinationInfo updated)? onUpdate,
  }) async {
    // Check cache first
    final key = _cacheKey(location);
    if (_cache.containsKey(key)) {
      debugPrint('[DestInfo] Cache hit for $key');
      return _cache[key]!;
    }

    final stopwatch = Stopwatch()..start();

    // ── Phase 1: Fast APIs (parallel) ──────────────────────────────
    // Nominatim + Wikipedia both respond in < 1-2 seconds
    final phase1 = await Future.wait<dynamic>([
      _fetchNominatimInfo(location),   // [0]: Map with population, country
      _fetchWikipediaInfo(cityName),   // [1]: Map with description, thumbnail
    ], eagerError: false);

    final nominatimInfo = phase1[0] as Map<String, dynamic>?;
    final wikiInfo = phase1[1] as Map<String, String?>?;

    final postalCode = nominatimInfo?['postalCode'] as String?;

    final phase1Info = DestinationInfo(
      population: nominatimInfo?['population'] as int?,
      country: nominatimInfo?['country'] as String?,
      countryCode: nominatimInfo?['countryCode'] as String?,
      cityName: nominatimInfo?['cityName'] as String?,
      postalCode: postalCode,
      description: wikiInfo?['description'],
      thumbnailUrl: wikiInfo?['thumbnail'],
    );

    // Cache Phase 1 immediately
    _cache[key] = phase1Info;
    debugPrint('[DestInfo] Phase 1 done in ${stopwatch.elapsedMilliseconds}ms: '
        'pop=${phase1Info.population}, wiki=${phase1Info.description != null}, plz=$postalCode');

    // ── Phase 2: Overpass POIs + Supabase Biker/Auto count (parallel, background) ──
    Future.wait([
      _fetchOverpassPOIs(location),
      _fetchBikerAutoCount(postalCode),
    ]).then((results) {
      final pois = results[0] as Map<String, int>?;
      final vehicles = results[1] as Map<String, int>?;

      if (pois != null || vehicles != null) {
        final updated = (_cache[key] ?? phase1Info).merge(DestinationInfo(
          fuelStationCount: pois?['fuel'],
          repairShopCount: pois?['repair'],
          bikerCount: vehicles?['bikes'],
          autoCount: vehicles?['autos'],
        ));
        _cache[key] = updated;
        debugPrint('[DestInfo] Phase 2 done in ${stopwatch.elapsedMilliseconds}ms: '
            'fuel=${pois?['fuel']}, repair=${pois?['repair']}, '
            'bikes=${vehicles?['bikes']}, autos=${vehicles?['autos']}');
        onUpdate?.call(updated);
      }
    });

    return phase1Info;
  }

  // ─── Nominatim Reverse Geocoding: Population + Country ──────────
  //
  // FAST (~0.5-1s). Uses Nominatim's `extratags` which includes
  // population data from OpenStreetMap directly.

  Future<Map<String, dynamic>?> _fetchNominatimInfo(LatLng location) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=${location.latitude}'
        '&lon=${location.longitude}'
        '&format=json'
        '&extratags=1'
        '&namedetails=1'
        '&zoom=10'  // City-level zoom
        '&accept-language=de',
      );

      final response = await http.get(url, headers: {
        'User-Agent': 'Bikergram/1.0 (biker community app)',
      }).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        debugPrint('[DestInfo] Nominatim HTTP ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final extratags = data['extratags'] as Map<String, dynamic>? ?? {};
      final address = data['address'] as Map<String, dynamic>? ?? {};

      // Population from extratags (OSM stores this for cities)
      int? population;
      final popStr = extratags['population']?.toString();
      if (popStr != null) {
        // Handle various formats: "1234567", "1.234.567", "1,234,567"
        final cleaned = popStr.replaceAll(RegExp(r'[.\s,]'), '');
        population = int.tryParse(cleaned);
      }

      // Country from address
      final country = address['country'] as String?;
      final countryCode = (address['country_code'] as String?)?.toUpperCase();
      final postalCode = address['postcode'] as String?;
      // City name — try city, then town, then village
      final cityName = address['city'] as String? ??
          address['town'] as String? ??
          address['village'] as String? ??
          address['municipality'] as String?;

      debugPrint('[DestInfo] Nominatim: pop=$population, city=$cityName, country=$country, cc=$countryCode, plz=$postalCode');
      return {
        'population': population,
        'country': country,
        'countryCode': countryCode,
        'cityName': cityName,
        'postalCode': postalCode,
      };
    } catch (e) {
      debugPrint('[DestInfo] Nominatim error: $e');
      return null;
    }
  }

  // ─── Wikipedia REST API: Beschreibung + Thumbnail ──────────────

  /// Fetch city description + thumbnail from Wikipedia.
  /// Tries German Wikipedia first, falls back to English.
  Future<Map<String, String?>?> _fetchWikipediaInfo(String? cityName) async {
    if (cityName == null || cityName.isEmpty) return null;

    try {
      // Clean city name: remove state suffix (e.g. "München, Bayern" → "München")
      final cleanName = cityName.split(',').first.trim();
      final encoded = Uri.encodeComponent(cleanName);

      // Try German Wikipedia first
      var result = await _fetchWikipediaSummary(encoded, 'de');

      // Fallback to English if German has no result
      if (result == null) {
        result = await _fetchWikipediaSummary(encoded, 'en');
      }

      return result;
    } catch (e) {
      debugPrint('[DestInfo] Wikipedia error: $e');
      return null;
    }
  }

  Future<Map<String, String?>?> _fetchWikipediaSummary(
    String encodedName,
    String lang,
  ) async {
    final url = Uri.parse(
      'https://$lang.wikipedia.org/api/rest_v1/page/summary/$encodedName',
    );

    final response = await http.get(url, headers: {
      'User-Agent': 'Bikergram/1.0 (biker community app)',
      'Accept': 'application/json',
    }).timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) {
      debugPrint('[DestInfo] Wikipedia ($lang) HTTP ${response.statusCode}');
      return null;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    // Check if this is a disambiguation page — skip
    if (data['type'] == 'disambiguation') {
      debugPrint('[DestInfo] Wikipedia ($lang): disambiguation, skipping');
      return null;
    }

    // Extract description (max 200 chars, trim to last full sentence)
    String? desc = data['extract'] as String?;
    if (desc != null && desc.length > 200) {
      final trimmed = desc.substring(0, 200);
      final lastDot = trimmed.lastIndexOf('.');
      if (lastDot > 80) {
        desc = trimmed.substring(0, lastDot + 1);
      } else {
        desc = '${trimmed.trimRight()}...';
      }
    }

    final thumbnail = data['thumbnail'] as Map<String, dynamic>?;
    final thumbUrl = thumbnail?['source'] as String?;

    if (desc == null && thumbUrl == null) return null;

    debugPrint('[DestInfo] Wikipedia ($lang): '
        '"${desc?.substring(0, desc.length.clamp(0, 40)) ?? 'null'}...", '
        'thumb: ${thumbUrl != null}');
    return {'description': desc, 'thumbnail': thumbUrl};
  }

  // ─── Overpass API: Tankstellen + Werkstätten ────────────────────
  //
  // Optimized: 5km radius (statt 10km), 8s timeout, compact query.

  Future<Map<String, int>?> _fetchOverpassPOIs(LatLng location) async {
    try {
      final lat = location.latitude;
      final lon = location.longitude;
      const radius = 5000; // 5km — schneller als 10km

      // Compact count query — both in one request
      final query = '[out:json][timeout:8];'
          'node["amenity"="fuel"](around:$radius,$lat,$lon);out count;'
          'node["shop"~"car_repair|motorcycle_repair|motorcycle|car_parts"](around:$radius,$lat,$lon);out count;';

      final response = await http.post(
        Uri.parse(_overpassUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'data=${Uri.encodeComponent(query)}',
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        debugPrint('[DestInfo] Overpass HTTP ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final elements = data['elements'] as List<dynamic>? ?? [];

      int fuelCount = 0;
      int repairCount = 0;
      int countIdx = 0;
      for (final el in elements) {
        if (el is Map<String, dynamic> && el['type'] == 'count') {
          final rawTotal = el['tags']?['total'];
          final total = rawTotal is num ? rawTotal.toInt() : int.tryParse('$rawTotal') ?? 0;
          if (countIdx == 0) {
            fuelCount = total;
          } else {
            repairCount = total;
          }
          countIdx++;
        }
      }

      debugPrint('[DestInfo] Overpass: $fuelCount Tankstellen, $repairCount Werkstätten (5km)');
      return {'fuel': fuelCount, 'repair': repairCount};
    } catch (e) {
      debugPrint('[DestInfo] Overpass error: $e');
      return null;
    }
  }

  // ─── Supabase: Biker + Auto Count in PLZ-Region ─────────────────
  //
  // Counts registered vehicles near the destination by matching
  // first 2 digits of postal code (~50km region).

  Future<Map<String, int>?> _fetchBikerAutoCount(String? postalCode) async {
    if (postalCode == null || postalCode.length < 2) return null;

    try {
      final supabase = Supabase.instance.client;
      // Match first 2 digits of PLZ (~50km region)
      final plzPrefix = postalCode.substring(0, 2);

      // Count bikes (community = bikergram)
      final bikeResult = await supabase
          .from('vehicles')
          .select('id, profiles!inner(postal_code)')
          .eq('community', 'bikergram')
          .like('profiles.postal_code', '$plzPrefix%')
          .count(CountOption.exact)
          .timeout(const Duration(seconds: 5));

      // Count autos (community = cargram)
      final autoResult = await supabase
          .from('vehicles')
          .select('id, profiles!inner(postal_code)')
          .eq('community', 'cargram')
          .like('profiles.postal_code', '$plzPrefix%')
          .count(CountOption.exact)
          .timeout(const Duration(seconds: 5));

      final bikes = bikeResult.count;
      final autos = autoResult.count;

      debugPrint('[DestInfo] Supabase: $bikes Bikes, $autos Autos in PLZ $plzPrefix*');
      return {'bikes': bikes, 'autos': autos};
    } catch (e) {
      debugPrint('[DestInfo] Supabase vehicle count error: $e');
      return null;
    }
  }

  // ─── Along-Route POI Counts ─────────────────────────────────────
  //
  // Samples the polyline every ~50km and counts POIs within 5km of
  // each sample point. Gives a rough count of fuel stations,
  // biker shops, and workshops ALONG the entire route.

  /// Fetch POIs along a route polyline with positions.
  /// Returns RoutePois with counts AND locations for map markers.
  // Google Maps API key (same as in AndroidManifest)
  static const googleApiKey = 'AIzaSyCDfLYfcdMx1MBVmVJswpRB8MzPO5nLN9U';

  Future<RoutePois> getAlongRoutePoiCounts(List<LatLng> polyline) async {
    if (polyline.length < 2) return RoutePois.empty();

    // Estimate total route length
    double totalKm = 0;
    for (int i = 1; i < polyline.length; i++) {
      final dx = (polyline[i].latitude - polyline[i - 1].latitude);
      final dy = (polyline[i].longitude - polyline[i - 1].longitude);
      totalKm += math.sqrt(dx * dx + dy * dy) * 111;
    }

    // Sample every 3-60km depending on route length (denser = finds more stations)
    final intervalKm = (totalKm / 30).clamp(3.0, 60.0);
    final samples = <LatLng>[polyline.first];
    double acc = 0;
    for (int i = 1; i < polyline.length; i++) {
      final dx = (polyline[i].latitude - polyline[i - 1].latitude);
      final dy = (polyline[i].longitude - polyline[i - 1].longitude);
      acc += math.sqrt(dx * dx + dy * dy) * 111;
      if (acc >= intervalKm) {
        samples.add(polyline[i]);
        acc = 0;
      }
    }
    samples.add(polyline.last);

    debugPrint('[DestInfo] Fuel: ${samples.length} sample points, ${totalKm.toStringAsFixed(0)}km route');

    try {
      // ── Run Google Places + Overpass in PARALLEL for maximum coverage ──
      final allFuel = <RoutePoi>[];

      // 1) Google Places (parallel requests per sample point)
      final googleFuture = Future(() async {
        final googleFuel = <RoutePoi>[];
        final seen = <String>{};
        try {
          final futures = samples.map((pt) async {
            try {
              return await http.get(
                Uri.parse('https://maps.googleapis.com/maps/api/place/nearbysearch/json'
                    '?location=${pt.latitude},${pt.longitude}'
                    '&radius=2500&type=gas_station&key=$googleApiKey'),
              ).timeout(const Duration(seconds: 8));
            } catch (_) { return null; }
          }).toList();
          final responses = await Future.wait(futures);
          for (final resp in responses) {
            if (resp == null || resp.statusCode != 200) continue;
            final json = jsonDecode(resp.body) as Map<String, dynamic>;
            final status = json['status'] as String? ?? '';
            if (status == 'REQUEST_DENIED') break;
            if (status != 'OK' && status != 'ZERO_RESULTS') continue;
            final results = json['results'] as List<dynamic>? ?? [];
            for (final r in results) {
              if (r is! Map<String, dynamic>) continue;
              final placeId = r['place_id'] as String? ?? '';
              if (!seen.add(placeId)) continue;
              final loc = (r['geometry'] as Map?)?['location'] as Map?;
              if (loc == null) continue;
              final lat = (loc['lat'] as num?)?.toDouble();
              final lon = (loc['lng'] as num?)?.toDouble();
              if (lat == null || lon == null) continue;
              final name = r['name'] as String? ?? '';
              googleFuel.add(RoutePoi(lat: lat, lon: lon, name: name));
            }
          }
        } catch (e) {
          debugPrint('[DestInfo] Google Places error: $e');
        }
        return googleFuel;
      });

      // 2) Overpass / OpenStreetMap (finds small/independent stations Google misses)
      final overpassFuture = Future(() async {
        final osmFuel = <RoutePoi>[];
        try {
          final buffer = StringBuffer('[out:json][timeout:25];(');
          for (final pt in samples) {
            buffer.write('node["amenity"="fuel"](around:2500,${pt.latitude},${pt.longitude});');
          }
          buffer.write(');out body;');
          final response = await http.post(
            Uri.parse(_overpassUrl),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: 'data=${Uri.encodeComponent(buffer.toString())}',
          ).timeout(const Duration(seconds: 25));
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            _parseFuelElements(data, osmFuel, <int>{});
          }
        } catch (e) {
          debugPrint('[DestInfo] Overpass error: $e');
        }
        return osmFuel;
      });

      // Wait for both
      final results = await Future.wait([googleFuture, overpassFuture]);
      allFuel.addAll(results[0]);
      final osmCount = results[1].length;
      // Merge Overpass results (dedupe by distance — if <200m from existing, skip)
      for (final osm in results[1]) {
        bool duplicate = false;
        for (final g in allFuel) {
          final dx = (osm.lat - g.lat) * 111320;
          final dy = (osm.lon - g.lon) * 111320 * math.cos(osm.lat * math.pi / 180);
          if (dx * dx + dy * dy < 200 * 200) { duplicate = true; break; }
        }
        if (!duplicate && osm.name.isNotEmpty) allFuel.add(osm);
      }

      debugPrint('[DestInfo] Merged: ${results[0].length} Google + $osmCount OSM → ${allFuel.length} total');

      // Thin out clusters: min distance scales with route length
      final minDistM = (totalKm * 20).clamp(3000.0, 50000.0);
      final fuel = <RoutePoi>[];
      for (final f in allFuel) {
        bool tooClose = false;
        for (final existing in fuel) {
          final dx = (f.lat - existing.lat) * 111320;
          final dy = (f.lon - existing.lon) * 111320 *
              math.cos(f.lat * math.pi / 180);
          if (dx * dx + dy * dy < minDistM * minDistM) {
            tooClose = true;
            break;
          }
        }
        if (!tooClose) fuel.add(f);
      }

      debugPrint('[DestInfo] Final: ${fuel.length} Tankstellen nach Clustering');
      return RoutePois(fuel: fuel, bikerShops: [], workshops: []);
    } catch (e) {
      debugPrint('[DestInfo] Fuel search error: $e');
      return _getAlongRoutePoiOverpass(polyline, totalKm, samples);
    }
  }

  /// Overpass fallback if Google Places fails.
  Future<RoutePois> _getAlongRoutePoiOverpass(
      List<LatLng> polyline, double totalKm, List<LatLng> samples) async {
    try {
      final buffer = StringBuffer('[out:json][timeout:25];(');
      for (final pt in samples) {
        buffer.write('node["amenity"="fuel"](around:2500,${pt.latitude},${pt.longitude});');
      }
      buffer.write(');out body;');

      final response = await http.post(
        Uri.parse(_overpassUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'data=${Uri.encodeComponent(buffer.toString())}',
      ).timeout(const Duration(seconds: 25));

      if (response.statusCode != 200) return RoutePois.empty();

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final allFuel = <RoutePoi>[];
      _parseFuelElements(data, allFuel, <int>{});

      final minDistM = (totalKm * 20).clamp(3000.0, 50000.0);
      final named = allFuel.where((f) => f.name.isNotEmpty).toList();
      final fuel = <RoutePoi>[];
      for (final f in named) {
        bool tooClose = false;
        for (final existing in fuel) {
          final dx = (f.lat - existing.lat) * 111320;
          final dy = (f.lon - existing.lon) * 111320 *
              math.cos(f.lat * math.pi / 180);
          if (dx * dx + dy * dy < minDistM * minDistM) {
            tooClose = true;
            break;
          }
        }
        if (!tooClose) fuel.add(f);
      }
      debugPrint('[DestInfo] Overpass fallback: ${fuel.length} Tankstellen');
      return RoutePois(fuel: fuel, bikerShops: [], workshops: []);
    } catch (e) {
      debugPrint('[DestInfo] Overpass fallback error: $e');
      return RoutePois.empty();
    }
  }

  /// Parse fuel station elements from Overpass response.
  void _parseFuelElements(Map<String, dynamic> data, List<RoutePoi> fuel, Set<int> seen) {
    final elements = data['elements'] as List<dynamic>? ?? [];
    for (final el in elements) {
      if (el is! Map<String, dynamic>) continue;
      final id = (el['id'] as num?)?.toInt() ?? 0;
      if (!seen.add(id)) continue;
      final lat = (el['lat'] as num?)?.toDouble();
      final lon = (el['lon'] as num?)?.toDouble();
      if (lat == null || lon == null) continue;
      final tags = el['tags'] as Map<String, dynamic>? ?? {};
      final name = tags['name'] as String? ?? '';
      fuel.add(RoutePoi(lat: lat, lon: lon, name: name));
    }
  }

  /// Check if a point is within radiusM of any point on the polyline.
  bool _isNearPolyline(LatLng point, List<LatLng> polyline, double radiusM) {
    // Check every 10th point (tighter radius needs finer sampling)
    for (int i = 0; i < polyline.length; i += 10) {
      final dx = (point.latitude - polyline[i].latitude) * 111320;
      final dy = (point.longitude - polyline[i].longitude) * 111320 *
          math.cos(polyline[i].latitude * math.pi / 180);
      if (dx * dx + dy * dy < radiusM * radiusM) return true;
    }
    return false;
  }

  /// Sample a polyline at regular km intervals.
  List<LatLng> _samplePolyline(List<LatLng> polyline, {double intervalKm = 50}) {
    final samples = <LatLng>[polyline.first];
    double accumulated = 0;

    for (int i = 1; i < polyline.length; i++) {
      final prev = polyline[i - 1];
      final curr = polyline[i];
      final segDist = _haversineKm(prev, curr);
      accumulated += segDist;

      if (accumulated >= intervalKm) {
        samples.add(curr);
        accumulated = 0;
      }
    }

    // Always include endpoint
    if (samples.last != polyline.last) {
      samples.add(polyline.last);
    }

    // Limit to 20 sample points to keep Overpass query reasonable
    if (samples.length > 20) {
      final step = samples.length / 20;
      return List.generate(20, (i) => samples[(i * step).floor()]);
    }

    return samples;
  }

  /// Haversine distance in km between two LatLng points.
  static double _haversineKm(LatLng a, LatLng b) {
    const r = 6371.0; // Earth radius km
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final h = math.pow(math.sin(dLat / 2), 2).toDouble() +
        math.pow(math.sin(dLon / 2), 2).toDouble() * math.cos(lat1) * math.cos(lat2);
    return 2 * r * math.asin(math.sqrt(h));
  }

  /// Clear the cache (e.g. on memory pressure).
  void clearCache() => _cache.clear();
}
