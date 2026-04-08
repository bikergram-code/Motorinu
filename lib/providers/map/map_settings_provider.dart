import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Blitzer Settings Provider ────────────────────────────────────────────────
//
// Persists all blitzer/navigation preferences to SharedPreferences.
// Used by: Driving Mode, Alert System, Navigation UI, Settings Screen.

final blitzerSettingsProvider =
    AsyncNotifierProvider<BlitzerSettingsNotifier, BlitzerSettings>(
        BlitzerSettingsNotifier.new);

// ─── Settings Model ──────────────────────────────────────────────────────────

class BlitzerSettings {
  // Alert distances (meters)
  final int alertDistanceFixed;    // Fester Blitzer: default 500m
  final int alertDistanceMobile;   // Mobiler Blitzer: default 800m
  final int alertDistancePolice;   // Polizei: default 600m

  // Alert stages
  final bool earlyWarningEnabled;  // Frühwarnung (1000m+)
  final bool approachWarningEnabled; // Annäherung (500m)
  final bool immediateWarningEnabled; // Direkt (200m)

  // Audio
  final bool audioAlertsEnabled;
  final double audioVolume; // 0.0 - 1.0
  final String alertSoundType; // 'beep', 'chime', 'voice'

  // Navigation sounds (turn-by-turn)
  final bool navSoundEnabled; // Navigations-Töne (Abbiegen, Ankunft)

  // Warning sounds (Blitzer etc.)
  final bool warningSoundEnabled; // Warnmeldungs-Töne (Blitzer, Polizei)

  // Haptic
  final bool hapticAlertsEnabled;
  final String hapticIntensity; // 'light', 'medium', 'heavy'

  // Driving Mode
  final bool autoFollowMode; // Kamera folgt automatisch
  final bool headingRotation; // Karte dreht mit Fahrtrichtung
  final double followZoom; // Zoom-Level im Follow-Mode (14-19)
  final double followTilt; // Tilt im Follow-Mode (0-67)
  final bool speedDisplay; // Geschwindigkeit anzeigen
  final bool keepScreenOn; // Bildschirm an lassen

  // Battery
  final String batteryMode; // 'performance', 'balanced', 'saver'
  final int gpsUpdateIntervalMs; // GPS Update (computed from battery mode)

  // 3D View
  final bool auto3dNavigation; // Automatisch 3D bei Navigation
  final bool always3d; // Karte immer in 3D

  // GPS Smoothing (Kalman filter)
  final bool smoothingEnabled; // Kalman-Filter für GPS-Glättung

  // Live on Map (Online-Sichtbarkeit)
  final bool liveOnMap; // Auf der Karte für andere sichtbar sein

  // Route options (avoid)
  final bool avoidTolls;       // Maut meiden
  final bool avoidFerries;     // Fähren meiden
  final bool avoidMotorways;   // Autobahnen meiden

  // Filter: Which blitzer types to warn about
  final bool warnFixed;
  final bool warnMobile;
  final bool warnPolice;
  final bool warnConstruction;
  final bool warnAccident;

  const BlitzerSettings({
    this.alertDistanceFixed = 500,
    this.alertDistanceMobile = 800,
    this.alertDistancePolice = 600,
    this.earlyWarningEnabled = true,
    this.approachWarningEnabled = true,
    this.immediateWarningEnabled = true,
    this.audioAlertsEnabled = true,
    this.audioVolume = 0.8,
    this.alertSoundType = 'beep',
    this.navSoundEnabled = true,
    this.warningSoundEnabled = true,
    this.hapticAlertsEnabled = true,
    this.hapticIntensity = 'medium',
    this.autoFollowMode = true,
    this.headingRotation = true,
    this.followZoom = 17.0,
    this.followTilt = 45.0,
    this.speedDisplay = true,
    this.keepScreenOn = true,
    this.auto3dNavigation = true,
    this.always3d = false,
    this.batteryMode = 'balanced',
    this.gpsUpdateIntervalMs = 1000,
    this.smoothingEnabled = true,
    this.liveOnMap = true,
    this.avoidTolls = false,
    this.avoidFerries = false,
    this.avoidMotorways = false,
    this.warnFixed = true,
    this.warnMobile = true,
    this.warnPolice = true,
    this.warnConstruction = true,
    this.warnAccident = true,
  });

