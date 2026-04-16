import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// A single POI result.
class PoiResult {
  final String name;
  final double lat;
  final double lon;
  final double distanceM;
  final double? rating;
  final int? ratingCount;
  final String type;
  final String? address;
  final String? openingHours;
  final String? brand;
  final String? phone;

  const PoiResult({
    required this.name,
    required this.lat,
    required this.lon,
    required this.distanceM,
    this.rating,
    this.ratingCount,
    required this.type,
    this.address,
    this.openingHours,
    this.brand,
    this.phone,
  });

  String get distanceText {
    if (distanceM >= 1000) {
      return '${(distanceM / 1000).toStringAsFixed(1)} km';
    }
    return '${distanceM.round()} m';
  }

  String get ratingText {
    if (rating == null) return '';
    final r = rating!.toStringAsFixed(1).replaceAll('.', ',');
    return ratingCount != null ? '$r ($ratingCount)' : r;
  }
}

/// Predefined POI categories.
class PoiCategory {
  final String id;
  final String label;
  final String labelPlural;
  final String overpassTag;
  final String? overpassTag2;
  final String? overpassTag3;
  final String googleType;
  final int radiusMeters;
  /// Photon reverse-geocode OSM tags (key:value format).
  final List<String> photonOsmTags;

  const PoiCategory({
    required this.id,
    required this.label,
    required this.labelPlural,
    required this.overpassTag,
    this.overpassTag2,
    this.overpassTag3,
    required this.googleType,
    this.radiusMeters = 10000,
    this.photonOsmTags = const [],
  });

  static const fuel = PoiCategory(
    id: 'fuel', label: 'Tankstelle', labelPlural: 'Tankstellen',
    overpassTag: '["amenity"="fuel"]',
    googleType: 'gas_station', radiusMeters: 8000,
    photonOsmTags: ['amenity:fuel'],
  );

  static const workshop = PoiCategory(
    id: 'workshop', label: 'Werkstatt', labelPlural: 'Werkstätten',
    overpassTag: '["shop"="car_repair"]',
    overpassTag2: '["craft"="car_repair"]',
    overpassTag3: '["shop"="motorcycle"]',
    googleType: 'car_repair', radiusMeters: 15000,
    photonOsmTags: ['shop:car_repair', 'craft:car_repair', 'shop:motorcycle'],
  );

  static const bikerShop = PoiCategory(
    id: 'biker_shop', label: 'Biker Shop', labelPlural: 'Biker Shops',
    overpassTag: '["shop"="motorcycle"]',
    overpassTag2: '["shop"="motorcycle_repair"]',
    googleType: 'store', radiusMeters: 20000,
    photonOsmTags: ['shop:motorcycle', 'shop:motorcycle_repair'],
  );

  static const autoShop = PoiCategory(
    id: 'auto_shop', label: 'Auto Shop', labelPlural: 'Auto Shops',
    overpassTag: '["shop"="car"]',
    overpassTag2: '["shop"="car_parts"]',
    overpassTag3: '["shop"="tyres"]',
    googleType: 'car_dealer', radiusMeters: 15000,
    photonOsmTags: ['shop:car', 'shop:car_parts', 'shop:tyres'],
  );

  static const restaurant = PoiCategory(
    id: 'restaurant', label: 'Restaurant', labelPlural: 'Restaurants',
    overpassTag: '["amenity"="restaurant"]',
    overpassTag2: '["amenity"="fast_food"]',
    overpassTag3: '["amenity"="biergarten"]',
    googleType: 'restaurant', radiusMeters: 8000,
    photonOsmTags: ['amenity:restaurant', 'amenity:fast_food', 'amenity:biergarten'],
  );

  static const cafe = PoiCategory(
    id: 'cafe', label: 'Café', labelPlural: 'Cafés',
    overpassTag: '["amenity"="cafe"]',
    overpassTag2: '["amenity"="ice_cream"]',
    googleType: 'cafe', radiusMeters: 8000,
    photonOsmTags: ['amenity:cafe', 'amenity:ice_cream'],
  );

  static const bank = PoiCategory(
    id: 'bank', label: 'Bank', labelPlural: 'Banken',
    overpassTag: '["amenity"="bank"]',
    overpassTag2: '["amenity"="atm"]',
    googleType: 'bank', radiusMeters: 8000,
    photonOsmTags: ['amenity:bank', 'amenity:atm'],
  );

