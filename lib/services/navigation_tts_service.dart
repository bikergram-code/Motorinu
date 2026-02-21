import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'osrm_service.dart';

// ─── Navigation TTS Service ──────────────────────────────────────────────────
//
// Provides German voice announcements for turn-by-turn navigation.
// - 3 distance thresholds per step (500m, 200m, "Jetzt" <40m)
// - Deduplication: each threshold announced exactly once per step
// - 3-second cooldown between announcements
// - Special announcements: arrival, re-route, off-route
// - Multiple voice profiles: Standard, Pirat, Biker, Robot, Opa, Drill Sergeant
//
// Singleton pattern — shared across the app lifecycle.

/// Voice profile configuration.
class TtsVoiceProfile {
  final String id;
  final String name;
  final String icon;
  final String description;
  final double pitch;
  final double rate;
  final String Function(String baseText) transform;

  const TtsVoiceProfile({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    required this.pitch,
    required this.rate,
    required this.transform,
  });
}

/// All available voice profiles.
final Map<String, TtsVoiceProfile> ttsVoiceProfiles = {
  'standard': TtsVoiceProfile(
    id: 'standard',
    name: 'Standard',
    icon: 'record_voice_over',
    description: 'Klare Navigationsansage',
    pitch: 1.0,
    rate: 0.5,
    transform: (t) => t,
  ),
  'pirat': TtsVoiceProfile(
    id: 'pirat',
    name: 'Pirat',
    icon: 'sailing',
    description: 'Arrr! Auf zur Schatzsuche!',
    pitch: 0.8,
    rate: 0.45,
    transform: _piratTransform,
  ),
  'biker': TtsVoiceProfile(
    id: 'biker',
    name: 'Biker',
    icon: 'two_wheeler',
    description: 'Ride on, Bruder!',
    pitch: 0.7,
    rate: 0.5,
    transform: _bikerTransform,
  ),
  'robot': TtsVoiceProfile(
    id: 'robot',
    name: 'Roboter',
    icon: 'smart_toy',
    description: 'Beep boop. Ziel berechnet.',
    pitch: 0.3,
    rate: 0.55,
    transform: _robotTransform,
  ),
  'opa': TtsVoiceProfile(
    id: 'opa',
    name: 'Opa',
    icon: 'elderly',
    description: 'Immer langsam, mein Junge!',
    pitch: 0.85,
    rate: 0.4,
    transform: _opaTransform,
  ),
  'drill': TtsVoiceProfile(
    id: 'drill',
    name: 'Feldwebel',
    icon: 'military_tech',
    description: 'LINKS! RECHTS! VORWÄRTS!',
    pitch: 0.6,
    rate: 0.6,
    transform: _drillTransform,
  ),
};

// ─── Voice Transforms ────────────────────────────────────────────────────────

String _piratTransform(String text) {
  return text
      .replaceAll('links abbiegen', 'nach Backbord drehen, Arrr')
      .replaceAll('rechts abbiegen', 'nach Steuerbord drehen, Arrr')
      .replaceAll('leicht links abbiegen', 'leicht nach Backbord, Matrose')
      .replaceAll('leicht rechts abbiegen', 'leicht nach Steuerbord, Matrose')
      .replaceAll('scharf links abbiegen', 'hart Backbord! Festhalten!')
      .replaceAll('scharf rechts abbiegen', 'hart Steuerbord! Festhalten!')
      .replaceAll('wenden', 'Klar zum Wenden! Umkehren!')
      .replaceAll('geradeaus weiterfahren', 'Kurs halten, geradeaus segeln')
      .replaceAll('einfädeln', 'in die Flotte einfädeln')
      .replaceAll('links halten', 'Backbord halten, Seemann')
      .replaceAll('rechts halten', 'Steuerbord halten, Seemann')
      .replaceAll('die Abfahrt links nehmen', 'Abfahrt Backbord nehmen, hoho')
      .replaceAll('die Abfahrt rechts nehmen', 'Abfahrt Steuerbord nehmen, hoho')
      .replaceAll('in den Kreisverkehr fahren', 'in den Strudel reinfahren, Arrr')
      .replaceAll('Ziel erreicht. Navigation beendet.', 'Land in Sicht! Wir haben den Schatz gefunden! Arrr!')
      .replaceAll('Route wird neu berechnet.', 'Oje, die Seekarte stimmt nicht! Neuen Kurs berechnen!')
      .replaceAll('Sie haben die Route verlassen.', 'Blitz und Donner! Wir sind vom Kurs abgekommen!')
      .replaceAll('In 500 Metern', 'In 500 Schritt')
      .replaceAll('In 200 Metern', 'In 200 Schritt');
}

