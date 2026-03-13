import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'blitzer_alert_service.dart';

// ─── Audio & Haptic Alert Service ────────────────────────────────────────────
//
// Manages sound and vibration alerts for blitzer warnings.
// - Three alert stages with different sounds/vibration patterns
// - Configurable volume and intensity
// - Singleton pattern — shared across the app lifecycle
//
// Generates WAV tones programmatically in memory (no asset files needed).
// Uses AudioPlayers BytesSource for loud, clear playback.

class AlertAudioService {
  AlertAudioService._();
  static final instance = AlertAudioService._();

  final _blitzerPlayer = AudioPlayer();
  final _navPlayer = AudioPlayer();
  final _sosPlayer = AudioPlayer();
  bool _initialized = false;

  // Separate throttle timers for blitzer vs nav sounds
  DateTime? _lastBlitzerTime;
  DateTime? _lastNavTime;
  static const _minBlitzerInterval = Duration(milliseconds: 1500);
  static const _minNavInterval = Duration(milliseconds: 800);

  // ─── Cached tones ─────────────────────────────────────────────────────
  Uint8List? _cameraMp3; // Real camera shutter MP3 from assets
  Uint8List? _navTurnTone;
  Uint8List? _navArriveTone;
  Uint8List? _navRecalcTone;
  Uint8List? _navOffRouteTone;
  Uint8List? _warningTone;
  Uint8List? _sosTone;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await _blitzerPlayer.setReleaseMode(ReleaseMode.stop);
    await _navPlayer.setReleaseMode(ReleaseMode.stop);
    await _sosPlayer.setReleaseMode(ReleaseMode.stop);

    // Load real camera shutter sound from assets
    try {
      final data = await rootBundle.load('assets/sounds/camera_shutter.mp3');
      _cameraMp3 = data.buffer.asUint8List();
      debugPrint('[AlertAudio] Loaded camera_shutter.mp3 (${_cameraMp3!.length} bytes)');
    } catch (e) {
      debugPrint('[AlertAudio] Failed to load camera MP3: $e — using synthetic fallback');
      // Fallback: generate synthetic shutter sounds
      _cameraMp3 = _buildSyntheticShutter();
    }

    // Generate navigation tones in memory
    _navTurnTone = _buildNavTurnTone();
    _navArriveTone = _buildNavArriveTone();
    _navRecalcTone = _buildNavRecalcTone();
    _navOffRouteTone = _buildNavOffRouteTone();
    _warningTone = _buildWarningTone();
    _sosTone = _buildSosTone();

    debugPrint('[AlertAudio] Initialized');
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  WAV Tone Generator
  // ═══════════════════════════════════════════════════════════════════════

  static const int _sampleRate = 44100;

  /// Generate a single sine wave tone as PCM samples (normalized -1..1).
  List<double> _sineTone(double freqHz, double durationSec,
      {double fadeMs = 20}) {
    final numSamples = (_sampleRate * durationSec).round();
    final fadeSamples = (_sampleRate * fadeMs / 1000).round();
    final samples = List<double>.filled(numSamples, 0);

    for (int i = 0; i < numSamples; i++) {
      double s = sin(2 * pi * freqHz * i / _sampleRate);

      // Fade in
      if (i < fadeSamples) {
        s *= i / fadeSamples;
      }
      // Fade out
      if (i > numSamples - fadeSamples) {
        s *= (numSamples - i) / fadeSamples;
      }
      samples[i] = s;
    }
    return samples;
  }

  /// Silence (zeros) for a given duration.
  List<double> _silence(double durationSec) {
    return List<double>.filled((_sampleRate * durationSec).round(), 0);
  }

  /// Concatenate multiple sample lists.
  List<double> _concat(List<List<double>> parts) {
    final total = parts.fold<int>(0, (sum, p) => sum + p.length);
    final result = List<double>.filled(total, 0);
    int offset = 0;
    for (final part in parts) {
      result.setRange(offset, offset + part.length, part);
      offset += part.length;
    }
    return result;
  }