  static const hospital = PoiCategory(
    id: 'hospital', label: 'Krankenhaus', labelPlural: 'Krankenhäuser',
    overpassTag: '["amenity"="hospital"]',
    overpassTag2: '["amenity"="clinic"]',
    overpassTag3: '["amenity"="doctors"]',
    googleType: 'hospital', radiusMeters: 15000,
    photonOsmTags: ['amenity:hospital', 'amenity:clinic', 'amenity:doctors'],
  );

  static const grocery = PoiCategory(
    id: 'grocery', label: 'Lebensmittel', labelPlural: 'Lebensmittelläden',
    overpassTag: '["shop"="supermarket"]',
    overpassTag2: '["shop"="convenience"]',
    overpassTag3: '["shop"="grocery"]',
    googleType: 'supermarket', radiusMeters: 8000,
    photonOsmTags: ['shop:supermarket', 'shop:convenience'],
  );

  static const pharmacy = PoiCategory(
    id: 'pharmacy', label: 'Apotheke', labelPlural: 'Apotheken',
    overpassTag: '["amenity"="pharmacy"]',
    overpassTag2: '["shop"="chemist"]',
    googleType: 'pharmacy', radiusMeters: 8000,
    photonOsmTags: ['amenity:pharmacy'],
  );

  static const all = [fuel, workshop, bikerShop, autoShop, restaurant, cafe, bank, hospital, grocery, pharmacy];
}

class PoiNetworkException implements Exception {
  final String message;
  const PoiNetworkException(this.message);
  @override
  String toString() => 'PoiNetworkException: $message';
}

class _CacheEntry {
  final List<PoiResult> results;
  final DateTime timestamp;
  const _CacheEntry(this.results, this.timestamp);
  bool get isExpired => DateTime.now().difference(timestamp).inMinutes > 30;
}

const _overpassServers = [
  'https://overpass-api.de/api/interpreter',
  'https://overpass.kumi.systems/api/interpreter',
  'https://overpass.private.coffee/api/interpreter',
  'https://overpass.osm.ch/api/interpreter',
];

const _photonHeaders = {
  'User-Agent': 'Motorinu-App/1.6 (Android; contact@bikergram.com)',
  'Accept': 'application/json',
};

/// POI Search Service.
///
/// 1. Overpass (2 Server, 15s)
/// 2. Bei Fehler → Photon Reverse-Geocode mit osm_tag Filter (< 1s)
class PoiSearchService {
  PoiSearchService._();
  static final instance = PoiSearchService._();

  final Map<String, _CacheEntry> _cache = {};
  int _serverIdx = 0;

  String _cacheKey(String id, double lat, double lon) =>
      '$id:${lat.toStringAsFixed(3)}:${lon.toStringAsFixed(3)}';

  void clearCache() => _cache.clear();

  List<String> _pickServers() {
    final s1 = _overpassServers[_serverIdx % _overpassServers.length];
    final s2 = _overpassServers[(_serverIdx + 1) % _overpassServers.length];
    _serverIdx = (_serverIdx + 1) % _overpassServers.length;
    return [s1, s2];
  }

  Future<List<PoiResult>> search({
    required double lat,
    required double lon,
    required PoiCategory category,
    int limit = 10,
  }) async {
    final key = _cacheKey(category.id, lat, lon);
    final cached = _cache[key];
    if (cached != null && !cached.isExpired) {
      debugPrint('[POI] Cache hit ${category.id} (${cached.results.length})');
      return _sortAndLimit(cached.results, limit);
    }

    final sw = Stopwatch()..start();
    List<PoiResult> results = [];

    // 1. Photon Reverse (schnell ~200ms, zuverlässig, echte Nähe-Suche)
    if (category.photonOsmTags.isNotEmpty) {
      try {
        results = await _photonReverseSearch(lat, lon, category);
        debugPrint('[POI] Photon: ${results.length} Ergebnisse');
      } catch (e) {
        debugPrint('[POI] Photon failed: $e');
      }
    }

    // 2. Overpass Fallback (langsamer, aber mehr Details: Öffnungszeiten, Telefon)
    if (results.isEmpty) {
      debugPrint('[POI] ${category.id}: Photon leer → Overpass Fallback');
      try {
        results = await _overpassSearch(lat, lon, category);
      } catch (e) {
        debugPrint('[POI] Overpass failed: $e');
      }
    }

    sw.stop();
    debugPrint('[POI] ${category.id}: ${results.length} Ergebnisse in ${sw.elapsedMilliseconds}ms');

    if (results.isNotEmpty) {
      _cache[key] = _CacheEntry(results, DateTime.now());
    } else if (cached != null && cached.results.isNotEmpty) {
      return _sortAndLimit(cached.results, limit);
    }

    return _sortAndLimit(results, limit);
  }

