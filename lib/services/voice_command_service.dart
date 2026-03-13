/// Voice command intent parser for German speech commands.
///
/// Stateless utility — parses spoken text into structured intents.
/// Used by GroupRideScreen to dispatch voice commands to the correct handler.
library;

// ═══════════════════════════════════════════════════
//  VOICE INTENT MODEL
// ═══════════════════════════════════════════════════

enum VoiceIntent {
  /// POI / destination search (e.g., "Tankstelle", "Werkstatt")
  searchPoi,

  /// Toggle camera on/off (e.g., "Kamera an", "Video aus")
  toggleCamera,

  /// Toggle microphone mute (e.g., "Mikrofon stumm", "Mute")
  toggleMic,

  /// Report a blitzer (e.g., "Blitzer melden", "Radar melden")
  reportBlitzer,

  /// Show nearest blitzers (e.g., "Blitzer", "Radar", "wo sind Blitzer")
  showBlitzer,

  /// End ride / leave group (e.g., "Fahrt beenden", "Aussteigen")
  endRide,

  /// Activate SOS (e.g., "SOS", "Hilfe", "Notfall")
  activateSos,

  /// Navigation stop (e.g., "Navigation stoppen", "Route abbrechen")
  stopNavigation,

  /// AI query — send to Moto KI assistant for natural language understanding
  aiQuery,

  /// Unknown / not recognized (too short or noise)
  unknown,
}

class VoiceCommand {
  final VoiceIntent intent;

  /// For [searchPoi]: the search query or POI label.
  /// For other intents: null.
  final String? query;

  /// Human-readable label for the POI type (e.g., "Tankstelle").
  final String? poiLabel;

  const VoiceCommand({
    required this.intent,
    this.query,
    this.poiLabel,
  });
}

// ═══════════════════════════════════════════════════
//  PARSER
// ═══════════════════════════════════════════════════

class VoiceCommandService {
  VoiceCommandService._();

  /// Parse spoken German text into a structured [VoiceCommand].
  ///
  /// Only recognizes: Tankstelle, Blitzer, Werkstatt, Shop + action commands.
  /// Everything else → unknown (no random searches).
  static VoiceCommand parse(String text) {
    final lower = text.toLowerCase().trim();

    // ── Camera commands ──
    if (_matchesAny(lower, _cameraKeywords)) {
      return const VoiceCommand(intent: VoiceIntent.toggleCamera);
    }

    // ── Mic commands ──
    if (_matchesAny(lower, _micKeywords)) {
      return const VoiceCommand(intent: VoiceIntent.toggleMic);
    }

    // ── Blitzer melden (explicit "melden" keyword) ──
    if (_matchesAny(lower, _blitzerReportKeywords)) {
      return const VoiceCommand(intent: VoiceIntent.reportBlitzer);
    }

    // ── Blitzer anzeigen / abfragen (just "Blitzer" or "Radar") ──
    if (_matchesAny(lower, _blitzerShowKeywords)) {
      return const VoiceCommand(intent: VoiceIntent.showBlitzer);
    }

    // ── End ride ──
    if (_matchesAny(lower, _endRideKeywords)) {
      return const VoiceCommand(intent: VoiceIntent.endRide);
    }

    // ── SOS ──
    if (_matchesAny(lower, _sosKeywords)) {
      return const VoiceCommand(intent: VoiceIntent.activateSos);
    }

    // ── Stop navigation ──
    if (_matchesAny(lower, _stopNavKeywords)) {
      return const VoiceCommand(intent: VoiceIntent.stopNavigation);
    }

    // ── POI search (only: Tankstelle, Werkstatt, Shop) ──
    final poi = _matchPoi(lower);
    if (poi != null) return poi;

    // ── AI query: user already said "Hi Moto" (wake word), so anything
    //    that's not a keyword command goes to the KI assistant.
    //    Strip "moto/motto/motor" if present, then send if long enough. ──
    final cleanQuery = _stripMotoPrefix(text);
    if (cleanQuery.length >= 3) {
      return VoiceCommand(intent: VoiceIntent.aiQuery, query: cleanQuery);
    }

    // ── Too short / noise: ignore ──
    return const VoiceCommand(intent: VoiceIntent.unknown);
  }

