import 'dart:convert';
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

/// Predefined POI categories with Overpass + Google types.
class PoiCategory {
  final String id;
  final String label;
  final String labelPlural;
  final String overpassTag;
  final String? overpassTag2;
  final String googleType;
  final int radiusMeters;

  const PoiCategory({
    required this.id,
    required this.label,
    required this.labelPlural,
    required this.overpassTag,
    this.overpassTag2,
    required this.googleType,
    this.radiusMeters = 10000,
  });

  static const fuel = PoiCategory(
    id: 'fuel',
    label: 'Tankstelle',
    labelPlural: 'Tankstellen',
    overpassTag: '["amenity"="fuel"]',
    googleType: 'gas_station',
    radiusMeters: 5000,
  );

  static const workshop = PoiCategory(
    id: 'workshop',
    label: 'Werkstatt',
    labelPlural: 'Werkstätten',
    overpassTag: '["shop"="motorcycle"]',
    overpassTag2: '["shop"="car_repair"]',
    googleType: 'car_repair',
    radiusMeters: 10000,
  );

  static const bikerShop = PoiCategory(
    id: 'biker_shop',
    label: 'Biker Shop',
    labelPlural: 'Biker Shops',
    overpassTag: '["shop"="motorcycle"]',
    googleType: 'store',
    radiusMeters: 15000,
  );

  static const autoShop = PoiCategory(
    id: 'auto_shop',
    label: 'Auto Shop',
    labelPlural: 'Auto Shops',
    overpassTag: '["shop"="car"]',
    overpassTag2: '["shop"="car_parts"]',
    googleType: 'car_dealer',
    radiusMeters: 15000,
  );

  static const restaurant = PoiCategory(
    id: 'restaurant',
    label: 'Restaurant',
    labelPlural: 'Restaurants',
    overpassTag: '["amenity"="restaurant"]',
    overpassTag2: '["amenity"="fast_food"]',
    googleType: 'restaurant',
    radiusMeters: 5000,
  );

  static const cafe = PoiCategory(
    id: 'cafe',
    label: 'Café',
    labelPlural: 'Cafés',
    overpassTag: '["amenity"="cafe"]',
    googleType: 'cafe',
    radiusMeters: 5000,
  );

  static const bank = PoiCategory(
    id: 'bank',
    label: 'Bank',
    labelPlural: 'Banken',
    overpassTag: '["amenity"="bank"]',
    overpassTag2: '["amenity"="atm"]',
    googleType: 'bank',
    radiusMeters: 5000,
  );

  static const hospital = PoiCategory(
    id: 'hospital',
    label: 'Krankenhaus',
    labelPlural: 'Krankenhäuser',
    overpassTag: '["amenity"="hospital"]',
    overpassTag2: '["amenity"="clinic"]',
    googleType: 'hospital',
    radiusMeters: 10000,
  );

  static const all = [fuel, workshop, bikerShop, autoShop, restaurant, cafe, bank, hospital];
}

/// Service to search for POIs using Overpass API (OSM).
class PoiSearchService {
  PoiSearchService._();
  static final instance = PoiSearchService._();