  BlitzerSettings copyWith({
    int? alertDistanceFixed,
    int? alertDistanceMobile,
    int? alertDistancePolice,
    bool? earlyWarningEnabled,
    bool? approachWarningEnabled,
    bool? immediateWarningEnabled,
    bool? audioAlertsEnabled,
    double? audioVolume,
    String? alertSoundType,
    bool? navSoundEnabled,
    bool? warningSoundEnabled,
    bool? hapticAlertsEnabled,
    String? hapticIntensity,
    bool? autoFollowMode,
    bool? headingRotation,
    double? followZoom,
    double? followTilt,
    bool? speedDisplay,
    bool? keepScreenOn,
    bool? auto3dNavigation,
    bool? always3d,
    String? batteryMode,
    int? gpsUpdateIntervalMs,
    bool? smoothingEnabled,
    bool? liveOnMap,
    bool? avoidTolls,
    bool? avoidFerries,
    bool? avoidMotorways,
    bool? warnFixed,
    bool? warnMobile,
    bool? warnPolice,
    bool? warnConstruction,
    bool? warnAccident,
  }) {
    return BlitzerSettings(
      alertDistanceFixed: alertDistanceFixed ?? this.alertDistanceFixed,
      alertDistanceMobile: alertDistanceMobile ?? this.alertDistanceMobile,
      alertDistancePolice: alertDistancePolice ?? this.alertDistancePolice,
      earlyWarningEnabled: earlyWarningEnabled ?? this.earlyWarningEnabled,
      approachWarningEnabled: approachWarningEnabled ?? this.approachWarningEnabled,
      immediateWarningEnabled: immediateWarningEnabled ?? this.immediateWarningEnabled,
      audioAlertsEnabled: audioAlertsEnabled ?? this.audioAlertsEnabled,
      audioVolume: audioVolume ?? this.audioVolume,
      alertSoundType: alertSoundType ?? this.alertSoundType,
      navSoundEnabled: navSoundEnabled ?? this.navSoundEnabled,
      warningSoundEnabled: warningSoundEnabled ?? this.warningSoundEnabled,
      hapticAlertsEnabled: hapticAlertsEnabled ?? this.hapticAlertsEnabled,
      hapticIntensity: hapticIntensity ?? this.hapticIntensity,
      autoFollowMode: autoFollowMode ?? this.autoFollowMode,
      headingRotation: headingRotation ?? this.headingRotation,
      followZoom: followZoom ?? this.followZoom,
      followTilt: followTilt ?? this.followTilt,
      speedDisplay: speedDisplay ?? this.speedDisplay,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      auto3dNavigation: auto3dNavigation ?? this.auto3dNavigation,
      always3d: always3d ?? this.always3d,
      batteryMode: batteryMode ?? this.batteryMode,
      gpsUpdateIntervalMs: gpsUpdateIntervalMs ?? this.gpsUpdateIntervalMs,
      smoothingEnabled: smoothingEnabled ?? this.smoothingEnabled,
      liveOnMap: liveOnMap ?? this.liveOnMap,
      avoidTolls: avoidTolls ?? this.avoidTolls,
      avoidFerries: avoidFerries ?? this.avoidFerries,
      avoidMotorways: avoidMotorways ?? this.avoidMotorways,
      warnFixed: warnFixed ?? this.warnFixed,
      warnMobile: warnMobile ?? this.warnMobile,
      warnPolice: warnPolice ?? this.warnPolice,
      warnConstruction: warnConstruction ?? this.warnConstruction,
      warnAccident: warnAccident ?? this.warnAccident,
    );
  }

