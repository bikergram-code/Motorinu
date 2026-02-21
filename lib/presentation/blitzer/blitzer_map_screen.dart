import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

import '../../core/community.dart';
import '../../domain/models/saved_place.dart';
import '../../domain/models/user.dart' as app_user;
import '../../domain/xp_calculator.dart';
import '../../data/repositories/blitzer_repository.dart';
import '../../services/osm_blitzer_service.dart';
import '../../data/repositories/ride_repository.dart';
import '../../providers/ride/ride_notifier.dart';
import '../../providers/auth/auth_notifier.dart';
import '../../providers/auth/auth_state.dart';
import '../../providers/blitzer/blitzer_settings_provider.dart';
import '../../providers/blitzer/country_policy_provider.dart';
import '../../providers/blitzer/driving_mode_provider.dart';
import '../../providers/blitzer/navigation_provider.dart';
import '../../providers/blitzer/saved_places_provider.dart';
import '../../providers/core/providers.dart';
import '../../providers/map/live_location_provider.dart';
import '../../services/alert_audio_service.dart';
import '../../services/blitzer_alert_service.dart';
import '../../services/geocoding_service.dart';
import '../../services/live_location_service.dart';
import '../../services/osrm_service.dart';
import '../../services/location_engine.dart';
import '../../services/kalman_filter.dart';
import '../../services/app_mode_controller.dart';
import '../../services/destination_info_service.dart';
import '../../services/android_auto_service.dart';
import '../../services/navigation_tts_service.dart';
import '../../theme/app_theme.dart';

// ─── Default fallback center: Germany ───────────────────────────────────────
const _defaultCenter = LatLng(51.1657, 10.4515);

// ─── Custom marker icon cache (shared across rebuilds) ──────────────────────
final Map<String, BitmapDescriptor> _markerIconCache = {};

// ─── Profile picture nav icon cache ──────────────────────────────────────────
final Map<String, BitmapDescriptor> _navIconCache = {};

/// Creates a circular profile picture marker with accent-colored border.
/// Falls back to a vehicle icon if no avatar URL is available.
Future<BitmapDescriptor> _getProfileNavIcon({
  required String? avatarUrl,
  required Color accentColor,
  required String communityKey,
}) async {
  final cacheKey = '${avatarUrl ?? 'fallback'}_${accentColor.value}';
  if (_navIconCache.containsKey(cacheKey)) return _navIconCache[cacheKey]!;

  const double size = 128;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));

  // Try to load profile picture
  ui.Image? profileImage;
  if (avatarUrl != null && avatarUrl.isNotEmpty) {
    try {
      final response = await http.get(Uri.parse(avatarUrl));
      if (response.statusCode == 200) {
        final codec = await ui.instantiateImageCodec(
          response.bodyBytes,
          targetWidth: size.toInt(),
          targetHeight: size.toInt(),
        );
        final frame = await codec.getNextFrame();
        profileImage = frame.image;
      }
    } catch (e) {
      debugPrint('[NavIcon] Failed to load profile image: $e');
    }
  }

  // Outer glow
  canvas.drawCircle(const Offset(size / 2, size / 2), size / 2,
    Paint()..color = accentColor.withValues(alpha: 0.3));

  // Accent border circle
  canvas.drawCircle(const Offset(size / 2, size / 2), size / 2 - 4,
    Paint()..color = accentColor);

  if (profileImage != null) {
    // Clip to circle and draw profile image
    canvas.save();
    final clipPath = Path()
      ..addOval(Rect.fromCircle(center: const Offset(size / 2, size / 2), radius: size / 2 - 8));
    canvas.clipPath(clipPath);

    final srcRect = Rect.fromLTWH(0, 0, profileImage.width.toDouble(), profileImage.height.toDouble());
    final dstRect = Rect.fromCircle(center: const Offset(size / 2, size / 2), radius: size / 2 - 8);
    canvas.drawImageRect(profileImage, srcRect, dstRect, Paint());
    canvas.restore();
  } else {
    // Fallback: white circle with vehicle icon
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2 - 8,
      Paint()..color = Colors.white);

    final iconData = communityKey == 'bikergram'
        ? Icons.two_wheeler_rounded
        : Icons.directions_car_rounded;
    final tp = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: String.fromCharCode(iconData.codePoint),
        style: TextStyle(
          fontSize: 52,
          fontFamily: iconData.fontFamily,
          package: iconData.fontPackage,
          color: accentColor,
        ),
      )
      ..layout();
    tp.paint(canvas, Offset((size - tp.width) / 2, (size - tp.height) / 2));
  }

  // White inner ring (on top of image)
  canvas.drawCircle(const Offset(size / 2, size / 2), size / 2 - 6,
    Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 3);

  final picture = recorder.endRecording();
  final image = await picture.toImage(size.toInt(), size.toInt());
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  final bytes = byteData!.buffer.asUint8List();

  final descriptor = BitmapDescriptor.bytes(bytes, width: 48, height: 48);
  _navIconCache[cacheKey] = descriptor;
  return descriptor;
}

// ─── Live user profile marker cache ──────────────────────────────────────────
final Map<String, BitmapDescriptor> _liveUserIconCache = {};

/// Creates a circular profile picture marker with green border for live users.
Future<BitmapDescriptor> _getLiveUserMarkerIcon({
  required String? avatarUrl,
  required String displayName,
}) async {
  final cacheKey = 'live_${avatarUrl ?? displayName}';
  if (_liveUserIconCache.containsKey(cacheKey)) return _liveUserIconCache[cacheKey]!;

  const double size = 112;
  const borderColor = Color(0xFF4CAF50); // Green

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));

  // Try to load profile picture
  ui.Image? profileImage;
  if (avatarUrl != null && avatarUrl.isNotEmpty) {
    try {
      final response = await http.get(Uri.parse(avatarUrl));
      if (response.statusCode == 200) {
        final codec = await ui.instantiateImageCodec(
          response.bodyBytes,
          targetWidth: size.toInt(),
          targetHeight: size.toInt(),
        );
        final frame = await codec.getNextFrame();
        profileImage = frame.image;
      }
    } catch (e) {
      debugPrint('[LiveIcon] Failed to load profile image: $e');
    }
  }

  // Outer glow (green)
  canvas.drawCircle(const Offset(size / 2, size / 2), size / 2,
    Paint()..color = borderColor.withValues(alpha: 0.3));

  // Green border circle
  canvas.drawCircle(const Offset(size / 2, size / 2), size / 2 - 4,
    Paint()..color = borderColor);

  if (profileImage != null) {
    // Clip to circle and draw profile image
    canvas.save();
    final clipPath = Path()
      ..addOval(Rect.fromCircle(center: const Offset(size / 2, size / 2), radius: size / 2 - 8));
    canvas.clipPath(clipPath);
    final srcRect = Rect.fromLTWH(0, 0, profileImage.width.toDouble(), profileImage.height.toDouble());
    final dstRect = Rect.fromCircle(center: const Offset(size / 2, size / 2), radius: size / 2 - 8);
    canvas.drawImageRect(profileImage, srcRect, dstRect, Paint());
    canvas.restore();
  } else {
    // Fallback: white circle with first letter
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2 - 8,
      Paint()..color = Colors.white);
    final letter = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    final tp = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: letter,
        style: const TextStyle(fontSize: 44, fontWeight: FontWeight.bold, color: borderColor),
      )
      ..layout();
    tp.paint(canvas, Offset((size - tp.width) / 2, (size - tp.height) / 2));
  }

  // White inner ring (on top of image)
  canvas.drawCircle(const Offset(size / 2, size / 2), size / 2 - 6,
    Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 3);

  final picture = recorder.endRecording();
  final image = await picture.toImage(size.toInt(), size.toInt());
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  final bytes = byteData!.buffer.asUint8List();

  final descriptor = BitmapDescriptor.bytes(bytes, width: 42, height: 42);
  _liveUserIconCache[cacheKey] = descriptor;
  return descriptor;
}

Future<BitmapDescriptor> _getCustomMarkerIcon(String type, {double opacity = 1.0}) async {
  // Cache key includes opacity level (quantized to avoid too many entries)
  final opacityKey = (opacity * 10).round(); // 0-10
  final cacheKey = '${type}_a$opacityKey';
  if (_markerIconCache.containsKey(cacheKey)) return _markerIconCache[cacheKey]!;

  final (iconData, color) = switch (type) {
    'fixed' => (Icons.photo_camera_rounded, Colors.red),
    'fixed_osm' => (Icons.photo_camera_rounded, const Color(0xFF8B0000)), // Dark red for OSM
    'mobile' => (Icons.directions_car_rounded, Colors.orange),
    'construction' => (Icons.construction_rounded, Colors.amber),
    'accident' => (Icons.warning_rounded, Colors.purple),
    'police' => (Icons.local_police_rounded, Colors.blue),
    'workshop' => (Icons.build_rounded, Colors.green),
    'gas_station' => (Icons.local_gas_station_rounded, Colors.cyan),
    'biker_meetup' => (Icons.groups_rounded, Colors.pink),
    'scenic_route' => (Icons.landscape_rounded, Colors.teal),
    _ => (Icons.photo_camera_rounded, Colors.red),
  };

  const double size = 96;
  const double iconSize = 48;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));

  // Apply opacity to all elements
  final alpha = opacity.clamp(0.0, 1.0);

  // Colored circle
  canvas.drawCircle(const Offset(size / 2, size / 2), size / 2,
    Paint()..color = color.withValues(alpha: alpha));
  // White border
  canvas.drawCircle(const Offset(size / 2, size / 2), size / 2 - 3,
    Paint()..color = Colors.white.withValues(alpha: alpha)..style = PaintingStyle.stroke..strokeWidth = 4);

  // Icon via TextPainter (Material Icons are a font)
  final tp = TextPainter(textDirection: TextDirection.ltr)
    ..text = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontSize: iconSize,
        fontFamily: iconData.fontFamily,
        package: iconData.fontPackage,
        color: Colors.white.withValues(alpha: alpha),
      ),
    )
    ..layout();
  tp.paint(canvas, Offset((size - tp.width) / 2, (size - tp.height) / 2));

  final picture = recorder.endRecording();
  final image = await picture.toImage(size.toInt(), size.toInt());
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  final bytes = byteData!.buffer.asUint8List();

  final descriptor = BitmapDescriptor.bytes(bytes, width: 36, height: 36);
  _markerIconCache[cacheKey] = descriptor;
  return descriptor;
}

// ─── Helper: maneuver → icon ────────────────────────────────────────────────
IconData _maneuverIconData(String maneuver) => switch (maneuver) {
  String m when m.contains('uturn') => Icons.u_turn_left_rounded,
  String m when m.contains('roundabout') || m.contains('rotary') => Icons.roundabout_left_rounded,
  String m when m.contains('fork-left') => Icons.fork_left_rounded,
  String m when m.contains('fork-right') => Icons.fork_right_rounded,
  String m when m.contains('ferry') => Icons.directions_boat_rounded,
  String m when m.contains('ramp') => Icons.ramp_right_rounded,
  String m when m.contains('merge') => Icons.merge_rounded,
  String m when m.contains('left') => Icons.turn_left_rounded,
  String m when m.contains('right') => Icons.turn_right_rounded,
  'arrive' => Icons.flag_rounded,
  'depart' => Icons.navigation_rounded,
  'motorway' => Icons.add_road_rounded, // virtual step — overridden by _roadIcon()
  _ => Icons.straight_rounded,
};

// ─── Helper: Detect highway/motorway from road name ──────────────────────
final _highwayPattern = RegExp(r'\b([AaBbEeMm]\s?\d{1,4})\b');

/// Is this road name a highway/autobahn? (A1, B27, E45, M1, etc.)
bool _isHighway(String? roadName) {
  if (roadName == null || roadName.isEmpty) return false;
  return _highwayPattern.hasMatch(roadName);
}

/// Extract highway number from road name (e.g. "A 7" → "A7")
String? _extractHighwayNumber(String? roadName) {
  if (roadName == null) return null;
  final match = _highwayPattern.firstMatch(roadName);
  return match?.group(1)?.replaceAll(' ', '');
}

// ─── Helper: Road badge style by road type (like real German road signs) ────
({Color bg, Color text}) _roadBadgeStyle(String badge) {
  final c = badge.toUpperCase();
  if (c.startsWith('A')) return (bg: const Color(0xFF1565C0), text: Colors.white);  // Autobahn = Blau
  if (c.startsWith('B')) return (bg: const Color(0xFFF9A825), text: Colors.black);  // Bundesstraße = Gelb
  if (c.startsWith('E')) return (bg: const Color(0xFF2E7D32), text: Colors.white);  // Europastraße = Grün
  return (bg: Colors.blue.shade700, text: Colors.white);
}

// ─── Helper: Icon color by road type + maneuver ─────────────────────────────
Color? _roadIconColor(String? badge, String maneuver) {
  if (badge != null) {
    final c = badge.toUpperCase();
    if (c.startsWith('A')) return const Color(0xFF1565C0); // Autobahn blau
    if (c.startsWith('B')) return const Color(0xFFF9A825); // Bundesstraße gelb
    if (c.startsWith('E')) return const Color(0xFF2E7D32); // Europastraße grün
  }
  if (maneuver.contains('roundabout') || maneuver.contains('rotary')) return Colors.purple;
  if (maneuver.contains('ramp') || maneuver.contains('off-ramp') || maneuver.contains('on-ramp')) return Colors.orange.shade700;
  if (maneuver.contains('ferry')) return Colors.blue;
  return null; // accent color als default
}

// ─── Helper: Road icon by road type ─────────────────────────────────────────
IconData _roadIcon(String? badge) {
  if (badge == null) return Icons.add_road_rounded;
  final c = badge.toUpperCase();
  if (c.startsWith('A')) return Icons.add_road_rounded;    // Autobahn
  if (c.startsWith('B')) return Icons.signpost_rounded;    // Bundesstraße
  if (c.startsWith('E')) return Icons.public_rounded;      // Europastraße
  return Icons.add_road_rounded;
}

// ─── Helper: Road type label (German) ───────────────────────────────────────
String _roadTypeLabel(String badge) {
  final c = badge.toUpperCase();
  if (c.startsWith('A')) return 'Autobahn';
  if (c.startsWith('B')) return 'Bundesstraße';
  if (c.startsWith('E')) return 'Europastraße';
  return 'Straße';
}

/// Data class for a smart/merged step in the route overview.
class _SmartStep {
  final String instruction;
  final String maneuver;
  final String? roadName;
  final double distanceMeters;
  final IconData icon;
  final Color? iconColor; // null = use accent
  final bool isHighlight; // highways, ferries, etc.
  final String? badge; // e.g. "A7", "E45"

  _SmartStep({
    required this.instruction,
    required this.maneuver,
    this.roadName,
    required this.distanceMeters,
    required this.icon,
    this.iconColor,
    this.isHighlight = false,
    this.badge,
  });

  String get distanceText {
    if (distanceMeters < 1000) return '${distanceMeters.round()} m';
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }
}

/// Build smart steps: merge consecutive "Weiter/Geradeaus" into one,
/// highlight highways, and make the route readable.
List<_SmartStep> _buildSmartSteps(List<OsrmStep> rawSteps) {
  final smart = <_SmartStep>[];

  for (int i = 0; i < rawSteps.length; i++) {
    final step = rawSteps[i];
    final isContinue = step.maneuver == 'continue' || step.maneuver == 'straight' ||
        step.maneuver == 'new-name' || step.maneuver.startsWith('continue-');
    final isDepart = step.maneuver == 'depart';
    final isArrive = step.maneuver == 'arrive';
    final highway = _extractHighwayNumber(step.roadName);

    // Always show: depart, arrive, turns, roundabouts, ferries, ramps
    if (!isContinue || isDepart || isArrive) {
      String instruction = step.instruction;
      // Enhance highway instructions with road type label
      if (highway != null && !isArrive) {
        final label = _roadTypeLabel(highway);
        instruction = '${step.instruction} ($label $highway)';
      }
      smart.add(_SmartStep(
        instruction: instruction,
        maneuver: step.maneuver,
        roadName: step.roadName,
        distanceMeters: step.distanceMeters,
        icon: _maneuverIconData(step.maneuver),
        isHighlight: highway != null || step.maneuver.contains('ferry') ||
            step.maneuver.contains('roundabout') || step.maneuver.contains('rotary'),
        badge: highway,
        iconColor: _roadIconColor(highway, step.maneuver),
      ));
      continue;
    }

    // For "Weiter/Geradeaus": merge consecutive ones on the same road
    // Only show if it's a highway, or distance > 2km, or road name changes
    if (highway != null) {
      final label = _roadTypeLabel(highway);
      // Highway segment — always show, merge consecutive on same highway
      if (smart.isNotEmpty && smart.last.badge == highway) {
        // Extend the previous highway step
        final prev = smart.removeLast();
        smart.add(_SmartStep(
          instruction: '$label $highway',
          maneuver: 'motorway',
          roadName: step.roadName,
          distanceMeters: prev.distanceMeters + step.distanceMeters,
          icon: _roadIcon(highway),
          isHighlight: true,
          badge: highway,
          iconColor: _roadIconColor(highway, 'motorway'),
        ));
      } else {
        smart.add(_SmartStep(
          instruction: 'Auffahrt $label $highway',
          maneuver: 'motorway',
          roadName: step.roadName,
          distanceMeters: step.distanceMeters,
          icon: _roadIcon(highway),
          isHighlight: true,
          badge: highway,
          iconColor: _roadIconColor(highway, 'motorway'),
        ));
      }
    } else if (step.distanceMeters > 2000) {
      // Long straight segment (> 2km) — show it
      final name = (step.roadName != null && step.roadName!.isNotEmpty)
          ? step.roadName! : 'Straße';
      smart.add(_SmartStep(
        instruction: 'Geradeaus auf $name',
        maneuver: step.maneuver,
        roadName: step.roadName,
        distanceMeters: step.distanceMeters,
        icon: Icons.straight_rounded,
      ));
    } else if (smart.isNotEmpty && !smart.last.isHighlight) {
      // Short segment — merge distance into previous step
      final prev = smart.removeLast();
      smart.add(_SmartStep(
        instruction: prev.instruction,
        maneuver: prev.maneuver,
        roadName: prev.roadName,
        distanceMeters: prev.distanceMeters + step.distanceMeters,
        icon: prev.icon,
        isHighlight: prev.isHighlight,
        badge: prev.badge,
        iconColor: prev.iconColor,
      ));
    }
    // else: skip very short "Weiter" steps
  }

  return smart;
}

// ═════════════════════════════════════════════════════════════════════════════
// MAIN SCREEN
// ═════════════════════════════════════════════════════════════════════════════

class BlitzerMapScreen extends ConsumerStatefulWidget {
  const BlitzerMapScreen({super.key});

  @override
  ConsumerState<BlitzerMapScreen> createState() => _BlitzerMapScreenState();
}

