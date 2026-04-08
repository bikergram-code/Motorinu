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

  /// Report police (e.g., "Polizei melden", "Polizeikontrolle")
  reportPolice,

  /// Report hazard/construction (e.g., "Gefahr melden", "Baustelle")
  reportHazard,

  /// Report traffic jam (e.g., "Stau melden")
  reportTraffic,

  /// Show nearest blitzers (e.g., "Blitzer", "Radar", "wo sind Blitzer")
  showBlitzer,

  /// End ride / leave group (e.g., "Fahrt beenden", "Aussteigen")
  endRide,

  /// Activate SOS (e.g., "SOS", "Hilfe", "Notfall")
  activateSos,

  /// Navigation stop (e.g., "Navigation stoppen", "Route abbrechen")
  stopNavigation,

  /// Navigate to address/destination (e.g., "navigiere zur Ahrstraße in Solingen")
  navigateTo,

  /// Announce current route status (e.g., "Route ansagen", "Wie weit noch?")
  announceRoute,

  /// Switch tab (e.g., "Feed", "Karte", "Garage", "Profil")
  switchTab,

  /// Search for Racer Events (e.g., "was geht ab?", "was machen wir heute?")
  searchEvents,

  /// Thank Moto (e.g., "Danke Moto", "Danke")
  thankMoto,

  /// Ask weather (e.g., "Wetter", "Wie ist das Wetter?")
  askWeather,

  /// Ask current speed (e.g., "Wie schnell?", "Geschwindigkeit")
  askSpeed,

  /// Ask current location (e.g., "Wo bin ich?")
  askLocation,

  /// Confirm yes (for follow-up questions like "Soll ich navigieren?")
  confirmYes,

  /// Confirm no (for follow-up questions)
  confirmNo,

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

  /// For [reportBlitzer]: detected blitzer type ('mobile', 'fixed', 'police', 'construction').
  final String? blitzerType;

  const VoiceCommand({
    required this.intent,
    this.query,
    this.poiLabel,
    this.blitzerType,
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

    // ── Yes/No confirmations (for follow-up questions) ──
    if (_matchesAny(lower, _confirmYesKeywords)) {
      return const VoiceCommand(intent: VoiceIntent.confirmYes);
    }
    if (_matchesAny(lower, _confirmNoKeywords)) {
      return const VoiceCommand(intent: VoiceIntent.confirmNo);
    }

    // ── Thank Moto ──
    if (_matchesAny(lower, _thankKeywords)) {
      return const VoiceCommand(intent: VoiceIntent.thankMoto);
    }

    // ── Weather ──
    if (_matchesAny(lower, _weatherKeywords)) {
      return const VoiceCommand(intent: VoiceIntent.askWeather);
    }

    // ── Speed query ──
    if (_matchesAny(lower, _speedQueryKeywords)) {
      return const VoiceCommand(intent: VoiceIntent.askSpeed);
    }

    // ── Location query ──
    if (_matchesAny(lower, _locationQueryKeywords)) {
      return const VoiceCommand(intent: VoiceIntent.askLocation);
    }

    // ── Route status announcement ──
    if (_matchesAny(lower, _announceRouteKeywords)) {
      return const VoiceCommand(intent: VoiceIntent.announceRoute);
    }

    // ── Tab switching ──
    final tabRoute = _matchTab(lower);
    if (tabRoute != null) return tabRoute;

    // ── Police report (separate from blitzer) ──
    // Regex fallback: "poli*" catches Vosk variants (polizist, polizai, etc.)
    if (_matchesAny(lower, _policeReportKeywords) || RegExp(r'\bpoli').hasMatch(lower)) {
      return const VoiceCommand(intent: VoiceIntent.reportPolice);
    }

    // ── Hazard / construction report ──
    // Also catch "bau*" variants via regex (Vosk misrecognitions)
    if (_matchesAny(lower, _hazardReportKeywords) || RegExp(r'\bbau').hasMatch(lower)) {
      final isConstruction = lower.contains('bau') || lower.contains('mautstelle') || lower.contains('schraubwelle');
      return VoiceCommand(
        intent: VoiceIntent.reportHazard,
        blitzerType: isConstruction ? 'construction' : 'hazard',
      );
    }

    // ── Traffic jam report ──
    // Regex: "stau" catches all variants (stau, stauen, gestaut, etc.)
    if (_matchesAny(lower, _trafficReportKeywords) || RegExp(r'\bstau').hasMatch(lower)) {
      return const VoiceCommand(intent: VoiceIntent.reportTraffic);
    }

    // ── Blitzer melden (mobile or fixed) ──
    // Regex: "blitz" catches blitzer, blitzen, geblitzt, etc.
    if (_matchesAny(lower, _blitzerReportKeywords) || RegExp(r'\bblitz').hasMatch(lower)) {
      String blitzerType = 'mobile'; // Default: most common
      if (lower.contains('fest') || lower.contains('stationär') || lower.contains('fix')) {
        blitzerType = 'fixed';
      }
      return VoiceCommand(intent: VoiceIntent.reportBlitzer, blitzerType: blitzerType);
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

    // ── Navigate to address/destination ──
    final navTo = _matchNavigateTo(lower, text);
    if (navTo != null) return navTo;

    // ── POI search (only: Tankstelle, Werkstatt, Shop) ──
    final poi = _matchPoi(lower);
    if (poi != null) return poi;

    // ── Racer Events ("was geht ab?", "was machen wir heute?") ──
    if (_matchesAny(lower, _eventKeywords)) {
      return const VoiceCommand(intent: VoiceIntent.searchEvents);
    }

    // ── Fallback nav detection: text contains street/address patterns ──
    // Catches cases where Vosk misses "navigiere" but recognizes the address
    // e.g. "ahrstraße 1 in solingen" or "hauptstraße solingen"
    final navFallback = _matchAddressPattern(lower, text);
    if (navFallback != null) return navFallback;

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

  // ── Blitzer report (only mobile + fixed, no police/hazard) ──
  static const _blitzerReportKeywords = [
    'blitzer melden', 'radar melden',
    'melde blitzer', 'melde radar',
    'blitzer gefunden', 'fester blitzer',
    'mobiler blitzer', 'radarfalle melden',
  ];

  // ── Police report (separate intent) ──
  static const _policeReportKeywords = [
    'polizei', 'polizei melden', 'melde polizei',
    'polizeikontrolle melden', 'kontrolle melden',
    'melde kontrolle', 'polizeikontrolle',
    'polizei gesehen', 'polizei voraus',
    'bullen', 'cops', 'streife',
  ];

  // ── Hazard / construction report ──
  static const _hazardReportKeywords = [
    'gefahr melden', 'melde gefahr', 'gefahr',
    'baustelle melden', 'melde baustelle', 'baustelle',
    'mautstelle', 'schraubwelle', 'bau stelle', 'baustele',
    'baustellle', 'bau stele', 'maustelle',
    'unfall melden', 'melde unfall', 'unfall',
    'gefahrenstelle', 'vorsicht gefahr',
    'hindernis', 'ölspur', 'schlagloch',
    'straßenschaden', 'strassenschaden',
  ];

  // ── Traffic jam report ──
  static const _trafficReportKeywords = [
    'stau melden', 'melde stau',
    'stau', 'verkehr', 'stockender verkehr',
    'stau voraus', 'stau gemeldet',
    'zähfließender verkehr',
  ];

  // ── Confirm yes/no (for follow-up questions) ──
  // Vosk often mishears short words — include all common variants
  static const _confirmYesKeywords = [
    'ja', 'jawohl', 'klar', 'ok',
    'okay', 'genau', 'stimmt', 'richtig',
    'mach das', 'bitte', 'gerne',
    'ja bitte', 'ja gerne', 'los',
    'jah', 'jo', 'jep', 'jepp', 'yep',
    'na klar', 'sicher', 'auf jeden',
    'dorthin', 'dahin', 'fahr',
  ];
  static const _confirmNoKeywords = [
    'nein', 'nee', 'nicht', 'stop',
    'falsch', 'weg', 'abbrechen',
    'nein danke', 'lass mal', 'vergiss es',
    'ne', 'nö', 'nix', 'niemals',
    'lieber nicht', 'kein', 'keine',
    'lass', 'stopp', 'halt',
  ];

  // ── Thank Moto ──
  static const _thankKeywords = [
    'danke', 'danke moto', 'danke schön',
    'vielen dank', 'merci', 'top', 'super',
    'gut gemacht', 'perfekt', 'nice',
  ];

  // ── Weather ──
  static const _weatherKeywords = [
    'wetter', 'wie ist das wetter',
    'regnet es', 'wird es regnen',
    'temperatur', 'wie warm',
  ];

  // ── Speed query ──
  static const _speedQueryKeywords = [
    'wie schnell', 'geschwindigkeit',
    'tempo', 'wie schnell bin ich',
    'speed', 'kmh',
  ];

  // ── Location query ──
  static const _locationQueryKeywords = [
    'wo bin ich', 'wo sind wir',
    'welche straße', 'welche stadt',
    'standort', 'position',
  ];

  // ── Route announcement ──
  static const _announceRouteKeywords = [
    'route ansagen', 'wie weit noch',
    'wann sind wir da', 'restzeit',
    'wie weit', 'noch wie weit',
    'route status', 'navigation ansagen',
    'nächste abfahrt', 'nächste abbiegung',
  ];

  // ── Tab switching (avoid collision with nav commands) ──
  static const _tabMap = <String, String>{
    'feed': '/feed', 'home': '/feed', 'startseite': '/feed',
    'karte': '/map', 'map': '/map',
    'garage': '/garage', 'marktplatz': '/garage',
    'profil': '/profile', 'profile': '/profile',
  };

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

  static const _eventKeywords = [
    'was machen wir', 'was geht ab', 'was geht',
    'was ist los', 'was steht an', 'events',
    'veranstaltung', 'trackday', 'track day',
    'was machen wir heute', 'was gibt es',
    'racer event', 'biker event', 'motorrad event',
    'biker treffen', 'motorrad treffen',
    'auto treffen', 'car meet', 'tuning treffen',
    'was los', 'was läuft', 'was passiert',
    'rennen', 'rennstrecke', 'treffen',
  ];

  /// Navigation trigger keywords — extract destination after these.
  static const _navigateKeywords = [
    'navigiere zur', 'navigiere zum', 'navigiere nach',
    'navigier zur', 'navigier zum', 'navigier nach',
    'navigation zur', 'navigation zum', 'navigation nach',
    'navi zur', 'navi zum', 'navi nach',
    'route zur', 'route zum', 'route nach',
    'fahre zur', 'fahre zum', 'fahre nach',
    'fahr zur', 'fahr zum', 'fahr nach',
    'bring mich zur', 'bring mich zum', 'bring mich nach',
    'führe mich zur', 'führe mich zum', 'führe mich nach',
  ];

  /// POI categories recognized via voice (keyword fast-path, no AI needed):
  static const _poiMap = <List<String>, (String, String)>{
    // Tankstelle — Vosk variants: "tank", "tanke", "tank stellen", "den ken", "tan ke"
    ['tanke', 'tankstelle', 'tankstellen', 'benzin', 'sprit', 'tanken', 'zapfsäule',
     'tank stellen', 'tank stelle', 'den ken', 'tan ke', 'tange', 'aral', 'shell',
     'total', 'esso', 'jet', 'volltanken', 'nachtanken', 'auftanken', 'diesel',
     'super', 'benziner', 'kraftstoff', 'zapfen', 'tankene', 'stelle',
     'sofort tankstelle', 'sofort tanken', 'tanken sofort', 'ich muss tanken',
     'wo kann ich tanken', 'nächste tankstelle', 'nächste tanke', 'brauche sprit',
     'brauche benzin', 'brauche diesel', 'tank leer', 'benzin leer']:
        ('Tankstelle', 'Tankstelle'),
    // Werkstatt
    ['werkstatt', 'reparatur', 'motorrad werkstatt', 'pannenhilfe', 'reifendienst',
     'werkstadt', 'panne', 'abschleppdienst', 'reifenpanne', 'motorschaden']:
        ('Motorrad Werkstatt', 'Werkstatt'),
    // Shop
    ['shop', 'laden', 'einkaufen', 'supermarkt', 'kiosk', 'markt', 'edeka',
     'rewe', 'lidl', 'aldi', 'netto', 'penny', 'kaufland']:
        ('Supermarkt', 'Shop'),
    // Restaurant — Vosk variants: "essen", "hunger", "was essen"
    ['restaurant', 'essen', 'hunger', 'hungrig', 'gaststätte', 'imbiss', 'döner',
     'pizza', 'burger', 'sushi', 'chinese', 'italiener', 'grieche', 'türke',
     'mcdonalds', 'mc donalds', 'was essen', 'essen gehen', 'mittagessen',
     'abendessen', 'kebab', 'currywurst', 'pommes', 'schnitzel', 'steak']:
        ('Restaurant', 'Restaurant'),
    // Bar
    ['bar', 'kneipe', 'pub', 'biergarten', 'trinken', 'bier', 'cocktail',
     'shots', 'ausgehen', 'feiern', 'club', 'disko', 'disco', 'lounge',
     'was trinken', 'einen trinken', 'alkohol', 'wein']:
        ('Bar', 'Bar'),
    // Café
    ['café', 'cafe', 'kaffee', 'coffee', 'cappuccino', 'espresso', 'latte',
     'starbucks', 'kaffeepause', 'kaffeetrinken', 'eiskaffee', 'kakao']:
        ('Café', 'Café'),
    // Biker Shop
    ['biker shop', 'motorrad shop', 'helm', 'motorradbekleidung', 'louis',
     'polo motorrad', 'hein gericke', 'motorradhelm', 'motorrad laden',
     'biker laden', 'motorrad zubehör']:
        ('Biker Shop', 'Biker Shop'),
    // Auto Shop
    ['auto shop', 'autozubehör', 'autoteile', 'atu', 'auto teile', 'forstinger',
     'auto laden', 'kfz teile', 'kfz zubehör']:
        ('Auto Shop', 'Auto Shop'),
    // Bank / Geldautomat
    ['bank', 'geldautomat', 'atm', 'geld abheben', 'sparkasse', 'volksbank',
     'commerzbank', 'deutsche bank', 'postbank', 'bargeld', 'geld holen',
     'bankautomat', 'ec automat', 'geld ziehen']:
        ('Bank', 'Bank'),
  };

  // ─────────────────────────────────────────────────
  //  HELPERS
  // ─────────────────────────────────────────────────

  static bool _matchesAny(String lower, List<String> keywords) {
    return keywords.any((kw) => lower.contains(kw));
  }

  /// Match tab switching keywords and return route.
  static VoiceCommand? _matchTab(String lower) {
    final words = lower.split(RegExp(r'\s+'));
    for (final word in words) {
      final route = _tabMap[word];
      if (route != null) {
        return VoiceCommand(intent: VoiceIntent.switchTab, query: route);
      }
    }
    return null;
  }

  /// Match POI keywords and return a VoiceCommand, or null.
  static VoiceCommand? _matchPoi(String lower) {
    // Fuzzy: Vosk often splits "Tankstelle" → "tank stellen" or "stellen"
    // Check for "tank" prefix first (catches tank, tanke, tankstelle, tank stellen)
    if (RegExp(r'\btank').hasMatch(lower)) {
      return const VoiceCommand(intent: VoiceIntent.searchPoi, query: 'Tankstelle', poiLabel: 'Tankstelle');
    }

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

  /// Match "navigiere zur/zum/nach [destination]" and extract destination.
  /// Uses regex to catch all verb forms: navigiere, navigieren, navigier, etc.
  static VoiceCommand? _matchNavigateTo(String lower, String originalText) {
    // Track if we found a nav keyword at all (even without valid destination)
    bool foundNavKeyword = false;

    // 1. Exact keyword match first
    for (final keyword in _navigateKeywords) {
      final idx = lower.indexOf(keyword);
      if (idx >= 0) {
        foundNavKeyword = true;
        final dest = originalText.substring(idx + keyword.length).trim();
        if (dest.length >= 3) {
          return VoiceCommand(intent: VoiceIntent.navigateTo, query: dest);
        }
      }
    }

    // 2. Regex fallback: any form of navigier* + preposition + destination
    final navRegex = RegExp(
      r'navigier\w*\s+(zur?|zum|nach|in|an|auf)\s+(.+)',
      caseSensitive: false,
    );
    final navMatch = navRegex.firstMatch(lower);
    if (navMatch != null) {
      foundNavKeyword = true;
      final dest = navMatch.group(2)!.trim();
      if (dest.length >= 3) {
        return VoiceCommand(intent: VoiceIntent.navigateTo, query: dest);
      }
    }

    // 2b. Just "navigiere/navigier/navi" without preposition — still a nav intent
    if (!foundNavKeyword && RegExp(r'\b(navigier\w*|navi)\b', caseSensitive: false).hasMatch(lower)) {
      foundNavKeyword = true;
    }

    // 3. "fahr/fahre/fahren + preposition + destination"
    final fahrRegex = RegExp(
      r'fahr\w*\s+(zur?|zum|nach|in|an|auf)\s+(.+)',
      caseSensitive: false,
    );
    final fahrMatch = fahrRegex.firstMatch(lower);
    if (fahrMatch != null) {
      foundNavKeyword = true;
      final dest = fahrMatch.group(2)!.trim();
      if (dest.length >= 3) {
        return VoiceCommand(intent: VoiceIntent.navigateTo, query: dest);
      }
    }

    // 4. "route/navi + preposition + destination"
    final routeRegex = RegExp(
      r'(?:route|navi|navigation)\s+(zur?|zum|nach|in|an|auf)\s+(.+)',
      caseSensitive: false,
    );
    final routeMatch = routeRegex.firstMatch(lower);
    if (routeMatch != null) {
      foundNavKeyword = true;
      final dest = routeMatch.group(2)!.trim();
      if (dest.length >= 3) {
        return VoiceCommand(intent: VoiceIntent.navigateTo, query: dest);
      }
    }

    // 5. "bring/führ mich + preposition + destination"
    final bringRegex = RegExp(
      r'(?:bring|führ)\w*\s+mich\s+(zur?|zum|nach|in|an|auf)\s+(.+)',
      caseSensitive: false,
    );
    final bringMatch = bringRegex.firstMatch(lower);
    if (bringMatch != null) {
      foundNavKeyword = true;
      final dest = bringMatch.group(2)!.trim();
      if (dest.length >= 3) {
        return VoiceCommand(intent: VoiceIntent.navigateTo, query: dest);
      }
    }

    // Nav keyword found but no valid destination → return empty navigateTo
    // so the handler can ask "Wohin?"
    if (foundNavKeyword) {
      return const VoiceCommand(intent: VoiceIntent.navigateTo, query: '');
    }

    return null;
  }

  /// Check if text contains a "moto" trigger word.
  /// Matches: "moto", "motto", "motor" at word boundary.
  static bool _containsMotoTrigger(String lower) {
    return RegExp(r'\bmoto\b|\bmotto\b|\bmotor\b').hasMatch(lower);
  }

  /// Fallback: detect address patterns without navigation keywords.
  /// Catches "ahrstraße in solingen", "hauptstraße solingen",
  /// "ahrstraße 1 solingen", etc.
  /// User doesn't need to say "navigiere zur" — just the address is enough.
  static VoiceCommand? _matchAddressPattern(String lower, String originalText) {
    // Must contain a street-type suffix
    final streetMatch = RegExp(
      r'(\w*(?:straße|strasse|str)\b|\w*(?:weg|platz|allee|gasse|ring|damm|ufer|chaussee)\b)',
    ).hasMatch(lower);
    if (!streetMatch) return null;

    // Strip moto prefix and clean up
    final dest = _stripMotoPrefix(originalText);
    if (dest.length < 5) return null;

    // Any of these make it a clear address → navigate:
    // 1. "in [city]" (e.g., "ahrstraße in solingen")
    // 2. House number (e.g., "ahrstraße 1")
    // 3. A second word after the street name (e.g., "ahrstraße solingen")
    //    — at least 2 words total means street + city/context
    final hasCity = RegExp(r'\bin\s+\w{3,}').hasMatch(lower);
    final hasNumber = RegExp(r'\d').hasMatch(lower);
    final wordCount = dest.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

    if (hasCity || hasNumber || wordCount >= 2) {
      return VoiceCommand(intent: VoiceIntent.navigateTo, query: dest);
    }
    return null;
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