  /// Pack PCM samples into a valid WAV byte array (16-bit mono).
  Uint8List _samplesToWav(List<double> samples) {
    final numSamples = samples.length;
    final dataSize = numSamples * 2; // 16-bit = 2 bytes per sample
    final fileSize = 44 + dataSize; // WAV header = 44 bytes

    final buffer = ByteData(fileSize);
    int offset = 0;

    // ─── RIFF header ───
    // "RIFF"
    buffer.setUint8(offset++, 0x52); // R
    buffer.setUint8(offset++, 0x49); // I
    buffer.setUint8(offset++, 0x46); // F
    buffer.setUint8(offset++, 0x46); // F
    // File size - 8
    buffer.setUint32(offset, fileSize - 8, Endian.little);
    offset += 4;
    // "WAVE"
    buffer.setUint8(offset++, 0x57); // W
    buffer.setUint8(offset++, 0x41); // A
    buffer.setUint8(offset++, 0x56); // V
    buffer.setUint8(offset++, 0x45); // E

    // ─── fmt sub-chunk ───
    // "fmt "
    buffer.setUint8(offset++, 0x66); // f
    buffer.setUint8(offset++, 0x6D); // m
    buffer.setUint8(offset++, 0x74); // t
    buffer.setUint8(offset++, 0x20); // (space)
    // Sub-chunk size (16 for PCM)
    buffer.setUint32(offset, 16, Endian.little);
    offset += 4;
    // Audio format (1 = PCM)
    buffer.setUint16(offset, 1, Endian.little);
    offset += 2;
    // Number of channels (1 = mono)
    buffer.setUint16(offset, 1, Endian.little);
    offset += 2;
    // Sample rate
    buffer.setUint32(offset, _sampleRate, Endian.little);
    offset += 4;
    // Byte rate (sampleRate * numChannels * bitsPerSample / 8)
    buffer.setUint32(offset, _sampleRate * 2, Endian.little);
    offset += 4;
    // Block align (numChannels * bitsPerSample / 8)
    buffer.setUint16(offset, 2, Endian.little);
    offset += 2;
    // Bits per sample
    buffer.setUint16(offset, 16, Endian.little);
    offset += 2;

    // ─── data sub-chunk ───
    // "data"
    buffer.setUint8(offset++, 0x64); // d
    buffer.setUint8(offset++, 0x61); // a
    buffer.setUint8(offset++, 0x74); // t
    buffer.setUint8(offset++, 0x61); // a
    // Data size
    buffer.setUint32(offset, dataSize, Endian.little);
    offset += 4;

    // ─── PCM data ───
    for (int i = 0; i < numSamples; i++) {
      // Clamp to -1..1 and convert to 16-bit signed integer
      final clamped = samples[i].clamp(-1.0, 1.0);
      final intVal = (clamped * 32767).round().clamp(-32768, 32767);
      buffer.setInt16(offset, intVal, Endian.little);
      offset += 2;
    }

    return buffer.buffer.asUint8List();
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Tone Presets (built once, cached as Uint8List)
  // ═══════════════════════════════════════════════════════════════════════

  /// Synthetic fallback shutter sound (used if MP3 asset fails to load).
  Uint8List _buildSyntheticShutter() {
    final rng = Random();
    final samples = <double>[];

    // Simple click: noise burst with fast decay (~80ms)
    final len = (_sampleRate * 0.08).round();
    for (int i = 0; i < len; i++) {
      final t = i / _sampleRate;
      double s = (rng.nextDouble() * 2 - 1) * 0.5 +
          sin(2 * pi * 4000 * t) * 0.4;
      s *= exp(-t * 50);
      samples.add(s.clamp(-1.0, 1.0));
    }

    return _samplesToWav(samples);
  }

  /// Nav turn: short click-like beep (660 Hz, 0.12s)
  Uint8List _buildNavTurnTone() {
    final samples = _sineTone(660, 0.12);
    return _samplesToWav(samples);
  }

  /// Nav arrive: happy double tone (880→1320 Hz, major fifth)
  Uint8List _buildNavArriveTone() {
    final samples = _concat([
      _sineTone(880, 0.20),
      _silence(0.10),
      _sineTone(1320, 0.30),
    ]);
    return _samplesToWav(samples);
  }

  /// Nav recalculate: descending tone (660→440 Hz)
  Uint8List _buildNavRecalcTone() {
    final samples = _concat([
      _sineTone(660, 0.15),
      _silence(0.05),
      _sineTone(440, 0.15),
    ]);
    return _samplesToWav(samples);
  }

  /// Nav off-route: warning double tone (880→880 Hz)
  Uint8List _buildNavOffRouteTone() {
    final samples = _concat([
      _sineTone(880, 0.15),
      _silence(0.10),
      _sineTone(880, 0.15),
    ]);
    return _samplesToWav(samples);
  }

  /// General warning: urgent double tone (1000→1200 Hz)
  Uint8List _buildWarningTone() {
    final samples = _concat([
      _sineTone(1000, 0.20),
      _silence(0.08),
      _sineTone(1200, 0.25),
    ]);
    return _samplesToWav(samples);
  }

  /// SOS alarm: angenehmer, tiefer Dreiklang-Alarm.
  /// Drei aufsteigende Töne (C5→E5→G5) — Dur-Akkord klingt weniger aggressiv
  /// als typische Sirenen, ist aber klar erkennbar.
  Uint8List _buildSosTone() {
    final samples = _concat([
      // Drei aufsteigende Töne (C5-E5-G5 Dur-Dreiklang)
      _sineTone(523, 0.25),   // C5
      _silence(0.08),
      _sineTone(659, 0.25),   // E5
      _silence(0.08),
      _sineTone(784, 0.35),   // G5 (etwas länger für Abschluss)
    ]);
    return _samplesToWav(samples);
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Blitzer Alert Sound + Haptic
  // ═══════════════════════════════════════════════════════════════════════

  /// Play alert sound + haptic for a given stage.
  Future<void> playAlert({
    required AlertStage stage,
    required bool audioEnabled,
    required double volume,
    required String soundType,
    required bool hapticEnabled,
    required String hapticIntensity,
  }) async {
    // Throttle (blitzer-specific)
    final now = DateTime.now();
    if (_lastBlitzerTime != null &&
        now.difference(_lastBlitzerTime!) < _minBlitzerInterval) {
      return;
    }
    _lastBlitzerTime = now;

    // Haptic
    if (hapticEnabled) {
      _triggerHaptic(stage, hapticIntensity);
    }

    // Audio
    if (audioEnabled && volume > 0) {
      await _playSound(stage, volume, soundType);
    }
  }

  void _triggerHaptic(AlertStage stage, String intensity) {
    switch (stage) {
      case AlertStage.early:
        HapticFeedback.lightImpact();
      case AlertStage.approach:
        switch (intensity) {
          case 'light':
            HapticFeedback.lightImpact();
          case 'heavy':
            HapticFeedback.heavyImpact();
          default:
            HapticFeedback.mediumImpact();
        }
      case AlertStage.immediate:
        // Double vibration for immediate alerts
        HapticFeedback.heavyImpact();
        Future.delayed(const Duration(milliseconds: 200), () {
          HapticFeedback.heavyImpact();
        });
    }
  }

  /// Play camera shutter sound once.
  Future<void> _playCameraOnce(double volume) async {
    if (_cameraMp3 == null) return;
    await _blitzerPlayer.stop();
    await _blitzerPlayer.setVolume(volume.clamp(0.0, 1.0));
    await _blitzerPlayer.play(BytesSource(_cameraMp3!));
  }

  Future<void> _playSound(
      AlertStage stage, double volume, String soundType) async {
    try {
      // Determine repeat count based on alert stage
      final int repeats;
      final int delayMs;
      switch (stage) {
        case AlertStage.early:
          repeats = 1;
          delayMs = 0;
        case AlertStage.approach:
          repeats = 2;
          delayMs = 250;
        case AlertStage.immediate:
          repeats = 3;
          delayMs = 150;
      }

      // Play camera shutter sound with repeats
      for (int i = 0; i < repeats; i++) {
        await _playCameraOnce(volume);
        if (i < repeats - 1 && delayMs > 0) {
          // Wait for sound to finish + gap before next repeat
          await Future.delayed(Duration(milliseconds: 400 + delayMs));
        }
      }

      debugPrint('[AlertAudio] Blitzer $stage: ${repeats}x camera shutter (vol=$volume)');
    } catch (e) {
      debugPrint('[AlertAudio] Sound error: $e');
      // Fallback to system sound
      SystemSound.play(SystemSoundType.alert);
    }
  }

  // ─── Navigation Sounds ────────────────────────────────────────────────

  /// Play a navigation sound (turn, arrive, etc.)
  Future<void> playNavSound({
    required NavSoundType type,
    required bool enabled,
    required double volume,
  }) async {
    if (!enabled || volume <= 0) return;

    // Throttle (nav-specific, separate from blitzer)
    final now = DateTime.now();
    if (_lastNavTime != null &&
        now.difference(_lastNavTime!) < _minNavInterval) {
      return;
    }
    _lastNavTime = now;

    try {
      // Haptic per type
      switch (type) {
        case NavSoundType.turn:
          HapticFeedback.mediumImpact();
        case NavSoundType.arrive:
          HapticFeedback.heavyImpact();
        case NavSoundType.recalculate:
          HapticFeedback.lightImpact();
        case NavSoundType.offRoute:
          HapticFeedback.heavyImpact();
      }

      // Audio tone
      final Uint8List? tone;
      switch (type) {
        case NavSoundType.turn:
          tone = _navTurnTone;
        case NavSoundType.arrive:
          tone = _navArriveTone;
        case NavSoundType.recalculate:
          tone = _navRecalcTone;
        case NavSoundType.offRoute:
          tone = _navOffRouteTone;
      }

      if (tone != null) {
        await _navPlayer.stop();
        await _navPlayer.setVolume(volume.clamp(0.0, 1.0));
        await _navPlayer.play(BytesSource(tone));
      }
      debugPrint('[AlertAudio] Nav sound: $type');
    } catch (e) {
      debugPrint('[AlertAudio] Nav sound error: $e');
      SystemSound.play(SystemSoundType.click);
    }
  }

  /// Play a warning sound (blitzer, police etc.)
  Future<void> playWarningSound({
    required bool enabled,
    required double volume,
  }) async {
    if (!enabled || volume <= 0) return;

    final now = DateTime.now();
    if (_lastBlitzerTime != null &&
        now.difference(_lastBlitzerTime!) < _minBlitzerInterval) {
      return;
    }
    _lastBlitzerTime = now;

    try {
      HapticFeedback.heavyImpact();

      if (_warningTone != null) {
        await _blitzerPlayer.stop();
        await _blitzerPlayer.setVolume(volume.clamp(0.0, 1.0));
        await _blitzerPlayer.play(BytesSource(_warningTone!));
      }
      debugPrint('[AlertAudio] Warning sound played');
    } catch (e) {
      debugPrint('[AlertAudio] Warning sound error: $e');
      SystemSound.play(SystemSoundType.alert);
    }
  }

  // ─── SOS Alarm ───────────────────────────────────────────────────────

  /// Play the SOS alarm tone once. Angenehmer Dreiklang.
  Future<void> playSosAlarm({double volume = 0.9}) async {
    try {
      if (_sosTone == null) return;
      HapticFeedback.heavyImpact();
      await _sosPlayer.stop();
      await _sosPlayer.setVolume(volume.clamp(0.0, 1.0));
      await _sosPlayer.play(BytesSource(_sosTone!));
      debugPrint('[AlertAudio] SOS alarm played');
    } catch (e) {
      debugPrint('[AlertAudio] SOS alarm error: $e');
      SystemSound.play(SystemSoundType.alert);
    }
  }

  /// Stop the SOS alarm.
  Future<void> stopSosAlarm() async {
    await _sosPlayer.stop();
  }

  /// Stop any playing sound.
  Future<void> stop() async {
    await _blitzerPlayer.stop();
    await _navPlayer.stop();
    await _sosPlayer.stop();
  }

  void dispose() {
    _blitzerPlayer.dispose();
    _navPlayer.dispose();
    _sosPlayer.dispose();
    _initialized = false;
  }
}

/// Types of navigation sounds.
enum NavSoundType {
  turn,        // Abbiegen / nächster Schritt
  arrive,      // Ankunft am Ziel
  recalculate, // Route wird neu berechnet
  offRoute,    // Von der Route abgekommen
}