  // ─── OVERPASS ───

  Future<List<PoiResult>> _overpassSearch(double lat, double lon, PoiCategory cat) async {
    var results = await _doOverpass(lat, lon, cat, cat.radiusMeters);
    if (results.isEmpty) {
      results = await _doOverpass(lat, lon, cat, min(cat.radiusMeters * 2, 30000));
    }
    return results;
  }

  Future<List<PoiResult>> _doOverpass(double lat, double lon, PoiCategory cat, int radius) async {
    final tags = [cat.overpassTag, if (cat.overpassTag2 != null) cat.overpassTag2!, if (cat.overpassTag3 != null) cat.overpassTag3!];
    final buf = StringBuffer();
    for (final t in tags) { buf.write('node$t(around:$radius,$lat,$lon);way$t(around:$radius,$lat,$lon);'); }

    final query = '[out:json][timeout:15][maxsize:2000000];(${buf.toString()});out center body;';
    final resp = await _raceRequests(
      _pickServers().map((s) => http.post(Uri.parse(s),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'data=${Uri.encodeComponent(query)}',
      ).timeout(const Duration(seconds: 15))).toList(),
    );
    if (resp == null) throw const PoiNetworkException('Overpass nicht erreichbar');
    return _parseOverpass(resp.body, lat, lon, cat.id);
  }