String _bikerTransform(String text) {
  return text
      .replaceAll('links abbiegen', 'links rüber, Bruder')
      .replaceAll('rechts abbiegen', 'rechts rüber, Bruder')
      .replaceAll('leicht links abbiegen', 'easy links, Bro')
      .replaceAll('leicht rechts abbiegen', 'easy rechts, Bro')
      .replaceAll('scharf links abbiegen', 'Vollgas links reinlegen!')
      .replaceAll('scharf rechts abbiegen', 'Vollgas rechts reinlegen!')
      .replaceAll('wenden', 'Umdrehen und zurück donnern!')
      .replaceAll('geradeaus weiterfahren', 'Gerade durch, Gas geben!')
      .replaceAll('einfädeln', 'cool einfädeln')
      .replaceAll('links halten', 'links halten, Ride on')
      .replaceAll('rechts halten', 'rechts halten, Ride on')
      .replaceAll('in den Kreisverkehr fahren', 'ab in den Kreisverkehr, easy')
      .replaceAll('Ziel erreicht. Navigation beendet.', 'Yeah Bruder! Angekommen! Ride on!')
      .replaceAll('Route wird neu berechnet.', 'Eh, falscher Weg. Neue Route, Bro!')
      .replaceAll('Sie haben die Route verlassen.', 'Hey Bro, du bist vom Weg ab!');
}

String _robotTransform(String text) {
  return text
      .replaceAll('links abbiegen', 'Richtungsänderung, 90 Grad links, initiiert')
      .replaceAll('rechts abbiegen', 'Richtungsänderung, 90 Grad rechts, initiiert')
      .replaceAll('leicht links abbiegen', 'Kurskorrektur, 30 Grad links')
      .replaceAll('leicht rechts abbiegen', 'Kurskorrektur, 30 Grad rechts')
      .replaceAll('scharf links abbiegen', 'Warnung. Scharfe Kurve links. 120 Grad.')
      .replaceAll('scharf rechts abbiegen', 'Warnung. Scharfe Kurve rechts. 120 Grad.')
      .replaceAll('wenden', 'U-Turn. 180 Grad Drehung einleiten.')
      .replaceAll('geradeaus weiterfahren', 'Kurs beibehalten. Geradeaus.')
      .replaceAll('einfädeln', 'Einfädelprotokoll aktiviert.')
      .replaceAll('in den Kreisverkehr fahren', 'Kreisverkehr detektiert. Einfahrt.')
      .replaceAll('Ziel erreicht. Navigation beendet.', 'Zielkoordinaten erreicht. Mission abgeschlossen. Beep boop.')
      .replaceAll('Route wird neu berechnet.', 'Fehler. Neuberechnung läuft. Bitte warten.')
      .replaceAll('Sie haben die Route verlassen.', 'Achtung. Routenabweichung festgestellt.')
      .replaceAll('In 500 Metern', 'In 500 Metern')
      .replaceAll('In 200 Metern', 'In 200 Metern')
      .replaceAll('Jetzt', 'Jetzt. Ausführen.');
}

