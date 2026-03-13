import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Fast-Answer-Datenbank für häufige Biker-Fragen.
///
/// Pattern-matched auf Keywords → sofortige Antwort mit echten Live-Daten.
/// Kein Server-Roundtrip, kein LLM, funktioniert teilweise offline.
///
/// Fallback: returns null → caller should use Ollama LLM.
class FastAnswerService {
  FastAnswerService._();
  static final instance = FastAnswerService._();

  // ── Weather cache (Open-Meteo, 10 min TTL) ──
  _WeatherData? _weatherCache;
  DateTime? _weatherCacheTime;
  double _weatherCacheLat = 0;
  double _weatherCacheLon = 0;

  // ── City name cache (shared with BikerAiService) ──
  String? _cachedCity;
  double _cachedCityLat = 0;
  double _cachedCityLon = 0;

  /// Try to answer a voice query instantly using pattern matching + live data.
  ///
  /// Returns spoken answer text, or null if no pattern matched (→ use LLM).
  Future<String?> tryAnswer({
    required String query,
    required double lat,
    required double lon,
    required double speedKmh,
    required double heading,
    required bool isNavigating,
    String? routeDestination,
    double? distanceRemainingKm,
    double? etaMinutes,
    String? currentRoadName,
    int? speedLimit,
  }) async {
    final lower = query.toLowerCase().trim();
    debugPrint('[FastAnswer] Trying: "$lower"');

    // ── Weather ──
    if (_matchesAny(lower, _weatherKeywords)) {
      return _answerWeather(lat, lon, query: lower);
    }

    // ── Speed ──
    if (_matchesAny(lower, _speedKeywords)) {
      return _answerSpeed(speedKmh, speedLimit);
    }

    // ── Location / Where am I ──
    if (_matchesAny(lower, _locationKeywords)) {
      return _answerLocation(lat, lon, currentRoadName);
    }

    // ── Time ──
    if (_matchesAny(lower, _timeKeywords)) {
      return _answerTime();
    }

    // ── Distance remaining (navigation) ──
    if (_matchesAny(lower, _distanceKeywords)) {
      return _answerDistance(
        isNavigating, routeDestination, distanceRemainingKm, etaMinutes,
      );
    }

    // ── Biker tips ──
    if (_matchesAny(lower, _tipKeywords)) {
      return _answerTip();
    }

    // ── Greeting / How are you ──
    if (_matchesAny(lower, _greetingKeywords)) {
      return _answerGreeting(speedKmh);
    }

    // ── Who are you ──
    if (_matchesAny(lower, _identityKeywords)) {
      return _answerIdentity();
    }

    // ── Thank you ──
    if (_matchesAny(lower, _thanksKeywords)) {
      return _answerThanks();
    }

    // No pattern matched → null → caller uses Ollama
    debugPrint('[FastAnswer] No match, falling through to LLM');
    return null;
  }

  // ═══════════════════════════════════════════════════
  //  KEYWORD TABLES
  // ═══════════════════════════════════════════════════

  static const _weatherKeywords = [
    'wetter', 'regen', 'regnen', 'regnet', 'sonne', 'sonnig',
    'temperatur', 'grad', 'kalt', 'warm', 'wind', 'sturm',
    'schnee', 'gewitter', 'wolken', 'bewölkt', 'trocken',
    'nass', 'weather', 'rain',
    'morgen', 'übermorgen', 'wochenende', 'nächste woche',
    'kommende tage', 'vorhersage', 'prognose',
  ];

  static const _speedKeywords = [
    'wie schnell', 'geschwindigkeit', 'speed', 'tempo',
    'wie viel fahre', 'kmh', 'km/h', 'sachen',
  ];

  static const _locationKeywords = [
    'wo bin ich', 'wo sind wir', 'standort', 'position',
    'welche stadt', 'welcher ort', 'location', 'wo genau',
    'in welcher stadt',
  ];

  static const _timeKeywords = [
    'wie spät', 'uhrzeit', 'wieviel uhr', 'wie viel uhr',
    'zeit', 'uhr',
  ];

  static const _distanceKeywords = [
    'wie weit', 'noch weit', 'entfernung', 'wie lange noch',
    'wann sind wir da', 'ankunft', 'eta', 'restzeit',
    'wie viele kilometer', 'noch wie viel',
  ];

