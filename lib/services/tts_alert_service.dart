import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'blitzer_alert_service.dart';

/// German TTS voice alert service for blitzer warnings and POI announcements.
///
/// Singleton — shared across the app lifecycle.
/// Uses flutter_tts with German language for clear, reliable voice announcements.
/// Handles Chinese/non-German devices by explicitly selecting the right TTS engine.
class TtsAlertService {
  TtsAlertService._();
  static final instance = TtsAlertService._();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  bool _isSpeaking = false;
  /// Whether TTS is currently speaking.
  bool get isSpeaking => _isSpeaking;
  bool _germanAvailable = false;

  /// Tracks which blitzer IDs have been spoken at which stage.
  /// Key: "${blitzerId}_${stage.name}" → prevents repeating same warning.
  final Set<String> _spokenAlerts = {};

  /// Minimum time between any TTS announcements (prevents overlapping speech).
  DateTime? _lastSpeakTime;
  static const _minInterval = Duration(seconds: 3);

  /// Initialize TTS engine with German language.
  /// On Chinese phones: tries to find a Google TTS engine that supports German.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    if (Platform.isAndroid) {
      await _selectBestEngine();
    }

    // Try setting German
    final langResult = await _tts.setLanguage('de-DE');
    _germanAvailable = langResult == 1;
    debugPrint('[TTS] de-DE available: $_germanAvailable (result=$langResult)');

    // If de-DE failed, try just 'de'
    if (!_germanAvailable) {
      final deFallback = await _tts.setLanguage('de');
      _germanAvailable = deFallback == 1;
      debugPrint('[TTS] de fallback: $_germanAvailable');
    }

    // If German still not available, try English as last resort
    if (!_germanAvailable) {
      final enResult = await _tts.setLanguage('en-US');
      debugPrint('[TTS] Falling back to en-US: $enResult');
    }

    await _tts.setSpeechRate(0.55); // Slightly faster, still clear for riding
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    // Use a completion handler to track speaking state
    _tts.setCompletionHandler(() {
      _isSpeaking = false;
    });
    _tts.setCancelHandler(() {
      _isSpeaking = false;
    });
    _tts.setErrorHandler((msg) {
      _isSpeaking = false;
      debugPrint('[TTS] Error: $msg');
    });

    debugPrint('[TTS] Initialized (german=$_germanAvailable)');
  }

  /// On Android: try to select Google TTS engine (supports German).
  /// Chinese phones often have a local Chinese-only TTS as default.
  Future<void> _selectBestEngine() async {
    try {
      final engines = await _tts.getEngines;
      if (engines == null || engines.isEmpty) return;

      final engineList = List<String>.from(engines.map((e) => e.toString()));
      debugPrint('[TTS] Available engines: $engineList');

      // Priority order: Google TTS > Samsung TTS > any other > default
      const preferredEngines = [
        'com.google.android.tts',
        'com.samsung.SMT',
        'com.samsung.android.honeyboard', // Samsung keyboard TTS
      ];

      for (final preferred in preferredEngines) {
        if (engineList.any((e) => e.contains(preferred))) {
          final match = engineList.firstWhere((e) => e.contains(preferred));
          await _tts.setEngine(match);
          debugPrint('[TTS] Selected engine: $match');

          // Check if this engine has German
          final languages = await _tts.getLanguages;
          final langList = languages != null
              ? List<String>.from(languages.map((l) => l.toString()))
              : <String>[];
          final hasGerman = langList.any((l) =>
              l.startsWith('de') || l.contains('de-DE') || l.contains('de_DE'));
          debugPrint('[TTS] Engine $match has German: $hasGerman (langs: ${langList.take(10)})');

          if (hasGerman) return; // Found a good engine!
        }
      }

      // If none of the preferred engines have German, log all available languages
      final languages = await _tts.getLanguages;
      debugPrint('[TTS] Default engine languages: $languages');
    } catch (e) {
      debugPrint('[TTS] Engine selection error: $e');
    }
  }

  /// Speak a blitzer warning based on alert stage.
  ///
  /// Each alert/stage combination is only spoken ONCE.
  /// Returns true if spoken, false if skipped (already spoken or throttled).
  Future<bool> speakBlitzerWarning({
    required int blitzerId,
    required AlertStage stage,
    required double distanceMeters,
    int? speedLimit,
    String blitzerType = 'fixed',
  }) async {
    final key = '${blitzerId}_${stage.name}';
    if (_spokenAlerts.contains(key)) return false;

    // Build the warning text
    final distText = distanceMeters >= 1000
        ? '${(distanceMeters / 1000).toStringAsFixed(1)} Kilometer'
        : '${distanceMeters.round()} Meter';

    final typeLabel = switch (blitzerType) {
      'fixed' => 'Fester Blitzer',
      'mobile' => 'Mobiler Blitzer',
      'police' => 'Polizeikontrolle',
      'construction' => 'Baustelle',
      'accident' => 'Unfall',
      _ => 'Blitzer',
    };

    String text;
    switch (stage) {
      case AlertStage.early:
        // ~800m — first warning
        text = 'Achtung! $typeLabel in $distText.';
        if (speedLimit != null && speedLimit > 0) {
          text += ' Tempo $speedLimit.';
        }
        break;
      case AlertStage.approach:
        // ~200m — second warning, urgent
        text = '$typeLabel voraus, noch $distText!';
        if (speedLimit != null && speedLimit > 0) {
          text += ' Tempo $speedLimit!';
        }
        break;
      case AlertStage.immediate:
        // < 50m — directly ahead (fallback, rarely used)
        text = 'Vorsicht! $typeLabel direkt voraus!';
        break;
    }

    final spoken = await _speak(text);
    if (spoken) {
      _spokenAlerts.add(key);
    }
    return spoken;
  }

  /// Announce a POI search result.
  Future<bool> speakPoiResult(String poiType, String name, double distanceMeters) async {
    final distText = distanceMeters >= 1000
        ? '${(distanceMeters / 1000).toStringAsFixed(1)} Kilometer'
        : '${distanceMeters.round()} Meter';
    return _speak('$poiType $name in $distText gefunden.');
  }

  /// Speak arbitrary text (e.g., group announcements).
  Future<bool> speakText(String text) async {
    return _speak(text);
  }

  /// Clear spoken alert tracking (e.g., when starting a new ride).
  void clearSpokenAlerts() {
    _spokenAlerts.clear();
  }

  /// Stop any current speech.
  Future<void> stop() async {
    await _tts.stop();
    _isSpeaking = false;
  }

  /// Speak with priority — skips throttle, interrupts current speech.
  /// Use for important multi-sentence announcements (e.g. fuel station list).
  Future<bool> speakPriority(String text) async {
    return _speak(text, priority: true);
  }

  /// Internal: speak text with throttling.
  Future<bool> _speak(String text, {bool priority = false}) async {
    if (!_initialized) await init();

    // Throttle (skip for priority messages)
    if (!priority) {
      final now = DateTime.now();
      if (_lastSpeakTime != null &&
          now.difference(_lastSpeakTime!) < _minInterval) {
        debugPrint('[TTS] Throttled: $text');
        return false;
      }
    }

    // If already speaking, stop previous and speak new
    if (_isSpeaking) {
      await _tts.stop();
    }

    // Re-set language before each speak (some engines reset it)
    if (_germanAvailable) {
      await _tts.setLanguage('de-DE');
    }

    _lastSpeakTime = DateTime.now();
    _isSpeaking = true;
    debugPrint('[TTS] Speaking${priority ? ' [PRIORITY]' : ''}: $text');

    await _tts.speak(text);
    return true;
  }

  /// Dispose TTS engine.
  Future<void> dispose() async {
    await _tts.stop();
    _isSpeaking = false;
    _initialized = false;
  }
}