String _opaTransform(String text) {
  return text
      .replaceAll('links abbiegen', 'links abbiegen, mein Junge, schön langsam')
      .replaceAll('rechts abbiegen', 'rechts abbiegen, ganz vorsichtig')
      .replaceAll('leicht links abbiegen', 'ein bisschen nach links, nicht so hastig')
      .replaceAll('leicht rechts abbiegen', 'ein bisschen nach rechts, immer schön mit der Ruhe')
      .replaceAll('scharf links abbiegen', 'Achtung, scharf links! Nicht so schnell, Jungchen!')
      .replaceAll('scharf rechts abbiegen', 'Achtung, scharf rechts! Immer langsam!')
      .replaceAll('wenden', 'Och, umdrehen? Na dann mal zurück')
      .replaceAll('geradeaus weiterfahren', 'einfach geradeaus, ist doch nicht schwer')
      .replaceAll('in den Kreisverkehr fahren', 'in den Kreisverkehr, aber nicht schwindelig werden')
      .replaceAll('Ziel erreicht. Navigation beendet.', 'So, da wären wir! Endlich angekommen, mein Junge!')
      .replaceAll('Route wird neu berechnet.', 'Oje, verfahren! Zu meiner Zeit hatten wir noch Landkarten!')
      .replaceAll('Sie haben die Route verlassen.', 'Na sowas, das war wohl der falsche Weg');
}

String _drillTransform(String text) {
  return text
      .replaceAll('links abbiegen', 'LINKS ABBIEGEN! BEWEGEN!')
      .replaceAll('rechts abbiegen', 'RECHTS ABBIEGEN! SOFORT!')
      .replaceAll('leicht links abbiegen', 'LEICHT LINKS! ZACKIG!')
      .replaceAll('leicht rechts abbiegen', 'LEICHT RECHTS! TEMPO!')
      .replaceAll('scharf links abbiegen', 'SCHARF LINKS! ACHTUNG!')
      .replaceAll('scharf rechts abbiegen', 'SCHARF RECHTS! ACHTUNG!')
      .replaceAll('wenden', 'KEHRT! UMDREHEN! VORWÄRTS MARSCH!')
      .replaceAll('geradeaus weiterfahren', 'GERADEAUS! NICHT SCHLAFEN!')
      .replaceAll('einfädeln', 'EINFÄDELN! SCHNELL SCHNELL!')
      .replaceAll('links halten', 'LINKS HALTEN! DISZIPLIN!')
      .replaceAll('rechts halten', 'RECHTS HALTEN! DISZIPLIN!')
      .replaceAll('in den Kreisverkehr fahren', 'AB IN DEN KREISVERKEHR! LOS LOS!')
      .replaceAll('Ziel erreicht. Navigation beendet.', 'ZIEL ERREICHT! MISSION ERFÜLLT! WEGTRETEN!')
      .replaceAll('Route wird neu berechnet.', 'WIR HABEN UNS VERFAHREN! NEUER BEFEHL WIRD ERTEILT!')
      .replaceAll('Sie haben die Route verlassen.', 'SIE SIND VOM WEG ABGEKOMMEN! DAS IST INAKZEPTABEL!')
      .replaceAll('In 500 Metern', 'IN 500 METERN')
      .replaceAll('In 200 Metern', 'IN 200 METERN')
      .replaceAll('Jetzt', 'JETZT!');
}

// ─── Service ─────────────────────────────────────────────────────────────────

class NavigationTtsService {
  NavigationTtsService._();
  static final instance = NavigationTtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  bool _isSpeaking = false;
  String _currentVoice = 'standard';

  // ─── Deduplication ─────────────────────────────────────────────────
  // Tracks which (stepIndex, threshold) pairs have been announced.
  final Set<String> _announcedPairs = {};

  // Cooldown between announcements (3 seconds)
  DateTime? _lastAnnounceTime;
  static const _cooldown = Duration(seconds: 3);

  // ─── Distance Thresholds ───────────────────────────────────────────
  static const double _threshold500m = 500;
  static const double _threshold200m = 200;
  static const double _thresholdNow = 40;

  // ─── Init ──────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;