  static const _tipKeywords = [
    'tipp', 'tipps', 'ratschlag', 'hinweis',
    'worauf achten', 'sicherheit', 'sicher fahren',
    'was muss ich', 'empfehlung',
  ];

  static const _greetingKeywords = [
    'wie geht', 'hallo', 'na du', 'alles klar',
    'was geht', 'hey', 'servus', 'moin',
    'guten morgen', 'guten tag', 'guten abend',
  ];

  static const _identityKeywords = [
    'wer bist du', 'was bist du', 'was kannst du',
    'bist du eine ki', 'bist du ein bot',
    'wie heißt du', 'dein name',
  ];

  static const _thanksKeywords = [
    'danke', 'dankeschön', 'vielen dank', 'merci',
    'thanks', 'cool danke', 'super danke',
  ];

  // ═══════════════════════════════════════════════════
  //  ANSWER GENERATORS
  // ═══════════════════════════════════════════════════

  Future<String> _answerWeather(double lat, double lon, {String query = ''}) async {
    try {
      final weather = await _getWeather(lat, lon);
      if (weather == null) {
        return 'Wetterdaten konnte ich gerade nicht laden. Versuch es gleich nochmal!';
      }

      final city = await _getCityName(lat, lon);
      final cityStr = city != null ? 'In $city' : 'Bei dir';

      final lower = query.toLowerCase();

      // ── Multi-day forecast request ──
      if (lower.contains('morgen') || lower.contains('übermorgen') ||
          lower.contains('woche') || lower.contains('tage') ||
          lower.contains('vorhersage') || lower.contains('prognose') ||
          lower.contains('wochenende')) {
        return _buildMultiDayForecast(weather, cityStr);
      }

      // ── Current conditions ──
      final temp = weather.temperature.round();
      final condition = _weatherCodeToGerman(weather.weatherCode);
      final windKmh = weather.windSpeed.round();
      final isRainy = [51, 53, 55, 61, 63, 65, 80, 81, 82, 95, 96, 99]
          .contains(weather.weatherCode);

      // Rain forecast (next hours)
      String rainForecast = '';
      if (weather.hourlyRainChance.isNotEmpty) {
        final nextRainHour = weather.hourlyRainChance.indexWhere((c) => c > 40);
        if (nextRainHour >= 0 && nextRainHour <= 2) {
          rainForecast = ' In $nextRainHour Stunden wirds nass!';
        } else if (nextRainHour >= 0) {
          rainForecast = ' In $nextRainHour Stunden könnte es regnen.';
        } else {
          rainForecast = ' Die nächsten Stunden bleibt es trocken.';
        }
      }

      final windInfo = windKmh > 30 ? ' Aufpassen, $windKmh km/h Wind!' : '';

      // Weather-dependent outro
      String outro;
      if (isRainy) {
        outro = ' Bleib zuhause Racer und lass dein Babe in der Garage!';
      } else if (temp < 5) {
        outro = ' Ziemlich frisch, Racer. Zieh dich warm an!';
      } else if (weather.weatherCode == 0 && temp > 18) {
        outro = ' Perfektes Bikerwetter, Racer! Gib Gas!';
      } else {
        outro = ' Ride on!';
      }

      return '$cityStr sind es $temp Grad, $condition.$rainForecast$windInfo$outro';
    } catch (e) {
      debugPrint('[FastAnswer] Weather error: $e');
      return 'Wetterdaten nicht verfügbar. Schau mal aus dem Visier!';
    }
  }

