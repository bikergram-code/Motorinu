import 'dart:convert';
import 'dart:math' show sqrt;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// "Moto" KI-Biker-Assistent — calls Ollama (Mistral 7B) directly on our server.
///
/// Open-source, self-hosted, completely free. No API keys needed in stores.
/// Server: 152.53.255.4 via Nginx reverse proxy with API-key header.
///
/// Usage:
///   final response = await BikerAiService.instance.query(
///     text: 'Wird es gleich regnen?',
///     lat: 51.02, lon: 7.05, speed: 80, heading: 180,
///     isNavigating: true,
///   );
///   if (response != null) TtsAlertService.instance.speakPriority(response.response);
class BikerAiService {
  BikerAiService._();
  static final instance = BikerAiService._();

  static const _ollamaUrl = 'http://152.53.255.4/ollama/api/generate';
  static const _ollamaKey = 'moto-bikergram-2026-secure';
  static const _model = 'mistral:7b-instruct-v0.3-q4_K_M';

  // Reverse geocode cache — avoids repeated Nominatim calls for same area
  String? _cachedCity;
  double _cachedLat = 0;
  double _cachedLon = 0;

  static const _systemPrompt = '''Du bist Moto, Biker-KI-Kumpel. Locker, motivierend, Biker-Slang. Max 2 Sätze! Deutsch. Nenne Stadt/Ort. Kein Markdown.
Antwort NUR als JSON: {"response":"Text","action":{"type":"none","params":{}}}
action.type: "searchPoi" (params: query, poiLabel), "navigate" (params: address), "none"''';

  /// Query the Moto KI assistant with riding context.
  ///
  /// Returns [AiResponse] with spoken text + optional action, or null on error.
  Future<AiResponse?> query({
    required String text,
    required double lat,
    required double lon,
    required double speed,
    required double heading,
    required bool isNavigating,
    String? routeDestination,
    String? currentRoadName,
    int? speedLimit,
  }) async {
    try {
      debugPrint('[MotoAI] Query: "$text"');

      // Get city name via reverse geocoding (cached, only re-fetches if moved > 2km)
      final cityName = await _getCityName(lat, lon);

      // Build user prompt with riding context
      final locationInfo = cityName != null ? ', Standort: $cityName' : '';
      final roadInfo = currentRoadName != null ? ', Straße: $currentRoadName' : '';
      final limitInfo = speedLimit != null ? ', Tempolimit: $speedLimit km/h' : '';
      final contextStr = 'Fahrer-Kontext: GPS ${lat.toStringAsFixed(4)},${lon.toStringAsFixed(4)}$locationInfo$roadInfo, '
          'Geschwindigkeit ${speed.round()} km/h$limitInfo, '
          '${isNavigating ? 'navigiert nach ${routeDestination ?? "unbekannt"}' : 'keine Navigation aktiv'}';

      final userPrompt = '$contextStr\n\nFahrer sagt: "$text"';

      final response = await http.post(
        Uri.parse(_ollamaUrl),
        headers: {
          'Content-Type': 'application/json',
          'X-Ollama-Key': _ollamaKey,
        },
        body: jsonEncode({
          'model': _model,
          'prompt': userPrompt,
          'system': _systemPrompt,
          'stream': false,
          'options': {
            'temperature': 0.7,
            'num_predict': 120,  // Shorter answers = faster response
            'num_ctx': 1024,     // Smaller context = less RAM, faster
          },
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        debugPrint('[MotoAI] Ollama error: ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final rawText = data['response'] as String? ?? '';

      debugPrint('[MotoAI] Raw: ${rawText.substring(0, rawText.length.clamp(0, 200))}');

      // Parse JSON from Ollama response
      return _parseOllamaResponse(rawText);
    } catch (e) {
      debugPrint('[MotoAI] Error: $e');
      return null;
    }
  }

  /// Get city name from Nominatim reverse geocoding (cached, re-fetches if moved > 2km).
  Future<String?> _getCityName(double lat, double lon) async {
    // Check cache — only re-fetch if moved > 2km from last lookup
    final distFromCache = _cachedCity != null
        ? _haversineDistance(_cachedLat, _cachedLon, lat, lon)
        : double.infinity;
    if (distFromCache < 2000 && _cachedCity != null) return _cachedCity;

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
          _cachedLat = lat;
          _cachedLon = lon;
          debugPrint('[MotoAI] City: $city');
        }
        return city;
      }
    } catch (e) {
      debugPrint('[MotoAI] Geocode error: $e');
    }
    return _cachedCity; // Return old cache on error
  }

  /// Approximate distance in meters (good enough for cache invalidation).
  static double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const m = 111320.0; // meters per degree latitude
    final dLat = (lat2 - lat1) * m;
    final dLon = (lon2 - lon1) * m * 0.65; // cos(~50°) for Germany
    return sqrt(dLat * dLat + dLon * dLon);
  }

  /// Parse Ollama's response text into structured AiResponse.
  AiResponse _parseOllamaResponse(String rawText) {
    try {
      // Try to extract JSON from the response (model might add extra text)
      final jsonMatch = RegExp(r'\{[\s\S]*"response"[\s\S]*\}').firstMatch(rawText);
      if (jsonMatch != null) {
        final parsed = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
        final responseText = parsed['response'] as String? ?? rawText.trim();

        AiAction? action;
        if (parsed['action'] != null) {
          final actionData = parsed['action'] as Map<String, dynamic>;
          final type = actionData['type'] as String? ?? 'none';
          if (type != 'none') {
            action = AiAction(
              type: type,
              params: actionData['params'] as Map<String, dynamic>? ?? {},
            );
            debugPrint('[MotoAI] Action: ${action.type} ${action.params}');
          }
        }

        return AiResponse(response: responseText, action: action);
      }
    } catch (e) {
      debugPrint('[MotoAI] JSON parse error: $e');
    }

    // Fallback: use raw text as response (strip any JSON artifacts)
    final cleanText = rawText
        .replaceAll(RegExp(r'```json?'), '')
        .replaceAll(RegExp(r'```'), '')
        .trim();
    return AiResponse(response: cleanText.isNotEmpty ? cleanText : 'Keine Antwort erhalten.');
  }
}

/// AI response with spoken text and optional action.
class AiResponse {
  final String response;
  final AiAction? action;

  const AiResponse({required this.response, this.action});
}

/// Structured action the AI wants to execute.
class AiAction {
  final String type; // 'searchPoi', 'navigate', 'reportBlitzer', etc.
  final Map<String, dynamic> params;

  const AiAction({required this.type, this.params = const {}});
}