  /// GPS distance filter based on battery mode and speed.
  int get gpsDistanceFilter => switch (batteryMode) {
    'performance' => 3,   // 3m — very precise
    'balanced' => 5,      // 5m — good balance (default)
    'saver' => 15,        // 15m — battery saving
    _ => 5,
  };

  /// GPS accuracy based on battery mode (string for legacy compat).
  String get gpsAccuracyLevel => switch (batteryMode) {
    'performance' => 'bestForNavigation',
    'balanced' => 'high',
    'saver' => 'medium',
    _ => 'high',
  };

  /// GPS accuracy as Geolocator enum (for LocationEngine).
  LocationAccuracy get gpsAccuracy => switch (batteryMode) {
    'performance' => LocationAccuracy.bestForNavigation,
    'balanced' => LocationAccuracy.high,
    'saver' => LocationAccuracy.medium,
    _ => LocationAccuracy.high,
  };

  /// Whether a given blitzer type should trigger an alert.
  bool shouldWarn(String type) => switch (type) {
    'fixed' => warnFixed,
    'mobile' => warnMobile,
    'police' => warnPolice,
    'construction' => warnConstruction,
    'accident' => warnAccident,
    _ => false,
  };

  /// Get alert distance for a given blitzer type.
  int alertDistanceFor(String type) => switch (type) {
    'fixed' => alertDistanceFixed,
    'mobile' => alertDistanceMobile,
    'police' => alertDistancePolice,
    'construction' => alertDistanceMobile, // Same as mobile
    'accident' => alertDistanceMobile,
    _ => 500,
  };
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class BlitzerSettingsNotifier extends AsyncNotifier<BlitzerSettings> {
  static const _prefix = 'blitzer_';

  @override
  Future<BlitzerSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    return BlitzerSettings(
      alertDistanceFixed: prefs.getInt('${_prefix}alert_dist_fixed') ?? 500,
      alertDistanceMobile: prefs.getInt('${_prefix}alert_dist_mobile') ?? 800,
      alertDistancePolice: prefs.getInt('${_prefix}alert_dist_police') ?? 600,
      earlyWarningEnabled: prefs.getBool('${_prefix}early_warning') ?? true,
      approachWarningEnabled: prefs.getBool('${_prefix}approach_warning') ?? true,
      immediateWarningEnabled: prefs.getBool('${_prefix}immediate_warning') ?? true,
      audioAlertsEnabled: prefs.getBool('${_prefix}audio_alerts') ?? true,
      audioVolume: prefs.getDouble('${_prefix}audio_volume') ?? 0.8,
      alertSoundType: prefs.getString('${_prefix}alert_sound') ?? 'beep',
      navSoundEnabled: prefs.getBool('${_prefix}nav_sound') ?? true,
      warningSoundEnabled: prefs.getBool('${_prefix}warning_sound') ?? true,
      hapticAlertsEnabled: prefs.getBool('${_prefix}haptic_alerts') ?? true,
      hapticIntensity: prefs.getString('${_prefix}haptic_intensity') ?? 'medium',
      autoFollowMode: prefs.getBool('${_prefix}auto_follow') ?? true,
      headingRotation: prefs.getBool('${_prefix}heading_rotation') ?? true,
      followZoom: prefs.getDouble('${_prefix}follow_zoom') ?? 17.0,
      followTilt: prefs.getDouble('${_prefix}follow_tilt') ?? 45.0,
      speedDisplay: prefs.getBool('${_prefix}speed_display') ?? true,
      keepScreenOn: prefs.getBool('${_prefix}keep_screen_on') ?? true,
      auto3dNavigation: prefs.getBool('${_prefix}auto_3d_nav') ?? true,
      always3d: prefs.getBool('${_prefix}always_3d') ?? false,
      batteryMode: prefs.getString('${_prefix}battery_mode') ?? 'balanced',
      smoothingEnabled: prefs.getBool('${_prefix}smoothing_enabled') ?? true,
      liveOnMap: prefs.getBool('${_prefix}live_on_map') ?? true,
      avoidTolls: prefs.getBool('${_prefix}avoid_tolls') ?? false,
      avoidFerries: prefs.getBool('${_prefix}avoid_ferries') ?? false,
      avoidMotorways: prefs.getBool('${_prefix}avoid_motorways') ?? false,
      warnFixed: prefs.getBool('${_prefix}warn_fixed') ?? true,
      warnMobile: prefs.getBool('${_prefix}warn_mobile') ?? true,
      warnPolice: prefs.getBool('${_prefix}warn_police') ?? true,
      warnConstruction: prefs.getBool('${_prefix}warn_construction') ?? true,
      warnAccident: prefs.getBool('${_prefix}warn_accident') ?? true,
    );
  }