  /// Build multi-day forecast TTS response.
  String _buildMultiDayForecast(_WeatherData weather, String cityStr) {
    if (weather.dailyForecasts.isEmpty) {
      return '$cityStr aktuell ${weather.temperature.round()} Grad. Leider keine Mehrtage-Vorhersage verfügbar.';
    }

    final dayNames = ['Heute', 'Morgen', 'Übermorgen'];
    final weekdays = ['Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag', 'Sonntag'];
    final parts = <String>[];

    for (int i = 0; i < weather.dailyForecasts.length && i < 4; i++) {
      final day = weather.dailyForecasts[i];
      String dayName;
      if (i < dayNames.length) {
        dayName = dayNames[i];
      } else {
        try {
          final date = DateTime.parse(day.date);
          dayName = weekdays[date.weekday - 1];
        } catch (_) {
          dayName = 'Tag ${i + 1}';
        }
      }

      final condition = _weatherCodeToGerman(day.weatherCode);
      final isRainy = day.rainChanceMax > 50;
      final rainInfo = isRainy ? ', ${day.rainChanceMax}% Regen' : '';

      parts.add('$dayName: ${day.maxTemp.round()} Grad, $condition$rainInfo');
    }

    // Check if any day is good for riding
    final goodDays = weather.dailyForecasts
        .where((d) => d.rainChanceMax < 30 && d.maxTemp > 10)
        .length;

    String outro;
    if (goodDays == 0) {
      outro = ' Sieht nicht gut aus für eine Tour. Lass dein Babe in der Garage!';
    } else if (goodDays >= 3) {
      outro = ' Sieht gut aus die Woche, Racer! Gib Gas!';
    } else {
      outro = ' Such dir den besten Tag aus, Racer!';
    }

    return '$cityStr die Vorhersage: ${parts.join('. ')}.$outro';
  }

  String _answerSpeed(double speedKmh, int? speedLimit) {
    final speed = speedKmh.round();
    if (speed < 5) {
      return 'Du stehst gerade, Racer. Alles easy!';
    }

    String limitInfo = '';
    if (speedLimit != null && speedLimit > 0) {
      if (speed > speedLimit + 5) {
        limitInfo = ' Achtung, Tempolimit ist $speedLimit!';
      } else {
        limitInfo = ' Tempolimit $speedLimit, passt perfekt.';
      }
    }

    if (speed > 120) {
      return '$speed Sachen, Racer! Gib Gas!$limitInfo';
    } else if (speed > 80) {
      return '$speed km/h, läuft smooth bei dir!$limitInfo';
    } else {
      return 'Du machst gerade $speed Sachen.$limitInfo';
    }
  }

  Future<String> _answerLocation(double lat, double lon, String? roadName) async {
    final city = await _getCityName(lat, lon);
    final road = roadName != null ? ' auf der $roadName' : '';

    if (city != null) {
      return 'Du bist in $city$road, Racer!';
    }
    return 'GPS sagt ${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}$road.';
  }

  String _answerTime() {
    final now = DateTime.now();
    final hour = now.hour;
    final min = now.minute;

    String timeStr;
    if (min == 0) {
      timeStr = '$hour Uhr';
    } else if (min == 15) {
      timeStr = 'Viertel nach $hour';
    } else if (min == 30) {
      timeStr = 'halb ${hour + 1}';
    } else if (min == 45) {
      timeStr = 'Viertel vor ${hour + 1}';
    } else {
      timeStr = '$hour Uhr $min';
    }

    String greeting;
    if (hour < 6) {
      greeting = 'Nachtfahrt! ';
    } else if (hour < 12) {
      greeting = '';
    } else if (hour < 18) {
      greeting = '';
    } else {
      greeting = 'Abendtour! ';
    }

    return '${greeting}Es ist $timeStr, Racer!';
  }

  String _answerDistance(
    bool isNavigating, String? destination,
    double? distanceKm, double? etaMin,
  ) {
    if (!isNavigating || destination == null) {
      return 'Keine Navigation aktiv. Sag mir wohin du willst!';
    }

    if (distanceKm != null && etaMin != null) {
      final distStr = distanceKm < 1
          ? '${(distanceKm * 1000).round()} Meter'
          : '${distanceKm.toStringAsFixed(1).replaceAll('.', ',')} km';
      final etaStr = etaMin < 1
          ? 'gleich da'
          : etaMin < 60
              ? '${etaMin.round()} Minuten'
              : '${(etaMin / 60).toStringAsFixed(1).replaceAll('.', ',')} Stunden';
      return 'Noch $distStr bis $destination, etwa $etaStr. Fahr weiter, Racer!';
    }

    return 'Du navigierst nach $destination. Bleib auf Kurs!';
  }

