import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:vosk_flutter_service/vosk_flutter.dart';

/// Vosk-based always-on wake word + command recognition service.
/// Runs 100% offline with German language model.
///
/// Flow:
/// 1. Always listening for wake word ("hi moto", "hey moto")
/// 2. When detected → callback with [VoskWakeEvent.wakeWordDetected]
/// 3. Continues listening for command (e.g. "Tankstelle", "Ahrstraße Solingen")
/// 4. When command recognized → callback with [VoskWakeEvent.commandRecognized]
/// 5. Goes back to wake word listening
class VoskWakeWordService {
  VoskWakeWordService._();
  static final instance = VoskWakeWordService._();

  final _vosk = VoskFlutterPlugin.instance();
  Model? _model;
  Recognizer? _recognizer;
  SpeechService? _speechService;

  bool _isInitialized = false;
  bool _isListening = false;
  bool _wakeWordTriggered = false;

  /// Direct listen mode — bypass wake word, fire commandRecognized for ANY speech.
  /// Used for off-route Ja/Nein answers and fuel station choice.
  bool directListenMode = false;

  // Callback for events
  void Function(VoskWakeEvent event, String text)? onEvent;

  // Timer for command timeout (go back to wake word after X seconds of silence)
  Timer? _commandTimeout;

  /// Wake word prefix variants — the greeting part before "moto".
  static const _wakePrefixes = ['hi', 'hey', 'hallo', 'hej', 'he'];

  /// "Moto" variants — Vosk German model often mis-transcribes "moto" as
  /// "motor", "motto", "modo", "modus", "foto", "model" etc.
  /// We match any word starting with "mo" after a greeting prefix.
  static const _motoVariants = [
    'moto', 'motto', 'motor', 'modo', 'modus', 'modul', 'modal', 'model',
    'mordo', 'morto', 'mojo', 'mono', 'mozo',
  ];

  /// Initialize Vosk with German model from assets.
  Future<bool> init() async {
    if (_isInitialized) return true;
    try {
      debugPrint('[Vosk] Loading German model...');
      final modelPath = await ModelLoader().loadFromAssets(
        'assets/models/vosk-model-small-de-0.15.zip',
      );
      _model = await _vosk.createModel(modelPath);
      _isInitialized = true;
      debugPrint('[Vosk] Model loaded successfully');
      return true;
    } catch (e) {
      debugPrint('[Vosk] Init error: $e');
      return false;
    }
  }

  /// Start always-on listening.
  Future<void> startListening() async {
    if (!_isInitialized || _isListening) return;

    try {
      _recognizer = await _vosk.createRecognizer(
        model: _model!,
        sampleRate: 16000,
      );

      // Enable 3 alternatives for better wake word matching
      await _recognizer!.setMaxAlternatives(3);

      _speechService = await _vosk.initSpeechService(_recognizer!);

      // Listen to partial results (real-time, before sentence ends)
      _speechService!.onPartial().listen((partial) {
        _handlePartial(partial);
      });

      // Listen to final results (after pause/sentence end)
      _speechService!.onResult().listen((result) {
        _handleResult(result);
      });

      await _speechService!.start();
      _isListening = true;
      _wakeWordTriggered = false;
      debugPrint('[Vosk] Listening started (wake word mode, 3 alternatives)');
    } catch (e) {
      debugPrint('[Vosk] Start error: $e');
    }
  }

  /// Pause/resume microphone input (prevents TTS echo from being recognized).
  Future<void> setPaused(bool paused) async {
    try {
      if (_speechService != null) {
        await _speechService!.setPause(paused: paused);
        debugPrint('[Vosk] ${paused ? "PAUSED" : "RESUMED"}');
      }
    } catch (e) {
      debugPrint('[Vosk] setPause error: $e');
    }
  }

  /// Stop listening completely.
  Future<void> stopListening() async {
    _commandTimeout?.cancel();
    try {
      await _speechService?.stop();
      _speechService?.dispose();
    } catch (_) {}
    _speechService = null;
    try {
      _recognizer?.dispose();
    } catch (_) {}
    _recognizer = null;
    _isListening = false;
    _wakeWordTriggered = false;
    debugPrint('[Vosk] Listening stopped');
  }

  /// Extract all text variants from a Vosk JSON result.
  /// Handles both single-result and alternatives format.
  List<String> _extractTexts(Map<String, dynamic> map) {
    final texts = <String>[];

    // Single result format: {"text": "..."}
    final text = map['text'] as String?;
    if (text != null && text.trim().isNotEmpty) {
      texts.add(text.toLowerCase().trim());
    }

    // Partial result format: {"partial": "..."}
    final partial = map['partial'] as String?;
    if (partial != null && partial.trim().isNotEmpty) {
      texts.add(partial.toLowerCase().trim());
    }

    // Alternatives format: {"alternatives": [{"text": "...", "confidence": 0.9}, ...]}
    final alts = map['alternatives'] as List?;
    if (alts != null) {
      for (final alt in alts) {
        if (alt is Map<String, dynamic>) {
          final altText = alt['text'] as String?;
          if (altText != null && altText.trim().isNotEmpty) {
            texts.add(altText.toLowerCase().trim());
          }
        }
      }
    }

    return texts;
  }

