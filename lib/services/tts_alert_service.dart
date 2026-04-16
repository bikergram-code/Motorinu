import 'dart:async';

import 'package:audio_session/audio_session.dart';
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
  /// 1s is enough gap — 3s was blocking sequential nav announcements.
  DateTime? _lastSpeakTime;
  static const _minInterval = Duration(milliseconds: 1500);

  /// Queue for sequential speech (used by speakQueued).
  final List<String> _speechQueue = [];
  bool _processingQueue = false;
  Completer<void>? _speechCompleter;

  /// Whether the queue is currently processing speech.
  bool get isQueueActive => _processingQueue;

  /// Initialize TTS engine with German language.
  /// On Chinese phones: tries to find a Google TTS engine that supports German.
  Future<void> init() async {
    if (_initialized) return;
    if (kIsWeb) return; // TTS not supported on web
    _initialized = true;

    if (defaultTargetPlatform == TargetPlatform.android) {
      await _selectBestEngine();
    }

    // Configure AudioSession for Bluetooth/media routing
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionMode: AVAudioSessionMode.spokenAudio,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: AndroidAudioUsage.media, // Routes through Bluetooth/media
          flags: AndroidAudioFlags.none,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck,
      ));
      debugPrint('[TTS] AudioSession configured for Bluetooth/media routing');
    } catch (e) {
      debugPrint('[TTS] AudioSession config failed: $e');
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

    // Select best quality German voice available
    await _selectBestGermanVoice();

    await _tts.setSpeechRate(0.52); // Natural pace, clear for riding
    await _tts.setVolume(1.0);
    await _tts.setPitch(0.9); // Deeper pitch — mature, professional navi voice

    // Use a completion handler to track speaking state + resolve queue completer.
    // Guard against completing an already-completed completer (race condition).
    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      if (_speechCompleter != null && !_speechCompleter!.isCompleted) {
        _speechCompleter!.complete();
      }
      _speechCompleter = null;
    });
    _tts.setCancelHandler(() {
      _isSpeaking = false;
      if (_speechCompleter != null && !_speechCompleter!.isCompleted) {
        _speechCompleter!.complete();
      }
      _speechCompleter = null;
    });
    _tts.setErrorHandler((msg) {
      _isSpeaking = false;
      debugPrint('[TTS] Error: $msg');
      if (_speechCompleter != null && !_speechCompleter!.isCompleted) {
        _speechCompleter!.complete();
      }
      _speechCompleter = null;
    });

    debugPrint('[TTS] Initialized (german=$_germanAvailable)');
  }

  /// Select the highest quality German voice on the device.
  /// Prefers: Network/HD voices > female voices > any German voice.
  Future<void> _selectBestGermanVoice() async {
    try {
      final voices = await _tts.getVoices;
      if (voices == null) return;
      final voiceList = (voices as List).map((v) => Map<String, String>.from(
        (v as Map).map((k, val) => MapEntry(k.toString(), val.toString())),
      )).toList();

      // Filter German voices
      final deVoices = voiceList.where((v) {
        final locale = (v['locale'] ?? v['language'] ?? '').toLowerCase();
        return locale.startsWith('de');
      }).toList();

      debugPrint('[TTS-Alert] Deutsche Stimmen: ${deVoices.length}');
      for (final v in deVoices) {
        debugPrint('[TTS-Alert]   ${v['name']} (locale: ${v['locale']})');
      }

      if (deVoices.isEmpty) return;

      Map<String, String>? bestVoice;

      // 1st priority: Network/HD male voice (deep, mature — like a navi)
      for (final v in deVoices) {
        final name = (v['name'] ?? '').toLowerCase();
        if ((name.contains('network') || name.contains('hd')) &&
            (name.contains('dea') || name.contains('dec') || name.contains('deg') ||
             name.contains('male') || name.contains('m00') || name.contains('m01')) &&
            !name.contains('female')) {
          bestVoice = v;
          break;
        }
      }

      // 2nd priority: Any male voice (local)
      if (bestVoice == null) {
        for (final v in deVoices) {
          final name = (v['name'] ?? '').toLowerCase();
          if ((name.contains('dea') || name.contains('dec') || name.contains('deg') ||
               name.contains('male') || name.contains('m00') || name.contains('m01')) &&
              !name.contains('female')) {
            bestVoice = v;
            break;
          }
        }
      }

      // 3rd priority: Network/HD mature female voice (fallback)
      if (bestVoice == null) {
        for (final v in deVoices) {
          final name = (v['name'] ?? '').toLowerCase();
          if (name.contains('network') || name.contains('hd')) {
            bestVoice = v;
            break;
          }
        }
      }

      // 4th priority: Any "local" (offline HD) voice
      if (bestVoice == null) {
        bestVoice = deVoices.cast<Map<String, String>?>().firstWhere(
          (v) => (v?['name'] ?? '').toLowerCase().contains('local'),
          orElse: () => null,
        );
      }

      // 5th: any German voice
      bestVoice ??= deVoices.first;

      await _tts.setVoice({'name': bestVoice['name']!, 'locale': bestVoice['locale'] ?? 'de-DE'});
      debugPrint('[TTS-Alert] Stimme gewählt: ${bestVoice['name']}');
    } catch (e) {
      debugPrint('[TTS-Alert] Stimmenauswahl fehlgeschlagen: $e');
    }
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

  /// Add text to a sequential speech queue.
  /// Each message waits for the previous one to finish — no cutting off.
  /// Use this for multi-sentence flows (Events, POI lists, Blitzer).
  void speakQueued(String text) {
    _speechQueue.add(text);
    if (!_processingQueue) {
      _processQueue();
    }
  }

  /// Clear the speech queue and stop current queued speech.
  /// Also resets throttle so next speak call isn't blocked.
  void clearQueue() {
    _speechQueue.clear();
    _processingQueue = false;
    _lastSpeakTime = null; // Reset throttle — next TTS call goes through immediately
  }

  /// Process queued speech items sequentially.
  Future<void> _processQueue() async {
    if (_processingQueue) return;
    _processingQueue = true;

    if (!_initialized) await init();

    // Set language ONCE before processing the queue (not per item!)
    // Setting language mid-speech can abort the current utterance.
    if (_germanAvailable) {
      await _tts.setLanguage('de-DE');
    }

    while (_speechQueue.isNotEmpty) {
      final text = _speechQueue.removeAt(0);

      // Wait for any current speech to finish first (don't kill it)
      if (_isSpeaking && _speechCompleter != null) {
        await _speechCompleter!.future.timeout(
          const Duration(seconds: 15),
          onTimeout: () {},
        );
      }

      // Set up completer BEFORE speaking so completion handler can resolve it
      _speechCompleter = Completer<void>();

      _lastSpeakTime = DateTime.now();
      _isSpeaking = true;
      debugPrint('[TTS] Speaking [QUEUED]: $text');
      await _tts.speak(text);

      // Wait for this speech to complete — with safety timeout
      try {
        await _speechCompleter?.future.timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            debugPrint('[TTS] Queue timeout for: $text');
          },
        );
      } catch (_) {
        debugPrint('[TTS] Completer error for: $text');
      }
      // Always reset speaking state after each item
      _isSpeaking = false;
      _speechCompleter = null;

      // 800ms pause between queued items — fast enough to feel responsive
      await Future.delayed(const Duration(milliseconds: 800));
    }

    _processingQueue = false;
    // Reset throttle so nav announcements can fire right after queue ends
    _lastSpeakTime = null;
  }

  /// Internal: speak text with throttling.
  Future<bool> _speak(String text, {bool priority = false}) async {
    if (!_initialized) await init();

    // Don't interrupt queued speech with non-priority calls
    if (_processingQueue && !priority) {
      debugPrint('[TTS] Skipped (queue active): $text');
      return false;
    }

    // Throttle (skip for priority messages)
    if (!priority) {
      final now = DateTime.now();
      if (_lastSpeakTime != null &&
          now.difference(_lastSpeakTime!) < _minInterval) {
        debugPrint('[TTS] Throttled: $text');
        return false;
      }
    }

    // If already speaking: priority interrupts, normal calls wait or skip
    if (_isSpeaking) {
      if (priority) {
        // Priority: interrupt current speech immediately
        await _tts.stop();
      } else {
        // Non-priority: skip — don't cut off current announcement
        debugPrint('[TTS] Skipped (already speaking): $text');
        return false;
      }
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