  String _answerTip() {
    final tips = [
      'Denk dran Racer: Bei Nässe immer smooth bremsen, nie ruckartig!',
      'Profi-Tipp: In Kurven nie am Vorderrad bremsen. Gas rollen lassen!',
      'Safety first: Alle 2 Stunden Pause machen. Dein Körper dankt es dir!',
      'Auf nasser Straße: Fahrbahnmarkierungen und Kanaldeckel meiden, die sind glatt wie Eis!',
      'Vergiss nicht: Reifendruck checken bevor du losfährst. Spart Sprit und rettet Leben!',
      'Bei Gruppenfahrten: Immer versetzt fahren, nie nebeneinander. Mehr Sicht, mehr Sicherheit!',
      'Tipp: Schau immer dahin wo du hin willst, nicht auf das Hindernis. Dein Bike folgt deinem Blick!',
      'Dunkle Kleidung sieht cool aus, aber reflektierende Elemente retten Leben. Ride smart!',
      'Bei starkem Seitenwind: Knie an den Tank pressen und locker in den Armen bleiben!',
      'Wichtig: Motorradkette alle 500 km schmieren. Deine Kette wird es dir danken!',
    ];
    return tips[DateTime.now().millisecond % tips.length];
  }

  String _answerGreeting(double speedKmh) {
    if (speedKmh > 10) {
      return 'Hey Racer! Alles klar bei mir, und bei dir läufts ja auch! Ride on!';
    }
    return 'Hey Racer! Mir gehts blendend. Bereit zum Cruisen?';
  }

  String _answerIdentity() {
    return 'Ich bin Moto, dein KI-Biker-Kumpel in der Motorinu App! '
        'Frag mich nach Wetter, Geschwindigkeit, Tankstellen oder einfach nach einem Tipp. Ride on!';
  }

  String _answerThanks() {
    final responses = [
      'Immer gerne, Racer! Dafür bin ich da.',
      'Kein Ding! Frag mich jederzeit. Ride on!',
      'Bitte bitte! Zusammen cruisen wir durch alles.',
      'Gerne! Ich bin immer für dich da auf der Strecke.',
    ];
    return responses[DateTime.now().millisecond % responses.length];
  }

  // ═══════════════════════════════════════════════════
  //  OPEN-METEO WEATHER API (free, no API key!)
  // ═══════════════════════════════════════════════════

  Future<_WeatherData?> _getWeather(double lat, double lon) async {
    // Check cache (10 min TTL, 5km distance)
    if (_weatherCache != null && _weatherCacheTime != null) {
      final age = DateTime.now().difference(_weatherCacheTime!);
      final dist = _approxDistance(_weatherCacheLat, _weatherCacheLon, lat, lon);
      if (age.inMinutes < 10 && dist < 5000) {
        debugPrint('[FastAnswer] Weather from cache');
        return _weatherCache;
      }
    }

    try {
      final url = 'https://api.open-meteo.com/v1/forecast'
          '?latitude=$lat&longitude=$lon'
          '&current=temperature_2m,weather_code,wind_speed_10m'
          '&hourly=precipitation_probability'
          '&forecast_hours=12'
          '&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max'
          '&forecast_days=5'
          '&timezone=auto';

      final resp = await http.get(Uri.parse(url))
          .timeout(const Duration(seconds: 5));

      if (resp.statusCode != 200) return null;

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final current = data['current'] as Map<String, dynamic>;

      final hourly = data['hourly'] as Map<String, dynamic>?;
      final rainChance = <int>[];
      if (hourly != null) {
        final probs = hourly['precipitation_probability'] as List?;
        if (probs != null) {
          for (final p in probs) {
            rainChance.add((p as num?)?.toInt() ?? 0);
          }
        }
      }

      // Parse daily forecast
      final daily = data['daily'] as Map<String, dynamic>?;
      final dailyForecasts = <_DailyForecast>[];
      if (daily != null) {
        final dates = daily['time'] as List? ?? [];
        final codes = daily['weather_code'] as List? ?? [];
        final maxTemps = daily['temperature_2m_max'] as List? ?? [];
        final minTemps = daily['temperature_2m_min'] as List? ?? [];
        final rainProbs = daily['precipitation_probability_max'] as List? ?? [];
        for (int i = 0; i < dates.length && i < 5; i++) {
          dailyForecasts.add(_DailyForecast(
            date: dates[i] as String? ?? '',
            weatherCode: (codes.length > i ? codes[i] as num? : null)?.toInt() ?? 0,
            maxTemp: (maxTemps.length > i ? maxTemps[i] as num? : null)?.toDouble() ?? 0,
            minTemp: (minTemps.length > i ? minTemps[i] as num? : null)?.toDouble() ?? 0,
            rainChanceMax: (rainProbs.length > i ? rainProbs[i] as num? : null)?.toInt() ?? 0,
          ));
        }
      }

      final weather = _WeatherData(
        temperature: (current['temperature_2m'] as num).toDouble(),
        weatherCode: (current['weather_code'] as num).toInt(),
        windSpeed: (current['wind_speed_10m'] as num).toDouble(),
        hourlyRainChance: rainChance,
        dailyForecasts: dailyForecasts,
      );

      // Update cache
      _weatherCache = weather;
      _weatherCacheTime = DateTime.now();
      _weatherCacheLat = lat;
      _weatherCacheLon = lon;

      debugPrint('[FastAnswer] Weather: ${weather.temperature}°C, code=${weather.weatherCode}');
      return weather;
    } catch (e) {
      debugPrint('[FastAnswer] Weather fetch error: $e');
      return _weatherCache; // Return stale cache on error
    }
  }

