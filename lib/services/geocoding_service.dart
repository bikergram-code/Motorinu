import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

// ─── Data Model ─────────────────────────────────────────────────────────────

/// A geocoding search result.
class GeocodingResult {
  final String displayName;
  final String? name; // POI name (e.g. "Shell", "McDonald's")
  final String? city;
  final String? state;
  final String? country;
  final LatLng location;

  /// Nominatim classification (e.g. "place", "highway", "amenity", "shop").
  final String? osmClass;

  /// Nominatim sub-type (e.g. "city", "fuel", "restaurant", "supermarket").
  final String? osmType;

  /// Street address if available.
  final String? road;
  final String? houseNumber;

  const GeocodingResult({
    required this.displayName,
    this.name,
    this.city,
    this.state,
    this.country,
    required this.location,
    this.osmClass,
    this.osmType,
    this.road,
    this.houseNumber,
  });

  /// Short name for display — prefers POI name, then address, then city.
  String get shortName {
    // POI with a name (e.g. "Shell Tankstelle", "McDonald's")
    if (name != null && name!.isNotEmpty) {
      if (city != null) return '$name, $city';
      return name!;
    }
    // Street address
    if (road != null && road!.isNotEmpty) {
      final addr = houseNumber != null ? '$road $houseNumber' : road!;
      if (city != null) return '$addr, $city';
      return addr;
    }
    // City + state
    if (city != null && state != null) return '$city, $state';
    if (city != null) return city!;
    // Trim long display names
    if (displayName.length > 50) {
      return '${displayName.substring(0, 47)}...';
    }
    return displayName;
  }

  /// Type-specific icon based on Nominatim class/type.
  IconData get typeIcon {
    // Amenity — most POIs
    if (osmClass == 'amenity') {
      return switch (osmType) {
        'fuel' || 'charging_station' => Icons.local_gas_station_rounded,
        'restaurant' || 'fast_food' || 'food_court' => Icons.restaurant_rounded,
        'cafe' || 'ice_cream' => Icons.local_cafe_rounded,
        'bar' || 'pub' || 'biergarten' => Icons.sports_bar_rounded,
        'pharmacy' => Icons.local_pharmacy_rounded,
        'hospital' || 'clinic' || 'doctors' => Icons.local_hospital_rounded,
        'bank' || 'atm' => Icons.account_balance_rounded,
        'parking' || 'motorcycle_parking' => Icons.local_parking_rounded,
        'police' => Icons.local_police_rounded,
        'post_office' => Icons.local_post_office_rounded,
        'school' || 'university' || 'college' => Icons.school_rounded,
        'place_of_worship' => Icons.church_rounded,
        'car_wash' => Icons.local_car_wash_rounded,
        'car_rental' => Icons.car_rental_rounded,
        'cinema' || 'theatre' => Icons.theaters_rounded,
        'library' => Icons.local_library_rounded,
        'hotel' || 'motel' || 'hostel' => Icons.hotel_rounded,
        'swimming_pool' => Icons.pool_rounded,
        _ => Icons.storefront_rounded,
      };
    }
    // Shop
    if (osmClass == 'shop') {
      return switch (osmType) {
        'supermarket' || 'convenience' || 'grocery' => Icons.shopping_cart_rounded,
        'motorcycle' || 'car' || 'car_parts' || 'car_repair' => Icons.two_wheeler_rounded,
        'clothes' || 'fashion' => Icons.checkroom_rounded,
        'electronics' || 'computer' || 'mobile_phone' => Icons.devices_rounded,
        'bakery' => Icons.bakery_dining_rounded,
        'butcher' => Icons.set_meal_rounded,
        'hardware' || 'doityourself' => Icons.hardware_rounded,
        _ => Icons.store_rounded,
      };
    }
    // Place
    if (osmClass == 'place') {
      return switch (osmType) {
        'city' || 'town' => Icons.location_city_rounded,
        'village' || 'hamlet' => Icons.house_rounded,
        'suburb' || 'neighbourhood' || 'quarter' => Icons.holiday_village_rounded,
        'state' || 'country' => Icons.public_rounded,
        _ => Icons.place_rounded,
      };
    }
    // Tourism
    if (osmClass == 'tourism') {
      return switch (osmType) {
        'hotel' || 'motel' || 'hostel' || 'guest_house' => Icons.hotel_rounded,
        'camp_site' || 'caravan_site' => Icons.cabin_rounded,
        'museum' => Icons.museum_rounded,
        'viewpoint' => Icons.panorama_rounded,
        _ => Icons.attractions_rounded,
      };
    }
    // Leisure
    if (osmClass == 'leisure') {
      return switch (osmType) {
        'stadium' || 'sports_centre' => Icons.stadium_rounded,
        'park' || 'garden' => Icons.park_rounded,
        'playground' => Icons.toys_rounded,
        _ => Icons.sports_rounded,
      };
    }
    if (osmClass == 'highway') return Icons.route_rounded;
    if (osmClass == 'railway') return Icons.train_rounded;
    if (osmClass == 'building') return Icons.apartment_rounded;
    if (osmClass == 'boundary') return Icons.public_rounded;
    if (osmClass == 'office') return Icons.business_rounded;
    if (osmClass == 'craft') return Icons.construction_rounded;
    return Icons.location_on_rounded;
  }
}