  // ─────────────────────────────────────────────────
  //  KEYWORD TABLES
  // ─────────────────────────────────────────────────

  static const _cameraKeywords = [
    'kamera an', 'kamera aus',
    'kamera ein', 'kamera off',
    'video an', 'video aus',
    'video ein', 'video off',
    'dashcam', 'aufnahme',
  ];

  static const _micKeywords = [
    'mikrofon stumm', 'mikrofon an', 'mikrofon aus',
    'mikro stumm', 'mikro an', 'mikro aus',
    'mute', 'unmute', 'stumm',
    'mic an', 'mic aus',
  ];

  // "Melden" keywords → reportBlitzer (user reports a new blitzer)
  static const _blitzerReportKeywords = [
    'blitzer melden', 'radar melden',
    'polizei melden', 'melde blitzer',
    'melde radar', 'blitzer gefunden',
  ];

  // Just "Blitzer" / "Radar" → showBlitzer (show nearest 3)
  static const _blitzerShowKeywords = [
    'blitzer', 'radar', 'radarfalle',
    'blitzer warnung', 'wo sind blitzer',
    'wo ist blitzer', 'blitzer in der nähe',
  ];

  static const _endRideKeywords = [
    'fahrt beenden', 'fahrt stoppen',
    'aussteigen', 'ride beenden',
    'fahrt ende', 'stop ride',
    'aufhören', 'raus hier',
  ];

  static const _sosKeywords = [
    'sos', 'hilfe', 'notfall', 'notruf',
    'unfall', 'crash', 'sturz',
    'hilfe rufen', 'notfall melden',
  ];

  static const _stopNavKeywords = [
    'navigation stoppen', 'navigation beenden',
    'navigation aus', 'navi stoppen',
    'navi aus', 'navi beenden',
    'route abbrechen', 'route stoppen',
    'route beenden', 'stopp navigation',
  ];

  /// POI categories recognized via voice (keyword fast-path, no AI needed):
  static const _poiMap = <List<String>, (String, String)>{
    ['tanke', 'tankstelle', 'benzin', 'sprit', 'tanken']:
        ('Tankstelle', 'Tankstelle'),
    ['werkstatt', 'reparatur', 'motorrad werkstatt', 'pannenhilfe']:
        ('Motorrad Werkstatt', 'Werkstatt'),
    ['shop', 'laden', 'einkaufen', 'supermarkt', 'kiosk', 'markt']:
        ('Supermarkt', 'Shop'),
    ['restaurant', 'essen', 'hunger', 'hungrig', 'gaststätte', 'imbiss', 'döner', 'pizza', 'burger']:
        ('Restaurant', 'Restaurant'),
  };

  // ─────────────────────────────────────────────────
  //  HELPERS
  // ─────────────────────────────────────────────────

  static bool _matchesAny(String lower, List<String> keywords) {
    return keywords.any((kw) => lower.contains(kw));
  }

  /// Match POI keywords and return a VoiceCommand, or null.
  static VoiceCommand? _matchPoi(String lower) {
    for (final entry in _poiMap.entries) {
      final keywords = entry.key;
      final (query, label) = entry.value;
      if (keywords.any((kw) => lower.contains(kw))) {
        return VoiceCommand(
          intent: VoiceIntent.searchPoi,
          query: query,
          poiLabel: label,
        );
      }
    }
    return null;
  }

  /// Check if text contains a "moto" trigger word.
  /// Matches: "moto", "motto", "motor" at word boundary.
  static bool _containsMotoTrigger(String lower) {
    return RegExp(r'\bmoto\b|\bmotto\b|\bmotor\b').hasMatch(lower);
  }

  /// Remove "moto" prefix, TTS echo ("ja"), and common filler words from the query.
  /// "ja moto wird es regnen" → "wird es regnen"
  /// "ja wie wird das wetter" → "wie wird das wetter"
  /// "hey moto wie weit noch" → "wie weit noch"
  static String _stripMotoPrefix(String text) {
    return text
        .replaceAll(RegExp(r'\b(hey|hi|hallo)?\s*(moto|motto|motor)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'^ja\s+', caseSensitive: false), '') // Strip TTS echo "ja"
        .replaceAll(RegExp(r'^\s*[,!?.]\s*'), '') // Strip leading punctuation
        .trim();
  }
}
