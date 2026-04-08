import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// A Racer Event / Biker Spot with coordinates and distance.
class RacerEvent {
  final String name;
  final double lat;
  final double lng;
  final double distanceKm;
  final String? description;
  final String source; // 'hardcoded', 'google', 'web'

  const RacerEvent({
    required this.name,
    required this.lat,
    required this.lng,
    required this.distanceKm,
    this.description,
    required this.source,
  });
}

/// Service to find nearby Racer Events / Biker Spots.
/// Combines hardcoded motorsport venues + Google Places search.
class RacerEventsService {
  RacerEventsService._();
  static final instance = RacerEventsService._();

  static const _googleApiKey = 'AIzaSyCDfLYfcdMx1MBVmVJswpRB8MzPO5nLN9U';

  /// Search for nearby racer events from all sources.
  /// Returns up to [limit] results sorted by distance.
  Future<List<RacerEvent>> searchEvents({
    required double lat,
    required double lng,
    int radiusKm = 200,
    int limit = 3,
  }) async {
    final results = <RacerEvent>[];

    // Hardcoded biker spots — instant, no network needed
    for (final spot in _bikerSpots) {
      final dist = _haversineKm(lat, lng, spot.lat, spot.lng);
      if (dist <= radiusKm) {
        results.add(RacerEvent(
          name: spot.name,
          lat: spot.lat,
          lng: spot.lng,
          distanceKm: dist,
          description: spot.description,
          source: 'hardcoded',
        ));
      }
    }

    // Sort by distance, return top N — instant, no waiting
    results.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return results.take(limit).toList();
  }

  /// Search Google Places for motorsport venues.
  Future<List<RacerEvent>> _searchGooglePlaces(double lat, double lng, int radiusKm) async {
    final queries = [
      'Motorrad Treffen Event',
      'Rennstrecke Motorsport',
      'Biker Treff Motorrad',
    ];

    final results = <RacerEvent>[];

    for (final query in queries) {
      try {
        final resp = await http.get(Uri.parse(
          'https://maps.googleapis.com/maps/api/place/textsearch/json'
          '?query=${Uri.encodeComponent(query)}'
          '&location=$lat,$lng'
          '&radius=${radiusKm * 1000}'
          '&language=de'
          '&key=$_googleApiKey',
        )).timeout(const Duration(seconds: 8));

        if (resp.statusCode == 200) {
          final json = jsonDecode(resp.body) as Map<String, dynamic>;
          final places = json['results'] as List? ?? [];
          for (final place in places.take(5)) {
            final loc = (place['geometry'] as Map?)?['location'] as Map?;
            if (loc == null) continue;
            final pLat = (loc['lat'] as num).toDouble();
            final pLng = (loc['lng'] as num).toDouble();
            final dist = _haversineKm(lat, lng, pLat, pLng);
            if (dist > radiusKm) continue;

            final name = place['name'] as String? ?? 'Unbekannt';
            final address = place['formatted_address'] as String? ?? '';

            // Skip if already in results (dedup by name similarity)
            if (results.any((r) => r.name.toLowerCase() == name.toLowerCase())) continue;

            results.add(RacerEvent(
              name: name,
              lat: pLat,
              lng: pLng,
              distanceKm: dist,
              description: address,
              source: 'google',
            ));
          }
        }
      } catch (e) {
        debugPrint('[RacerEvents] Google query "$query" error: $e');
      }
    }

    return results;
  }

  /// Haversine distance in km.
  static double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  static double _deg2rad(double deg) => deg * pi / 180;

  // ─────────────────────────────────────────────────
  //  HARDCODED BIKER SPOTS / MOTORSPORT VENUES
  // ─────────────────────────────────────────────────