  List<PoiResult> _parseOverpass(String body, double lat, double lon, String catId) {
    final results = <PoiResult>[];
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final elements = data['elements'] as List? ?? [];
      final seen = <String>{};
      for (final el in elements) {
        if (el is! Map<String, dynamic>) continue;
        double? sLat = (el['lat'] as num?)?.toDouble();
        double? sLon = (el['lon'] as num?)?.toDouble();
        if (sLat == null || sLon == null) {
          final c = el['center'] as Map<String, dynamic>?;
          if (c != null) { sLat = (c['lat'] as num?)?.toDouble(); sLon = (c['lon'] as num?)?.toDouble(); }
        }
        if (sLat == null || sLon == null) continue;
        final tags = el['tags'] as Map<String, dynamic>? ?? {};
        final name = tags['name'] as String? ?? tags['brand'] as String? ?? tags['operator'] as String? ?? '';
        if (name.isEmpty) continue;
        final dk = '${name.toLowerCase()}:${sLat.toStringAsFixed(3)}:${sLon.toStringAsFixed(3)}';
        if (seen.contains(dk)) continue;
        seen.add(dk);
        final dist = Geolocator.distanceBetween(lat, lon, sLat, sLon);
        final street = tags['addr:street'] as String? ?? '';
        final houseNr = tags['addr:housenumber'] as String? ?? '';
        final plz = tags['addr:postcode'] as String? ?? '';
        final city = tags['addr:city'] as String? ?? '';
        final addr = <String>[
          if (street.isNotEmpty) '$street${houseNr.isNotEmpty ? ' $houseNr' : ''}',
          if (plz.isNotEmpty || city.isNotEmpty) '${plz.isNotEmpty ? '$plz ' : ''}$city',
        ];
        results.add(PoiResult(
          name: name, lat: sLat, lon: sLon, distanceM: dist, type: catId,
          address: addr.isNotEmpty ? addr.join(', ') : null,
          openingHours: tags['opening_hours'] as String?,
          brand: (tags['brand'] as String?) != name ? tags['brand'] as String? : null,
          phone: tags['phone'] as String? ?? tags['contact:phone'] as String?,
        ));
      }
    } catch (e) { debugPrint('[POI] Parse error: $e'); }
    return results;
  }

  // ─── PHOTON REVERSE (proximity search mit osm_tag filter) ───

  /// Uses Photon /reverse endpoint with OSM tag filter.
  /// Returns the NEAREST POIs of the exact category — sorted by proximity.
  /// Much faster than Overpass (~200ms), always available, no rate limit.
  Future<List<PoiResult>> _photonReverseSearch(
      double lat, double lon, PoiCategory category) async {
    final radiusKm = (category.radiusMeters / 1000.0).clamp(1.0, 30.0);

    // Build URL with multiple osm_tag params (Dart Uri doesn't support dupes)
    final params = StringBuffer(
      'lat=$lat&lon=$lon&radius=$radiusKm&limit=25&lang=de',
    );
    for (final tag in category.photonOsmTags) {
      params.write('&osm_tag=$tag');
    }
    final url = Uri.parse('https://photon.komoot.io/reverse?$params');

    debugPrint('[POI] Photon reverse: ${category.id} r=${radiusKm}km tags=${category.photonOsmTags}');
    final resp = await http.get(url, headers: _photonHeaders)
        .timeout(const Duration(seconds: 8));

    if (resp.statusCode != 200) {
      debugPrint('[POI] Photon ${resp.statusCode}');
      throw PoiNetworkException('Photon ${resp.statusCode}');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final features = data['features'] as List? ?? [];
    debugPrint('[POI] Photon reverse: ${features.length} features');

    final results = <PoiResult>[];
    final seen = <String>{};

    for (final f in features) {
      if (f is! Map<String, dynamic>) continue;
      final geom = f['geometry'] as Map<String, dynamic>?;
      final props = f['properties'] as Map<String, dynamic>?;
      if (geom == null || props == null) continue;

      final coords = geom['coordinates'] as List?;
      if (coords == null || coords.length < 2) continue;
      final pLon = (coords[0] as num).toDouble();
      final pLat = (coords[1] as num).toDouble();

      final name = props['name'] as String? ?? '';
      if (name.isEmpty) continue;

      final dk = '${name.toLowerCase()}:${pLat.toStringAsFixed(3)}:${pLon.toStringAsFixed(3)}';
      if (seen.contains(dk)) continue;
      seen.add(dk);

      final dist = Geolocator.distanceBetween(lat, lon, pLat, pLon);

      // Build address
      final street = props['street'] as String? ?? '';
      final houseNr = props['housenumber'] as String? ?? '';
      final plz = props['postcode'] as String? ?? '';
      final city = props['city'] as String? ?? props['locality'] as String? ?? '';
      final addr = <String>[
        if (street.isNotEmpty) '$street${houseNr.isNotEmpty ? ' $houseNr' : ''}',
        if (plz.isNotEmpty || city.isNotEmpty) '${plz.isNotEmpty ? '$plz ' : ''}$city',
      ];

      results.add(PoiResult(
        name: name, lat: pLat, lon: pLon, distanceM: dist, type: category.id,
        address: addr.isNotEmpty ? addr.join(', ') : null,
      ));
    }

    return results;
  }

  // ─── UTILS ───

  Future<http.Response?> _raceRequests(List<Future<http.Response>> futures) async {
    final completer = Completer<http.Response?>();
    int remaining = futures.length;
    for (final f in futures) {
      f.then((r) {
        if (r.statusCode == 200 && !completer.isCompleted) { completer.complete(r); }
        else { remaining--; if (remaining <= 0 && !completer.isCompleted) completer.complete(null); }
      }).catchError((Object e) {
        remaining--;
        if (remaining <= 0 && !completer.isCompleted) completer.complete(null);
      });
    }
    return completer.future;
  }

  List<PoiResult> _sortAndLimit(List<PoiResult> results, int limit) {
    final sorted = List<PoiResult>.from(results)
      ..sort((a, b) => a.distanceM.compareTo(b.distanceM));
    return sorted.length > limit ? sorted.sublist(0, limit) : sorted;
  }

  Future<Map<String, List<PoiResult>>> searchAll({
    required double lat, required double lon,
    List<PoiCategory> categories = const [], int limitPerCategory = 5,
  }) async {
    final cats = categories.isEmpty ? PoiCategory.all : categories;
    final futures = <String, Future<List<PoiResult>>>{};
    for (final c in cats) { futures[c.id] = search(lat: lat, lon: lon, category: c, limit: limitPerCategory); }
    final results = <String, List<PoiResult>>{};
    for (final e in futures.entries) {
      try { results[e.key] = await e.value; } catch (_) { results[e.key] = []; }
    }
    return results;
  }
}