  /// WMO Weather Code → German description.
  static String _weatherCodeToGerman(int code) {
    return switch (code) {
      0 => 'klarer Himmel',
      1 => 'überwiegend klar',
      2 => 'teilweise bewölkt',
      3 => 'bewölkt',
      45 || 48 => 'Nebel',
      51 || 53 || 55 => 'Nieselregen',
      56 || 57 => 'gefrierender Nieselregen',
      61 || 63 || 65 => 'Regen',
      66 || 67 => 'gefrierender Regen',
      71 || 73 || 75 => 'Schneefall',
      77 => 'Schneekörner',
      80 || 81 || 82 => 'Regenschauer',
      85 || 86 => 'Schneeschauer',
      95 => 'Gewitter',
      96 || 99 => 'Gewitter mit Hagel',
      _ => 'wechselhaft',
    };
  }

  // ═══════════════════════════════════════════════════
  //  NOMINATIM REVERSE GEOCODING (cached)
  // ═══════════════════════════════════════════════════

  Future<String?> _getCityName(double lat, double lon) async {
    final dist = _cachedCity != null
        ? _approxDistance(_cachedCityLat, _cachedCityLon, lat, lon)
        : double.infinity;
    if (dist < 2000 && _cachedCity != null) return _cachedCity;

    try {
      final resp = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/reverse'
            '?lat=$lat&lon=$lon&format=json&accept-language=de&zoom=14'),
        headers: {'User-Agent': 'Bikergram-App/1.0'},
      ).timeout(const Duration(seconds: 3));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>? ?? {};
        final city = address['city'] as String?
            ?? address['town'] as String?
            ?? address['village'] as String?
            ?? address['municipality'] as String?;
        if (city != null) {
          _cachedCity = city;
          _cachedCityLat = lat;
          _cachedCityLon = lon;
        }
        return city;
      }
    } catch (e) {
      debugPrint('[FastAnswer] Geocode error: $e');
    }
    return _cachedCity;
  }

  // ═══════════════════════════════════════════════════
  //  HELPERS
  // ═══════════════════════════════════════════════════

  static bool _matchesAny(String lower, List<String> keywords) {
    return keywords.any((kw) => lower.contains(kw));
  }

  static double _approxDistance(double lat1, double lon1, double lat2, double lon2) {
    const m = 111320.0;
    final dLat = (lat2 - lat1) * m;
    final dLon = (lon2 - lon1) * m * 0.65;
    return sqrt(dLat * dLat + dLon * dLon);
  }
}

/// Internal weather data model.
class _WeatherData {
  final double temperature;
  final int weatherCode;
  final double windSpeed;
  final List<int> hourlyRainChance; // Next 12 hours, % chance
  final List<_DailyForecast> dailyForecasts; // Next 5 days

  const _WeatherData({
    required this.temperature,
    required this.weatherCode,
    required this.windSpeed,
    required this.hourlyRainChance,
    this.dailyForecasts = const [],
  });
}

class _DailyForecast {
  final String date; // YYYY-MM-DD
  final int weatherCode;
  final double maxTemp;
  final double minTemp;
  final int rainChanceMax;

  const _DailyForecast({
    required this.date,
    required this.weatherCode,
    required this.maxTemp,
    required this.minTemp,
    required this.rainChanceMax,
  });
}