    // TTS-Engine und Sprache konfigurieren
    try {
      // Verfügbare Engines auflisten und Google TTS bevorzugen
      final engines = await _tts.getEngines;
      final engineList = (engines as List).map((e) => e.toString()).toList();
      debugPrint('[TTS] Verfügbare Engines: $engineList');

      // Google TTS bevorzugen (unterstützt Deutsch zuverlässig)
      final googleEngine = engineList.firstWhere(
        (e) => e.contains('google'),
        orElse: () => '',
      );
      if (googleEngine.isNotEmpty) {
        await _tts.setEngine(googleEngine);
        debugPrint('[TTS] Engine gesetzt: $googleEngine');
      } else {
        debugPrint('[TTS] Google TTS nicht gefunden, verwende Standard-Engine');
      }

      // Sprache auf Deutsch setzen
      final languages = await _tts.getLanguages;
      final available = (languages as List).map((e) => e.toString()).toList();
      debugPrint('[TTS] Verfügbare Sprachen: ${available.where((l) => l.toLowerCase().startsWith('de')).toList()}');

      bool langSet = false;
      for (final lang in ['de-DE', 'de_DE', 'de']) {
        final result = await _tts.setLanguage(lang);
        if (result == 1) {
          debugPrint('[TTS] Sprache gesetzt: $lang');
          langSet = true;
          break;
        }
      }
      if (!langSet) {
        debugPrint('[TTS] WARNUNG: Deutsch nicht verfügbar! Fallback en-US');
        await _tts.setLanguage('en-US');
      }
    } catch (e) {
      debugPrint('[TTS] Engine/Sprach-Setup fehlgeschlagen: $e');
      try { await _tts.setLanguage('de-DE'); } catch (_) {}
    }

    // Select the best female German voice available
    try {
      final voices = await _tts.getVoices;
      final voiceList = (voices as List).map((v) => Map<String, String>.from(
        (v as Map).map((k, val) => MapEntry(k.toString(), val.toString())),
      )).toList();

      // Filter German voices
      final deVoices = voiceList.where((v) {
        final locale = (v['locale'] ?? v['language'] ?? '').toLowerCase();
        return locale.startsWith('de');
      }).toList();

      debugPrint('[TTS] Deutsche Stimmen: ${deVoices.length}');
      for (final v in deVoices) {
        debugPrint('[TTS]   ${v['name']} (locale: ${v['locale']})');
      }

      // Prefer female voices: look for keywords like "female", "Frau", "woman"
      // Google TTS uses names like "de-de-x-deb-local" (female), "de-de-x-deg-local" (male)
      // Samsung uses "de-de-SMTf00" (f=female), "de-de-SMTm00" (m=male)
      Map<String, String>? bestVoice;
      for (final v in deVoices) {
        final name = (v['name'] ?? '').toLowerCase();
        // Google's German female voices often contain 'deb', 'ded', 'dee'
        // Samsung female voices contain 'f0'
        if (name.contains('deb') || name.contains('ded') || name.contains('dee') ||
            name.contains('female') || name.contains('f00') || name.contains('f01')) {
          bestVoice = v;
          break;
        }
      }

      // If no explicitly female voice, try high-quality voices (network/local)
      if (bestVoice == null && deVoices.isNotEmpty) {
        bestVoice = deVoices.firstWhere(
          (v) => (v['name'] ?? '').toLowerCase().contains('local'),
          orElse: () => deVoices.first,
        );
      }

      if (bestVoice != null) {
        await _tts.setVoice({'name': bestVoice['name']!, 'locale': bestVoice['locale'] ?? 'de-DE'});
        debugPrint('[TTS] Stimme gewählt: ${bestVoice['name']}');
      }
    } catch (e) {
      debugPrint('[TTS] Stimmenauswahl fehlgeschlagen: $e');
    }

    // Apply default voice profile
    await _applyVoiceProfile('standard');

    await _tts.setVolume(1.0);