class _BlitzerMapScreenState extends ConsumerState<BlitzerMapScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;

  // Loading state
  bool _locationReady = false;
  bool _locationFailed = false;

  // Reports
  bool _isLoadingReports = false;
  List<BlitzerReport> _reports = [];
  Set<Marker> _blitzerMarkers = {};

  // Cached sets for GoogleMap (avoid creating new objects in build)
  Set<Marker> _cachedAllMarkers = {};
  Set<Polyline> _cachedPolylines = {};
  Set<Circle> _cachedDangerZones = {};

  // Country policy state
  String? _detectedCountryCode;
  bool _countryDetectionInProgress = false;
  DateTime? _lastCountryCheck;

  // Distance-based marker opacity refresh
  DateTime? _lastMarkerOpacityRefresh;

  // Search
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  bool _showSearchResults = false;
  Timer? _searchDebounce;
  List<Map<String, dynamic>> _filteredHistory = []; // Sofortige Historie-Vorschläge
  bool _historyExpanded = true; // Letzte Ziele auf-/zuklappbar

  // Spracheingabe
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;

  // Live GPS
  StreamSubscription<Map<String, LiveUserPosition>>? _liveSub;
  Map<String, LiveUserPosition> _liveUsers = {};
  final Map<String, BitmapDescriptor> _liveUserIcons = {};

  // Location Engine (GPS pipeline with Kalman smoothing)
  LocationEngine? _locationEngine;
  StreamSubscription<SmoothedPosition>? _navSmoothedStream;
  StreamSubscription<SmoothedPosition>? _bgLocationStream; // Background blitzer checks (non-nav mode)

  // Navigation mode
  StreamSubscription<Position>? _navPositionStream;
  String? _blitzerWarning;
  Timer? _blitzerWarningTimer;
  Timer? _autoReCenterTimer; // Auto re-center after user pans/zooms (3s)

  // ref.listenManual subscriptions (MUST cancel in dispose to avoid framework assertion)
  ProviderSubscription? _routeChangeSub;

  // Map view mode (satellite as default — better for bikers)
  MapType _mapType = MapType.hybrid;
  bool _is3D = false;

  // Cached nav state (avoid ref.read() in async callbacks after dispose)
  OsrmRoute? _cachedRoute;
  LatLng? _cachedDestination;
  String? _cachedDestinationName;
  Color _cachedAccentColor = AppTheme.accentDark;
  Community? _cachedCommunity;

  // Community-specific nav icon (moped for Biker, car for Cars)
  BitmapDescriptor? _navMarkerIcon;
  bool _isNavigatingCached = false;

  // Route panel: expandable steps
  bool _stepsExpanded = false;
  bool _routeSheetOpen = false;
  bool _routeCancelled = false; // Prevents auto-reopen after Abbrechen
  bool _routePanelExpanded = true; // true = volles Panel, false = nur Peek (Buttons)
  bool _showProfileBubble = false; // Profil-Bubble über dem Marker
  LiveUserPosition? _selectedLiveUser; // Angeklickter Live-User für Bubble
  int _profileTotalLikes = 0; // Eigene Gesamtlikes für Profil-Bubble

  // ── Smooth Navigation Camera ──
  double _smoothBearing = 0;      // Interpolated bearing for smooth rotation
  double _targetBearing = 0;      // Target bearing from GPS
  double _smoothZoom = 17;        // Interpolated zoom for smooth zoom transitions
  Timer? _cameraAnimTimer;        // 60fps camera interpolation timer
  int _polylineClosestIdx = 0;    // Cached closest polyline index (optimization)
  int _navMarkerRebuildSkip = 0;  // Skip marker rebuilds (every Nth update)
  bool _navCameraDirty = false;   // Whether camera needs update
  double _lastNavLat = 0;
  double _lastNavLng = 0;

  // ── Navigation Ride Tracking (XP) ──
  DateTime? _navStartTime;
  double _navDistanceMeters = 0;
  double _navMaxSpeed = 0; // km/h
  Position? _navLastPosition;

  // Supabase Realtime: live sync of blitzer reports across users
  RealtimeChannel? _blitzerRealtimeChannel;
  // Polling-Fallback: regelmäßig Reports neu laden (30s)
  Timer? _reportPollingTimer;

  // Extra guard: set to true in dispose() to block ALL async callbacks
  bool _disposed = false;

  // ── Community User Map (PLZ-based offline markers) ──
  Set<Marker> _communityUserMarkers = {};
  bool _showCommunityUsers = true; // Toggleable layer
  int _communityUserCount = 0;
  List<Map<String, dynamic>> _communityUsersData = []; // Raw user data for list sheet

  @override
  void initState() {
    super.initState();
    _initLocation();
    _listenToLiveUsers();
    _autoStartLive();
    _loadCommunityUsers();
    _preloadMarkerIcons();
    _loadSearchHistory();

    // Initialize audio service early so tones are ready for all modes
    AlertAudioService.instance.init();

    // Initialize TTS for navigation voice announcements
    NavigationTtsService.instance.init().then((_) {
      // Apply saved voice profile
      final settings = ref.read(blitzerSettingsProvider).value;
      if (settings != null) {
        NavigationTtsService.instance.setVoice(settings.ttsVoice);
      }
    });

    // Spracheingabe initialisieren
    _speech.initialize(
      onStatus: (status) {
        if (mounted) setState(() => _isListening = status == 'listening');
      },
      onError: (_) {
        if (mounted) setState(() => _isListening = false);
      },
    ).then((available) {
      _speechAvailable = available;
      debugPrint('[Speech] available=$available');
    });

    // Rebuild when search field gains/loses focus (show/hide history)
    _searchFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    _preloadNavIcon();

    // Load own total likes for profile bubble
    _loadProfileTotalLikes();

    // Register Speed-Dial items for the Blitzer tab
    _registerSpeedDialItems();

    // Apply "always 3D" setting on startup
    final initSettings = ref.read(blitzerSettingsProvider).value;
    if (initSettings != null && initSettings.always3d) {
      _is3D = true;
    }

    // ── Realtime: Live-Sync neuer Blitzer-Meldungen ──
    _startBlitzerRealtime();

    // Listen for route/destination changes to rebuild cached polylines & markers
    _routeChangeSub = ref.listenManual(
      navigationProvider.select((s) => (s.route, s.destination, s.destinationName)),
      (prev, next) {
        if (_disposed || !mounted) return;
        // Cache nav values so we don't need ref.read() in async callbacks
        _cachedRoute = next.$1;
        _cachedDestination = next.$2;
        _cachedDestinationName = next.$3;
        _rebuildCachedPolylines();
        _rebuildCachedMarkers();
        setState(() {});

        // ═══ AUTO-OPEN ROUTE SHEET ═══
        // Wenn eine neue Route berechnet wurde, Sheet inline anzeigen (kein Navigator.push)
        final hasNewRoute = next.$1 != null && next.$2 != null;
        debugPrint('[RouteSheet] LISTENER: hasNewRoute=$hasNewRoute, _routeSheetOpen=$_routeSheetOpen, _routeCancelled=$_routeCancelled');
        if (hasNewRoute && !_routeSheetOpen && !_routeCancelled) {
          debugPrint('[RouteSheet] LISTENER → Sheet wird angezeigt');
          _routeSheetOpen = true;
          // setState wird oben schon aufgerufen (Zeile 518)
        }
      },
    );

    // ── Android Auto: init service and set position callback ──
    final autoService = ref.read(androidAutoServiceProvider);
    autoService.init();
    autoService.getCurrentPosition = () {
      if (_currentPosition != null) {
        return LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
      }
      return _defaultCenter;
    };
  }

  @override
  void dispose() {
    _disposed = true; // Block ALL async callbacks immediately
    // Cancel streams & subscriptions FIRST
    _reportPollingTimer?.cancel();
    _blitzerRealtimeChannel?.unsubscribe();
    _routeChangeSub?.close();
    _liveSub?.cancel();
    _bgLocationStream?.cancel();
    _navSmoothedStream?.cancel();
    _navPositionStream?.cancel();
    _blitzerWarningTimer?.cancel();
    _autoReCenterTimer?.cancel();
    _cameraAnimTimer?.cancel();
    _searchDebounce?.cancel();
    _speech.stop();
    // Stop LocationEngine
    _locationEngine?.stop();
    // Then dispose controllers
    _mapController?.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// Register Blitzer-specific Speed-Dial items in the global provider.
  /// Each onTap closure is guarded with _disposed/mounted checks because
  /// the closures capture `this` and may be called after dispose (e.g. when
  /// user switches tabs while Speed-Dial is open).
  void _registerSpeedDialItems() {
    Future.microtask(() {
      if (_disposed || !mounted) return;
      final isSat = _mapType == MapType.satellite;
      ref.read(speedDialItemsProvider.notifier).register([
        SpeedDialItem(
          icon: Icons.my_location_rounded,
          label: 'Standort',
          color: Colors.blue,
          onTap: () {
            if (_disposed || !mounted) return;
            if (_currentPosition != null) {
              _mapController?.animateCamera(CameraUpdate.newLatLngZoom(
                LatLng(_currentPosition!.latitude, _currentPosition!.longitude), 15.0));
            } else {
              setState(() { _locationReady = false; _locationFailed = false; });
              _initLocation();
            }
          },
        ),
        SpeedDialItem(
          icon: isSat ? Icons.map_rounded : Icons.satellite_alt_rounded,
          label: isSat ? 'Karte' : 'Satellit',
          color: Colors.indigo,
          onTap: () { if (_disposed || !mounted) return; _toggleSatellite(); },
        ),
        SpeedDialItem(
          icon: Icons.threed_rotation_rounded,
          label: _is3D ? '2D' : '3D',
          color: _is3D ? Colors.teal : Colors.deepPurple,
          onTap: () { if (_disposed || !mounted) return; _toggle3D(); },
        ),
        SpeedDialItem(
          icon: Icons.warning_amber_rounded,
          label: 'Melden',
          color: Colors.red,
          onTap: () { if (_disposed || !mounted) return; _showCreateReportSheet(); },
        ),
        SpeedDialItem(
          icon: Icons.navigation_rounded,
          label: 'Navigation',
          color: _cachedAccentColor,
          onTap: () { if (_disposed || !mounted) return; _searchFocusNode.requestFocus(); },
        ),
        SpeedDialItem(
          icon: Icons.settings_rounded,
          label: 'Blitzer-Einst.',
          color: Colors.grey,
          onTap: () { if (_disposed || !mounted) return; context.push('/blitzer-settings'); },
        ),
        SpeedDialItem(
          icon: Icons.navigation_rounded,
          label: 'Navi-Einst.',
          color: Colors.teal,
          onTap: () { if (_disposed || !mounted) return; context.push('/navigation-settings'); },
        ),
      ]);
    });
  }

  // ─── Preload custom marker icons ──────────────────────────────────────

  Future<void> _preloadMarkerIcons() async {
    const types = ['fixed', 'fixed_osm', 'mobile', 'construction', 'accident', 'police', 'workshop', 'gas_station', 'biker_meetup', 'scenic_route'];
    for (final type in types) {
      await _getCustomMarkerIcon(type);
    }
    debugPrint('[Blitzer] Marker icons preloaded');
    if (_reports.isNotEmpty && !_disposed && mounted) {
      _buildBlitzerMarkers();
      _rebuildCachedMarkers();
      setState(() {});
    }
  }

  /// Preload the navigation icon using the user's profile picture.
  Future<void> _preloadNavIcon() async {
    final community = ref.read(communityProvider);
    _cachedCommunity = community;
    if (community == null) return;

    // Get user's avatar URL
    String? avatarUrl;
    final authState = ref.read(authNotifierProvider);
    if (authState is Authenticated) {
      avatarUrl = authState.user.avatarUrl;
    }

    final icon = await _getProfileNavIcon(
      avatarUrl: avatarUrl,
      accentColor: community.accentColor,
      communityKey: community.name,
    );
    if (_disposed || !mounted) return;
    _navMarkerIcon = icon;
    debugPrint('[Blitzer] Nav icon preloaded (profile pic: ${avatarUrl != null})');
  }

  // ─── Cached marker/polyline rebuilders ────────────────────────────────

  void _rebuildCachedMarkers() {
    if (_disposed || !mounted) return;
    final all = <Marker>{..._blitzerMarkers};

    // Community user markers (PLZ-based, dimmed)
    if (_showCommunityUsers) {
      // Don't add PLZ markers for users who are already live (avoid duplicates)
      final liveUserIds = _liveUsers.keys.toSet();
      for (final marker in _communityUserMarkers) {
        final plzUserId = marker.markerId.value.replaceFirst('plz_', '');
        if (!liveUserIds.contains(plzUserId)) {
          all.add(marker);
        }
      }
    }

    // Live user markers (profile picture with green border, tap → profile)
    for (final user in _liveUsers.values) {
      all.add(Marker(
        markerId: MarkerId('live_${user.userId}'),
        position: LatLng(user.lat, user.lng),
        infoWindow: InfoWindow(
          title: '${user.displayName} (Live)',
          snippet: '${user.speed.toStringAsFixed(0)} km/h',
        ),
        icon: _liveUserIcons[user.userId] ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        anchor: const Offset(0.5, 0.5),
        flat: true,
        zIndex: 10,
        onTap: () {
          if (mounted) {
            setState(() {
              _selectedLiveUser = _selectedLiveUser?.userId == user.userId ? null : user;
              _showProfileBubble = false;
            });
          }
        },
      ));
    }

    // Destination marker (use cached nav state to avoid ref.read after dispose)
    if (_cachedDestination != null) {
      all.add(Marker(
        markerId: const MarkerId('destination'),
        position: _cachedDestination!,
        infoWindow: InfoWindow(title: _cachedDestinationName ?? 'Ziel'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
        zIndex: 20,
      ));
    }

    // Community-specific vehicle marker — IMMER sichtbar (Navigation + Normal)
    // Tippen öffnet das eigene Profil
    if (_currentPosition != null && _navMarkerIcon != null) {
      all.add(Marker(
        markerId: const MarkerId('my_vehicle'),
        position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        icon: _navMarkerIcon!,
        rotation: 0,
        anchor: const Offset(0.5, 0.5),
        flat: true,
        zIndex: 30,
        onTap: () {
          if (mounted) {
            setState(() => _showProfileBubble = !_showProfileBubble);
          }
        },
      ));
    }

    _cachedAllMarkers = all;
  }

  void _rebuildCachedPolylines() {
    if (_disposed || !mounted) return;
    if (_cachedRoute == null) {
      _cachedPolylines = {};
      return;
    }

    // Only show the route AHEAD of the user (trim passed points)
    final allPoints = _cachedRoute!.polylinePoints;
    List<LatLng> aheadPoints = allPoints;

    if (_currentPosition != null && allPoints.length > 2) {
      final userLat = _currentPosition!.latitude;
      final userLng = _currentPosition!.longitude;

      // Find the closest point on the route to the user's current position
      double minDist = double.infinity;
      int closestIdx = 0;
      for (int i = 0; i < allPoints.length; i++) {
        final d = Geolocator.distanceBetween(
          userLat, userLng,
          allPoints[i].latitude, allPoints[i].longitude,
        );
        if (d < minDist) {
          minDist = d;
          closestIdx = i;
        }
      }

      // Show from the closest point onward (+ include user's current pos as start)
      if (closestIdx < allPoints.length - 1) {
        aheadPoints = [
          LatLng(userLat, userLng),
          ...allPoints.sublist(closestIdx + 1),
        ];
      }
    }

    _cachedPolylines = {
      Polyline(
        polylineId: const PolylineId('route'),
        points: aheadPoints,
        color: _cachedAccentColor,
        width: 5,
      ),
    };
  }

  // ─── Live GPS ──────────────────────────────────────────────────────────

  /// Load all profile icons for [users] first, then update the map.
  /// This prevents showing the default green arrow while the icon is loading.
  Future<void> _loadIconsThenApply(Map<String, LiveUserPosition> users) async {
    for (final user in users.values) {
      if (!_liveUserIcons.containsKey(user.userId)) {
        try {
          final icon = await _getLiveUserMarkerIcon(
            avatarUrl: user.avatarUrl,
            displayName: user.displayName,
          );
          if (_disposed || !mounted) return;
          _liveUserIcons[user.userId] = icon;
        } catch (_) {}
      }
    }
    if (_disposed || !mounted) return;
    _liveUsers = users;
    _rebuildCachedMarkers();
    setState(() {});
  }

  void _listenToLiveUsers() {
    final service = ref.read(liveLocationServiceProvider);
    // Seed with current snapshot after loading icons to avoid green arrow flash
    final initialUsers = Map<String, LiveUserPosition>.from(service.nearbyUsers);
    if (initialUsers.isNotEmpty) {
      _loadIconsThenApply(initialUsers);
    }
    _liveSub = service.nearbyUsersStream.listen((users) async {
      if (_disposed || !mounted) return;

      // Preload profile icons for ALL users BEFORE updating the map,
      // so we never show the default green arrow fallback.
      for (final user in users.values) {
        if (!_liveUserIcons.containsKey(user.userId)) {
          try {
            final icon = await _getLiveUserMarkerIcon(
              avatarUrl: user.avatarUrl,
              displayName: user.displayName,
            );
            if (_disposed || !mounted) return;
            _liveUserIcons[user.userId] = icon;
          } catch (_) {}
        }
      }
      // Clean up icons for users no longer live
      _liveUserIcons.removeWhere((id, _) => !users.containsKey(id));

      // Update _liveUsers only after icons are ready → no green arrow flash
      _liveUsers = users;

      if (_disposed || !mounted) return;
      _rebuildCachedMarkers();
      setState(() {});
    });
  }

  // ─── Community User Map (PLZ-based offline markers) ────────────────

  /// Load all community users with postal codes and display them as dimmed markers.
  Future<void> _loadCommunityUsers() async {
    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      final data = await Supabase.instance.client
          .from('profiles')
          .select('id, username, display_name, avatar_url, postal_code')
          .not('postal_code', 'is', null);

      final markers = <Marker>{};
      final usersData = <Map<String, dynamic>>[];

      for (final profile in data) {
        final postalCode = profile['postal_code'] as String?;
        if (postalCode == null || postalCode.isEmpty) continue;
        final coords = _plzToCoords(postalCode);
        if (coords == null) continue;

        final displayName = profile['display_name'] ?? profile['username'] ?? 'User';
        final isMe = profile['id'] == currentUserId;

        usersData.add({
          ...profile,
          'lat': coords.latitude,
          'lng': coords.longitude,
          'is_me': isMe,
        });

        markers.add(Marker(
          markerId: MarkerId('plz_${profile['id']}'),
          position: coords,
          infoWindow: InfoWindow(
            title: isMe ? '$displayName (Du)' : displayName as String,
            snippet: 'PLZ: $postalCode',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            isMe ? BitmapDescriptor.hueAzure : BitmapDescriptor.hueOrange,
          ),
          alpha: 0.35, // Dimmed for offline/PLZ markers
          zIndex: 1, // Below blitzer markers and live users
        ));
      }

      if (_disposed || !mounted) return;
      setState(() {
        _communityUserMarkers = markers;
        _communityUserCount = markers.length;
        _communityUsersData = usersData;
      });
      _rebuildCachedMarkers();
    } catch (e) {
      debugPrint('[CommunityUsers] Error loading: $e');
    }
  }

  /// Convert German PLZ to approximate coordinates.
  LatLng? _plzToCoords(String plz) {
    if (plz.isEmpty) return null;
    final code = int.tryParse(plz.replaceAll(RegExp(r'[^0-9]'), ''));
    if (code == null) return null;

    final region = code ~/ 10000;
    return switch (region) {
      0 => LatLng(51.05 + (code % 10000) * 0.00005, 13.74 + (code % 1000) * 0.0003),
      1 => LatLng(52.52 + (code % 10000) * 0.00004, 13.40 + (code % 1000) * 0.0002),
      2 => LatLng(53.55 + (code % 10000) * 0.00003, 9.99 + (code % 1000) * 0.0003),
      3 => LatLng(52.37 + (code % 10000) * 0.00004, 9.74 + (code % 1000) * 0.0002),
      4 => LatLng(51.48 + (code % 10000) * 0.00003, 7.45 + (code % 1000) * 0.0002),
      5 => LatLng(50.94 + (code % 10000) * 0.00003, 6.96 + (code % 1000) * 0.0003),
      6 => LatLng(50.11 + (code % 10000) * 0.00004, 8.68 + (code % 1000) * 0.0002),
      7 => LatLng(48.78 + (code % 10000) * 0.00004, 9.18 + (code % 1000) * 0.0002),
      8 => LatLng(48.14 + (code % 10000) * 0.00004, 11.58 + (code % 1000) * 0.0002),
      9 => LatLng(49.45 + (code % 10000) * 0.00004, 11.08 + (code % 1000) * 0.0002),
      _ => const LatLng(51.16, 10.45),
    };
  }

  /// Load total likes count for the profile bubble.
  void _loadProfileTotalLikes() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_disposed || !mounted) return;
      final authState = ref.read(authNotifierProvider);
      if (authState is! Authenticated) return;
      try {
        final profileRepo = ref.read(profileRepositoryProvider);
        final likes = await profileRepo.getTotalLikes(authState.user.id);
        if (!_disposed && mounted) {
          setState(() => _profileTotalLikes = likes);
        }
      } catch (e) {
        debugPrint('[ProfileBubble] Could not load total likes: $e');
      }
    });
  }

  /// Helper widget for stats in user bubbles (Follower, Likes).
  Widget _bubbleStat(IconData icon, String value, String label, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark ? Colors.white70 : Colors.black54;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(value, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
        ]),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: mutedColor)),
      ],
    );
  }

  /// Helper: start live broadcasting with follower/likes stats.
  Future<void> _startLiveWithStats(app_user.User user) async {
    final service = ref.read(liveLocationServiceProvider);
    if (service.isLive) return;

    // Load follower count + total likes in parallel (fire-and-forget on error)
    int followers = user.followerCount;
    int totalLikes = 0;
    try {
      final profileRepo = ref.read(profileRepositoryProvider);
      final results = await Future.wait([
        profileRepo.getFollowerCount(user.id),
        profileRepo.getTotalLikes(user.id),
      ]);
      followers = results[0];
      totalLikes = results[1];
    } catch (e) {
      debugPrint('[LiveGPS] Could not load stats: $e');
    }

    final community = ref.read(communityProvider);

    await service.goLive(
      userId: user.id,
      displayName: user.displayName ?? user.bikername ?? user.username,
      avatarUrl: user.avatarUrl,
      plzRegion: user.postalCode,
      xpTotal: user.xpTotal ?? 0,
      bikeName: user.bikername,
      followerCount: followers,
      totalLikes: totalLikes,
      community: community?.name ?? 'bikergram',
    );
  }

  /// Auto-start live if liveOnMap setting is enabled.
  /// Uses a post-frame callback to ensure ref is ready.
  void _autoStartLive() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_disposed || !mounted) return;

      // Listen to settings — when loaded, check liveOnMap
      final settingsAsync = ref.read(blitzerSettingsProvider);
      BlitzerSettings? settings = settingsAsync.value;

      if (settings == null) {
        // Settings still loading — listen for changes
        ref.listenManual(blitzerSettingsProvider, (prev, next) async {
          if (_disposed || !mounted) return;
          final s = next.value;
          if (s == null) return;
          if (!s.liveOnMap) return;

          final service = ref.read(liveLocationServiceProvider);
          if (service.isLive) return;

          final authState = ref.read(authNotifierProvider);
          if (authState is! Authenticated) return;

          final user = authState.user;
          debugPrint('[LiveGPS] Auto-starting live for ${user.displayName ?? user.username}...');
          await _startLiveWithStats(user);
          if (_disposed || !mounted) return;
          ref.read(isLiveProvider.notifier).set(true);
          debugPrint('[LiveGPS] Auto-started live (liveOnMap=true)');
        });
        return;
      }

      if (!settings.liveOnMap) {
        debugPrint('[LiveGPS] Auto-start skipped (liveOnMap=false)');
        return;
      }

      final service = ref.read(liveLocationServiceProvider);
      if (service.isLive) return;

      final authState = ref.read(authNotifierProvider);
      if (authState is! Authenticated) {
        debugPrint('[LiveGPS] Auto-start skipped (not authenticated)');
        return;
      }

      final user = authState.user;
      debugPrint('[LiveGPS] Auto-starting live for ${user.displayName ?? user.username}...');
      await _startLiveWithStats(user);
      if (_disposed || !mounted) return;
      ref.read(isLiveProvider.notifier).set(true);
      debugPrint('[LiveGPS] Auto-started live (liveOnMap=true)');
    });
  }

  Future<void> _toggleLive() async {
    if (_disposed || !mounted) return;
    final service = ref.read(liveLocationServiceProvider);
    final authState = ref.read(authNotifierProvider);

    if (service.isLive) {
      await service.goOffline();
      if (_disposed || !mounted) return;
      ref.read(isLiveProvider.notifier).set(false);
    } else {
      if (authState is! Authenticated) return;
      final user = authState.user;
      await _startLiveWithStats(user);
      if (_disposed || !mounted) return;
      ref.read(isLiveProvider.notifier).set(true);
    }
    if (!_disposed && mounted) setState(() {});
  }

  // ─── Background Blitzer Checks (non-navigation mode) ─────────────────

  /// Runs blitzer proximity checks even when NOT navigating.
  /// When navigation IS active, _navSmoothedStream handles checks instead.
  void _onBgLocationUpdate(SmoothedPosition smoothed) {
    if (_disposed || !mounted) return;

    // Skip if navigation is active — nav stream handles everything
    if (_isNavigatingCached) return;

    final now = DateTime.now();

    // Periodic country re-detection (every 5 minutes, for cross-border travel)
    if (_lastCountryCheck == null ||
        now.difference(_lastCountryCheck!) > const Duration(minutes: 5)) {
      _lastCountryCheck = now;
      _detectCountryFromPosition(smoothed.smoothedLat, smoothed.smoothedLng);
    }

    // Refresh marker opacity every 30 seconds (distance-based transparency)
    if (_reports.isNotEmpty &&
        (_lastMarkerOpacityRefresh == null ||
            now.difference(_lastMarkerOpacityRefresh!) > const Duration(seconds: 30))) {
      _lastMarkerOpacityRefresh = now;
      _buildBlitzerMarkers();
    }

    // Update current position for map display
    final pos = Position(
      latitude: smoothed.smoothedLat,
      longitude: smoothed.smoothedLng,
      timestamp: smoothed.timestamp,
      accuracy: smoothed.accuracy,
      altitude: smoothed.altitude,
      altitudeAccuracy: 0,
      heading: smoothed.smoothedHeading,
      headingAccuracy: 0,
      speed: smoothed.smoothedSpeed / 3.6, // km/h → m/s
      speedAccuracy: 0,
    );
    _currentPosition = pos;

    // Run blitzer alert check via DrivingModeProvider
    if (_reports.isNotEmpty) {
      // Activate driving mode if not already active (needed for alert checks)
      final drivingState = ref.read(drivingModeProvider);
      if (!drivingState.isActive) {
        ref.read(drivingModeProvider.notifier).activate(keepScreenOn: false);
      }

      ref.read(drivingModeProvider.notifier).processSmoothedUpdate(
        smoothed: smoothed,
        rawPos: pos,
        reports: _reports,
      );

      // Update blitzer warning banner
      final updatedState = ref.read(drivingModeProvider);
      if (updatedState.hasWarning) {
        final warning = updatedState.primaryAlert!.warningText;
        if (warning != _blitzerWarning) {
          setState(() => _blitzerWarning = warning);
          _blitzerWarningTimer?.cancel();
          _blitzerWarningTimer = Timer(const Duration(seconds: 10), () {
            if (!_disposed && mounted) {
              setState(() => _blitzerWarning = null);
              ref.read(drivingModeProvider.notifier).dismissAlert();
            }
          });
        }
      } else if (_blitzerWarning != null && updatedState.activeAlerts.isEmpty) {
        setState(() => _blitzerWarning = null);
        _blitzerWarningTimer?.cancel();
      }
    }
  }

  // ─── Location ─────────────────────────────────────────────────────────

  Future<void> _initLocation() async {
    try {
      debugPrint('[Blitzer] _initLocation START');

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[Blitzer] GPS service disabled');
        if (mounted) setState(() { _locationReady = true; _locationFailed = true; });
        _loadReports();
        return;
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        debugPrint('[Blitzer] GPS permission denied');
        if (mounted) setState(() { _locationReady = true; _locationFailed = true; });
        _loadReports();
        return;
      }

      // Initialize LocationEngine (Kalman-smoothed GPS pipeline)
      _locationEngine = ref.read(locationEngineProvider);
      await _locationEngine!.start(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      );

      // Background listener for blitzer checks in non-navigation mode
      _bgLocationStream?.cancel();
      _bgLocationStream = _locationEngine!.positionStream.listen(_onBgLocationUpdate);

      // 1) Try last known position first (instant, from LocationEngine cache)
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && mounted) {
        debugPrint('[Blitzer] Using last known: ${lastKnown.latitude}, ${lastKnown.longitude}');
        setState(() {
          _currentPosition = Position(
            latitude: lastKnown.latitude, longitude: lastKnown.longitude,
            timestamp: lastKnown.timestamp, accuracy: lastKnown.accuracy,
            altitude: lastKnown.altitude, altitudeAccuracy: lastKnown.altitudeAccuracy,
            heading: lastKnown.heading, headingAccuracy: lastKnown.headingAccuracy,
            speed: lastKnown.speed, speedAccuracy: lastKnown.speedAccuracy,
          );
          _locationReady = true;
          _locationFailed = false;
        });
        // Detect country from initial position (async, non-blocking)
        _detectCountryFromPosition(lastKnown.latitude, lastKnown.longitude);
        _loadReports();
      }

      // 2) Wait for first smoothed position from LocationEngine
      SmoothedPosition? smoothedPos;
      try {
        smoothedPos = await _locationEngine!.positionStream.first.timeout(
          const Duration(seconds: 8),
        );
      } catch (_) {
        debugPrint('[Blitzer] Timeout waiting for LocationEngine first position');
      }

      if (!mounted) return;

      if (smoothedPos != null) {
        debugPrint('[Blitzer] Got smoothed position: ${smoothedPos.smoothedLat}, ${smoothedPos.smoothedLng} (accuracy: ${smoothedPos.accuracy}m, quality: ${smoothedPos.quality.name})');
        final pos = Position(
          latitude: smoothedPos.smoothedLat,
          longitude: smoothedPos.smoothedLng,
          timestamp: smoothedPos.timestamp,
          accuracy: smoothedPos.accuracy,
          altitude: smoothedPos.altitude,
          altitudeAccuracy: 0,
          heading: smoothedPos.smoothedHeading,
          headingAccuracy: 0,
          speed: smoothedPos.smoothedSpeed / 3.6,
          speedAccuracy: 0,
        );
        setState(() {
          _currentPosition = pos;
          _locationReady = true;
          _locationFailed = false;
        });
        _mapController?.animateCamera(CameraUpdate.newLatLng(
          LatLng(pos.latitude, pos.longitude),
        ));
        if (lastKnown == null) _loadReports();
      } else if (!_locationReady) {
        // Fallback: try direct Geolocator
        try {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
          );
          if (!mounted) return;
          setState(() {
            _currentPosition = pos;
            _locationReady = true;
            _locationFailed = false;
          });
          _mapController?.animateCamera(CameraUpdate.newLatLng(
            LatLng(pos.latitude, pos.longitude),
          ));
          if (lastKnown == null) _loadReports();
        } catch (e2) {
          debugPrint('[Blitzer] Fallback position also failed: $e2');
        }
      }
    } catch (e) {
      debugPrint('[Blitzer] Location error: $e');
      if (mounted && !_locationReady) {
        setState(() { _locationReady = true; _locationFailed = true; });
        _loadReports();
      }
    }
  }

  // ─── Country Detection (for Blitzer compliance) ─────────────────────

  /// Detect country from GPS position and load the appropriate policy.
  /// Called on first location fix and periodically when user moves significantly.
  Future<void> _detectCountryFromPosition(double lat, double lng) async {
    if (_countryDetectionInProgress) return;
    _countryDetectionInProgress = true;

    try {
      final geocoding = GeocodingService();
      final countryCode = await geocoding.reverseGeocodeCountryCode(lat, lng);

      if (!mounted || _disposed) return;

      if (countryCode != null && countryCode != _detectedCountryCode) {
        debugPrint('[Blitzer] Country detected: $countryCode (was: $_detectedCountryCode)');
        _detectedCountryCode = countryCode;

        // Load policy for this country
        await ref.read(countryPolicyProvider.notifier).loadPolicy(countryCode);

        if (!mounted || _disposed) return;

        // Reload reports with new policy
        _loadReports();
      }
    } catch (e) {
      debugPrint('[Blitzer] Country detection error: $e');
    } finally {
      _countryDetectionInProgress = false;
    }
  }

  // ─── Reports ──────────────────────────────────────────────────────────

  Future<void> _loadReports() async {
    if (_isLoadingReports) return;
    setState(() => _isLoadingReports = true);

    // Check country policy — if mode is 'off', don't load reports
    final policyState = ref.read(countryPolicyProvider);
    final policy = policyState.policy;
    if (policy != null && policy.isOff) {
      _reports = [];
      _isLoadingReports = false;
      _buildBlitzerMarkers();
      _rebuildCachedMarkers();
      setState(() {});
      debugPrint('[Blitzer] Country ${policy.countryCode}: mode=off → skipping report load');
      return;
    }

    try {
      final repo = ref.read(blitzerRepositoryProvider);
      List<BlitzerReport> communityReports;
      if (_currentPosition != null) {
        communityReports = await repo.getNearbyReportsWithPolicy(
          latitude: _currentPosition!.latitude,
          longitude: _currentPosition!.longitude,
          policy: policy,
          radiusKm: 50,
        );
      } else {
        communityReports = await repo.getAllActiveReports();
      }
      debugPrint('[Blitzer] Loaded ${communityReports.length} community reports');

      // Fetch OSM stationäre Blitzer (cached, refreshed daily)
      List<BlitzerReport> osmReports = [];
      if (_currentPosition != null) {
        try {
          final osmCameras = await OsmBlitzerService.instance.getNearby(
            latitude: _currentPosition!.latitude,
            longitude: _currentPosition!.longitude,
            radiusMeters: 50000,
          );
          osmReports = osmCameras.map((c) => BlitzerReport.fromOsm(c)).toList();
          debugPrint('[Blitzer] Loaded ${osmReports.length} OSM speed cameras');
        } catch (e) {
          debugPrint('[Blitzer] OSM load error: $e');
        }
      }

      if (!mounted) return;

      // Merge: community reports + OSM (deduplicate by proximity)
      final merged = [...communityReports];
      for (final osm in osmReports) {
        // Skip OSM camera if a community report exists within 50m
        final hasCommunityNearby = communityReports.any((c) =>
            c.type == 'fixed' &&
            _approxDistanceMeters(c.latitude, c.longitude, osm.latitude, osm.longitude) < 50);
        if (!hasCommunityNearby) {
          merged.add(osm);
        }
      }

      _reports = merged;
      _isLoadingReports = false;
      _buildBlitzerMarkers();
      _rebuildCachedMarkers();
      setState(() {});
      debugPrint('[Blitzer] Total: ${merged.length} reports (${communityReports.length} community + ${osmReports.length} OSM)');
    } catch (e) {
      debugPrint('[Blitzer] Load reports error: $e');
      if (mounted) setState(() => _isLoadingReports = false);
    }
  }

  // ─── Realtime + Polling: Live-Sync neuer Blitzer-Meldungen ─────────
  void _startBlitzerRealtime() {
    // 1. Supabase Realtime (sofort, wenn Tabelle für Replication aktiviert)
    try {
      final repo = ref.read(blitzerRepositoryProvider);
      _blitzerRealtimeChannel = repo.subscribeToBlitzerReports(
        onNewReport: (report) {
          if (_disposed || !mounted) return;
          final myUserId = Supabase.instance.client.auth.currentUser?.id;
          if (report.userId == myUserId) return;
          if (!report.isActive || report.isExpired) return;
          if (_reports.any((r) => r.id == report.id)) return;
          if (_currentPosition != null) {
            final dist = _approxDistanceMeters(
              _currentPosition!.latitude, _currentPosition!.longitude,
              report.latitude, report.longitude,
            );
            if (dist > 50000) return;
          }
          debugPrint('[Blitzer RT] Neuer Report: ${report.typeLabel} (id=${report.id})');
          _reports.add(report);
          _buildBlitzerMarkers();
          _rebuildCachedMarkers();
          if (mounted) setState(() {});
        },
        onUpdate: (report) {
          if (_disposed || !mounted) return;
          final idx = _reports.indexWhere((r) => r.id == report.id);
          if (idx == -1) return;
          if (!report.isTrusted) {
            _reports.removeAt(idx);
          } else {
            _reports[idx] = report;
          }
          _buildBlitzerMarkers();
          _rebuildCachedMarkers();
          if (mounted) setState(() {});
        },
      );
      debugPrint('[Blitzer RT] Realtime subscription active');
    } catch (e) {
      debugPrint('[Blitzer RT] Realtime subscription failed: $e');
    }

    // 2. Polling-Fallback: Alle 30 Sekunden Reports neu laden
    // Funktioniert IMMER, auch wenn Supabase Realtime nicht aktiviert ist
    _reportPollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_disposed || !mounted) return;
      debugPrint('[Blitzer Poll] Auto-refresh reports');
      _loadReports();
    });
    debugPrint('[Blitzer Poll] Polling-Timer gestartet (30s Intervall)');
  }

  /// Approximate distance in meters between two lat/lng points.
  static double _approxDistanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const metersPerDegree = 111319.0;
    final dLat = (lat2 - lat1) * metersPerDegree;
    final cosLat = (lat1 * 3.14159265359 / 180);
    // Simple cosine approximation
    final cosApprox = 1 - cosLat * cosLat / 2;
    final dLon = (lon2 - lon1) * metersPerDegree * cosApprox;
    return (dLat * dLat + dLon * dLon).abs() > 0 ? _sqrt(dLat * dLat + dLon * dLon) : 0;
  }

  static double _sqrt(double x) {
    if (x <= 0) return 0;
    double g = x / 2;
    for (int i = 0; i < 8; i++) { g = (g + x / g) / 2; }
    return g;
  }

  void _buildBlitzerMarkers() {
    final policyState = ref.read(countryPolicyProvider);
    final policy = policyState.policy;
    final isDangerZone = policy != null && policy.isDangerZone;

    if (isDangerZone) {
      // ── DANGER ZONE MODE: show coarse circles instead of exact points ──
      // No precise markers — only zones (radius 800–2000m)
      _blitzerMarkers = {};
      _cachedDangerZones = _reports.map((report) {
        final (_, color) = switch (report.type) {
          'fixed' => (Icons.photo_camera_rounded, Colors.red),
          'mobile' => (Icons.directions_car_rounded, Colors.orange),
          'police' => (Icons.local_police_rounded, Colors.blue),
          _ => (Icons.warning_rounded, Colors.amber),
        };
        return Circle(
          circleId: CircleId('danger_${report.id}'),
          center: LatLng(report.latitude, report.longitude),
          radius: report.type == 'fixed' ? 1500 : 1000, // meters
          fillColor: color.withValues(alpha: 0.12),
          strokeColor: color.withValues(alpha: 0.35),
          strokeWidth: 2,
        );
      }).toSet();
    } else {
      // ── EXACT MODE: show pin markers with distance-based opacity ──
      // Markers far away are transparent, nearby ones are fully visible
      _cachedDangerZones = {};
      _blitzerMarkers = {};
      _buildDistanceBasedMarkers();
    }
  }

  /// Build markers with distance-based opacity.
  /// Far away = transparent, nearby = fully visible.
  Future<void> _buildDistanceBasedMarkers() async {
    final markers = <Marker>{};

    for (final report in _reports) {
      // Calculate distance-based opacity
      double opacity = 1.0;
      if (_currentPosition != null) {
        final distM = _approxDistanceMeters(
          _currentPosition!.latitude, _currentPosition!.longitude,
          report.latitude, report.longitude,
        );
        if (distM > 10000) {
          opacity = 0.2; // > 10 km: very faint
        } else if (distM > 5000) {
          opacity = 0.35; // 5-10 km: faint
        } else if (distM > 2000) {
          opacity = 0.55; // 2-5 km: semi-transparent
        } else if (distM > 500) {
          opacity = 0.8; // 500m-2km: mostly visible
        } else {
          opacity = 1.0; // < 500m: fully visible
        }
      }

      final iconKey = report.isOsm ? 'fixed_osm' : report.type;
      final icon = await _getCustomMarkerIcon(iconKey, opacity: opacity);

      markers.add(Marker(
        markerId: MarkerId('blitzer_${report.id}'),
        position: LatLng(report.latitude, report.longitude),
        icon: icon,
        alpha: opacity, // Google Maps marker alpha (additional layer)
        onTap: () => _showReportDetail(report),
      ));
    }

    if (!_disposed && mounted) {
      _blitzerMarkers = markers;
      _rebuildCachedMarkers();
      setState(() {});
    }
  }

  // ─── Spracheingabe ────────────────────────────────────────────────────

  void _toggleVoiceSearch() {
    if (_isListening) {
      _speech.stop();
      setState(() => _isListening = false);
    } else {
      _searchFocusNode.requestFocus();
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (result) {
          _searchController.text = result.recognizedWords;
          _searchController.selection = TextSelection.fromPosition(
            TextPosition(offset: _searchController.text.length),
          );
          if (result.finalResult && result.recognizedWords.isNotEmpty) {
            setState(() => _isListening = false);
            _onSearchChanged(result.recognizedWords);
          }
          if (mounted) setState(() {});
        },
        localeId: 'de_DE',
        listenMode: stt.ListenMode.dictation,
      );
    }
  }

  // ─── Search ───────────────────────────────────────────────────────────

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) {
      ref.read(navigationProvider.notifier).clearSearch();
      setState(() {
        _showSearchResults = false;
        _filteredHistory = [];
      });
      return;
    }
    if (query.trim().length < 2) {
      setState(() {
        _showSearchResults = false;
        _filteredHistory = [];
      });
      return;
    }
    // ── Sofort: Lokale Historie filtern (0ms) ──
    final filtered = _filterHistoryByQuery(query.trim());
    setState(() {
      _showSearchResults = true;
      _filteredHistory = filtered;
    });
    // ── Nach 250ms: Nominatim API aufrufen ──
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (_disposed || !mounted) return;
      final near = _currentPosition != null
          ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
          : null;
      ref.read(navigationProvider.notifier).searchPlaces(query.trim(), near: near);
    });
  }

  /// Filtert die lokale Suchhistorie nach Query (Name, DisplayName, Straße).
  List<Map<String, dynamic>> _filterHistoryByQuery(String query) {
    final q = query.toLowerCase();
    return _searchHistory.where((e) {
      final name = (e['name'] as String? ?? '').toLowerCase();
      final display = (e['displayName'] as String? ?? '').toLowerCase();
      final road = (e['road'] as String? ?? '').toLowerCase();
      return name.contains(q) || display.contains(q) || road.contains(q);
    }).toList();
  }

  void _onSearchResultTap(GeocodingResult result) {
    _searchController.text = result.shortName;
    _searchFocusNode.unfocus();
    setState(() => _showSearchResults = false);
    _routeCancelled = false; // Neues Ziel → Sheet darf wieder geöffnet werden

    // Save to search history
    _saveSearchHistory(result);

    final origin = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : _defaultCenter;

    ref.read(navigationProvider.notifier).calculateRoute(origin, result.location, name: result.shortName);

    final sw = LatLng(min(origin.latitude, result.location.latitude), min(origin.longitude, result.location.longitude));
    final ne = LatLng(max(origin.latitude, result.location.latitude), max(origin.longitude, result.location.longitude));
    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(LatLngBounds(southwest: sw, northeast: ne), 80));
  }

  // ─── Search History ──────────────────────────────────────────────────

  static const _historyKey = 'blitzer_search_history';
  static const _maxHistoryItems = 50;
  List<Map<String, dynamic>> _searchHistory = [];

  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_historyKey) ?? [];
    _searchHistory = raw.map((e) {
      try { return jsonDecode(e) as Map<String, dynamic>; } catch (_) { return null; }
    }).whereType<Map<String, dynamic>>().toList();
  }

  Future<void> _saveSearchHistory(GeocodingResult result) async {
    final entry = {
      'name': result.shortName,
      'displayName': result.displayName,
      'lat': result.location.latitude,
      'lng': result.location.longitude,
      'city': result.city,
      'state': result.state,
      'road': result.road,
      'houseNumber': result.houseNumber,
      'osmClass': result.osmClass,
      'osmType': result.osmType,
      'ts': DateTime.now().millisecondsSinceEpoch,
    };
    // Remove duplicate (same name)
    _searchHistory.removeWhere((e) => e['name'] == result.shortName);
    // Add to front
    _searchHistory.insert(0, entry);
    // Trim to max
    if (_searchHistory.length > _maxHistoryItems) {
      _searchHistory = _searchHistory.sublist(0, _maxHistoryItems);
    }
    // Persist
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_historyKey, _searchHistory.map((e) => jsonEncode(e)).toList());
  }

  Future<void> _clearSearchHistory() async {
    _searchHistory.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
    if (mounted) setState(() {});
  }

  void _onHistoryItemTap(Map<String, dynamic> entry) {
    final result = GeocodingResult(
      displayName: entry['displayName'] as String? ?? entry['name'] as String,
      city: entry['city'] as String?,
      state: entry['state'] as String?,
      location: LatLng(
        (entry['lat'] as num?)?.toDouble() ?? 0,
        (entry['lng'] as num?)?.toDouble() ?? 0,
      ),
      osmClass: entry['osmClass'] as String?,
      osmType: entry['osmType'] as String?,
    );
    _onSearchResultTap(result);
  }

  // ─── Navigation Control ───────────────────────────────────────────────

  /// Toggle 3D/2D during active navigation.
  void _toggleNav3D() {
    setState(() => _is3D = !_is3D);
    _smoothZoom = _is3D ? 18.0 : 20.5;
    _navCameraDirty = true;
  }

  /// Toggle map type (satellite ↔ normal) during navigation.
  void _toggleNavMapType() {
    setState(() {
      _mapType = _mapType == MapType.hybrid ? MapType.normal : MapType.hybrid;
    });
  }

  /// Open navigation settings during active navigation.
  void _openNavSettingsDuringDrive(Brightness brightness) {
    context.push('/navigation-settings');
  }

  void _startNavigation() {
    ref.read(navigationProvider.notifier).startNavigation();
    ref.read(androidAutoServiceProvider).sendNavigationStarted();
    ref.read(blitzerSpeedDialProvider.notifier).close();
    setState(() => _isNavigatingCached = true); // setState → Padding-Wechsel triggern
    _rebuildCachedMarkers(); // Add vehicle marker

    // ── Start ride tracking for XP ──
    _navStartTime = DateTime.now();
    _navDistanceMeters = 0;
    _navMaxSpeed = 0;
    _navLastPosition = _currentPosition;

    // Activate Driving Mode
    final settings = ref.read(blitzerSettingsProvider).value ??
        const BlitzerSettings();
    ref.read(drivingModeProvider.notifier).activate(
      keepScreenOn: settings.keepScreenOn,
    );

    // Keep screen on
    if (settings.keepScreenOn) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }

    // Find blitzer on route
    if (_cachedRoute != null) {
      ref.read(drivingModeProvider.notifier).setBlitzerOnRoute(
        _reports,
        _cachedRoute!.polylinePoints,
      );
    }

    // 2D ist Standard bei Navigation (User kann manuell auf 3D umschalten)
    // Auto-3D deaktiviert — 2D bietet bessere Übersicht

    if (_currentPosition != null) {
      final use3d = _is3D;
      _smoothBearing = _currentPosition!.heading;
      _targetBearing = _smoothBearing;
      _smoothZoom = use3d ? 18.0 : 20.5; // 2D fast am Limit (max ~21)
      _lastNavLat = _currentPosition!.latitude;
      _lastNavLng = _currentPosition!.longitude;
      _polylineClosestIdx = 0;
      _navMarkerRebuildSkip = 0;

      // Waze-style: Kamera direkt auf Position, Padding verschiebt Viewport
      final tilt = use3d ? 65.0 : 35.0;

      _mapController?.moveCamera(CameraUpdate.newCameraPosition(CameraPosition(
        target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        zoom: _smoothZoom,
        tilt: tilt,
        bearing: _smoothBearing,
      )));
    }

    // Start smooth camera interpolation loop (30fps)
    _startNavCameraLoop();

    // Switch LocationEngine to high-accuracy navigation mode (Kalman-smoothed)
    _navSmoothedStream?.cancel();
    _navPositionStream?.cancel();

    if (_locationEngine != null) {
      _locationEngine!.setAccuracy(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 2, // Very responsive: update every 2 meters
      );
      _navSmoothedStream = _locationEngine!.positionStream.listen(_onNavSmoothedUpdate);
      debugPrint('[Nav] Navigation started (LocationEngine: bestForNavigation, 2m filter, Kalman-smoothed)');
    } else {
      // Fallback: direct Geolocator stream (if LocationEngine not initialized)
      _navPositionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 2,
        ),
      ).listen(_onNavPositionUpdate);
      debugPrint('[Nav] Navigation started (Fallback: direct Geolocator, no Kalman)');
    }
  }

  void _stopNavigation() {
    _stopNavCameraLoop();
    _navSmoothedStream?.cancel();
    _navSmoothedStream = null;
    _navPositionStream?.cancel();
    _navPositionStream = null;
    _blitzerWarning = null;
    _blitzerWarningTimer?.cancel();
    setState(() => _isNavigatingCached = false); // setState → Padding zurücksetzen

    // Restore LocationEngine to normal accuracy (battery-saving)
    if (_locationEngine != null) {
      _locationEngine!.setAccuracy(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      );
    }

    // ── Save ride & award XP ──
    final distanceKm = _navDistanceMeters / 1000;
    final startTime = _navStartTime;
    final maxSpeed = _navMaxSpeed;
    _navStartTime = null;
    _navDistanceMeters = 0;
    _navMaxSpeed = 0;
    _navLastPosition = null;

    // Stop TTS and reset state
    NavigationTtsService.instance.reset();

    // Deactivate Driving Mode
    ref.read(drivingModeProvider.notifier).deactivate();

    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    ref.read(navigationProvider.notifier).stopNavigation();
    ref.read(androidAutoServiceProvider).sendNavigationEnded();
    _rebuildCachedPolylines();
    _rebuildCachedMarkers();

    // Reset 3D (unless "always 3D" setting is active)
    final navSettings = ref.read(blitzerSettingsProvider).value ?? const BlitzerSettings();
    if (!navSettings.always3d) {
      _is3D = false;
    }

    if (_currentPosition != null) {
      _mapController?.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
        target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        zoom: _is3D ? 17 : 15,
        tilt: _is3D ? 55 : 0,
        bearing: 0,
      )));
    }
    _searchController.clear();
    _stepsExpanded = false;
    if (mounted) setState(() {});
    debugPrint('[Nav] Navigation stopped (DrivingMode deactivated, ${distanceKm.toStringAsFixed(1)} km)');

    // Save ride if distance is meaningful (> 100m)
    if (distanceKm >= 0.1 && startTime != null) {
      _saveNavRide(
        startedAt: startTime,
        distanceKm: distanceKm,
        maxSpeedKmh: maxSpeed,
      );
    }
  }

  Future<void> _saveNavRide({
    required DateTime startedAt,
    required double distanceKm,
    required double maxSpeedKmh,
  }) async {
    final endedAt = DateTime.now();
    final durationSeconds = endedAt.difference(startedAt).inSeconds;
    final avgSpeed = durationSeconds > 0
        ? (distanceKm / (durationSeconds / 3600))
        : 0.0;

    try {
      final repo = ref.read(rideRepositoryProvider);
      final ride = await repo.saveRide(
        startedAt: startedAt,
        endedAt: endedAt,
        distanceKm: distanceKm,
        durationSeconds: durationSeconds,
        avgSpeedKmh: avgSpeed,
        maxSpeedKmh: maxSpeedKmh,
      );

      ref.read(rideHistoryNotifierProvider.notifier).addRide(ride);

      debugPrint('[Nav] Ride saved: ${distanceKm.toStringAsFixed(1)} km, +${ride.xpEarned} XP');

      if (!_disposed && mounted) {
        _showRideCompleteDialog(ride, durationSeconds);
      }
    } catch (e) {
      debugPrint('[Nav] Ride save error: $e');
      if (!_disposed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ride konnte nicht gespeichert werden: $e'), backgroundColor: Colors.orange),
        );
      }
    }
  }

  void _showRideCompleteDialog(RideRecord ride, int durationSec) {
    final community = ref.read(communityProvider);
    final brightness = Theme.of(context).brightness;
    final accentColor = community?.accentColor ?? AppTheme.accentDark;
    final textColor = brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A);
    final mutedColor = brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF6C757D);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: community?.cardFor(brightness) ?? (brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(Icons.emoji_events_rounded, color: accentColor, size: 28),
          const SizedBox(width: 10),
          Text('Fahrt beendet!', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: textColor)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _statRow('Distanz', '${ride.distanceKm.toStringAsFixed(1)} km', textColor, mutedColor),
          _statRow('Dauer', ride.formattedDuration, textColor, mutedColor),
          _statRow('\u00d8 Tempo', '${ride.avgSpeedKmh.toStringAsFixed(0)} km/h', textColor, mutedColor),
          _statRow('Max Tempo', '${ride.maxSpeedKmh.toStringAsFixed(0)} km/h', textColor, mutedColor),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [accentColor.withValues(alpha: 0.15), accentColor.withValues(alpha: 0.05)]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accentColor.withValues(alpha: 0.3)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.bolt_rounded, color: accentColor, size: 22),
              const SizedBox(width: 8),
              Text('+${ride.xpEarned} XP', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: accentColor)),
            ]),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('OK', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: accentColor)),
          ),
        ],
      ),
    );
  }

  Widget _statRow(String label, String value, Color textColor, Color mutedColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: GoogleFonts.inter(fontSize: 14, color: mutedColor)),
        Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
      ]),
    );
  }

  void _onNavPositionUpdate(Position pos) {
    if (_disposed || !mounted) return;
    _currentPosition = pos;

    // ── Ride tracking: accumulate distance + max speed ──
    if (_navLastPosition != null) {
      final d = Geolocator.distanceBetween(
        _navLastPosition!.latitude, _navLastPosition!.longitude,
        pos.latitude, pos.longitude,
      );
      // Only add plausible distances (< 500m per update, filters GPS jumps)
      if (d < 500) _navDistanceMeters += d;
    }
    _navLastPosition = pos;
    final speedKmh = (pos.speed >= 0 ? pos.speed : 0) * 3.6;
    if (speedKmh > _navMaxSpeed) _navMaxSpeed = speedKmh;

    // ref.read() is safe here because we checked _disposed + mounted above.
    // The _disposed flag is set BEFORE dispose() cancels streams, so this
    // callback cannot fire after the widget element is deactivated.
    // Track current step BEFORE update (to detect step changes)
    final prevStepIndex = ref.read(navigationProvider).currentStepIndex;

    final arrived = ref.read(navigationProvider.notifier).updatePosition(pos);
    if (arrived) {
      // Play arrival sound
      final navSettings = ref.read(blitzerSettingsProvider).value ?? const BlitzerSettings();
      AlertAudioService.instance.playNavSound(
        type: NavSoundType.arrive,
        enabled: navSettings.navSoundEnabled && navSettings.audioAlertsEnabled,
        volume: navSettings.audioVolume,
      );
      // TTS: "Ziel erreicht. Navigation beendet."
      NavigationTtsService.instance.announceArrival(enabled: navSettings.ttsEnabled);
      _stopNavigation(); // This saves the ride and shows XP dialog
      return;
    }

    // ── Nav sound: play turn sound when step changes ──
    final navState = ref.read(navigationProvider);
    final newStepIndex = navState.currentStepIndex;
    if (prevStepIndex != newStepIndex && newStepIndex > 0) {
      final navSettings = ref.read(blitzerSettingsProvider).value ?? const BlitzerSettings();
      AlertAudioService.instance.playNavSound(
        type: NavSoundType.turn,
        enabled: navSettings.navSoundEnabled && navSettings.audioAlertsEnabled,
        volume: navSettings.audioVolume,
      );
    }

    // ── TTS: Announce current step at distance thresholds (500m, 200m, now) ──
    {
      final ttsSettings = ref.read(blitzerSettingsProvider).value ?? const BlitzerSettings();
      final currentStep = navState.currentStep;
      if (currentStep != null) {
        NavigationTtsService.instance.announceStep(
          stepIndex: newStepIndex,
          step: currentStep,
          distanceToStep: navState.distanceToNextStep,
          enabled: ttsSettings.ttsEnabled,
        );
      }
    }

    // Off-route check with cooldown (5s) + max 3 retries
    if (navState.isOffRoute && _cachedDestination != null && !navState.reRouteExhausted) {
      final didReRoute = ref.read(navigationProvider.notifier).tryReRoute(
        LatLng(pos.latitude, pos.longitude), _cachedDestination!, name: _cachedDestinationName,
      );
      if (didReRoute) {
        final offRouteSettings = ref.read(blitzerSettingsProvider).value ?? const BlitzerSettings();
        AlertAudioService.instance.playNavSound(
          type: NavSoundType.offRoute,
          enabled: offRouteSettings.navSoundEnabled && offRouteSettings.audioAlertsEnabled,
          volume: offRouteSettings.audioVolume,
        );
        // TTS: "Route wird neu berechnet."
        NavigationTtsService.instance.announceReRoute(enabled: offRouteSettings.ttsEnabled);
        Future.delayed(const Duration(seconds: 2), () {
          if (!_disposed && mounted && ref.read(navigationProvider).hasRoute) {
            ref.read(navigationProvider.notifier).startNavigation();
          }
        });
        return;
      }
    }

    // ── Driving Mode: process GPS update (alerts + camera) ──
    final cameraPos = ref.read(drivingModeProvider.notifier).processGpsUpdate(
      pos: pos,
      reports: _reports,
    );

    // Camera follow (from Driving Mode or fallback)
    if (cameraPos != null) {
      _mapController?.animateCamera(CameraUpdate.newCameraPosition(cameraPos));
    }

    // Update blitzer warning banner from Driving Mode
    final drivingState = ref.read(drivingModeProvider);
    if (drivingState.hasWarning) {
      final warning = drivingState.primaryAlert!.warningText;
      if (warning != _blitzerWarning) {
        _blitzerWarning = warning;
        _blitzerWarningTimer?.cancel();
        _blitzerWarningTimer = Timer(const Duration(seconds: 10), () {
          if (!_disposed && mounted) {
            setState(() => _blitzerWarning = null);
            ref.read(drivingModeProvider.notifier).dismissAlert();
          }
        });
      }
    } else if (_blitzerWarning != null && drivingState.activeAlerts.isEmpty) {
      _blitzerWarning = null;
      _blitzerWarningTimer?.cancel();
    }

    // Update vehicle marker + trim route polyline (only show ahead)
    _rebuildCachedMarkers();
    _rebuildCachedPolylines();
    // NO full setState — nav HUD widgets watch their own state via ref.watch
    // But we need setState to update the vehicle marker on the GoogleMap widget
    if (!_disposed && mounted) setState(() {});
  }

  /// Process Kalman-smoothed GPS update from LocationEngine.
  /// Uses smoothed lat/lng/speed/heading for stable camera and accurate alerts.
  void _onNavSmoothedUpdate(SmoothedPosition smoothed) {
    if (_disposed || !mounted) return;

    // Convert SmoothedPosition → Position for backward-compat with nav provider
    final pos = Position(
      latitude: smoothed.smoothedLat,
      longitude: smoothed.smoothedLng,
      timestamp: smoothed.timestamp,
      accuracy: smoothed.accuracy,
      altitude: smoothed.altitude,
      altitudeAccuracy: 0,
      heading: smoothed.smoothedHeading,
      headingAccuracy: 0,
      speed: smoothed.smoothedSpeed / 3.6, // km/h → m/s
      speedAccuracy: 0,
    );

    _currentPosition = pos;
    _lastNavLat = smoothed.smoothedLat;
    _lastNavLng = smoothed.smoothedLng;

    // ── Ride tracking: accumulate distance + max speed ──
    if (_navLastPosition != null) {
      final d = Geolocator.distanceBetween(
        _navLastPosition!.latitude, _navLastPosition!.longitude,
        pos.latitude, pos.longitude,
      );
      if (d < 500) _navDistanceMeters += d;
    }
    _navLastPosition = pos;
    if (smoothed.smoothedSpeed > _navMaxSpeed) _navMaxSpeed = smoothed.smoothedSpeed;

    // Read settings ONCE per update
    final settings = ref.read(blitzerSettingsProvider).value ?? const BlitzerSettings();

    // Track current step BEFORE update
    final prevStepIndex = ref.read(navigationProvider).currentStepIndex;

    final arrived = ref.read(navigationProvider.notifier).updatePosition(pos);
    if (arrived) {
      AlertAudioService.instance.playNavSound(
        type: NavSoundType.arrive,
        enabled: settings.navSoundEnabled && settings.audioAlertsEnabled,
        volume: settings.audioVolume,
      );
      NavigationTtsService.instance.announceArrival(enabled: settings.ttsEnabled);
      _stopNavigation();
      return;
    }

    // ── Nav sound + TTS ──
    final navState = ref.read(navigationProvider);
    final newStepIndex = navState.currentStepIndex;
    if (prevStepIndex != newStepIndex && newStepIndex > 0) {
      AlertAudioService.instance.playNavSound(
        type: NavSoundType.turn,
        enabled: settings.navSoundEnabled && settings.audioAlertsEnabled,
        volume: settings.audioVolume,
      );
    }

    final currentStep = navState.currentStep;
    if (currentStep != null) {
      NavigationTtsService.instance.announceStep(
        stepIndex: newStepIndex,
        step: currentStep,
        distanceToStep: navState.distanceToNextStep,
        enabled: settings.ttsEnabled,
      );
    }

    // Off-route check
    if (navState.isOffRoute && _cachedDestination != null && !navState.reRouteExhausted) {
      final didReRoute = ref.read(navigationProvider.notifier).tryReRoute(
        LatLng(pos.latitude, pos.longitude), _cachedDestination!, name: _cachedDestinationName,
      );
      if (didReRoute) {
        AlertAudioService.instance.playNavSound(
          type: NavSoundType.offRoute,
          enabled: settings.navSoundEnabled && settings.audioAlertsEnabled,
          volume: settings.audioVolume,
        );
        NavigationTtsService.instance.announceReRoute(enabled: settings.ttsEnabled);
        Future.delayed(const Duration(seconds: 2), () {
          if (!_disposed && mounted && ref.read(navigationProvider).hasRoute) {
            ref.read(navigationProvider.notifier).startNavigation();
          }
        });
        return;
      }
    }

    // ── Driving Mode: process alerts ──
    ref.read(drivingModeProvider.notifier).processSmoothedUpdate(
      smoothed: smoothed,
      rawPos: pos,
      reports: _reports,
    );

    // ── Smooth camera target update (bearing + zoom) ──
    // Kamera dreht sich IMMER in Fahrtrichtung während Navigation
    _targetBearing = smoothed.smoothedHeading;
    // Auto-zoom: higher speed → lower zoom for better overview
    final speedKmh = smoothed.smoothedSpeed;
    final use3d = _is3D;
    if (use3d) {
      // 3D: Speed-adaptive zoom: 18 at 0 km/h → 15.5 at 200 km/h
      _smoothZoom = (18.0 - (speedKmh / 80.0).clamp(0.0, 2.5));
    } else {
      // 2D: Speed-adaptive zoom: 20.5 at 0 km/h → 18.5 at 200+ km/h (fast am Limit)
      _smoothZoom = (20.5 - (speedKmh / 100.0).clamp(0.0, 2.0));
    }
    _navCameraDirty = true;

    // Update blitzer warning banner
    final drivingState = ref.read(drivingModeProvider);
    if (drivingState.hasWarning) {
      final warning = drivingState.primaryAlert!.warningText;
      if (warning != _blitzerWarning) {
        _blitzerWarning = warning;
        _blitzerWarningTimer?.cancel();
        _blitzerWarningTimer = Timer(const Duration(seconds: 10), () {
          if (!_disposed && mounted) {
            setState(() => _blitzerWarning = null);
            ref.read(drivingModeProvider.notifier).dismissAlert();
          }
        });
      }
    } else if (_blitzerWarning != null && drivingState.activeAlerts.isEmpty) {
      _blitzerWarning = null;
      _blitzerWarningTimer?.cancel();
    }

    // Rebuild markers only every 3rd update (vehicle marker position is handled by camera)
    _navMarkerRebuildSkip++;
    if (_navMarkerRebuildSkip >= 3) {
      _navMarkerRebuildSkip = 0;
      _rebuildCachedMarkers();
    }
    // Polylines: use optimized version
    _rebuildCachedPolylinesOptimized();

    if (!_disposed && mounted) setState(() {});
  }

  /// Calculate a point offset ahead of current position in bearing direction.
  /// This shifts the camera center forward so the user dot appears in the
  /// lower third of the screen (like Waze / Google Maps navigation).
  LatLng _offsetTarget(double lat, double lng, double bearingDeg, double distanceMeters) {
    const double earthRadius = 6371000; // meters
    final bearingRad = bearingDeg * pi / 180.0;
    final latRad = lat * pi / 180.0;
    final lngRad = lng * pi / 180.0;
    final angDist = distanceMeters / earthRadius;

    final newLatRad = asin(
      sin(latRad) * cos(angDist) + cos(latRad) * sin(angDist) * cos(bearingRad),
    );
    final newLngRad = lngRad + atan2(
      sin(bearingRad) * sin(angDist) * cos(latRad),
      cos(angDist) - sin(latRad) * sin(newLatRad),
    );

    return LatLng(newLatRad * 180.0 / pi, newLngRad * 180.0 / pi);
  }

  /// 30fps camera interpolation timer for smooth bearing/zoom/position transitions.
  void _startNavCameraLoop() {
    _cameraAnimTimer?.cancel();
    _cameraAnimTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (_disposed || !mounted || !_isNavigatingCached || _mapController == null) return;
      if (!_navCameraDirty && (_smoothBearing - _targetBearing).abs() < 0.5) return;

      final drivingState = ref.read(drivingModeProvider);
      if (!drivingState.isFollowing) return;

      // Smooth bearing: lerp toward target (handles 360° wrapping)
      double bearingDiff = _targetBearing - _smoothBearing;
      // Normalize to -180..180
      while (bearingDiff > 180) bearingDiff -= 360;
      while (bearingDiff < -180) bearingDiff += 360;
      _smoothBearing += bearingDiff * 0.15; // 15% per frame = smooth rotation
      // Normalize result
      if (_smoothBearing < 0) _smoothBearing += 360;
      if (_smoothBearing >= 360) _smoothBearing -= 360;

      final use3d = _is3D;
      // 3D: starker Tilt (65°), 2D: leichter Tilt (35°) für Fahrtrichtungs-Gefühl
      final tilt = use3d ? 65.0 : 35.0;

      // ── Waze-Style: Kamera direkt auf echte Position ──
      // Das GoogleMap-Padding (top: 50%) verschiebt den logischen Mittelpunkt
      // nach unten → Marker bleibt FEST unten-mitte, Karte dreht sich darum.
      _mapController!.moveCamera(CameraUpdate.newCameraPosition(CameraPosition(
        target: LatLng(_lastNavLat, _lastNavLng),
        zoom: _smoothZoom,
        tilt: tilt,
        bearing: _smoothBearing,
      )));

      _navCameraDirty = false;
    });
  }

  void _stopNavCameraLoop() {
    _cameraAnimTimer?.cancel();
    _cameraAnimTimer = null;
  }

  /// Optimized polyline rebuild: only search near last known index.
  void _rebuildCachedPolylinesOptimized() {
    if (_disposed || !mounted) return;
    if (_cachedRoute == null) {
      _cachedPolylines = {};
      return;
    }

    final allPoints = _cachedRoute!.polylinePoints;
    List<LatLng> aheadPoints = allPoints;

    if (_currentPosition != null && allPoints.length > 2) {
      final userLat = _currentPosition!.latitude;
      final userLng = _currentPosition!.longitude;

      // Search NEAR the last known index (±30 points) instead of the entire polyline
      final searchStart = (_polylineClosestIdx - 10).clamp(0, allPoints.length - 1);
      final searchEnd = (_polylineClosestIdx + 30).clamp(0, allPoints.length);

      double minDist = double.infinity;
      int closestIdx = _polylineClosestIdx;
      for (int i = searchStart; i < searchEnd; i++) {
        final d = Geolocator.distanceBetween(
          userLat, userLng,
          allPoints[i].latitude, allPoints[i].longitude,
        );
        if (d < minDist) {
          minDist = d;
          closestIdx = i;
        }
      }
      _polylineClosestIdx = closestIdx;

      if (closestIdx < allPoints.length - 1) {
        aheadPoints = [
          LatLng(userLat, userLng),
          ...allPoints.sublist(closestIdx + 1),
        ];
      }
    }

    _cachedPolylines = {
      Polyline(
        polylineId: const PolylineId('route'),
        points: aheadPoints,
        color: _cachedAccentColor,
        width: 5,
      ),
    };
  }

  // Blitzer proximity is now handled by DrivingModeProvider.processGpsUpdate()
  // which uses BlitzerAlertService for intelligent direction-sensitive,
  // time-to-camera based, multi-stage warnings.

  // ─── Speed-Dial ───────────────────────────────────────────────────────

  void _closeSpeedDial() {
    ref.read(blitzerSpeedDialProvider.notifier).close();
  }

  // ─── Report Detail ────────────────────────────────────────────────────

  void _showReportDetail(BlitzerReport report) {
    final community = ref.read(communityProvider);
    final brightness = Theme.of(context).brightness;
    final accentColor = community?.accentColor ?? AppTheme.accentDark;
    final textColor = brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A);
    final mutedColor = brightness == Brightness.dark ? Colors.white70 : const Color(0xFF6C757D);

    // Check if current user is the report creator
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isOwnReport = currentUserId != null && report.userId == currentUserId;
    debugPrint('[ReportDetail] type=${report.type}, reportUserId="${report.userId}", currentUserId="$currentUserId", isOwn=$isOwnReport');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: community?.cardFor(brightness) ?? (brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sheetHandle(brightness),
            Row(children: [
              _typeIcon(report.type, 28),
              const SizedBox(width: 12),
              Expanded(child: Text(report.typeLabel, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: textColor))),
              // Delete button — nur für Community-Meldungen (OSM nicht löschbar)
              if (!report.isOsm) IconButton(
                onPressed: () async {
                  final dialogTitle = isOwnReport ? 'Meldung löschen?' : 'Meldung entfernen?';
                  final dialogText = isOwnReport
                      ? 'Deine Meldung "${report.typeLabel}" wird für alle entfernt.'
                      : '"${report.typeLabel}" wird von deiner Karte entfernt.';
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: community?.cardFor(brightness) ?? (brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: Text(dialogTitle, style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: textColor)),
                      content: Text(dialogText, style: GoogleFonts.inter(color: mutedColor)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Abbrechen', style: GoogleFonts.inter(color: mutedColor))),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Entfernen', style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.w600))),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    // ── Immediately remove from local state (instant UI feedback) ──
                    _reports.removeWhere((r) => r.id == report.id);
                    _buildBlitzerMarkers();
                    _rebuildCachedMarkers();
                    if (mounted) {
                      Navigator.pop(context);
                      setState(() {});
                    }

                    // ── Persist deletion (local blacklist + server) ──
                    try {
                      await ref.read(blitzerRepositoryProvider).deleteReport(report.id);
                    } catch (e) {
                      debugPrint('[Blitzer] Server delete failed: $e');
                    }

                    // Reload from server to sync state
                    _loadReports();

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('${report.typeLabel} entfernt', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ));
                    }
                  }
                },
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 22),
                tooltip: isOwnReport ? 'Meldung löschen' : 'Von Karte entfernen',
              ),
            ]),
            if (report.description != null) ...[
              const SizedBox(height: 12),
              Text(report.description!, style: GoogleFonts.inter(fontSize: 14, color: mutedColor)),
            ],
            const SizedBox(height: 16),
            Row(children: [
              Icon(Icons.thumb_up_outlined, size: 16, color: mutedColor),
              const SizedBox(width: 4),
              Text('${report.confirmations}', style: GoogleFonts.inter(fontSize: 13, color: mutedColor)),
              const SizedBox(width: 16),
              Icon(Icons.thumb_down_outlined, size: 16, color: mutedColor),
              const SizedBox(width: 4),
              Text('${report.dismissals}', style: GoogleFonts.inter(fontSize: 13, color: mutedColor)),
              const Spacer(),
              if (report.createdAt != null)
                Text(_timeAgo(report.createdAt!), style: GoogleFonts.inter(fontSize: 12, color: mutedColor)),
            ]),
            const SizedBox(height: 16),
            // OSM-Blitzer: keine Bestätigen/Ist-weg Buttons (stationäre Daten, nicht löschbar)
            if (!report.isOsm) ...[
            Row(children: [
              Expanded(child: ElevatedButton.icon(
                onPressed: () async {
                  await ref.read(blitzerRepositoryProvider).confirmReport(report.id);
                  if (mounted) Navigator.pop(context);
                  _loadReports();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('${report.typeLabel} bestätigt!', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      backgroundColor: accentColor,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ));
                  }
                },
                icon: const Icon(Icons.thumb_up_rounded, size: 18),
                label: Text('Bestätigen', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(backgroundColor: accentColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
              )),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton.icon(
                onPressed: () async {
                  await ref.read(blitzerRepositoryProvider).dismissReport(report.id);
                  if (mounted) Navigator.pop(context);
                  _loadReports();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('${report.typeLabel} als "weg" gemeldet', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      backgroundColor: Colors.orange,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ));
                  }
                },
                icon: const Icon(Icons.close_rounded, size: 18),
                label: Text('Ist weg', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
              )),
            ]),
            ] else ...[
              // OSM-Info statt Buttons
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                decoration: BoxDecoration(
                  color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  Icon(Icons.verified_rounded, size: 16, color: accentColor),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Stationärer Blitzer — verifiziert durch OpenStreetMap', style: GoogleFonts.inter(fontSize: 12, color: mutedColor))),
                ]),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ─── Create Report Sheet ──────────────────────────────────────────────

  void _showCreateReportSheet() {
    _closeSpeedDial();

    // ── Country policy check — block if not allowed ──
    final policyState = ref.read(countryPolicyProvider);
    final policy = policyState.policy;
    if (policy != null && policy.isOff) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.block_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text('Meldungen sind in ${policy.countryCode} nicht verfügbar',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600))),
        ]),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }
    if (policy != null && !policy.allowReporting) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.shield_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text('Meldungen sind in ${policy.countryCode} eingeschränkt',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600))),
        ]),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }

    final community = ref.read(communityProvider);
    final brightness = Theme.of(context).brightness;
    final accentColor = community?.accentColor ?? AppTheme.accentDark;
    final textColor = brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A);
    final mutedColor = brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF6C757D);

    String selectedType = 'mobile';
    bool isSubmitting = false;

    // Speech-to-text + manual text input
    final speech = stt.SpeechToText();
    bool isListening = false;
    bool speechAvailable = false;
    bool speechInitialized = false;
    String spokenText = '';
    bool autoSubmitted = false; // Prevent double-submit from speech
    final descController = TextEditingController();
    bool useVoice = true; // Toggle between voice and text input

    final allTypes = [
      ('Mobiler Blitzer', 'mobile', Icons.directions_car_rounded, Colors.orange),
      ('Fester Blitzer', 'fixed', Icons.photo_camera_rounded, Colors.red),
      ('Baustelle', 'construction', Icons.construction_rounded, Colors.amber),
      ('Unfall', 'accident', Icons.warning_rounded, Colors.purple),
      ('Polizeikontrolle', 'police', Icons.local_police_rounded, Colors.blue),
      ('Werkstatt', 'workshop', Icons.build_rounded, Colors.green),
      ('Tankstelle', 'gas_station', Icons.local_gas_station_rounded, Colors.cyan),
      ('Biker-Treff', 'biker_meetup', Icons.groups_rounded, Colors.pink),
      ('Schöne Strecke', 'scenic_route', Icons.landscape_rounded, Colors.teal),
    ];

    // Map spoken keywords to report types
    String? _detectTypeFromSpeech(String text) {
      final lower = text.toLowerCase();
      if (lower.contains('blitzer') && lower.contains('mobil')) return 'mobile';
      if (lower.contains('blitzer') && lower.contains('fest')) return 'fixed';
      if (lower.contains('blitzer')) return 'mobile';
      if (lower.contains('baustelle')) return 'construction';
      if (lower.contains('unfall')) return 'accident';
      if (lower.contains('polizei')) return 'police';
      if (lower.contains('werkstatt')) return 'workshop';
      if (lower.contains('tank')) return 'gas_station';
      if (lower.contains('treff') || lower.contains('treffen')) return 'biker_meetup';
      if (lower.contains('strecke') || lower.contains('schön')) return 'scenic_route';
      return null;
    }

    // Get label for type
    String _labelForType(String type) {
      for (final t in allTypes) {
        if (t.$2 == type) return t.$1;
      }
      return type;
    }

    // ── Auto-submit function (called from speech detection) ──
    Future<void> _autoSubmitReport(String type, String? description, BuildContext sheetCtx) async {
      if (autoSubmitted || isSubmitting) return;
      if (_currentPosition == null) return;
      autoSubmitted = true;

      final repo = ref.read(blitzerRepositoryProvider);
      final currentPolicy = ref.read(countryPolicyProvider).policy;
      final policyError = repo.canCreateReportWithPolicy(currentPolicy);
      if (policyError != null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(policyError), backgroundColor: Colors.orange));
        autoSubmitted = false;
        return;
      }

      isSubmitting = true;
      speech.stop();

      try {
        await repo.createReportWithPolicy(
          latitude: _currentPosition!.latitude,
          longitude: _currentPosition!.longitude,
          policy: currentPolicy,
          type: type,
          description: description,
        );
        if (mounted) Navigator.pop(sheetCtx);
        _loadReports();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(children: [
              const Icon(Icons.bolt_rounded, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Text('${_labelForType(type)} gemeldet! +10 XP', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ]),
            backgroundColor: accentColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ));
        }
      } catch (e) {
        autoSubmitted = false;
        isSubmitting = false;
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          // Initialize speech on first build
          if (!speechInitialized) {
            speechInitialized = true;
            speech.initialize(
              onStatus: (status) {
                debugPrint('[Speech] Status: $status');
                if (status == 'done' || status == 'notListening') {
                  setSheetState(() => isListening = false);
                }
              },
              onError: (error) {
                debugPrint('[Speech] Error: $error');
                setSheetState(() => isListening = false);
              },
            ).then((available) {
              speechAvailable = available;
              debugPrint('[Speech] Available: $available');
              // Auto-start listening when sheet opens
              if (available && !isListening && useVoice) {
                setSheetState(() => isListening = true);
                speech.listen(
                  onResult: (result) {
                    setSheetState(() {
                      spokenText = result.recognizedWords;
                      // Auto-detect report type from speech
                      final detected = _detectTypeFromSpeech(spokenText);
                      if (detected != null) {
                        selectedType = detected;
                        // Auto-submit when type detected from final result
                        if (result.finalResult && !autoSubmitted) {
                          _autoSubmitReport(detected, spokenText.trim().isNotEmpty ? spokenText.trim() : null, ctx);
                        }
                      }
                    });
                  },
                  localeId: 'de_DE',
                  listenMode: stt.ListenMode.dictation,
                );
              }
            });
          }

          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: community?.cardFor(brightness) ?? (brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sheetHandle(brightness),
                Row(children: [
                  Expanded(child: Text('Meldung erstellen', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: textColor))),
                  // XP Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [accentColor.withValues(alpha: 0.15), accentColor.withValues(alpha: 0.05)]),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.bolt_rounded, color: accentColor, size: 14),
                      const SizedBox(width: 3),
                      Text('+10 XP', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: accentColor)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 6),
                Text('Tippe oder sprich den Typ deiner Meldung', style: GoogleFonts.inter(fontSize: 12, color: mutedColor)),
                const SizedBox(height: 12),

                // ── Voice / Text Toggle ──
                Row(children: [
                  Expanded(child: GestureDetector(
                    onTap: () => setSheetState(() { useVoice = true; }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: useVoice ? accentColor.withValues(alpha: 0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: useVoice ? accentColor.withValues(alpha: 0.4) : mutedColor.withValues(alpha: 0.2)),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.mic_rounded, size: 16, color: useVoice ? accentColor : mutedColor),
                        const SizedBox(width: 6),
                        Text('Spracheingabe', style: GoogleFonts.inter(fontSize: 12, fontWeight: useVoice ? FontWeight.w600 : FontWeight.w400, color: useVoice ? accentColor : mutedColor)),
                      ]),
                    ),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: GestureDetector(
                    onTap: () {
                      if (isListening) { speech.stop(); }
                      setSheetState(() { useVoice = false; isListening = false; });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: !useVoice ? accentColor.withValues(alpha: 0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: !useVoice ? accentColor.withValues(alpha: 0.4) : mutedColor.withValues(alpha: 0.2)),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.keyboard_rounded, size: 16, color: !useVoice ? accentColor : mutedColor),
                        const SizedBox(width: 6),
                        Text('Texteingabe', style: GoogleFonts.inter(fontSize: 12, fontWeight: !useVoice ? FontWeight.w600 : FontWeight.w400, color: !useVoice ? accentColor : mutedColor)),
                      ]),
                    ),
                  )),
                ]),
                const SizedBox(height: 14),

                // ── Voice Input Mode ──
                if (useVoice) ...[
                  Center(child: GestureDetector(
                    onTap: () {
                      if (isListening) {
                        speech.stop();
                        setSheetState(() => isListening = false);
                      } else if (speechAvailable) {
                        setSheetState(() {
                          isListening = true;
                          spokenText = '';
                          autoSubmitted = false;
                        });
                        speech.listen(
                          onResult: (result) {
                            setSheetState(() {
                              spokenText = result.recognizedWords;
                              final detected = _detectTypeFromSpeech(spokenText);
                              if (detected != null) {
                                selectedType = detected;
                                // Auto-submit when type detected from final result
                                if (result.finalResult && !autoSubmitted) {
                                  _autoSubmitReport(detected, spokenText.trim().isNotEmpty ? spokenText.trim() : null, ctx);
                                }
                              }
                            });
                          },
                          localeId: 'de_DE',
                          listenMode: stt.ListenMode.dictation,
                        );
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        color: isListening ? Colors.red : accentColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        boxShadow: isListening ? [
                          BoxShadow(color: Colors.red.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: 4),
                        ] : null,
                      ),
                      child: Icon(
                        isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                        color: isListening ? Colors.white : accentColor,
                        size: 30,
                      ),
                    ),
                  )),
                  if (spokenText.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
                      ),
                      child: Row(children: [
                        Icon(Icons.format_quote_rounded, size: 16, color: mutedColor),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                          '"$spokenText"',
                          style: GoogleFonts.inter(fontSize: 13, fontStyle: FontStyle.italic, color: textColor),
                        )),
                      ]),
                    ),
                  ],
                  if (isListening) ...[
                    const SizedBox(height: 8),
                    Center(child: Text(
                      'Sprich jetzt... z.B. "Blitzer" oder "Baustelle"',
                      style: GoogleFonts.inter(fontSize: 11, color: mutedColor),
                      textAlign: TextAlign.center,
                    )),
                  ],
                ],

                // ── Text Input Mode ──
                if (!useVoice) ...[
                  TextField(
                    controller: descController, style: GoogleFonts.inter(fontSize: 14, color: textColor),
                    decoration: InputDecoration(
                      hintText: 'Beschreibung (optional)', hintStyle: GoogleFonts.inter(fontSize: 14, color: mutedColor),
                      filled: true, fillColor: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.withValues(alpha: 0.06),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: mutedColor.withValues(alpha: 0.15))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: mutedColor.withValues(alpha: 0.15))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accentColor, width: 1.5)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // ── Type selection chips ──
                Wrap(spacing: 8, runSpacing: 8, children: allTypes.map((item) {
                  final isSel = selectedType == item.$2;
                  return GestureDetector(
                    onTap: () => setSheetState(() => selectedType = item.$2),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSel ? item.$4.withValues(alpha: 0.15) : (brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.withValues(alpha: 0.08)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isSel ? item.$4.withValues(alpha: 0.5) : (brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.15))),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(item.$3, size: 16, color: isSel ? item.$4 : mutedColor),
                        const SizedBox(width: 6),
                        Text(item.$1, style: GoogleFonts.inter(fontSize: 12, fontWeight: isSel ? FontWeight.w600 : FontWeight.w400, color: isSel ? item.$4 : mutedColor)),
                      ]),
                    ),
                  );
                }).toList()),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(
                  onPressed: isSubmitting ? null : () async {
                    // Stop listening if active
                    if (isListening) speech.stop();
                    if (_currentPosition == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('GPS wird noch ermittelt...'))); return; }
                    // Policy + rate limit check
                    final repo = ref.read(blitzerRepositoryProvider);
                    final currentPolicy = ref.read(countryPolicyProvider).policy;
                    final policyError = repo.canCreateReportWithPolicy(currentPolicy);
                    if (policyError != null) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(policyError), backgroundColor: Colors.orange));
                      return;
                    }
                    setSheetState(() => isSubmitting = true);
                    // Use voice text or manual text
                    final description = useVoice
                        ? (spokenText.trim().isNotEmpty ? spokenText.trim() : null)
                        : (descController.text.trim().isNotEmpty ? descController.text.trim() : null);
                    try {
                      await repo.createReportWithPolicy(
                        latitude: _currentPosition!.latitude,
                        longitude: _currentPosition!.longitude,
                        policy: currentPolicy,
                        type: selectedType,
                        description: description,
                      );
                      if (mounted) Navigator.pop(ctx);
                      _loadReports();
                      // Show XP feedback
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Row(children: [
                            const Icon(Icons.bolt_rounded, color: Colors.amber, size: 20),
                            const SizedBox(width: 8),
                            Text('${_labelForType(selectedType)} gemeldet! +10 XP', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                          ]),
                          backgroundColor: accentColor,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          duration: const Duration(seconds: 3),
                        ));
                      }
                    } catch (e) {
                      setSheetState(() => isSubmitting = false);
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
                    }
                  },
                  icon: isSubmitting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.add_location_alt_rounded, size: 20),
                  label: Text('Melden', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(backgroundColor: accentColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                )),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    ).whenComplete(() {
      // Ensure speech is stopped when sheet is dismissed
      speech.stop();
      descController.dispose();
    });
  }

  // ─── Policy Banner ───────────────────────────────────────────────────

  Widget _buildPolicyBanner(Color accentColor, Brightness brightness) {
    final policyState = ref.watch(countryPolicyProvider);
    final policy = policyState.policy;

    // No banner if policy not loaded yet or mode is exact (normal)
    if (policy == null || policy.isExact) return const SizedBox.shrink();

    final isDark = brightness == Brightness.dark;
    final countryCode = policy.countryCode;

    if (policy.isOff) {
      // ── Mode: OFF — Blitzer deactivated ──
      return Positioned(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: isDark ? 0.85 : 0.9),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.block_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Blitzer-Warnungen deaktiviert',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Nicht verfügbar in $countryCode',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (policy.isDangerZone) {
      // ── Mode: DANGER ZONE — coarse zones only ──
      return Positioned(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: isDark ? 0.85 : 0.9),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.shield_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Gefahrenzonen-Modus ($countryCode)',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Ungefähre Zonen statt exakter Standorte',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // ─── Helpers ──────────────────────────────────────────────────────────

  Widget _sheetHandle(Brightness brightness) => Center(child: Container(
    width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(2),
    ),
  ));

  Widget _typeIcon(String type, double size) {
    final (icon, color) = switch (type) {
      'fixed' => (Icons.photo_camera_rounded, Colors.red),
      'mobile' => (Icons.directions_car_rounded, Colors.orange),
      'construction' => (Icons.construction_rounded, Colors.amber),
      'accident' => (Icons.warning_rounded, Colors.purple),
      'police' => (Icons.local_police_rounded, Colors.blue),
      'workshop' => (Icons.build_rounded, Colors.green),
      'gas_station' => (Icons.local_gas_station_rounded, Colors.cyan),
      'biker_meetup' => (Icons.groups_rounded, Colors.pink),
      'scenic_route' => (Icons.landscape_rounded, Colors.teal),
      _ => (Icons.photo_camera_rounded, Colors.red),
    };
    return Icon(icon, size: size, color: color);
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'gerade eben';
    if (diff.inMinutes < 60) return 'vor ${diff.inMinutes} Min.';
    if (diff.inHours < 24) return 'vor ${diff.inHours} Std.';
    return 'vor ${diff.inDays} Tagen';
  }

  // ═════════════════════════════════════════════════════════════════════════
  // BUILD — minimal ref.watch, no side effects
  // ═════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final community = ref.watch(communityProvider);
    final brightness = Theme.of(context).brightness;
    final accentColor = community?.accentColor ?? AppTheme.accentDark;
    _cachedAccentColor = accentColor; // Keep in sync for async callbacks
    // Reload nav icon if community changed
    if (community != _cachedCommunity && community != null) {
      _cachedCommunity = community;
      _preloadNavIcon();
    }
    // Always black behind map (like UserMapScreen) — prevents beige bleed-through
    const scaffoldBg = Colors.black;

    // Only watch STRUCTURAL nav state (changes rarely)
    final isNavigating = ref.watch(navigationProvider.select((s) => s.isNavigating));
    final hasRoute = ref.watch(navigationProvider.select((s) => s.hasRoute));
    final isCalculating = ref.watch(navigationProvider.select((s) => s.isCalculating));
    final navError = ref.watch(navigationProvider.select((s) => s.error));
    // Watch search state so results trigger a rebuild
    final searchResults = ref.watch(navigationProvider.select((s) => s.searchResults));
    final isSearching = ref.watch(navigationProvider.select((s) => s.isSearching));

    final isLive = ref.watch(isLiveProvider);
    final liveCount = _liveUsers.length;

    // ── Android Auto: push nav state on every change ──
    ref.listen(navigationProvider, (_, next) {
      ref.read(androidAutoServiceProvider).pushNavigationState(next);
    });

    // ── Consume focus target (from global online users list) ──
    final focusTarget = ref.watch(focusMapTargetProvider);
    if (focusTarget != null && _mapController != null) {
      // Jump to the target location
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_disposed || !mounted) return;
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(
          focusTarget.position, focusTarget.zoom,
        ));
        // If it's a live user, select them and show their profile bubble
        if (focusTarget.userId != null && _liveUsers.containsKey(focusTarget.userId)) {
          setState(() {
            _selectedLiveUser = _liveUsers[focusTarget.userId!];
            _showProfileBubble = true;
          });
        }
        ref.read(focusMapTargetProvider.notifier).clear();
      });
    }

    // ── Loading ──
    if (!_locationReady) {
      return Scaffold(
        backgroundColor: scaffoldBg,
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(color: accentColor, strokeWidth: 3),
          const SizedBox(height: 20),
          Text('Standort wird ermittelt...', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: brightness == Brightness.dark ? Colors.white70 : const Color(0xFF6C757D))),
        ])),
      );
    }

    final initialTarget = _currentPosition != null ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude) : _defaultCenter;
    final initialZoom = _currentPosition != null ? 15.0 : 6.0;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Stack(
        children: [
          // ── Google Map (stable, no dynamic params) ──
          GoogleMap(
            key: const ValueKey('blitzer_map'),
            initialCameraPosition: CameraPosition(target: initialTarget, zoom: initialZoom),
            onMapCreated: (c) { _mapController = c; debugPrint('[Blitzer] Map created'); },
            myLocationEnabled: _navMarkerIcon == null, // Blauer Punkt nur wenn Profil-Icon noch nicht geladen
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            markers: _cachedAllMarkers,
            polylines: _cachedPolylines,
            circles: _cachedDangerZones,
            mapType: _mapType,
            // Waze-Style: Top-Padding verschiebt logischen Mittelpunkt nach unten
            // → Marker bleibt FEST unten-mitte, Karte dreht sich um diesen Punkt
            // Bei Navigation: 65% Shift (Marker ganz unten), sonst: 0 (zentriert)
            padding: EdgeInsets.only(
              top: _isNavigatingCached
                  ? MediaQuery.of(context).size.height * 0.65
                  : 0,
              bottom: 120 + MediaQuery.of(context).padding.bottom, // push Google logo behind bottom nav
            ),
            style: brightness == Brightness.dark ? _darkMapStyle : _lightMapStyle,
            onCameraMoveStarted: () {
              // Detect user gesture (pan/zoom) vs programmatic camera move
              // When user manually interacts, pause follow mode
              if (_isNavigatingCached) {
                ref.read(drivingModeProvider.notifier).onUserPannedMap();
              }

              // Auto re-center nach 3s — NICHT wenn Route-Sheet offen (User scrollt/zoomt selbst)
              _autoReCenterTimer?.cancel();
              if (!_routeSheetOpen) {
                _autoReCenterTimer = Timer(const Duration(seconds: 3), () {
                  if (_disposed || !mounted || _currentPosition == null) return;
                  if (_isNavigatingCached) {
                    // Navigation: 3D-Kamera mit Heading
                    final settings = ref.read(blitzerSettingsProvider).value ?? const BlitzerSettings();
                    final use3d = _is3D || settings.headingRotation;
                    _mapController?.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
                      target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                      zoom: _is3D ? 18 : settings.followZoom,
                      tilt: use3d ? (_is3D ? 65 : settings.followTilt) : 0,
                      bearing: use3d ? _currentPosition!.heading : 0,
                    )));
                    ref.read(drivingModeProvider.notifier).reCenter();
                  } else {
                    // Normal: zur aktuellen Position zentrieren + Zoom zurücksetzen
                    _mapController?.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
                      target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                      zoom: 15.0,
                    )));
                  }
                });
              }
            },
            onTap: (_) {
              if (_showProfileBubble || _selectedLiveUser != null) {
                setState(() { _showProfileBubble = false; _selectedLiveUser = null; });
              }
            },
          ),

          // ── Google-Logo & Copyright-Overlay ausblenden ──
          // Überdeckt "Google", "2026 Google", "Bilder 2016 Airbus, Maxar" etc.
          // ClipRect sorgt dafür, dass nichts durchscheint
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: IgnorePointer(
              child: Container(
                height: 56,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black,
                      Colors.black,
                      Color(0x00000000), // transparent
                    ],
                    stops: [0.0, 0.7, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // ══════════════════════════════════════════════════════════════
          // COUNTRY POLICY BANNER (off / danger_zone mode warning)
          // ══════════════════════════════════════════════════════════════
          if (!isNavigating) _buildPolicyBanner(accentColor, brightness),

          // ══════════════════════════════════════════════════════════════
          // PROFIL-BUBBLE — erscheint wenn man auf den Profil-Marker tippt
          // ══════════════════════════════════════════════════════════════
          if (_showProfileBubble && !isNavigating)
            _buildProfileBubble(accentColor, brightness),

          // ══════════════════════════════════════════════════════════════
          // LIVE-USER BUBBLE — erscheint wenn man auf einen Live-User tippt
          // ══════════════════════════════════════════════════════════════
          if (_selectedLiveUser != null)
            _buildLiveUserBubble(accentColor, brightness),

          // ══════════════════════════════════════════════════════════════
          // NORMAL MODE
          // ══════════════════════════════════════════════════════════════
          if (!isNavigating) ...[
            // DEBUG: Suchleiste-Sichtbarkeit
            if (hasRoute || _routeSheetOpen) Builder(builder: (_) { debugPrint('[Build] _routeSheetOpen=$_routeSheetOpen, hasRoute=$hasRoute'); return const SizedBox.shrink(); }),
            // Search bar — sichtbar wenn Route-Sheet NICHT offen ist
            if (!_routeSheetOpen)
            Positioned(
              left: 0, right: 0,
              bottom: 60 + MediaQuery.of(context).padding.bottom,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // Search results expand UPWARD from the search field
                  if (_showSearchResults || (_searchFocusNode.hasFocus && _searchController.text.isEmpty))
                    _buildSearchResults(brightness, searchResults: searchResults, isSearching: isSearching),
                  const SizedBox(height: 4),
                  Row(children: [
                    Expanded(child: _buildSearchField(brightness)),
                    // Community Users badge (tap → list, long-press → toggle layer)
                    if (_communityUserCount > 0 && !isNavigating) ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => _showCommunityUsersSheet(brightness),
                        onLongPress: () {
                          setState(() => _showCommunityUsers = !_showCommunityUsers);
                          _rebuildCachedMarkers();
                        },
                        child: Builder(builder: (context) {
                          // Live count from global notifier (not PLZ count)
                          final liveCount = _liveUsers.length;
                          final hasLive = liveCount > 0;
                          final iconColor = hasLive
                              ? const Color(0xFF00E676)
                              : (_showCommunityUsers
                                  ? accentColor
                                  : (brightness == Brightness.dark ? Colors.white38 : Colors.black38));
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                            decoration: BoxDecoration(
                              color: hasLive
                                  ? const Color(0xFF00C853).withValues(alpha: 0.15)
                                  : (_showCommunityUsers
                                      ? accentColor.withValues(alpha: 0.15)
                                      : (brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06))),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: hasLive
                                    ? const Color(0xFF00E676).withValues(alpha: 0.4)
                                    : (_showCommunityUsers ? accentColor.withValues(alpha: 0.3) : Colors.transparent),
                              ),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.people_rounded, size: 16, color: iconColor),
                              if (hasLive) ...[
                                const SizedBox(width: 4),
                                Text('$liveCount',
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600,
                                        color: const Color(0xFF00E676))),
                              ],
                            ]),
                          );
                        }),
                      ),
                    ],
                    // Online badge removed — shown in global top bar instead
                  ]),
                ]),
              ),
            ),

            // ═══ INLINE ROUTE SHEET ═══
            // Direkt im Stack — Karte bleibt scrollbar, kein Navigator.push nötig.
            if (_routeSheetOpen && hasRoute && !isNavigating)
              Positioned.fill(
                child: _buildInlineRouteSheet(accentColor, brightness),
              ),

            // Calculating spinner
            if (isCalculating)
              Positioned(left: 12, right: 12, bottom: 68 + MediaQuery.of(context).padding.bottom, child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: brightness == Brightness.dark ? Colors.black.withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)]),
                child: Row(children: [
                  SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: accentColor)),
                  const SizedBox(width: 12),
                  Text('Route wird berechnet...', style: GoogleFonts.inter(fontSize: 14, color: brightness == Brightness.dark ? Colors.white : Colors.black87)),
                ]),
              )),

            // Error panel
            if (navError != null && !hasRoute && !isCalculating)
              Positioned(left: 12, right: 12, bottom: 68 + MediaQuery.of(context).padding.bottom, child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Expanded(child: Text(navError!, style: GoogleFonts.inter(fontSize: 13, color: Colors.white))),
                  IconButton(onPressed: () { ref.read(navigationProvider.notifier).clearRoute(); }, icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                ]),
              )),

            // Speed-Dial overlay is now rendered by MainShell
          ],

          // ── Blitzer Alert Banner (ALWAYS visible — not just in navigation) ──
          if (_blitzerWarning != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + (isNavigating ? 110 : 60),
              left: 20, right: 20,
              child: _BlitzerAlertBanner(warning: _blitzerWarning!),
            ),

          // ── Profile Avatar (ALWAYS visible — top left on map) ──
          // ══════════════════════════════════════════════════════════════
          // NAVIGATION MODE — separate ConsumerWidgets watch fast state
          // ══════════════════════════════════════════════════════════════
          if (isNavigating) ...[
            // ── GPS Quality Indicator (colored dot) ──
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 16,
              child: Consumer(
                builder: (context, ref, _) {
                  final quality = ref.watch(drivingModeProvider).locationQuality;
                  final qualityColor = switch (quality) {
                    LocationQuality.good => const Color(0xFF4CAF50),
                    LocationQuality.degraded => const Color(0xFFFF9800),
                    LocationQuality.lost => const Color(0xFFF44336),
                  };
                  final qualityLabel = switch (quality) {
                    LocationQuality.good => 'GPS',
                    LocationQuality.degraded => 'GPS schwach',
                    LocationQuality.lost => 'Kein GPS',
                  };
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle, color: qualityColor,
                            boxShadow: [BoxShadow(color: qualityColor.withValues(alpha: 0.5), blurRadius: 4)],
                          ),
                        ),
                        if (quality != LocationQuality.good) ...[
                          const SizedBox(width: 6),
                          Text(qualityLabel, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500)),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),

            _NavTurnBanner(accentColor: accentColor, brightness: brightness),

            // ── Tempolimit-Badge (europäisches Schild, nur bei Blitzer mit Speed-Limit) ──
            Consumer(
              builder: (context, ref, _) {
                final speedLimit = ref.watch(drivingModeProvider.select((s) => s.nearestSpeedLimit));
                final currentSpeed = ref.watch(navigationProvider.select((s) => s.currentSpeed));
                if (speedLimit == null) return const SizedBox.shrink();

                final isOverLimit = currentSpeed > speedLimit + 5; // 5 km/h Toleranz
                return Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 16,
                  child: Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: isOverLimit ? Colors.red : Colors.red.shade700, width: isOverLimit ? 4 : 3),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8)],
                    ),
                    child: Center(
                      child: Text(
                        '$speedLimit',
                        style: GoogleFonts.inter(
                          fontSize: 18, fontWeight: FontWeight.w900,
                          color: isOverLimit ? Colors.red : Colors.black,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // ── Re-Center Button (when user panned map) ──
            _ReCenterButton(onReCenter: () {
              ref.read(drivingModeProvider.notifier).reCenter();
              if (_currentPosition != null) {
                final settings = ref.read(blitzerSettingsProvider).value ?? const BlitzerSettings();
                _mapController?.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
                  target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                  zoom: settings.followZoom,
                  tilt: settings.headingRotation ? settings.followTilt : 0,
                  bearing: _currentPosition!.heading,
                )));
              }
            }),

            _NavBottomBar(
              accentColor: accentColor, brightness: brightness,
              onStop: _stopNavigation, onReport: _showCreateReportSheet,
              onSettings: () => _openNavSettingsDuringDrive(brightness),
              onToggle3D: _toggleNav3D,
              onToggleMapType: _toggleNavMapType,
              onShowOnline: () => _showOnlineUsersSheet(brightness),
              is3D: _is3D,
              isLive: isLive,
              liveCount: liveCount,
              drivenKm: _navDistanceMeters / 1000,
            ),
          ],
        ],
      ),
    );
  }

  // ─── Widgets used in build ────────────────────────────────────────────

  Widget _mapButton({required IconData icon, required Color color, required Brightness brightness, required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(
        color: brightness == Brightness.dark ? Colors.black.withValues(alpha: 0.75) : Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        boxShadow: brightness == Brightness.light ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2))] : null,
      ),
      child: IconButton(onPressed: onTap, icon: Icon(icon, color: color, size: 22)),
    );
  }

  Widget _buildSearchField(Brightness brightness) {
    final hasFocus = _searchFocusNode.hasFocus;
    final accentColor = _cachedAccentColor;

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: brightness == Brightness.dark ? Colors.black.withValues(alpha: 0.75) : Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        border: hasFocus ? Border.all(color: accentColor.withValues(alpha: 0.6), width: 1.5) : null,
        boxShadow: brightness == Brightness.light ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2))] : null,
      ),
      child: TextField(
        controller: _searchController, focusNode: _searchFocusNode,
        onChanged: _onSearchChanged,
        textInputAction: TextInputAction.search,
        style: GoogleFonts.inter(fontSize: 14, color: brightness == Brightness.dark ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          hintText: 'Ziel suchen...', hintStyle: GoogleFonts.inter(fontSize: 14, color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.4) : Colors.grey),
          prefixIcon: Icon(Icons.search_rounded, color: hasFocus ? accentColor : (brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.4) : Colors.grey), size: 20),
          suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.close_rounded, size: 18, color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.4) : Colors.grey),
                onPressed: () {
                  _searchController.clear();
                  _onSearchChanged('');
                },
              )
            : Row(mainAxisSize: MainAxisSize.min, children: [
                // Mikrofon-Icon für Spracheingabe (immer sichtbar)
                if (_speechAvailable)
                  IconButton(
                    icon: Icon(
                      _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                      size: 20,
                      color: _isListening ? Colors.red : (brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.5) : Colors.grey),
                    ),
                    onPressed: () {
                      if (!hasFocus) _searchFocusNode.requestFocus();
                      _toggleVoiceSearch();
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                // Tastatur ausblenden (nur wenn fokussiert)
                if (hasFocus)
                  IconButton(
                    icon: Icon(Icons.keyboard_hide_rounded, size: 18, color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.4) : Colors.grey),
                    onPressed: () {
                      if (_isListening) _speech.stop();
                      _searchFocusNode.unfocus();
                      setState(() { _showSearchResults = false; _isListening = false; });
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
              ]),
          border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildSearchResults(Brightness brightness, {
    required List<GeocodingResult> searchResults,
    required bool isSearching,
  }) {
    final bgColor = brightness == Brightness.dark ? Colors.black.withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.95);
    final textColor = brightness == Brightness.dark ? Colors.white : Colors.black87;
    final mutedColor = brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.4) : Colors.grey;
    final accentColor = _cachedAccentColor;

    // Searching indicator
    if (isSearching) {
      return Container(
        margin: const EdgeInsets.only(top: 4), padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: accentColor)),
          const SizedBox(width: 12),
          Text('Suche...', style: GoogleFonts.inter(fontSize: 13, color: mutedColor)),
        ]),
      );
    }

    // ── Saved places (always visible when search focused) ──
    final savedPlaces = ref.watch(savedPlacesProvider);
    final homePlace = savedPlaces.where((p) => p.id == 'home').firstOrNull;
    final workPlace = savedPlaces.where((p) => p.id == 'work').firstOrNull;
    Widget buildQuickButtons() {
      return Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
        child: Row(children: [
          // Zuhause — immer sichtbar
          Expanded(child: GestureDetector(
            onTap: () {
              if (homePlace != null) {
                _onSavedPlaceTap(homePlace);
              } else {
                _showSetPlaceSheet(context, 'home');
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.withValues(alpha: 0.25)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.home_rounded, size: 18, color: Colors.green),
                const SizedBox(width: 6),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Zuhause', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: textColor)),
                    Text(
                      homePlace?.address ?? 'Nicht festgelegt',
                      style: GoogleFonts.inter(fontSize: 10, color: mutedColor),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ],
                )),
              ]),
            ),
          )),
          const SizedBox(width: 8),
          // Arbeit — immer sichtbar
          Expanded(child: GestureDetector(
            onTap: () {
              if (workPlace != null) {
                _onSavedPlaceTap(workPlace);
              } else {
                _showSetPlaceSheet(context, 'work');
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.25)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.work_rounded, size: 18, color: Colors.blue),
                const SizedBox(width: 6),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Arbeit', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: textColor)),
                    Text(
                      workPlace?.address ?? 'Nicht festgelegt',
                      style: GoogleFonts.inter(fontSize: 10, color: mutedColor),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ],
                )),
              ]),
            ),
          )),
        ]),
      );
    }

    // ── Show search results if we have query text ──
    if (_searchController.text.trim().length >= 2) {
      // Duplikate filtern: Historie-Namen aus API-Ergebnissen entfernen
      final historyNames = _filteredHistory
          .map((e) => (e['name'] as String? ?? '').toLowerCase())
          .toSet();
      final filteredApiResults = searchResults
          .where((r) => !historyNames.contains(r.shortName.toLowerCase()))
          .toList();

      final hasHistory = _filteredHistory.isNotEmpty;
      final hasApi = filteredApiResults.isNotEmpty;

      if (!hasHistory && !hasApi) {
        return Container(
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text('Kein Ergebnis für "${_searchController.text.trim()}"',
                style: GoogleFonts.inter(fontSize: 13, color: mutedColor)),
            ),
            Divider(height: 8, color: mutedColor.withValues(alpha: 0.15)),
            buildQuickButtons(),
          ]),
        );
      }
      return Container(
        margin: const EdgeInsets.only(top: 4), constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.65),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12), boxShadow: brightness == Brightness.light ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8)] : null),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Flexible(
            child: ListView(
              shrinkWrap: true, padding: const EdgeInsets.symmetric(vertical: 4),
              children: [
                // ── Letzte Ziele (Historie-Treffer, klappbar) ──
                if (hasHistory) ...[
                  GestureDetector(
                    onTap: () => setState(() => _historyExpanded = !_historyExpanded),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 4, 10, 4),
                      child: Row(children: [
                        Icon(Icons.history_rounded, size: 14, color: mutedColor),
                        const SizedBox(width: 4),
                        Text('Letzte Ziele (${_filteredHistory.length})', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: mutedColor)),
                        const Spacer(),
                        AnimatedRotation(
                          turns: _historyExpanded ? 0.0 : -0.25,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(Icons.expand_more_rounded, size: 18, color: mutedColor),
                        ),
                      ]),
                    ),
                  ),
                  if (_historyExpanded)
                    ..._filteredHistory.map((entry) {
                      final name = entry['name'] as String? ?? '';
                      final display = entry['displayName'] as String? ?? '';
                      final road = entry['road'] as String? ?? '';
                      final subtitle = road.isNotEmpty ? road : (display.length > name.length ? display : null);
                      return ListTile(
                        dense: true,
                        leading: Icon(Icons.schedule_rounded, color: accentColor, size: 20),
                        title: Text(name, style: GoogleFonts.inter(fontSize: 14, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: subtitle != null ? Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: mutedColor), maxLines: 1, overflow: TextOverflow.ellipsis) : null,
                        trailing: Icon(Icons.north_west_rounded, size: 14, color: mutedColor),
                        onTap: () => _onHistoryItemTap(entry),
                      );
                    }),
                ],
                // ── Trennlinie zwischen Historie und API ──
                if (hasHistory && hasApi)
                  Divider(height: 1, color: mutedColor.withValues(alpha: 0.2)),
                // ── Nominatim API-Ergebnisse ──
                if (hasApi) ...[
                  if (hasHistory)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
                      child: Row(children: [
                        Icon(Icons.search_rounded, size: 14, color: mutedColor),
                        const SizedBox(width: 4),
                        Text('Suchergebnisse', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: mutedColor)),
                      ]),
                    ),
                  ...filteredApiResults.map((r) => ListTile(
                    dense: true,
                    leading: Icon(r.typeIcon, color: accentColor, size: 20),
                    title: Text(r.shortName, style: GoogleFonts.inter(fontSize: 14, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: r.state != null ? Text(r.state!, style: GoogleFonts.inter(fontSize: 12, color: mutedColor), maxLines: 1, overflow: TextOverflow.ellipsis) : null,
                    onTap: () => _onSearchResultTap(r),
                  )),
                ],
              ],
            ),
          ),
          Divider(height: 8, color: mutedColor.withValues(alpha: 0.15)),
          buildQuickButtons(),
        ]),
      );
    }

    // ── No query text → show saved places + search history ──
    if (_searchHistory.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 4),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text('Ziel eingeben um zu suchen', style: GoogleFonts.inter(fontSize: 13, color: mutedColor)),
          ),
          Divider(height: 8, color: mutedColor.withValues(alpha: 0.15)),
          buildQuickButtons(),
        ]),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 4), constraints: const BoxConstraints(maxHeight: 340),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12), boxShadow: brightness == Brightness.light ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8)] : null),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // ── Letzte Ziele (klappbar) ──
        if (_searchHistory.isNotEmpty) ...[
        GestureDetector(
          onTap: () => setState(() => _historyExpanded = !_historyExpanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 6, 4),
            child: Row(children: [
              Icon(Icons.history_rounded, size: 16, color: mutedColor),
              const SizedBox(width: 6),
              Text('Letzte Ziele (${_searchHistory.length})', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: mutedColor)),
              const Spacer(),
              AnimatedRotation(
                turns: _historyExpanded ? 0.0 : -0.25,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.expand_more_rounded, size: 20, color: mutedColor),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: _clearSearchHistory,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text('Löschen', style: GoogleFonts.inter(fontSize: 11, color: mutedColor)),
                ),
              ),
            ]),
          ),
        ),
        Divider(height: 1, color: mutedColor.withValues(alpha: 0.15)),
        if (_historyExpanded)
        Flexible(
          child: ListView.separated(
            shrinkWrap: true, padding: const EdgeInsets.symmetric(vertical: 2),
            itemCount: _searchHistory.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: mutedColor.withValues(alpha: 0.15)),
            itemBuilder: (_, i) {
              final entry = _searchHistory[i];
              final name = entry['name'] as String? ?? '';
              final state = entry['state'] as String?;
              return ListTile(
                dense: true,
                leading: Icon(Icons.history_rounded, color: mutedColor, size: 20),
                title: Text(name, style: GoogleFonts.inter(fontSize: 14, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: state != null ? Text(state, style: GoogleFonts.inter(fontSize: 12, color: mutedColor), maxLines: 1, overflow: TextOverflow.ellipsis) : null,
                trailing: Icon(Icons.north_west_rounded, size: 16, color: mutedColor),
                onTap: () => _onHistoryItemTap(entry),
              );
            },
          ),
        ),
        ], // end if (_searchHistory.isNotEmpty)
        // ── Zuhause / Arbeit Quick-Buttons (unten) ──
        Divider(height: 8, color: mutedColor.withValues(alpha: 0.15)),
        buildQuickButtons(),
      ]),
    );
  }

  /// Show bottom sheet with all online users.
  void _showOnlineUsersSheet(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final mutedColor = isDark ? Colors.white70 : Colors.black54;
    final accentColor = _cachedAccentColor;
    final users = _liveUsers.values.toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Center(child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: mutedColor.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
          )),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Icon(Icons.group_rounded, size: 22, color: Colors.green),
              const SizedBox(width: 8),
              Text('${users.length} Biker online', style: GoogleFonts.inter(
                fontSize: 18, fontWeight: FontWeight.w700, color: textColor,
              )),
            ]),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: mutedColor.withValues(alpha: 0.15)),
          Flexible(
            child: users.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Keine Biker online', style: GoogleFonts.inter(fontSize: 14, color: mutedColor)),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: users.length,
                  separatorBuilder: (_, __) => Divider(height: 1, indent: 72, color: mutedColor.withValues(alpha: 0.1)),
                  itemBuilder: (_, i) {
                    final u = users[i];
                    final level = XpCalculator.levelFromXp(u.xpTotal);
                    final levelN = XpCalculator.levelName(level);
                    final levelC = XpCalculator.levelColor(level);

                    return InkWell(
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        // Karte auf User zentrieren und Bubble anzeigen
                        setState(() {
                          _selectedLiveUser = u;
                          _showProfileBubble = false;
                        });
                        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(
                          LatLng(u.lat, u.lng), 15,
                        ));
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(children: [
                          // Profilbild
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: levelC.withValues(alpha: 0.2),
                            backgroundImage: u.avatarUrl != null && u.avatarUrl!.isNotEmpty
                                ? NetworkImage(u.avatarUrl!)
                                : null,
                            child: u.avatarUrl == null || u.avatarUrl!.isEmpty
                                ? Icon(Icons.person_rounded, size: 22, color: levelC)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          // Name + Level
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(u.displayName, style: GoogleFonts.inter(
                                fontSize: 15, fontWeight: FontWeight.w600, color: textColor,
                              ), maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Row(children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: levelC.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('Lvl $level · $levelN', style: GoogleFonts.inter(
                                    fontSize: 10, fontWeight: FontWeight.w600, color: levelC,
                                  )),
                                ),
                                if (u.bikeName != null && u.bikeName!.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Icon(Icons.two_wheeler_rounded, size: 12, color: mutedColor),
                                  const SizedBox(width: 2),
                                  Flexible(child: Text(u.bikeName!, style: GoogleFonts.inter(
                                    fontSize: 11, color: mutedColor,
                                  ), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                ],
                              ]),
                            ],
                          )),
                          // Speed + PLZ
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (u.speed > 1)
                                Text('${u.speed.toStringAsFixed(0)} km/h', style: GoogleFonts.inter(
                                  fontSize: 13, fontWeight: FontWeight.w600, color: accentColor,
                                )),
                              if (u.postalCode != null && u.postalCode!.isNotEmpty)
                                Text('PLZ ${u.postalCode}', style: GoogleFonts.inter(
                                  fontSize: 11, color: mutedColor,
                                )),
                            ],
                          ),
                        ]),
                      ),
                    );
                  },
                ),
          ),
        ]),
      ),
    );
  }

  /// Show community users sheet (all users with PLZ on the map).
  /// Tapping on a user jumps the map to their PLZ location.
  void _showCommunityUsersSheet(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final mutedColor = isDark ? Colors.white70 : Colors.black54;
    final accentColor = _cachedAccentColor;

    // Separate live and offline users
    final liveUserIds = _liveUsers.keys.toSet();
    final offlineUsers = _communityUsersData
        .where((u) => !liveUserIds.contains(u['id']))
        .toList();
    final liveList = _liveUsers.values.toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Center(child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: mutedColor.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
          )),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Icon(Icons.people_rounded, size: 22, color: accentColor),
              const SizedBox(width: 8),
              Text('${_communityUserCount} Biker', style: GoogleFonts.inter(
                fontSize: 18, fontWeight: FontWeight.w700, color: textColor,
              )),
              const Spacer(),
              // Toggle visibility
              GestureDetector(
                onTap: () {
                  setState(() => _showCommunityUsers = !_showCommunityUsers);
                  _rebuildCachedMarkers();
                  Navigator.pop(sheetCtx);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _showCommunityUsers ? accentColor.withValues(alpha: 0.12) : mutedColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                      _showCommunityUsers ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                      size: 16,
                      color: _showCommunityUsers ? accentColor : mutedColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _showCommunityUsers ? 'Sichtbar' : 'Ausgeblendet',
                      style: GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w600,
                        color: _showCommunityUsers ? accentColor : mutedColor,
                      ),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: mutedColor.withValues(alpha: 0.15)),
          Flexible(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: [
                // ── Live Users Section ──
                if (liveList.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                    child: Row(children: [
                      Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.green)),
                      const SizedBox(width: 6),
                      Text('${liveList.length} Online', style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w600, color: Colors.green,
                      )),
                    ]),
                  ),
                  for (final u in liveList)
                    InkWell(
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        setState(() {
                          _selectedLiveUser = u;
                          _showProfileBubble = false;
                        });
                        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(
                          LatLng(u.lat, u.lng), 15,
                        ));
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.green.withValues(alpha: 0.2),
                            backgroundImage: u.avatarUrl != null && u.avatarUrl!.isNotEmpty
                                ? NetworkImage(u.avatarUrl!) : null,
                            child: u.avatarUrl == null || u.avatarUrl!.isEmpty
                                ? Text(u.displayName.isNotEmpty ? u.displayName[0].toUpperCase() : '?',
                                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.green))
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(u.displayName, style: GoogleFonts.inter(
                                fontSize: 14, fontWeight: FontWeight.w600, color: textColor,
                              ), maxLines: 1, overflow: TextOverflow.ellipsis),
                              if (u.speed > 1)
                                Text('${u.speed.toStringAsFixed(0)} km/h', style: GoogleFonts.inter(
                                  fontSize: 11, color: Colors.green,
                                )),
                            ],
                          )),
                          Icon(Icons.gps_fixed_rounded, size: 16, color: Colors.green),
                        ]),
                      ),
                    ),
                  Divider(height: 1, indent: 16, endIndent: 16, color: mutedColor.withValues(alpha: 0.1)),
                ],

                // ── Offline PLZ Users Section ──
                if (offlineUsers.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                    child: Row(children: [
                      Icon(Icons.location_on_rounded, size: 14, color: accentColor.withValues(alpha: 0.6)),
                      const SizedBox(width: 4),
                      Text('${offlineUsers.length} in deiner Region', style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w600, color: mutedColor,
                      )),
                    ]),
                  ),
                  for (final u in offlineUsers) ...[
                    InkWell(
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        final lat = u['lat'] as double;
                        final lng = u['lng'] as double;
                        // Enable community users layer if hidden
                        if (!_showCommunityUsers) {
                          setState(() => _showCommunityUsers = true);
                          _rebuildCachedMarkers();
                        }
                        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(
                          LatLng(lat, lng), 13,
                        ));
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: accentColor.withValues(alpha: 0.15),
                            backgroundImage: u['avatar_url'] != null && (u['avatar_url'] as String).isNotEmpty
                                ? NetworkImage(u['avatar_url'] as String) : null,
                            child: u['avatar_url'] == null || (u['avatar_url'] as String).isEmpty
                                ? Text(
                                    ((u['display_name'] ?? u['username'] ?? '?') as String).isNotEmpty
                                        ? ((u['display_name'] ?? u['username'] ?? '?') as String)[0].toUpperCase()
                                        : '?',
                                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: accentColor))
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                u['is_me'] == true
                                    ? '${u['display_name'] ?? u['username'] ?? 'User'} (Du)'
                                    : (u['display_name'] ?? u['username'] ?? 'User') as String,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: u['is_me'] == true ? accentColor : textColor,
                                ),
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          )),
                          // PLZ badge (tappable → jump to location)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'PLZ ${u['postal_code']}',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: accentColor),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ]),
      ),
    );
  }

  /// Navigate to a saved place (Zuhause/Arbeit)
  void _onSavedPlaceTap(SavedPlace place) {
    _searchController.text = place.name;
    _searchFocusNode.unfocus();
    setState(() => _showSearchResults = false);
    _routeCancelled = false;
    final origin = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : _defaultCenter;
    final dest = LatLng(place.lat, place.lng);
    ref.read(navigationProvider.notifier).calculateRoute(origin, dest, name: place.address ?? place.name);
    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(
        southwest: LatLng(
          origin.latitude < dest.latitude ? origin.latitude : dest.latitude,
          origin.longitude < dest.longitude ? origin.longitude : dest.longitude,
        ),
        northeast: LatLng(
          origin.latitude > dest.latitude ? origin.latitude : dest.latitude,
          origin.longitude > dest.longitude ? origin.longitude : dest.longitude,
        ),
      ),
      80,
    ));
  }

  /// BottomSheet zum Setzen von Zuhause/Arbeit via Suche.
  void _showSetPlaceSheet(BuildContext ctx, String placeId) {
    final isHome = placeId == 'home';
    final title = isHome ? 'Zuhause festlegen' : 'Arbeit festlegen';
    final iconData = isHome ? Icons.home_rounded : Icons.work_rounded;
    final color = isHome ? Colors.green : Colors.blue;
    final searchCtrl = TextEditingController();
    final geocoding = GeocodingService();
    List<GeocodingResult> results = [];
    bool searching = false;
    Timer? debounce;

    // Close main search
    _searchFocusNode.unfocus();
    setState(() => _showSearchResults = false);

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final brightness = Theme.of(sheetCtx).brightness;
        final bg = brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white;
        final textColor = brightness == Brightness.dark ? Colors.white : Colors.black87;
        final mutedColor = brightness == Brightness.dark ? Colors.white54 : Colors.grey;

        return StatefulBuilder(builder: (_, setSheetState) {
          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetCtx).size.height * 0.7),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Handle
              Center(child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 36, height: 4,
                decoration: BoxDecoration(color: mutedColor.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
              )),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(children: [
                  Icon(iconData, color: color, size: 22),
                  const SizedBox(width: 10),
                  Text(title, style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: textColor)),
                ]),
              ),
              // Search field
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextField(
                    controller: searchCtrl,
                    autofocus: true,
                    style: GoogleFonts.inter(fontSize: 14, color: textColor),
                    decoration: InputDecoration(
                      hintText: 'Adresse suchen...',
                      hintStyle: GoogleFonts.inter(fontSize: 14, color: mutedColor),
                      prefixIcon: Icon(Icons.search_rounded, size: 20, color: mutedColor),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onChanged: (q) {
                      debounce?.cancel();
                      if (q.trim().length < 2) {
                        setSheetState(() { results = []; searching = false; });
                        return;
                      }
                      setSheetState(() => searching = true);
                      debounce = Timer(const Duration(milliseconds: 400), () async {
                        final r = await geocoding.searchPlace(q.trim(), limit: 8);
                        setSheetState(() { results = r; searching = false; });
                      });
                    },
                  ),
                ),
              ),
              // Results
              if (searching)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: color)),
                    const SizedBox(width: 10),
                    Text('Suche...', style: GoogleFonts.inter(fontSize: 13, color: mutedColor)),
                  ]),
                )
              else if (results.isNotEmpty)
                Flexible(child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: results.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: mutedColor.withValues(alpha: 0.15)),
                  itemBuilder: (_, i) {
                    final r = results[i];
                    return ListTile(
                      dense: true,
                      leading: Icon(r.typeIcon, color: color, size: 20),
                      title: Text(r.shortName, style: GoogleFonts.inter(fontSize: 14, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: r.state != null ? Text(r.state!, style: GoogleFonts.inter(fontSize: 12, color: mutedColor), maxLines: 1, overflow: TextOverflow.ellipsis) : null,
                      onTap: () {
                        final notifier = ref.read(savedPlacesProvider.notifier);
                        if (isHome) {
                          notifier.setHome(address: r.displayName, lat: r.location.latitude, lng: r.location.longitude);
                        } else {
                          notifier.setWork(address: r.displayName, lat: r.location.latitude, lng: r.location.longitude);
                        }
                        Navigator.of(sheetCtx).pop();
                      },
                    );
                  },
                ))
              else if (searchCtrl.text.trim().length >= 2)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Keine Ergebnisse', style: GoogleFonts.inter(fontSize: 13, color: mutedColor)),
                ),
            ]),
          );
        });
      },
    ).whenComplete(() => debounce?.cancel());
  }

  /// Count community blitzer reports near the destination (within 15km).
  int _countBlitzerNearDestination(LatLng destination) {
    int count = 0;
    for (final r in _reports) {
      final dist = Geolocator.distanceBetween(
        destination.latitude, destination.longitude,
        r.latitude, r.longitude,
      );
      if (dist <= 15000) count++; // 15km radius
    }
    return count;
  }

  // ═══ DEAD CODE — alte Inline-Panel Methode, wird nicht mehr aufgerufen ═══
  // ignore: unused_element
  Widget _buildRoutePanelInline_OLD(Color accentColor, Brightness brightness) {
    final navState = ref.watch(navigationProvider);
    final isDark = brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xF0000000) : const Color(0xF2FFFFFF);
    final textColor = isDark ? Colors.white : Colors.black87;
    final mutedColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF6C757D);
    final chipBg = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.08);
    final cardBg = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.7);
    final dividerColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.15);
    final info = navState.destinationInfo;
    final isLoadingInfo = navState.isLoadingInfo;
    final routeMode = navState.routeMode;
    final blitzerCount = navState.destination != null
        ? _countBlitzerNearDestination(navState.destination!)
        : 0;

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, -2))],
        ),
        child: SafeArea(
          top: false,
          child: Column(children: [
            // ── Toggle Handle: Tippen zum Auf-/Zuklappen ──
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _routePanelExpanded = !_routePanelExpanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Center(child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: mutedColor.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2)),
                )),
              ),
            ),

            // ── Buttons: Abbrechen + Los ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                // ABBRECHEN — ElevatedButton (gleicher Typ wie Los!)
                Expanded(
                  flex: 4,
                  child: SizedBox(height: 48, child: ElevatedButton.icon(
                    onPressed: () {
                      debugPrint('[RoutePanel] ═══ ABBRECHEN GETIPPT ═══');
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          ref.read(navigationProvider.notifier).clearRoute();
                          _searchController.clear();
                          setState(() {
                            _stepsExpanded = false;
                            _routePanelExpanded = true;
                          });
                        }
                      });
                    },
                    icon: Icon(Icons.close_rounded, color: Colors.white, size: 20),
                    label: Text('Abbrechen', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                    ),
                  )),
                ),
                const SizedBox(width: 10),
                // LOS
                Expanded(
                  flex: 6,
                  child: SizedBox(height: 48, child: ElevatedButton.icon(
                    onPressed: _startNavigation,
                    icon: const Icon(Icons.navigation_rounded, size: 22),
                    label: Text('Los', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                    ),
                  )),
                ),
              ]),
            ),

            const SizedBox(height: 8),

            // ── Route Mode Toggle: Biker / Auto ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.all(3),
                child: Row(children: [
                  Expanded(child: _routeModeButton(
                    icon: Icons.two_wheeler_rounded, label: 'Biker',
                    isSelected: routeMode == RouteMode.biker, accentColor: accentColor, textColor: textColor,
                    onTap: () => _switchRouteMode(RouteMode.biker),
                  )),
                  const SizedBox(width: 4),
                  Expanded(child: _routeModeButton(
                    icon: Icons.directions_car_rounded, label: 'Auto',
                    isSelected: routeMode == RouteMode.auto, accentColor: accentColor, textColor: textColor,
                    onTap: () => _switchRouteMode(RouteMode.auto),
                  )),
                ]),
              ),
            ),

            // ── Expanded Content (scrollbar) ──
            if (_routePanelExpanded) ...[
              const SizedBox(height: 8),
              Divider(height: 1, color: dividerColor),

              Expanded(child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Destination Header
                  Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    if (info?.thumbnailUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(info!.thumbnailUrl!, width: 72, height: 72, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _routePanelCountryOrFallback(info, accentColor)),
                      )
                    else
                      _routePanelCountryOrFallback(info, accentColor),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        navState.destinationName ?? 'Ziel',
                        style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: textColor),
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                      ),
                      if (info?.country != null) ...[
                        const SizedBox(height: 2),
                        Text('${info!.countryFlag ?? ''} ${info.country!}',
                          style: GoogleFonts.inter(fontSize: 14, color: mutedColor)),
                      ],
                      const SizedBox(height: 6),
                      Wrap(spacing: 12, runSpacing: 4, children: [
                        if (navState.route != null) ...[
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.route_rounded, size: 16, color: accentColor),
                            const SizedBox(width: 4),
                            Text(navState.route!.distanceText, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: accentColor)),
                          ]),
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.schedule_rounded, size: 16, color: mutedColor),
                            const SizedBox(width: 4),
                            Text(navState.route!.durationText, style: GoogleFonts.inter(fontSize: 15, color: textColor)),
                          ]),
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.flag_rounded, size: 16, color: mutedColor),
                            const SizedBox(width: 4),
                            Text('${navState.etaText} Ank.', style: GoogleFonts.inter(fontSize: 15, color: textColor)),
                          ]),
                        ],
                      ]),
                    ])),
                  ]),

                  const SizedBox(height: 14),

                  // Info Chips
                  if (isLoadingInfo && (info == null || !info.hasData))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(children: [
                        SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: accentColor)),
                        const SizedBox(width: 8),
                        Text('Infos werden geladen...', style: GoogleFonts.inter(fontSize: 14, color: mutedColor)),
                      ]),
                    )
                  else if (info != null && info.hasData || blitzerCount > 0) ...[
                    Wrap(spacing: 10, runSpacing: 10, children: [
                      if (info?.population != null)
                        _infoChip(Icons.people_rounded, '${info!.populationText} Einwohner', accentColor, chipBg, textColor),
                      if (blitzerCount > 0)
                        _infoChip(Icons.camera_alt_rounded, '$blitzerCount Blitzer', Colors.red.shade600, chipBg, textColor),
                      if (info?.fuelStationCount != null)
                        _infoChip(Icons.local_gas_station_rounded, '${info!.fuelStationCount} Tankstellen', Colors.amber.shade700, chipBg, textColor),
                      if (info?.repairShopCount != null)
                        _infoChip(Icons.build_rounded, '${info!.repairShopCount} Werkstätten', Colors.blueGrey, chipBg, textColor),
                      if (info?.bikerCount != null && info!.bikerCount! > 0)
                        _infoChip(Icons.two_wheeler_rounded, '${info.bikerCount} Bikes', Colors.deepOrange, chipBg, textColor),
                      if (info?.autoCount != null && info!.autoCount! > 0)
                        _infoChip(Icons.directions_car_rounded, '${info.autoCount} Autos', Colors.indigo, chipBg, textColor),
                    ]),
                    const SizedBox(height: 14),
                  ],

                  // Wikipedia
                  if (info?.description != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: dividerColor)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Icon(Icons.info_outline_rounded, size: 16, color: accentColor),
                          const SizedBox(width: 6),
                          Text('Info', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: accentColor)),
                        ]),
                        const SizedBox(height: 8),
                        Text(info!.description!, style: GoogleFonts.inter(fontSize: 14, color: textColor.withValues(alpha: 0.85), height: 1.5), maxLines: 6, overflow: TextOverflow.ellipsis),
                      ]),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Route Steps
                  if (navState.route != null && navState.route!.steps.isNotEmpty)
                    Builder(builder: (context) {
                      final smartSteps = _buildSmartSteps(navState.route!.steps);
                      return Column(mainAxisSize: MainAxisSize.min, children: [
                        Row(children: [
                          Icon(Icons.turn_right_rounded, size: 18, color: accentColor),
                          const SizedBox(width: 6),
                          Text('Wegbeschreibung', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: accentColor)),
                          const Spacer(),
                          Text('${smartSteps.length} Schritte', style: GoogleFonts.inter(fontSize: 12, color: mutedColor)),
                        ]),
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: dividerColor)),
                          child: Column(children: [
                            for (int i = 0; i < smartSteps.length; i++)
                              _buildSmartStepRow(smartSteps[i], i, smartSteps.length, accentColor, textColor, mutedColor),
                          ]),
                        ),
                      ]);
                    }),

                  const SizedBox(height: 20),
                ]),
              )),
            ],
          ]),
        ),
      ),
    );
  }

  /// Inline Route Sheet — Widget im Stack, KEIN Navigator.push.
  /// Karte bleibt scrollbar weil das Sheet nur den unteren Teil abdeckt.
  Widget _buildInlineRouteSheet(Color accentColor, Brightness brightness) {

    final isDark = brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xF0000000) : const Color(0xF2FFFFFF);
    final navState = ref.watch(navigationProvider);
    final textColor = isDark ? Colors.white : Colors.black87;
    final mutedColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF6C757D);
    final chipBg = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.08);
    final cardBg = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.7);
    final dividerColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.15);
    final info = navState.destinationInfo;
    final isLoadingInfo = navState.isLoadingInfo;
    final routeMode = navState.routeMode;
    final blitzerCount = navState.destination != null
        ? _countBlitzerNearDestination(navState.destination!)
        : 0;

    void _onAbbrechen() {
      debugPrint('[RouteSheet] ═══ ABBRECHEN GETIPPT ═══');
      _routeSheetOpen = false;
      _routeCancelled = true;
      ref.read(navigationProvider.notifier).clearRoute();
      _searchController.clear();
      _stepsExpanded = false;
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _searchFocusNode.requestFocus();
          setState(() {});
        }
      });
    }

    void _onLos() {
      debugPrint('[RouteSheet] ═══ LOS GETIPPT ═══');
      _routeSheetOpen = false;
      _startNavigation();
      setState(() {});
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.50,
      minChildSize: 0.18,
      maxChildSize: 0.92,
      snap: true,
      snapSizes: const [0.18, 0.50, 0.85],
      builder: (sheetCtx, scrollController) {
        return Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, -4))],
            ),
            child: CustomScrollView(
              controller: scrollController,
              slivers: [
                // ── HEADER: Drag-Handle + Buttons + Toggle ──
                SliverToBoxAdapter(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // Drag Handle
                  const SizedBox(height: 10),
                  Center(child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: mutedColor.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2)),
                  )),
                  const SizedBox(height: 8),

                  // ── Buttons: Abbrechen + Los ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(children: [
                      SizedBox(height: 48, child: ElevatedButton.icon(
                        onPressed: _onAbbrechen,
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                        label: Text('Abbrechen', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 2,
                        ),
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: SizedBox(height: 48, child: ElevatedButton.icon(
                        onPressed: _onLos,
                        icon: const Icon(Icons.navigation_rounded, size: 22),
                        label: Text('Los', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 2,
                        ),
                      ))),
                    ]),
                  ),

                  const SizedBox(height: 8),

                  // ── Route Mode Toggle ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.all(3),
                      child: Row(children: [
                        Expanded(child: _routeModeButton(
                          icon: Icons.two_wheeler_rounded, label: 'Biker',
                          isSelected: routeMode == RouteMode.biker, accentColor: accentColor, textColor: textColor,
                          onTap: () => _switchRouteMode(RouteMode.biker),
                        )),
                        const SizedBox(width: 4),
                        Expanded(child: _routeModeButton(
                          icon: Icons.directions_car_rounded, label: 'Auto',
                          isSelected: routeMode == RouteMode.auto, accentColor: accentColor, textColor: textColor,
                          onTap: () => _switchRouteMode(RouteMode.auto),
                        )),
                      ]),
                    ),
                  ),

                  const SizedBox(height: 8),
                  Divider(height: 1, color: dividerColor),
                ])),

                // ── SCROLLBARER CONTENT ──
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                  sliver: SliverList(delegate: SliverChildListDelegate([
                    // Destination Header
                    Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                      if (info?.thumbnailUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(info!.thumbnailUrl!, width: 72, height: 72, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _routePanelCountryOrFallback(info, accentColor)),
                        )
                      else
                        _routePanelCountryOrFallback(info, accentColor),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(
                          navState.destinationName ?? 'Ziel',
                          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: textColor),
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                        ),
                        if (info?.country != null) ...[
                          const SizedBox(height: 2),
                          Text('${info!.countryFlag ?? ''} ${info.country!}',
                            style: GoogleFonts.inter(fontSize: 14, color: mutedColor)),
                        ],
                        const SizedBox(height: 6),
                        Wrap(spacing: 12, runSpacing: 4, children: [
                          if (navState.route != null) ...[
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.route_rounded, size: 16, color: accentColor),
                              const SizedBox(width: 4),
                              Text(navState.route!.distanceText, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: accentColor)),
                            ]),
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.schedule_rounded, size: 16, color: mutedColor),
                              const SizedBox(width: 4),
                              Text(navState.route!.durationText, style: GoogleFonts.inter(fontSize: 15, color: textColor)),
                            ]),
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.flag_rounded, size: 16, color: mutedColor),
                              const SizedBox(width: 4),
                              Text('${navState.etaText} Ank.', style: GoogleFonts.inter(fontSize: 15, color: textColor)),
                            ]),
                          ],
                        ]),
                      ])),
                    ]),

                    // ── XP-Vorschau ──
                    if (navState.route != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [accentColor.withValues(alpha: 0.12), accentColor.withValues(alpha: 0.04)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: accentColor.withValues(alpha: 0.25)),
                          ),
                          child: Row(children: [
                            Icon(Icons.bolt_rounded, color: accentColor, size: 22),
                            const SizedBox(width: 6),
                            Flexible(child: Text(
                              '+${XpCalculator.totalXp(navState.route!.distanceKm)} XP',
                              style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: accentColor),
                              overflow: TextOverflow.ellipsis,
                            )),
                            if (XpCalculator.distanceBonus(navState.route!.distanceKm) > 0) ...[
                              const SizedBox(width: 10),
                              Flexible(child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '+${XpCalculator.distanceBonus(navState.route!.distanceKm)} Bonus',
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: accentColor),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )),
                            ],
                            const SizedBox(width: 8),
                            Text(
                              'Level ${XpCalculator.levelName(XpCalculator.levelFromXp(XpCalculator.totalXp(navState.route!.distanceKm)))}',
                              style: GoogleFonts.inter(fontSize: 12, color: mutedColor),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ]),
                        ),
                      ),

                    // ── Als Zuhause/Arbeit speichern ──
                    if (navState.destination != null && !navState.isNavigating)
                      Builder(builder: (_) {
                        final places = ref.watch(savedPlacesProvider);
                        final isHome = places.any((p) => p.id == 'home' &&
                            (p.lat - navState.destination!.latitude).abs() < 0.001 &&
                            (p.lng - navState.destination!.longitude).abs() < 0.001);
                        final isWork = places.any((p) => p.id == 'work' &&
                            (p.lat - navState.destination!.latitude).abs() < 0.001 &&
                            (p.lng - navState.destination!.longitude).abs() < 0.001);
                        if (isHome && isWork) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Row(children: [
                            if (!isHome)
                              Expanded(child: _SaveAsPlaceChip(
                                icon: Icons.home_rounded,
                                label: 'Als Zuhause',
                                color: Colors.green,
                                onTap: () {
                                  ref.read(savedPlacesProvider.notifier).setHome(
                                    address: navState.destinationName ?? 'Zuhause',
                                    lat: navState.destination!.latitude,
                                    lng: navState.destination!.longitude,
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Als Zuhause gespeichert'), duration: Duration(seconds: 2)),
                                  );
                                },
                              )),
                            if (!isHome && !isWork) const SizedBox(width: 10),
                            if (!isWork)
                              Expanded(child: _SaveAsPlaceChip(
                                icon: Icons.work_rounded,
                                label: 'Als Arbeit',
                                color: Colors.blue,
                                onTap: () {
                                  ref.read(savedPlacesProvider.notifier).setWork(
                                    address: navState.destinationName ?? 'Arbeit',
                                    lat: navState.destination!.latitude,
                                    lng: navState.destination!.longitude,
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Als Arbeit gespeichert'), duration: Duration(seconds: 2)),
                                  );
                                },
                              )),
                          ]),
                        );
                      }),

                    // Info Chips
                    if (isLoadingInfo && (info == null || !info.hasData))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(children: [
                          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: accentColor)),
                          const SizedBox(width: 8),
                          Text('Infos werden geladen...', style: GoogleFonts.inter(fontSize: 14, color: mutedColor)),
                        ]),
                      )
                    else if (info != null && info.hasData || blitzerCount > 0) ...[
                      Wrap(spacing: 10, runSpacing: 10, children: [
                        if (info?.population != null)
                          _infoChip(Icons.people_rounded, '${info!.populationText} Einwohner', accentColor, chipBg, textColor),
                        if (blitzerCount > 0)
                          _infoChip(Icons.camera_alt_rounded, '$blitzerCount Blitzer', Colors.red.shade600, chipBg, textColor),
                        if (info?.fuelStationCount != null)
                          _infoChip(Icons.local_gas_station_rounded, '${info!.fuelStationCount} Tankstellen', Colors.amber.shade700, chipBg, textColor),
                        if (info?.repairShopCount != null)
                          _infoChip(Icons.build_rounded, '${info!.repairShopCount} Werkstätten', Colors.blueGrey, chipBg, textColor),
                        if (info?.bikerCount != null && info!.bikerCount! > 0)
                          _infoChip(Icons.two_wheeler_rounded, '${info.bikerCount} Bikes', Colors.deepOrange, chipBg, textColor),
                        if (info?.autoCount != null && info!.autoCount! > 0)
                          _infoChip(Icons.directions_car_rounded, '${info.autoCount} Autos', Colors.indigo, chipBg, textColor),
                      ]),
                      const SizedBox(height: 14),
                    ],

                    // Wikipedia
                    if (info?.description != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: dividerColor)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Icon(Icons.info_outline_rounded, size: 16, color: accentColor),
                            const SizedBox(width: 6),
                            Text('Info', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: accentColor)),
                          ]),
                          const SizedBox(height: 8),
                          Text(info!.description!, style: GoogleFonts.inter(fontSize: 14, color: textColor.withValues(alpha: 0.85), height: 1.5), maxLines: 6, overflow: TextOverflow.ellipsis),
                        ]),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Route Steps
                    if (navState.route != null && navState.route!.steps.isNotEmpty)
                      Builder(builder: (context) {
                        final smartSteps = _buildSmartSteps(navState.route!.steps);
                        return Column(mainAxisSize: MainAxisSize.min, children: [
                          Row(children: [
                            Icon(Icons.turn_right_rounded, size: 18, color: accentColor),
                            const SizedBox(width: 6),
                            Text('Wegbeschreibung', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: accentColor)),
                            const Spacer(),
                            Text('${smartSteps.length} Schritte', style: GoogleFonts.inter(fontSize: 12, color: mutedColor)),
                          ]),
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: dividerColor)),
                            child: Column(children: [
                              for (int i = 0; i < smartSteps.length; i++)
                                _buildSmartStepRow(smartSteps[i], i, smartSteps.length, accentColor, textColor, mutedColor),
                            ]),
                          ),
                        ]);
                      }),
                  ])),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Live-User Bubble — zeigt Profilbild, Name, XP/Level, PLZ, Bike, Follower, Likes, Link zum Profil.
  Widget _buildLiveUserBubble(Color accentColor, Brightness brightness) {
    final user = _selectedLiveUser;
    if (user == null) return const SizedBox.shrink();

    final isDark = brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xF0222222) : const Color(0xF5FFFFFF);
    final textColor = isDark ? Colors.white : Colors.black87;
    final mutedColor = isDark ? Colors.white70 : Colors.black54;

    final level = XpCalculator.levelFromXp(user.xpTotal);
    final levelN = XpCalculator.levelName(level);
    final levelC = XpCalculator.levelColor(level);

    return Positioned(
      left: 0, right: 0,
      top: MediaQuery.of(context).size.height * 0.25,
      child: Center(child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: () => setState(() => _selectedLiveUser = null),
          child: Container(
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(maxWidth: 300),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Profilbild
            CircleAvatar(
              radius: 36,
              backgroundColor: levelC.withValues(alpha: 0.2),
              backgroundImage: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                  ? NetworkImage(user.avatarUrl!)
                  : null,
              child: user.avatarUrl == null || user.avatarUrl!.isEmpty
                  ? Icon(Icons.person_rounded, size: 36, color: levelC)
                  : null,
            ),
            const SizedBox(height: 10),
            // Name
            Text(
              user.displayName,
              style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: textColor),
              textAlign: TextAlign.center,
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            // Level + XP
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: levelC.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Lvl $level · $levelN',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: levelC),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${user.xpTotal} XP',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: mutedColor),
              ),
            ]),
            const SizedBox(height: 10),
            // Stats row: Follower, Likes
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _bubbleStat(Icons.people_rounded, '${user.followerCount}', 'Follower', mutedColor),
                Container(width: 1, height: 24, margin: const EdgeInsets.symmetric(horizontal: 12), color: mutedColor.withValues(alpha: 0.2)),
                _bubbleStat(Icons.favorite_rounded, '${user.totalLikes}', 'Likes', Colors.redAccent),
              ],
            ),
            const SizedBox(height: 8),
            // Info row: PLZ + Bike + Speed
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 4,
              children: [
                if (user.postalCode != null && user.postalCode!.isNotEmpty)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.location_on_rounded, size: 14, color: mutedColor),
                    const SizedBox(width: 3),
                    Text('PLZ ${user.postalCode}', style: GoogleFonts.inter(fontSize: 12, color: mutedColor)),
                  ]),
                if (user.bikeName != null && user.bikeName!.isNotEmpty)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.two_wheeler_rounded, size: 14, color: mutedColor),
                    const SizedBox(width: 3),
                    Text(user.bikeName!, style: GoogleFonts.inter(fontSize: 12, color: mutedColor)),
                  ]),
                if (user.speed > 1)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.speed_rounded, size: 14, color: mutedColor),
                    const SizedBox(width: 3),
                    Text('${user.speed.toStringAsFixed(0)} km/h', style: GoogleFonts.inter(fontSize: 12, color: mutedColor)),
                  ]),
              ],
            ),
            const SizedBox(height: 14),
            // Profil öffnen Button
            GestureDetector(
              onTap: () {
                setState(() => _selectedLiveUser = null);
                context.push('/profile/${user.userId}');
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Profil öffnen',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ]),
        ),
        ),
      )),
    );
  }

  /// Profil-Bubble über dem Marker — zeigt Profilbild, Name, XP/Level, PLZ, Bike, Follower, Likes, Profil öffnen.
  Widget _buildProfileBubble(Color accentColor, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final authState = ref.watch(authNotifierProvider);
    if (authState is! Authenticated) return const SizedBox.shrink();

    final user = authState.user;
    final bgColor = isDark ? const Color(0xF0222222) : const Color(0xF5FFFFFF);
    final textColor = isDark ? Colors.white : Colors.black87;
    final mutedColor = isDark ? Colors.white70 : Colors.black54;

    final level = XpCalculator.levelFromXp(user.xpTotal);
    final levelN = XpCalculator.levelName(level);
    final levelC = XpCalculator.levelColor(level);

    return Positioned(
      left: 0, right: 0,
      top: MediaQuery.of(context).size.height * 0.25,
      child: Center(child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: () => setState(() => _showProfileBubble = false),
          child: Container(
            padding: const EdgeInsets.all(16),
            constraints: const BoxConstraints(maxWidth: 300),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Profilbild
              CircleAvatar(
                radius: 36,
                backgroundColor: levelC.withValues(alpha: 0.2),
                backgroundImage: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                    ? NetworkImage(user.avatarUrl!)
                    : null,
                child: user.avatarUrl == null || user.avatarUrl!.isEmpty
                    ? Icon(Icons.person_rounded, size: 36, color: levelC)
                    : null,
              ),
              const SizedBox(height: 10),
              // Name
              Text(
                user.displayName ?? 'Biker',
                style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: textColor),
                textAlign: TextAlign.center,
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
              if (user.username != null) ...[
                const SizedBox(height: 2),
                Text(
                  '@${user.username}',
                  style: GoogleFonts.inter(fontSize: 13, color: mutedColor),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 6),
              // Level + XP
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: levelC.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Lvl $level · $levelN',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: levelC),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${user.xpTotal} XP',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: mutedColor),
                ),
              ]),
              const SizedBox(height: 10),
              // Stats row: Follower, Likes
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _bubbleStat(Icons.people_rounded, '${user.followerCount}', 'Follower', mutedColor),
                  Container(width: 1, height: 24, margin: const EdgeInsets.symmetric(horizontal: 12), color: mutedColor.withValues(alpha: 0.2)),
                  _bubbleStat(Icons.favorite_rounded, '${_profileTotalLikes}', 'Likes', Colors.redAccent),
                ],
              ),
              const SizedBox(height: 8),
              // Info row: PLZ + Bike
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 4,
                children: [
                  if (user.postalCode != null && user.postalCode!.isNotEmpty)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.location_on_rounded, size: 14, color: mutedColor),
                      const SizedBox(width: 3),
                      Text('PLZ ${user.postalCode}', style: GoogleFonts.inter(fontSize: 12, color: mutedColor)),
                    ]),
                  if (user.bikername != null && user.bikername!.isNotEmpty)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.two_wheeler_rounded, size: 14, color: mutedColor),
                      const SizedBox(width: 3),
                      Text(user.bikername!, style: GoogleFonts.inter(fontSize: 12, color: mutedColor)),
                    ]),
                ],
              ),
              const SizedBox(height: 14),
              // Profil öffnen Button
              GestureDetector(
                onTap: () {
                  setState(() => _showProfileBubble = false);
                  context.go('/profile');
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Profil öffnen',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ]),
          ),
        ),
      )),
    );
  }

  /// Route-Panel mit eingebautem Abbrechen + Los Button — für BottomSheet.
  Widget _buildRoutePanelWithButtons(Color accentColor, Brightness brightness, ScrollController scrollController) {
    final navState = ref.watch(navigationProvider);
    final isDark = brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final mutedColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF6C757D);
    final chipBg = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.08);
    final cardBg = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.7);
    final dividerColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.15);
    final info = navState.destinationInfo;
    final isLoadingInfo = navState.isLoadingInfo;
    final routeMode = navState.routeMode;
    final blitzerCount = navState.destination != null
        ? _countBlitzerNearDestination(navState.destination!)
        : 0;

    return Column(children: [
      // Drag Handle
      const SizedBox(height: 10),
      Center(child: Container(
        width: 40, height: 4,
        decoration: BoxDecoration(color: mutedColor.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2)),
      )),
      const SizedBox(height: 8),

      // ── Buttons: Abbrechen + Los (OBEN, immer sichtbar) ──
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(children: [
          Expanded(flex: 4, child: SizedBox(height: 46, child: OutlinedButton.icon(
            onPressed: () {
              debugPrint('[RouteSheet] ═══ ABBRECHEN GETIPPT ═══');
              Navigator.of(context).pop(); // Sheet schließen → then() räumt auf
            },
            icon: Icon(Icons.cancel_rounded, color: Colors.red.shade600, size: 18),
            label: Text('Abbrechen', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.red.shade600), overflow: TextOverflow.ellipsis),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              side: BorderSide(color: Colors.red.withValues(alpha: 0.4)),
              backgroundColor: Colors.red.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ))),
          const SizedBox(width: 8),
          Expanded(flex: 5, child: SizedBox(height: 46, child: ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop(); // Sheet schließen
              _startNavigation();
            },
            icon: const Icon(Icons.navigation_rounded, size: 20),
            label: Text('Los', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ))),
        ]),
      ),

      const SizedBox(height: 8),

      // ── Route Mode Toggle: Biker / Auto ──
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Container(
          decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.all(3),
          child: Row(children: [
            Expanded(child: _routeModeButton(
              icon: Icons.two_wheeler_rounded, label: 'Biker',
              isSelected: routeMode == RouteMode.biker, accentColor: accentColor, textColor: textColor,
              onTap: () => _switchRouteMode(RouteMode.biker),
            )),
            const SizedBox(width: 4),
            Expanded(child: _routeModeButton(
              icon: Icons.directions_car_rounded, label: 'Auto',
              isSelected: routeMode == RouteMode.auto, accentColor: accentColor, textColor: textColor,
              onTap: () => _switchRouteMode(RouteMode.auto),
            )),
          ]),
        ),
      ),

      const SizedBox(height: 8),
      Divider(height: 1, color: dividerColor),

      // ── Scrollbarer Content ──
      Expanded(child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
        children: [
          // Destination Header
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            if (info?.thumbnailUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(info!.thumbnailUrl!, width: 72, height: 72, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _routePanelCountryOrFallback(info, accentColor)),
              )
            else
              _routePanelCountryOrFallback(info, accentColor),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                navState.destinationName ?? 'Ziel',
                style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: textColor),
                maxLines: 2, overflow: TextOverflow.ellipsis,
              ),
              if (info?.country != null) ...[
                const SizedBox(height: 2),
                Text('${info!.countryFlag ?? ''} ${info.country!}',
                  style: GoogleFonts.inter(fontSize: 14, color: mutedColor)),
              ],
              const SizedBox(height: 6),
              Wrap(spacing: 12, runSpacing: 4, children: [
                if (navState.route != null) ...[
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.route_rounded, size: 16, color: accentColor),
                    const SizedBox(width: 4),
                    Text(navState.route!.distanceText, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: accentColor)),
                  ]),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.schedule_rounded, size: 16, color: mutedColor),
                    const SizedBox(width: 4),
                    Text(navState.route!.durationText, style: GoogleFonts.inter(fontSize: 15, color: textColor)),
                  ]),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.flag_rounded, size: 16, color: mutedColor),
                    const SizedBox(width: 4),
                    Text('${navState.etaText} Ank.', style: GoogleFonts.inter(fontSize: 15, color: textColor)),
                  ]),
                ],
              ]),
            ])),
          ]),

          const SizedBox(height: 14),

          // Info Chips
          if (isLoadingInfo && (info == null || !info.hasData)) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: accentColor)),
                const SizedBox(width: 8),
                Text('Infos werden geladen...', style: GoogleFonts.inter(fontSize: 14, color: mutedColor)),
              ]),
            ),
          ] else if (info != null && info.hasData || blitzerCount > 0) ...[
            Wrap(spacing: 10, runSpacing: 10, children: [
              if (info?.population != null)
                _infoChip(Icons.people_rounded, '${info!.populationText} Einwohner', accentColor, chipBg, textColor),
              if (blitzerCount > 0)
                _infoChip(Icons.camera_alt_rounded, '$blitzerCount Blitzer', Colors.red.shade600, chipBg, textColor),
              if (info?.fuelStationCount != null)
                _infoChip(Icons.local_gas_station_rounded, '${info!.fuelStationCount} Tankstellen', Colors.amber.shade700, chipBg, textColor),
              if (info?.repairShopCount != null)
                _infoChip(Icons.build_rounded, '${info!.repairShopCount} Werkstätten', Colors.blueGrey, chipBg, textColor),
              if (info?.bikerCount != null && info!.bikerCount! > 0)
                _infoChip(Icons.two_wheeler_rounded, '${info.bikerCount} Bikes', Colors.deepOrange, chipBg, textColor),
              if (info?.autoCount != null && info!.autoCount! > 0)
                _infoChip(Icons.directions_car_rounded, '${info.autoCount} Autos', Colors.indigo, chipBg, textColor),
            ]),
            const SizedBox(height: 14),
          ],

          // Wikipedia
          if (info?.description != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: dividerColor)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: accentColor),
                  const SizedBox(width: 6),
                  Text('Info', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: accentColor)),
                ]),
                const SizedBox(height: 8),
                Text(info!.description!, style: GoogleFonts.inter(fontSize: 14, color: textColor.withValues(alpha: 0.85), height: 1.5), maxLines: 6, overflow: TextOverflow.ellipsis),
              ]),
            ),
            const SizedBox(height: 14),
          ],

          // Route Steps
          if (navState.route != null && navState.route!.steps.isNotEmpty)
            Builder(builder: (context) {
              final smartSteps = _buildSmartSteps(navState.route!.steps);
              return Column(mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Icon(Icons.turn_right_rounded, size: 18, color: accentColor),
                  const SizedBox(width: 6),
                  Text('Wegbeschreibung', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: accentColor)),
                  const Spacer(),
                  Text('${smartSteps.length} Schritte', style: GoogleFonts.inter(fontSize: 12, color: mutedColor)),
                ]),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: dividerColor)),
                  child: Column(children: [
                    for (int i = 0; i < smartSteps.length; i++)
                      _buildSmartStepRow(smartSteps[i], i, smartSteps.length, accentColor, textColor, mutedColor),
                  ]),
                ),
              ]);
            }),

          const SizedBox(height: 20),
        ],
      )),
    ]);
  }

  Widget _buildRoutePanel(Color accentColor, Brightness brightness) {
    final navState = ref.watch(navigationProvider);
    final isDark = brightness == Brightness.dark;
    // Semi-transparent background
    final bgColor = isDark ? Colors.black.withValues(alpha: 0.92) : Colors.white.withValues(alpha: 0.95);
    final textColor = isDark ? Colors.white : Colors.black87;
    final mutedColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF6C757D);
    final chipBg = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.08);
    final cardBg = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.7);
    final dividerColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.15);

    final info = navState.destinationInfo;
    final isLoadingInfo = navState.isLoadingInfo;

    // Count community blitzer near destination
    final blitzerCount = navState.destination != null
        ? _countBlitzerNearDestination(navState.destination!)
        : 0;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, -2))],
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ═══════════════════════════════════════════════════════════
            // HEADER
            // ═══════════════════════════════════════════════════════════
            const SizedBox(height: 14),

            // ── Destination: Thumbnail/Flag + Name + Distance/Time ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                // Thumbnail / Country Flag / Fallback Icon (72x72)
                if (info?.thumbnailUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(info!.thumbnailUrl!, width: 72, height: 72, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _routePanelCountryOrFallback(info, accentColor)),
                  )
                else
                  _routePanelCountryOrFallback(info, accentColor),
                const SizedBox(width: 14),
                // Name + Details
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    navState.destinationName ?? 'Ziel',
                    style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: textColor),
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                  ),
                  if (info?.country != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${info!.countryFlag ?? ''} ${info.country!}',
                      style: GoogleFonts.inter(fontSize: 14, color: mutedColor),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Wrap(spacing: 12, runSpacing: 4, children: [
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.route_rounded, size: 16, color: accentColor),
                      const SizedBox(width: 4),
                      Text(navState.route!.distanceText, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: accentColor)),
                    ]),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.schedule_rounded, size: 16, color: mutedColor),
                      const SizedBox(width: 4),
                      Text(navState.route!.durationText, style: GoogleFonts.inter(fontSize: 15, color: textColor)),
                    ]),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.flag_rounded, size: 16, color: mutedColor),
                      const SizedBox(width: 4),
                      Text('${navState.etaText} Ank.', style: GoogleFonts.inter(fontSize: 15, color: textColor)),
                    ]),
                  ]),
                ])),
              ]),
            ),

            const SizedBox(height: 8),
            Divider(height: 1, color: dividerColor),

            // ═══════════════════════════════════════════════════════════
            // CONTENT
            // ═══════════════════════════════════════════════════════════
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ── Info Chips ──
              if (isLoadingInfo && (info == null || !info.hasData)) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(children: [
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: accentColor)),
                    const SizedBox(width: 8),
                    Text('Infos werden geladen...', style: GoogleFonts.inter(fontSize: 14, color: mutedColor)),
                  ]),
                ),
              ] else if (info != null && info.hasData || blitzerCount > 0) ...[
                Wrap(spacing: 10, runSpacing: 10, children: [
                  if (info?.population != null)
                    _infoChip(Icons.people_rounded, '${info!.populationText} Einwohner', accentColor, chipBg, textColor),
                  if (blitzerCount > 0)
                    _infoChip(Icons.camera_alt_rounded, '$blitzerCount Blitzer', Colors.red.shade600, chipBg, textColor),
                  if (info?.fuelStationCount != null)
                    _infoChip(Icons.local_gas_station_rounded, '${info!.fuelStationCount} Tankstellen', Colors.amber.shade700, chipBg, textColor),
                  if (info?.repairShopCount != null)
                    _infoChip(Icons.build_rounded, '${info!.repairShopCount} Werkstätten', Colors.blueGrey, chipBg, textColor),
                  if (info?.bikerCount != null && info!.bikerCount! > 0)
                    _infoChip(Icons.two_wheeler_rounded, '${info.bikerCount} Bikes', Colors.deepOrange, chipBg, textColor),
                  if (info?.autoCount != null && info!.autoCount! > 0)
                    _infoChip(Icons.directions_car_rounded, '${info.autoCount} Autos', Colors.indigo, chipBg, textColor),
                ]),
                const SizedBox(height: 14),
              ],

              // ── Wikipedia Description Card ──
              if (info?.description != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: dividerColor),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(Icons.info_outline_rounded, size: 16, color: accentColor),
                      const SizedBox(width: 6),
                      Text('Info', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: accentColor)),
                    ]),
                    const SizedBox(height: 8),
                    Text(info!.description!,
                      style: GoogleFonts.inter(fontSize: 14, color: textColor.withValues(alpha: 0.85), height: 1.5),
                      maxLines: 6, overflow: TextOverflow.ellipsis),
                  ]),
                ),
                const SizedBox(height: 14),
              ],

              // ── Smart Route Steps (merged, with highway + POI info) ──
              if (navState.route!.steps.isNotEmpty) ...[
                Builder(builder: (context) {
                  final smartSteps = _buildSmartSteps(navState.route!.steps);
                  return Column(mainAxisSize: MainAxisSize.min, children: [
                    Row(children: [
                      Icon(Icons.turn_right_rounded, size: 18, color: accentColor),
                      const SizedBox(width: 6),
                      Text('Wegbeschreibung', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: accentColor)),
                      const Spacer(),
                      Text('${smartSteps.length} Schritte', style: GoogleFonts.inter(fontSize: 12, color: mutedColor)),
                    ]),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: dividerColor),
                      ),
                      child: Column(children: [
                        for (int i = 0; i < smartSteps.length; i++)
                          _buildSmartStepRow(smartSteps[i], i, smartSteps.length, accentColor, textColor, mutedColor),
                      ]),
                    ),
                  ]);
                }),
              ],

              // Bottom padding
              const SizedBox(height: 20),
            ]),
          ),
        ],
      ),
      ),
    );
  }

  /// Fixierte Buttons am unteren Bildschirmrand — AUSSERHALB des DraggableScrollableSheet.
  /// So werden Touch-Events nicht vom Sheet-Scroll verschluckt.
  Widget _buildRouteButtons(Color accentColor, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black.withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.97);
    final textColor = isDark ? Colors.white : Colors.black87;
    final chipBg = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.08);
    final routeMode = ref.watch(navigationProvider.select((s) => s.routeMode));

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: bgColor,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // ── Route Mode Toggle: Biker / Auto ──
        Container(
          decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.all(3),
          child: Row(children: [
            Expanded(child: _routeModeButton(
              icon: Icons.two_wheeler_rounded,
              label: 'Biker',
              isSelected: routeMode == RouteMode.biker,
              accentColor: accentColor,
              textColor: textColor,
              onTap: () => _switchRouteMode(RouteMode.biker),
            )),
            const SizedBox(width: 4),
            Expanded(child: _routeModeButton(
              icon: Icons.directions_car_rounded,
              label: 'Auto',
              isSelected: routeMode == RouteMode.auto,
              accentColor: accentColor,
              textColor: textColor,
              onTap: () => _switchRouteMode(RouteMode.auto),
            )),
          ]),
        ),
        const SizedBox(height: 10),
        // ── Abbrechen + Los ──
        Row(children: [
          SizedBox(height: 48, child: OutlinedButton.icon(
            onPressed: () {
              debugPrint('[RoutePanel] ═══ ABBRECHEN GETIPPT ═══');
              ref.read(navigationProvider.notifier).clearRoute();
              _searchController.clear();
              setState(() => _stepsExpanded = false);
            },
            icon: Icon(Icons.cancel_rounded, color: Colors.red.shade600, size: 20),
            label: Text('Abbrechen', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.red.shade600)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.red.withValues(alpha: 0.4)),
              backgroundColor: Colors.red.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          )),
          const SizedBox(width: 10),
          Expanded(child: SizedBox(height: 48, child: ElevatedButton.icon(
            onPressed: _startNavigation,
            icon: const Icon(Icons.navigation_rounded, size: 22),
            label: Text('Los', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ))),
        ]),
      ]),
    );
  }

  /// Switch route mode and recalculate route.
  void _switchRouteMode(RouteMode mode) {
    final navState = ref.read(navigationProvider);
    if (navState.routeMode == mode) return;

    final origin = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : _defaultCenter;
    final destination = navState.destination;
    final name = navState.destinationName;

    if (destination != null) {
      setState(() => _stepsExpanded = false);
      ref.read(navigationProvider.notifier).calculateRoute(
        origin, destination, name: name, mode: mode,
      );
    }
  }

  /// Route mode toggle button (Biker / Auto).
  Widget _routeModeButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required Color accentColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? accentColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 18, color: isSelected ? Colors.white : textColor.withValues(alpha: 0.5)),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? Colors.white : textColor.withValues(alpha: 0.5),
          )),
        ]),
      ),
    );
  }

  /// A smart step row — supports highway badges, color highlights, merged distances.
  Widget _buildSmartStepRow(_SmartStep step, int index, int totalSteps, Color accentColor, Color textColor, Color mutedColor) {
    final isLast = index == totalSteps - 1;
    final isFirst = index == 0;
    final iconColor = step.iconColor ?? (step.isHighlight ? Colors.blue.shade700 : accentColor);
    // Background highlight matches the road type color (subtle)
    final bgHighlight = step.isHighlight ? iconColor.withValues(alpha: 0.08) : null;
    // Badge style based on road type
    final badgeStyle = step.badge != null ? _roadBadgeStyle(step.badge!) : null;

    // For yellow backgrounds (B-roads), use a darker icon circle so it's visible
    final bool isYellowRoad = step.badge != null && step.badge!.toUpperCase().startsWith('B');
    final circleColor = isLast ? accentColor
        : (step.isHighlight ? iconColor : accentColor.withValues(alpha: 0.15));
    final circleIconColor = isLast || step.isHighlight
        ? (isYellowRoad ? Colors.black : Colors.white)
        : accentColor;

    return Container(
      decoration: bgHighlight != null
          ? BoxDecoration(
              color: bgHighlight,
              border: Border(left: BorderSide(color: iconColor, width: 3)),
            )
          : null,
      child: Padding(
        padding: EdgeInsets.only(left: 12, right: 12, top: isFirst ? 12 : 0, bottom: isLast ? 12 : 0),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Step timeline (dot + line)
          Column(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: circleColor,
                shape: BoxShape.circle,
                border: step.isHighlight && !isLast
                    ? Border.all(color: iconColor.withValues(alpha: 0.5), width: 2)
                    : null,
              ),
              child: Center(child: Icon(step.icon, size: 17, color: circleIconColor)),
            ),
            if (!isLast)
              Container(width: 2, height: 34, color: accentColor.withValues(alpha: 0.2)),
          ]),
          const SizedBox(width: 12),
          // Step text + road sign badge
          Expanded(child: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(step.instruction,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: step.isHighlight ? FontWeight.w600 : FontWeight.w400,
                    color: textColor),
                  maxLines: 2, overflow: TextOverflow.ellipsis)),
                // Road sign badge — colored by road type
                if (step.badge != null && badgeStyle != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeStyle.bg,
                      borderRadius: BorderRadius.circular(6),
                      border: badgeStyle.bg == const Color(0xFF1565C0)
                          ? Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5)
                          : null,
                    ),
                    child: Text(step.badge!, style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w800, color: badgeStyle.text,
                      letterSpacing: 0.5)),
                  ),
                ],
              ]),
              if (step.distanceMeters > 0 && !isLast)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(step.distanceText, style: GoogleFonts.inter(fontSize: 12, color: mutedColor)),
                ),
              SizedBox(height: isLast ? 0 : 12),
            ]),
          )),
        ]),
      ),
    );
  }

  /// A single step row in the route description (legacy, used during navigation).
  Widget _buildStepRow(OsrmStep step, int index, int totalSteps, Color accentColor, Color textColor, Color mutedColor) {
    final isLast = index == totalSteps - 1;
    return Padding(
      padding: EdgeInsets.only(left: 12, right: 12, top: index == 0 ? 12 : 0, bottom: isLast ? 12 : 0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Step timeline (dot + line)
        Column(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: isLast ? accentColor : accentColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(child: Icon(
              _maneuverIconData(step.maneuver),
              size: 16,
              color: isLast ? Colors.white : accentColor,
            )),
          ),
          if (!isLast)
            Container(width: 2, height: 32, color: accentColor.withValues(alpha: 0.2)),
        ]),
        const SizedBox(width: 12),
        // Step text
        Expanded(child: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(step.instruction, style: GoogleFonts.inter(fontSize: 14, color: textColor), maxLines: 2, overflow: TextOverflow.ellipsis),
            if (step.distanceMeters > 0 && !isLast)
              Text(step.distanceText, style: GoogleFonts.inter(fontSize: 12, color: mutedColor)),
            SizedBox(height: isLast ? 0 : 12),
          ]),
        )),
      ]),
    );
  }

  /// Shows country flag emoji if available, otherwise a generic icon.
  Widget _routePanelCountryOrFallback(DestinationInfo? info, Color accentColor) {
    final flag = info?.countryFlag;
    if (flag != null) {
      return Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(child: Text(flag, style: const TextStyle(fontSize: 40))),
      );
    }
    return _routePanelFallbackIcon(accentColor);
  }

  Widget _routePanelFallbackIcon(Color accentColor) {
    return Container(
      width: 72, height: 72,
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(Icons.flag_rounded, color: accentColor, size: 32),
    );
  }

  Widget _infoChip(IconData icon, String label, Color iconColor, Color chipBg, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: chipBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: iconColor.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: textColor)),
      ]),
    );
  }

  // ─── Speed-Dial Overlay ───────────────────────────────────────────────

  void _toggle3D() {
    if (_disposed || !mounted) return;
    setState(() => _is3D = !_is3D);
    _registerSpeedDialItems(); // Update labels
    if (_currentPosition != null) {
      final heading = _currentPosition!.heading;
      _mapController?.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
        target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        zoom: _is3D ? 18 : 15,
        tilt: _is3D ? 65 : 0,
        bearing: _is3D ? heading : 0,
      )));
    }
    // Auto-switch to satellite in 3D for better topography
    if (_is3D && _mapType == MapType.normal) {
      setState(() => _mapType = MapType.hybrid);
    }
  }

  void _toggleSatellite() {
    if (_disposed || !mounted) return;
    setState(() {
      _mapType = _mapType == MapType.hybrid ? MapType.normal : MapType.hybrid;
    });
    _registerSpeedDialItems(); // Update labels
  }

  // Speed-Dial overlay is now rendered by MainShell.
  // Blitzer-specific items are registered via _registerSpeedDialItems().

  // Dark map style JSON — Straßennamen + Städte sichtbar, keine POIs/Transit
  static const String _darkMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#212121"}]},
  {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"featureType":"administrative","elementType":"geometry","stylers":[{"color":"#757575"}]},
  {"featureType":"administrative","elementType":"labels.text.fill","stylers":[{"color":"#9e9e9e"}]},
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"road","elementType":"geometry.fill","stylers":[{"color":"#2c2c2c"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#9e9e9e"}]},
  {"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#373737"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#3c3c3c"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#000000"}]},
  {"featureType":"water","elementType":"labels","stylers":[{"visibility":"off"}]}
]
''';

  // Light map style JSON — Straßennamen + Städte sichtbar, keine POIs/Transit
  static const String _lightMapStyle = '''
[
  {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"featureType":"administrative","elementType":"labels.text.fill","stylers":[{"color":"#666666"}]},
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#555555"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]}
]
''';

}

// ═════════════════════════════════════════════════════════════════════════════
// SEPARATE CONSUMER WIDGETS — watch fast-changing nav state independently
// ═════════════════════════════════════════════════════════════════════════════

// ═════════════════════════════════════════════════════════════════════════════
// MAP PROFILE AVATAR — always visible on Blitzer map, links to profile
// ═════════════════════════════════════════════════════════════════════════════

class _MapProfileAvatar extends ConsumerWidget {
  final Color accentColor;
  const _MapProfileAvatar({required this.accentColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final community = ref.watch(communityProvider);
    final user = authState is Authenticated ? authState.user : null;
    final initial = (user?.displayName ?? user?.username ?? 'U')
        .characters.first.toUpperCase();

    final avatarUrl = community == Community.cargram
        ? (user?.avatarUrlCargram ?? user?.avatarUrl)
        : user?.avatarUrl;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.go('/profile'),
      child: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.5),
          border: Border.all(color: accentColor, width: 2.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: ClipOval(
          child: avatarUrl != null && avatarUrl.isNotEmpty
              ? Image.network(avatarUrl, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildInitial(initial))
              : _buildInitial(initial),
        ),
      ),
    );
  }

  Widget _buildInitial(String initial) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [accentColor, accentColor.withValues(alpha: 0.6)],
        ),
      ),
      child: Center(
        child: Text(initial, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ═════════════════════════════════════════════════════════════════════════════
// ROUTE SHEET TRIGGER — unsichtbares Widget das das BottomSheet öffnet
// ═════════════════════════════════════════════════════════════════════════════

/// Unsichtbares Widget das beim Einbau ins Widget-Tree automatisch
/// [onShow] aufruft — verwendet um das Route-BottomSheet zu triggern.
class _RouteSheetTrigger extends StatefulWidget {
  final VoidCallback onShow;
  const _RouteSheetTrigger({required this.onShow});

  @override
  State<_RouteSheetTrigger> createState() => _RouteSheetTriggerState();
}

class _RouteSheetTriggerState extends State<_RouteSheetTrigger> {
  @override
  void initState() {
    super.initState();
    // BottomSheet im nächsten Frame öffnen (nicht während build)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onShow();
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// BLITZER ALERT BANNER — multi-stage warning with animation
// ═════════════════════════════════════════════════════════════════════════════

class _SaveAsPlaceChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SaveAsPlaceChip({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
          ]),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════

class _BlitzerAlertBanner extends StatelessWidget {
  final String warning;
  const _BlitzerAlertBanner({required this.warning});

  @override
  Widget build(BuildContext context) {
    // Determine severity from warning prefix
    final isImmediate = warning.contains('🚨');
    final isApproach = warning.contains('⚠️');
    final bgColor = isImmediate
        ? Colors.red.shade700
        : isApproach
            ? Colors.amber.shade700
            : Colors.orange.shade600;
    final glowColor = isImmediate
        ? Colors.red.withValues(alpha: 0.5)
        : isApproach
            ? Colors.amber.withValues(alpha: 0.4)
            : Colors.orange.withValues(alpha: 0.3);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: glowColor, blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        Icon(
          isImmediate ? Icons.crisis_alert_rounded : Icons.warning_amber_rounded,
          color: Colors.white, size: 24,
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(
          warning,
          style: GoogleFonts.inter(
            fontSize: isImmediate ? 16 : 15,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        )),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// RE-CENTER BUTTON — shown when user manually panned during navigation
// ═════════════════════════════════════════════════════════════════════════════

class _ReCenterButton extends ConsumerWidget {
  final VoidCallback onReCenter;
  const _ReCenterButton({required this.onReCenter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPanned = ref.watch(
      drivingModeProvider.select((s) => s.userPannedMap),
    );

    if (!isPanned) return const SizedBox.shrink();

    return Positioned(
      right: 16,
      bottom: 180,
      child: GestureDetector(
        onTap: onReCenter,
        child: Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.8),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: const Icon(Icons.gps_fixed_rounded, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SEPARATE CONSUMER WIDGETS — watch fast-changing nav state independently
// ═════════════════════════════════════════════════════════════════════════════

class _NavTurnBanner extends ConsumerWidget {
  final Color accentColor;
  final Brightness brightness;
  const _NavTurnBanner({required this.accentColor, required this.brightness});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentStep = ref.watch(navigationProvider.select((s) => s.currentStep));
    final nextStep = ref.watch(navigationProvider.select((s) => s.nextStep));
    final distText = ref.watch(navigationProvider.select((s) => s.distanceToNextStepText));
    if (currentStep == null) return const SizedBox.shrink();

    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 8, 16, 16),
        decoration: BoxDecoration(
          color: brightness == Brightness.dark ? Colors.black.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.7),
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Aktueller Schritt
          Row(children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
              child: Center(child: Icon(_maneuverIconData(currentStep.maneuver), color: accentColor, size: 32)),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(currentStep.instruction, style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: brightness == Brightness.dark ? Colors.white : Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text('in $distText', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: accentColor)),
            ])),
          ]),
          // Nächster Schritt Vorschau
          if (nextStep != null && nextStep.maneuver != 'arrive') ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                Icon(_maneuverIconData(nextStep.maneuver), color: accentColor.withValues(alpha: 0.6), size: 18),
                const SizedBox(width: 8),
                Text('Danach: ', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: accentColor.withValues(alpha: 0.7))),
                Expanded(child: Text(nextStep.instruction, style: GoogleFonts.inter(fontSize: 12, color: brightness == Brightness.dark ? Colors.white70 : Colors.black54), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}

class _NavBottomBar extends ConsumerWidget {
  final Color accentColor;
  final Brightness brightness;
  final VoidCallback onStop;
  final VoidCallback onReport;
  final VoidCallback onSettings;
  final VoidCallback onToggle3D;
  final VoidCallback onToggleMapType;
  final VoidCallback onShowOnline;
  final bool is3D;
  final bool isLive;
  final int liveCount;
  final double drivenKm;
  const _NavBottomBar({required this.accentColor, required this.brightness, required this.onStop, required this.onReport, required this.onSettings, required this.onToggle3D, required this.onToggleMapType, required this.onShowOnline, required this.is3D, required this.isLive, required this.liveCount, required this.drivenKm});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speed = ref.watch(navigationProvider.select((s) => s.currentSpeed));
    final distText = ref.watch(navigationProvider.select((s) => s.remainingDistanceText));
    final timeText = ref.watch(navigationProvider.select((s) => s.remainingTimeText));
    final etaText = ref.watch(navigationProvider.select((s) => s.etaText));

    final textColor = brightness == Brightness.dark ? Colors.white : Colors.black87;
    final mutedColor = brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF6C757D);
    final xp = drivenKm.round();

    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(10, 8, 10, MediaQuery.of(context).padding.bottom + 8),
        decoration: BoxDecoration(
          color: brightness == Brightness.dark ? Colors.black.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.7),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, -4))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // ── Quick Actions: 3D/2D, Kartentyp, Einstellungen, Online, XP ──
          Row(children: [
            // 3D / 2D Toggle
            GestureDetector(
              onTap: onToggle3D,
              child: Container(
                height: 32, width: 38,
                decoration: BoxDecoration(
                  color: is3D ? accentColor.withValues(alpha: 0.2) : mutedColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: is3D ? accentColor.withValues(alpha: 0.4) : Colors.transparent),
                ),
                child: Center(child: Text(
                  is3D ? '3D' : '2D',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: is3D ? accentColor : mutedColor),
                )),
              ),
            ),
            const SizedBox(width: 4),
            // Kartentyp Toggle (Satellite/Normal)
            GestureDetector(
              onTap: onToggleMapType,
              child: Container(
                height: 32, width: 32,
                decoration: BoxDecoration(
                  color: mutedColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.layers_rounded, size: 16, color: mutedColor),
              ),
            ),
            const SizedBox(width: 4),
            // Einstellungen
            GestureDetector(
              onTap: onSettings,
              child: Container(
                height: 32, width: 32,
                decoration: BoxDecoration(
                  color: mutedColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.tune_rounded, size: 16, color: mutedColor),
              ),
            ),
            // Online badge removed — shown in global top bar instead
            const SizedBox(width: 4),
            // XP Badge
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [accentColor.withValues(alpha: 0.15), accentColor.withValues(alpha: 0.05)]),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.bolt_rounded, color: accentColor, size: 12),
                  const SizedBox(width: 2),
                  Flexible(child: Text('${drivenKm.toStringAsFixed(1)} km', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: accentColor), overflow: TextOverflow.ellipsis)),
                  Container(width: 1, height: 10, margin: const EdgeInsets.symmetric(horizontal: 3), color: accentColor.withValues(alpha: 0.3)),
                  Text('+$xp XP', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: accentColor)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          // ── Stats row ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Flexible(child: _stat(Icons.speed_rounded, '${speed.round()}', 'km/h', textColor, mutedColor)),
              Flexible(child: _stat(Icons.straighten_rounded, distText, '', textColor, mutedColor)),
              Flexible(child: _stat(Icons.schedule_rounded, timeText, '', textColor, mutedColor)),
              Flexible(child: _stat(Icons.flag_rounded, etaText, 'Ank.', textColor, mutedColor)),
              // Melden button
              GestureDetector(
                onTap: onReport,
                child: Container(
                  height: 34, width: 34,
                  decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.orange.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 2))]),
                  child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 15),
                ),
              ),
              const SizedBox(width: 4),
              // Stop button
              GestureDetector(
                onTap: onStop,
                child: Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.red.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 2))]),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
        ]),
      ),
    );
  }

  Widget _stat(IconData icon, String value, String unit, Color color, Color muted) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 18, color: muted),
      const SizedBox(height: 2),
      Text(value, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
      if (unit.isNotEmpty) Text(unit, style: GoogleFonts.inter(fontSize: 10, color: muted)),
    ]);
  }
}