  /// Handle partial recognition results (real-time).
  void _handlePartial(String partialJson) {
    try {
      final map = jsonDecode(partialJson) as Map<String, dynamic>;
      final texts = _extractTexts(map);
      if (texts.isEmpty) return;

      debugPrint('[Vosk] Partial: ${texts.take(2)} (wake=${_wakeWordTriggered})');

      if (!_wakeWordTriggered) {
        // Check for wake word in any text variant
        for (final text in texts) {
          if (_containsWakeWord(text)) {
            _wakeWordTriggered = true;
            debugPrint('[Vosk] WAKE WORD DETECTED in: "$text"');
            onEvent?.call(VoskWakeEvent.wakeWordDetected, 'hi moto');

            // Start command timeout — if no command after 8s, reset
            _commandTimeout?.cancel();
            _commandTimeout = Timer(const Duration(seconds: 12), () {
              if (_wakeWordTriggered) {
                debugPrint('[Vosk] Command timeout, back to wake word mode');
                _wakeWordTriggered = false;
                onEvent?.call(VoskWakeEvent.commandTimeout, '');
              }
            });
            return;
          }
        }
      }
    } catch (_) {}
  }

  /// Handle final recognition results (after pause).
  void _handleResult(String resultJson) {
    try {
      final map = jsonDecode(resultJson) as Map<String, dynamic>;
      final texts = _extractTexts(map);
      if (texts.isEmpty) return;

      // Use first (highest confidence) text for command processing
      final text = texts.first;
      debugPrint('[Vosk] Result: ${texts.take(2)} (wake=${_wakeWordTriggered})');

      // Direct listen mode — fire ANY speech as command (no wake word needed)
      if (directListenMode && !_wakeWordTriggered) {
        if (text.isNotEmpty) {
          debugPrint('[Vosk] DIRECT LISTEN: "$text"');
          onEvent?.call(VoskWakeEvent.commandRecognized, text);
        }
        return;
      }

      if (_wakeWordTriggered) {
        // We're in command mode — extract command after wake word
        String command = text;

        // Remove wake word prefix if present (using fuzzy matching)
        final wakeEnd = _findWakeWordEnd(command);
        if (wakeEnd >= 0) {
          command = command.substring(wakeEnd).trim();
        }

        // Minimum 3 chars to avoid noise like "da", "ja", "eh"
        if (command.length >= 3) {
          _commandTimeout?.cancel();
          _wakeWordTriggered = false;
          debugPrint('[Vosk] COMMAND: "$command"');
          onEvent?.call(VoskWakeEvent.commandRecognized, command);
        } else if (command.isNotEmpty) {
          debugPrint('[Vosk] Ignored too short: "$command"');
        }
      } else {
        // Check if wake word + command in one sentence (any alternative)
        for (final t in texts) {
          final wakeEnd = _findWakeWordEnd(t);
          if (wakeEnd >= 0) {
            String command = t.substring(wakeEnd).trim();
            if (command.length >= 3) {
              debugPrint('[Vosk] WAKE + COMMAND: "$command"');
              onEvent?.call(VoskWakeEvent.wakeWordDetected, 'hi moto');
              Future.delayed(const Duration(milliseconds: 300), () {
                onEvent?.call(VoskWakeEvent.commandRecognized, command);
              });
            } else {
              _wakeWordTriggered = true;
              onEvent?.call(VoskWakeEvent.wakeWordDetected, 'hi moto');
              _commandTimeout?.cancel();
              _commandTimeout = Timer(const Duration(seconds: 12), () {
                if (_wakeWordTriggered) {
                  _wakeWordTriggered = false;
                  onEvent?.call(VoskWakeEvent.commandTimeout, '');
                }
              });
            }
            return;
          }
        }
      }
    } catch (_) {}
  }

  bool get isListening => _isListening;
  bool get isInitialized => _isInitialized;
  bool get isWakeWordTriggered => _wakeWordTriggered;

  /// Check if text contains a wake word pattern: [prefix] + [moto variant].
  /// E.g. "hi motor", "hey motto", "hallo moto" all match.
  bool _containsWakeWord(String text) {
    final words = text.split(RegExp(r'\s+'));
    for (int i = 0; i < words.length - 1; i++) {
      if (_wakePrefixes.contains(words[i])) {
        // Check if next word is a moto variant OR starts with "mo"
        final next = words[i + 1];
        if (_motoVariants.contains(next) || (next.startsWith('mo') && next.length >= 3)) {
          return true;
        }
      }
    }
    return false;
  }

  /// Find the end index of the wake word in text, or -1 if not found.
  /// Used to extract the command after the wake word.
  int _findWakeWordEnd(String text) {
    final words = text.split(RegExp(r'\s+'));
    int charPos = 0;
    for (int i = 0; i < words.length - 1; i++) {
      charPos = text.indexOf(words[i], charPos);
      if (_wakePrefixes.contains(words[i])) {
        final next = words[i + 1];
        if (_motoVariants.contains(next) || (next.startsWith('mo') && next.length >= 3)) {
          // Return position after the moto word
          final motoStart = text.indexOf(next, charPos + words[i].length);
          return motoStart + next.length;
        }
      }
      charPos += words[i].length;
    }
    return -1;
  }

  /// Dispose all resources.
  void dispose() {
    stopListening();
    _model?.dispose();
    _model = null;
    _isInitialized = false;
  }
}

/// Events emitted by VoskWakeWordService.
enum VoskWakeEvent {
  /// Wake word detected — show visual feedback, play "Ja?"
  wakeWordDetected,

  /// Command recognized after wake word — process it
  commandRecognized,

  /// No command after timeout — go back to listening
  commandTimeout,
}