  /// Update a single setting and persist to SharedPreferences.
  Future<void> updateSetting(BlitzerSettings Function(BlitzerSettings) updater) async {
    final current = state.value ?? const BlitzerSettings();
    final updated = updater(current);
    state = AsyncData(updated);
    await _persist(updated);
  }

  Future<void> _persist(BlitzerSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setInt('${_prefix}alert_dist_fixed', s.alertDistanceFixed),
      prefs.setInt('${_prefix}alert_dist_mobile', s.alertDistanceMobile),
      prefs.setInt('${_prefix}alert_dist_police', s.alertDistancePolice),
      prefs.setBool('${_prefix}early_warning', s.earlyWarningEnabled),
      prefs.setBool('${_prefix}approach_warning', s.approachWarningEnabled),
      prefs.setBool('${_prefix}immediate_warning', s.immediateWarningEnabled),
      prefs.setBool('${_prefix}audio_alerts', s.audioAlertsEnabled),
      prefs.setDouble('${_prefix}audio_volume', s.audioVolume),
      prefs.setString('${_prefix}alert_sound', s.alertSoundType),
      prefs.setBool('${_prefix}nav_sound', s.navSoundEnabled),
      prefs.setBool('${_prefix}warning_sound', s.warningSoundEnabled),
      prefs.setBool('${_prefix}haptic_alerts', s.hapticAlertsEnabled),
      prefs.setString('${_prefix}haptic_intensity', s.hapticIntensity),
      prefs.setBool('${_prefix}auto_follow', s.autoFollowMode),
      prefs.setBool('${_prefix}heading_rotation', s.headingRotation),
      prefs.setDouble('${_prefix}follow_zoom', s.followZoom),
      prefs.setDouble('${_prefix}follow_tilt', s.followTilt),
      prefs.setBool('${_prefix}speed_display', s.speedDisplay),
      prefs.setBool('${_prefix}keep_screen_on', s.keepScreenOn),
      prefs.setBool('${_prefix}auto_3d_nav', s.auto3dNavigation),
      prefs.setBool('${_prefix}always_3d', s.always3d),
      prefs.setString('${_prefix}battery_mode', s.batteryMode),
      prefs.setBool('${_prefix}smoothing_enabled', s.smoothingEnabled),
      prefs.setBool('${_prefix}live_on_map', s.liveOnMap),
      prefs.setBool('${_prefix}avoid_tolls', s.avoidTolls),
      prefs.setBool('${_prefix}avoid_ferries', s.avoidFerries),
      prefs.setBool('${_prefix}avoid_motorways', s.avoidMotorways),
      prefs.setBool('${_prefix}warn_fixed', s.warnFixed),
      prefs.setBool('${_prefix}warn_mobile', s.warnMobile),
      prefs.setBool('${_prefix}warn_police', s.warnPolice),
      prefs.setBool('${_prefix}warn_construction', s.warnConstruction),
      prefs.setBool('${_prefix}warn_accident', s.warnAccident),
    ]);
  }
}