    // Track speaking state
    _tts.setStartHandler(() {
      _isSpeaking = true;
      debugPrint('[TTS] Speaking started');
    });
    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      debugPrint('[TTS] Speaking completed');
    });
    _tts.setCancelHandler(() {
      _isSpeaking = false;
      debugPrint('[TTS] Speaking cancelled');
    });
    _tts.setErrorHandler((msg) {
      _isSpeaking = false;
      debugPrint('[TTS] Error: $msg');
    });

    _initialized = true;
    debugPrint('[TTS] Initialized successfully');

    // Quick self-test: speak nothing, just verify TTS engine is working
    try {
      final testResult = await _tts.speak('');
      debugPrint('[TTS] Self-test result: $testResult');
      await _tts.stop();
    } catch (e) {
      debugPrint('[TTS] Self-test failed: $e');
    }
  }

  // ─── Voice Profile ──────────────────────────────────────────────────

  /// Set the active voice profile.
  Future<void> setVoice(String voiceId) async {
    if (_currentVoice == voiceId) return;
    _currentVoice = voiceId;
    await _applyVoiceProfile(voiceId);
    debugPrint('[TTS] Voice set to: $voiceId');
  }

  String get currentVoice => _currentVoice;

  Future<void> _applyVoiceProfile(String voiceId) async {
    final profile = ttsVoiceProfiles[voiceId] ?? ttsVoiceProfiles['standard']!;
    await _tts.setPitch(profile.pitch);
    await _tts.setSpeechRate(profile.rate);
  }

  /// Transform text using the current voice profile.
  String _transformText(String text) {
    final profile = ttsVoiceProfiles[_currentVoice];
    if (profile == null) return text;
    return profile.transform(text);
  }

  /// Speak a sample text for voice preview.
  Future<void> speakSample(String voiceId) async {
    if (!_initialized) await init();

    final profile = ttsVoiceProfiles[voiceId] ?? ttsVoiceProfiles['standard']!;

    // Temporarily apply profile settings
    await _tts.setPitch(profile.pitch);
    await _tts.setSpeechRate(profile.rate);

    final sample = profile.transform('In 200 Metern links abbiegen');
    await _speak(sample);

    // Restore current profile after sample
    if (voiceId != _currentVoice) {
      // Delay slightly to let the sample finish
      Future.delayed(const Duration(seconds: 3), () {
        _applyVoiceProfile(_currentVoice);
      });
    }
  }

  // ─── Step Announcements ────────────────────────────────────────────

  /// Announce the current navigation step based on distance.
  void announceStep({
    required int stepIndex,
    required OsrmStep step,
    required double distanceToStep,
    required bool enabled,
  }) {
    if (!enabled || !_initialized) return;

    // Don't announce "depart" step — that's just the start
    if (step.maneuver == 'depart') return;

    // Don't announce "arrive" here — use announceArrival() instead
    if (step.maneuver == 'arrive') return;

    // Determine which threshold we're at
    String? threshold;
    String? distanceText;

    if (distanceToStep <= _thresholdNow) {
      threshold = 'now';
      distanceText = 'Jetzt';
    } else if (distanceToStep <= _threshold200m) {
      threshold = '200m';
      distanceText = 'In 200 Metern';
    } else if (distanceToStep <= _threshold500m) {
      threshold = '500m';
      distanceText = 'In 500 Metern';
    }

    if (threshold == null) return; // Not close enough yet

    // Deduplication: check if this (step, threshold) was already announced
    final key = '$stepIndex:$threshold';
    if (_announcedPairs.contains(key)) return;

    // Cooldown check
    final now = DateTime.now();
    if (_lastAnnounceTime != null &&
        now.difference(_lastAnnounceTime!) < _cooldown) {
      return;
    }

    // Mark as announced
    _announcedPairs.add(key);
    _lastAnnounceTime = now;

    // Build the announcement text
    final instruction = _buildTtsInstruction(step);
    final baseText = '$distanceText $instruction';
    final text = _transformText(baseText);

    _speak(text);
    debugPrint('[TTS] Step $stepIndex ($threshold): $text');
  }

  /// Announce arrival at destination.
  void announceArrival({required bool enabled}) {
    if (!enabled || !_initialized) return;

    // Cooldown check
    final now = DateTime.now();
    if (_lastAnnounceTime != null &&
        now.difference(_lastAnnounceTime!) < _cooldown) {
      return;
    }
    _lastAnnounceTime = now;

    final text = _transformText('Ziel erreicht. Navigation beendet.');
    _speak(text);
    debugPrint('[TTS] Arrival announced');
  }

  /// Announce re-route.
  void announceReRoute({required bool enabled}) {
    if (!enabled || !_initialized) return;

    final now = DateTime.now();
    if (_lastAnnounceTime != null &&
        now.difference(_lastAnnounceTime!) < _cooldown) {
      return;
    }
    _lastAnnounceTime = now;

    final text = _transformText('Route wird neu berechnet.');
    _speak(text);
    debugPrint('[TTS] Re-route announced');
  }

  /// Announce off-route warning.
  void announceOffRoute({required bool enabled}) {
    if (!enabled || !_initialized) return;

    final now = DateTime.now();
    if (_lastAnnounceTime != null &&
        now.difference(_lastAnnounceTime!) < _cooldown) {
      return;
    }
    _lastAnnounceTime = now;

    final text = _transformText('Sie haben die Route verlassen.');
    _speak(text);
    debugPrint('[TTS] Off-route announced');
  }

  // ─── Internal ──────────────────────────────────────────────────────

  /// Build a clean TTS-friendly instruction from OsrmStep.
  String _buildTtsInstruction(OsrmStep step) {
    // Use the maneuver type to build a natural German instruction
    final road = step.roadName;
    final roadStr = (road != null && road.isNotEmpty) ? ' auf $road' : '';

    return switch (step.maneuver) {
      'turn-left' => 'links abbiegen$roadStr',
      'turn-right' => 'rechts abbiegen$roadStr',
      'turn-slight-left' => 'leicht links abbiegen$roadStr',
      'turn-slight-right' => 'leicht rechts abbiegen$roadStr',
      'turn-sharp-left' => 'scharf links abbiegen$roadStr',
      'turn-sharp-right' => 'scharf rechts abbiegen$roadStr',
      'uturn' || 'turn-uturn' => 'wenden$roadStr',
      'merge-left' || 'merge-right' || 'merge' => 'einfädeln$roadStr',
      'fork-left' => 'links halten$roadStr',
      'fork-right' => 'rechts halten$roadStr',
      'ramp-left' || 'off-ramp-left' || 'on-ramp-left' =>
        'die Abfahrt links nehmen$roadStr',
      'ramp-right' || 'off-ramp-right' || 'on-ramp-right' =>
        'die Abfahrt rechts nehmen$roadStr',
      'roundabout' || 'rotary' => 'in den Kreisverkehr fahren$roadStr',
      'continue' || 'new-name' || 'straight' => 'geradeaus weiterfahren$roadStr',
      _ => 'weiterfahren$roadStr',
    };
  }

  /// Speak text, stopping any previous announcement.
  Future<void> _speak(String text) async {
    try {
      if (_isSpeaking) {
        await _tts.stop();
      }
      await _tts.speak(text);
    } catch (e) {
      debugPrint('[TTS] Speak error: $e');
    }
  }

  /// Stop current speech.
  Future<void> stop() async {
    try {
      await _tts.stop();
      _isSpeaking = false;
    } catch (e) {
      debugPrint('[TTS] Stop error: $e');
    }
  }

  /// Reset state (call when starting/stopping navigation).
  void reset() {
    _announcedPairs.clear();
    _lastAnnounceTime = null;
    stop();
    debugPrint('[TTS] Reset');
  }

  /// Dispose TTS engine.
  void dispose() {
    _tts.stop();
    _initialized = false;
  }
}