  /// Search for nearby POIs of a given category.
  /// Returns results sorted by distance, max [limit].
  Future<List<PoiResult>> search({
    required double lat,
    required double lon,
    required PoiCategory category,
    int limit = 10,
  }) async {
    final results = <PoiResult>[];

    try {
      final tagQuery = category.overpassTag2 != null
          ? 'node${category.overpassTag}(around:${category.radiusMeters},$lat,$lon);'
            'way${category.overpassTag}(around:${category.radiusMeters},$lat,$lon);'
            'node${category.overpassTag2}(around:${category.radiusMeters},$lat,$lon);'
            'way${category.overpassTag2}(around:${category.radiusMeters},$lat,$lon);'
          : 'node${category.overpassTag}(around:${category.radiusMeters},$lat,$lon);'
            'way${category.overpassTag}(around:${category.radiusMeters},$lat,$lon);';

      final query = '[out:json][timeout:25];($tagQuery);out center body;';

      // Race all servers — first successful response wins
      const servers = [
        'https://overpass-api.de/api/interpreter',
        'https://overpass.kumi.systems/api/interpreter',
      ];

      final body = 'data=${Uri.encodeComponent(query)}';
      final headers = {'Content-Type': 'application/x-www-form-urlencoded'};

      // Fire all requests in parallel, take first 200 response
      final futures = servers.map((s) => http.post(
        Uri.parse(s), headers: headers, body: body,
      ).timeout(const Duration(seconds: 10)));

      http.Response? resp;
      try {
        final responses = await Future.any(
          futures.map((f) => f.then((r) {
            if (r.statusCode == 200) return r;
            throw Exception('Status ${r.statusCode}');
          })),
        );
        resp = responses;
      } catch (_) {
        debugPrint('[POI] All servers failed');
      }
      if (resp == null || resp.statusCode != 200) return results;

      {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final elements = data['elements'] as List? ?? [];

        for (final el in elements) {
          if (el is! Map<String, dynamic>) continue;

          double? sLat = (el['lat'] as num?)?.toDouble();
          double? sLon = (el['lon'] as num?)?.toDouble();
          if (sLat == null || sLon == null) {
            final center = el['center'] as Map<String, dynamic>?;
            if (center != null) {
              sLat = (center['lat'] as num?)?.toDouble();
              sLon = (center['lon'] as num?)?.toDouble();
            }
          }
          if (sLat == null || sLon == null) continue;

          final tags = el['tags'] as Map<String, dynamic>? ?? {};
          final name = tags['name'] as String?
              ?? tags['brand'] as String?
              ?? tags['operator'] as String?
              ?? '';
          if (name.isEmpty) continue;

          final dist = Geolocator.distanceBetween(lat, lon, sLat, sLon);

          // Extract address from OSM tags
          final street = tags['addr:street'] as String? ?? '';
          final houseNr = tags['addr:housenumber'] as String? ?? '';
          final plz = tags['addr:postcode'] as String? ?? '';
          final city = tags['addr:city'] as String? ?? '';
          final addrParts = <String>[
            if (street.isNotEmpty) '$street${houseNr.isNotEmpty ? ' $houseNr' : ''}',
            if (plz.isNotEmpty || city.isNotEmpty) '${plz.isNotEmpty ? '$plz ' : ''}$city',
          ];
          final address = addrParts.isNotEmpty ? addrParts.join(', ') : null;

          final hours = tags['opening_hours'] as String?;
          final brand = tags['brand'] as String?;
          final phone = tags['phone'] as String? ?? tags['contact:phone'] as String?;

          results.add(PoiResult(
            name: name,
            lat: sLat,
            lon: sLon,
            distanceM: dist,
            type: category.id,
            address: address,
            openingHours: hours,
            brand: brand != name ? brand : null,
            phone: phone,
          ));
        }
      }
    } catch (e) {
      debugPrint('[POI] Overpass search error: $e');
    }

    // Sort by distance, limit results
    results.sort((a, b) => a.distanceM.compareTo(b.distanceM));
    if (results.length > limit) return results.sublist(0, limit);
    return results;
  }

  /// Search all categories at once, returns map of category → results.
  Future<Map<String, List<PoiResult>>> searchAll({
    required double lat,
    required double lon,
    List<PoiCategory> categories = const [],
    int limitPerCategory = 5,
  }) async {
    final cats = categories.isEmpty ? PoiCategory.all : categories;
    final futures = <String, Future<List<PoiResult>>>{};

    for (final cat in cats) {
      futures[cat.id] = search(
        lat: lat, lon: lon,
        category: cat,
        limit: limitPerCategory,
      );
    }

    final results = <String, List<PoiResult>>{};
    for (final entry in futures.entries) {
      results[entry.key] = await entry.value;
    }
    return results;
  }
}