// ─── Service ────────────────────────────────────────────────────────────────

/// Geocoding via Nominatim (OpenStreetMap) — kostenlos, kein API-Key.
/// Findet Städte, Straßen, Firmen, Tankstellen, Restaurants, Shops etc.
class GeocodingService {
  static const _baseUrl = 'https://nominatim.openstreetmap.org';

  /// Search for places by query string.
  /// Returns up to [limit] results worldwide.
  /// Finds POIs (fuel stations, restaurants, shops) as well as cities/streets.
  Future<List<GeocodingResult>> searchPlace(
    String query, {
    int limit = 15,
    LatLng? near, // Optional: bias results near this location
  }) async {
    if (query.trim().isEmpty) return [];

    final params = <String, String>{
      'q': query,
      'format': 'json',
      'addressdetails': '1',
      'namedetails': '1',  // Get POI names
      'extratags': '1',    // Get extra info (brand, opening hours)
      'limit': '$limit',
      'dedupe': '1',       // Remove duplicates
    };

    // Bias results near user's location if available
    if (near != null) {
      params['viewbox'] = '${near.longitude - 0.5},${near.latitude + 0.5},'
          '${near.longitude + 0.5},${near.latitude - 0.5}';
      params['bounded'] = '0'; // Prefer but don't restrict to viewbox
    }

    final url = Uri.parse('$_baseUrl/search').replace(queryParameters: params);

    try {
      debugPrint('[Geocoding] Searching: $query (limit=$limit${near != null ? ', near=${near.latitude},${near.longitude}' : ''})');
      final response = await http.get(url, headers: {
        'User-Agent': 'Bikergram/1.0',
        'Accept-Language': 'de',
      });

      if (response.statusCode != 200) {
        debugPrint('[Geocoding] HTTP ${response.statusCode}');
        return [];
      }

      final results = jsonDecode(response.body) as List;
      return results.map((r) {
        final map = r as Map<String, dynamic>;
        final address = map['address'] as Map<String, dynamic>? ?? {};
        final nameDetails = map['namedetails'] as Map<String, dynamic>? ?? {};

        // Get the best name: namedetails.name > address name > display_name
        final poiName = nameDetails['name'] as String?;

        return GeocodingResult(
          displayName: map['display_name'] as String? ?? '',
          name: poiName,
          city: address['city'] as String? ??
              address['town'] as String? ??
              address['village'] as String?,
          state: address['state'] as String?,
          country: address['country'] as String?,
          location: LatLng(
            double.tryParse(map['lat']?.toString() ?? '0') ?? 0,
            double.tryParse(map['lon']?.toString() ?? '0') ?? 0,
          ),
          osmClass: map['class'] as String?,
          osmType: map['type'] as String?,
          road: address['road'] as String?,
          houseNumber: address['house_number'] as String?,
        );
      }).toList();
    } catch (e) {
      debugPrint('[Geocoding] Error: $e');
      return [];
    }
  }

  /// Reverse geocoding — get ISO 3166-1 alpha-2 country code from coordinates.
  /// Returns null if reverse geocoding fails.
  Future<String?> reverseGeocodeCountryCode(double lat, double lng) async {
    final url = Uri.parse(
      '$_baseUrl/reverse'
      '?lat=$lat'
      '&lon=$lng'
      '&format=json'
      '&addressdetails=1'
      '&zoom=3', // Country-level zoom (faster, less detail)
    );

    try {
      final response = await http.get(url, headers: {
        'User-Agent': 'Bikergram/1.0',
      });

      if (response.statusCode != 200) return null;

      final map = jsonDecode(response.body) as Map<String, dynamic>;
      final address = map['address'] as Map<String, dynamic>? ?? {};
      final code = address['country_code'] as String?;
      return code?.toUpperCase(); // Nominatim returns lowercase, we need uppercase
    } catch (e) {
      debugPrint('[Geocoding] Country code lookup error: $e');
      return null;
    }
  }

  /// Reverse geocoding — get address from coordinates.
  Future<GeocodingResult?> reverseGeocode(LatLng location) async {
    final url = Uri.parse(
      '$_baseUrl/reverse'
      '?lat=${location.latitude}'
      '&lon=${location.longitude}'
      '&format=json'
      '&addressdetails=1'
      '&namedetails=1',
    );

    try {
      final response = await http.get(url, headers: {
        'User-Agent': 'Bikergram/1.0',
        'Accept-Language': 'de',
      });

      if (response.statusCode != 200) return null;

      final map = jsonDecode(response.body) as Map<String, dynamic>;
      final address = map['address'] as Map<String, dynamic>? ?? {};
      final nameDetails = map['namedetails'] as Map<String, dynamic>? ?? {};

      return GeocodingResult(
        displayName: map['display_name'] as String? ?? '',
        name: nameDetails['name'] as String?,
        city: address['city'] as String? ??
            address['town'] as String? ??
            address['village'] as String?,
        state: address['state'] as String?,
        country: address['country'] as String?,
        location: location,
        osmClass: map['class'] as String?,
        osmType: map['type'] as String?,
        road: address['road'] as String?,
        houseNumber: address['house_number'] as String?,
      );
    } catch (e) {
      debugPrint('[Geocoding] Reverse error: $e');
      return null;
    }
  }
}