  static const _bikerSpots = [
    // 🇩🇪 Deutschland
    _BikerSpot('Nürburgring Nordschleife', 50.3356, 6.9475, 'Legendäre Rennstrecke, Grüne Hölle'),
    _BikerSpot('Nürburgring GP-Strecke', 50.3325, 6.9418, 'Grand Prix Strecke, Events & Rennen'),
    _BikerSpot('Hockenheimring', 49.3278, 8.5656, 'Formel 1 Strecke, Trackdays'),
    _BikerSpot('Sachsenring', 50.7911, 12.6872, 'MotoGP Deutschland, Motorrad-WM'),
    _BikerSpot('Lausitzring (Dekra)', 51.5275, 13.9236, 'Motorsport-Rennstrecke Lausitz'),
    _BikerSpot('Oschersleben Motorsport Arena', 52.0278, 11.2467, 'IDM, Trackdays, Motorsport'),
    _BikerSpot('Schleizer Dreieck', 50.5803, 11.8097, 'Älteste Naturrennstrecke, Bergrennen'),
    _BikerSpot('Bilster Berg Drive Resort', 51.7822, 9.0058, 'Exklusive Rennstrecke, Trackdays'),
    _BikerSpot('Nürburg Biker-Treff', 50.3431, 6.9436, 'Biker-Treffpunkt am Ring'),
    _BikerSpot('Eifel Motorrad Museum', 50.3489, 6.8489, 'Motorrad-Museum in der Eifel'),
    _BikerSpot('Motorrad-Wallfahrt Kevelaer', 51.5836, 6.2464, 'Jährliche Motorrad-Wallfahrt'),

    // 🇩🇪 Biker-Treffpunkte
    _BikerSpot('Café Hubraum Hamburg', 53.5544, 10.0067, 'Biker-Café & Treffpunkt Hamburg'),
    _BikerSpot('Glemseck 101', 48.7697, 9.0447, 'Café Racer Festival, Glemseck'),
    _BikerSpot('Wheels & Waves Biarritz', 43.4832, -1.5586, 'Biker-Festival Biarritz'),

    // 🇳🇱 Niederlande
    _BikerSpot('TT Circuit Assen', 52.9611, 6.5228, 'MotoGP Niederlande, TT Assen'),
    _BikerSpot('Circuit Zandvoort', 52.3889, 4.5406, 'Formel 1, Motorsport'),

    // 🇧🇪 Belgien
    _BikerSpot('Circuit Spa-Francorchamps', 50.4372, 5.9714, 'Formel 1 Belgien, Endurance'),
    _BikerSpot('Circuit Zolder', 50.9906, 5.2567, 'Belgischer Motorsport, Trackdays'),

    // 🇦🇹 Österreich
    _BikerSpot('Red Bull Ring Spielberg', 47.2197, 14.7647, 'MotoGP & F1 Österreich'),
    _BikerSpot('Salzburgring', 47.8486, 13.2186, 'Motorrad-Rennstrecke, IDM'),
    _BikerSpot('Großglockner Hochalpenstraße', 47.0764, 12.8428, 'Legendäre Motorrad-Passstraße'),

    // 🇨🇭 Schweiz
    _BikerSpot('Swiss Moto Zürich', 47.4111, 8.5506, 'Größte Schweizer Motorrad-Messe'),

    // 🇮🇹 Italien
    _BikerSpot('Autodromo di Monza', 45.6156, 9.2811, 'Formel 1 Italien, Tempel der Geschwindigkeit'),
    _BikerSpot('Mugello Circuit', 43.9975, 11.3719, 'MotoGP Italien, Ducati Heimat'),
    _BikerSpot('Misano World Circuit', 43.9622, 12.6847, 'MotoGP San Marino'),
    _BikerSpot('Stelvio Pass / Stilfser Joch', 46.5283, 10.4528, 'Legendärer Motorrad-Pass, 48 Kehren'),

    // 🇫🇷 Frankreich
    _BikerSpot('Circuit de la Sarthe Le Mans', 47.9561, 0.2075, 'MotoGP Frankreich, 24h Le Mans'),
    _BikerSpot('Circuit Paul Ricard', 43.2506, 5.7917, 'Formel 1 Frankreich'),

    // 🇪🇸 Spanien
    _BikerSpot('Circuit de Barcelona-Catalunya', 41.5700, 2.2611, 'MotoGP & F1 Spanien'),
    _BikerSpot('Circuito de Jerez', 36.7083, -6.0344, 'MotoGP Spanien, Wintertest'),

    // 🇬🇧 UK
    _BikerSpot('Silverstone Circuit', 52.0786, -1.0169, 'Formel 1 & MotoGP Großbritannien'),
    _BikerSpot('Donington Park', 52.8306, -1.3750, 'Britische Superbike, Trackdays'),
    _BikerSpot('Isle of Man TT', 54.2361, -4.5481, 'Das gefährlichste Rennen der Welt'),

    // 🇭🇺 Ungarn
    _BikerSpot('Hungaroring', 47.5789, 19.2486, 'Formel 1 Ungarn'),
  ];
}

/// Internal helper for hardcoded biker spots.
class _BikerSpot {
  final String name;
  final double lat;
  final double lng;
  final String? description;

  const _BikerSpot(this.name, this.lat, this.lng, [this.description]);
}
