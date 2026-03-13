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
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../core/community.dart';
import '../../domain/models/user.dart' as app_user;
import '../../domain/xp_calculator.dart';
import '../../data/repositories/blitzer_repository.dart';
import '../../services/osm_blitzer_service.dart';
import '../../providers/auth/auth_notifier.dart';
import '../../providers/auth/auth_state.dart';
import '../../providers/map/map_settings_provider.dart';
import '../../providers/map/country_policy_provider.dart';
import '../../providers/map/driving_mode_provider.dart';
import '../../providers/core/providers.dart';
import '../../providers/core/speed_dial_provider.dart';
import '../../providers/map/live_location_provider.dart';
import '../../services/alert_audio_service.dart';
import '../../services/blitzer_alert_service.dart';
import '../../services/geocoding_service.dart';
import '../../services/live_location_service.dart';
import '../../services/location_engine.dart';
import '../../services/marker_icon_service.dart';
import '../../services/kalman_filter.dart';
import '../../services/heading_sensor_service.dart';
import '../../services/app_mode_controller.dart';
import '../../services/tts_alert_service.dart';
import '../../services/vosk_wake_word_service.dart';
import '../../services/voice_command_service.dart';
import '../../services/fast_answer_service.dart';
import '../../services/biker_ai_service.dart';
import '../../theme/app_theme.dart';
import 'widgets/blitzer_alert_banner.dart';
import 'widgets/live_user_bubble.dart';
import 'widgets/map_bottom_bar.dart';
import 'widgets/map_profile_bubble.dart';
import 'widgets/privacy_prompt_sheet.dart';
import '../groups/groups_list_sheet.dart';

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
  const borderColor = Color(0xFF00C853); // Leuchtgrün = Online
  const center = Offset(size / 2, size / 2);

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

  // Grüner Glow (Online)
  canvas.drawCircle(center, size / 2,
    Paint()
      ..color = borderColor.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));

  // Grüner Rand (Online)
  canvas.drawCircle(center, size / 2 - 4, Paint()..color = borderColor);

  if (profileImage != null) {
    // Clip to circle and draw profile image
    canvas.save();
    final clipPath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: size / 2 - 10));
    canvas.clipPath(clipPath);
    final srcRect = Rect.fromLTWH(0, 0, profileImage.width.toDouble(), profileImage.height.toDouble());
    final dstRect = Rect.fromCircle(center: center, radius: size / 2 - 10);
    canvas.drawImageRect(profileImage, srcRect, dstRect, Paint());
    canvas.restore();
  } else {
    // Fallback: white circle with vehicle icon
    canvas.drawCircle(center, size / 2 - 10, Paint()..color = Colors.white);
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
          color: borderColor,
        ),
      )
      ..layout();
    tp.paint(canvas, Offset((size - tp.width) / 2, (size - tp.height) / 2));
  }

  // Weißer Innenring
  canvas.drawCircle(center, size / 2 - 8,
    Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 3);

  // Grüner Außenring (prominent)
  canvas.drawCircle(center, size / 2 - 3,
    Paint()..color = borderColor..style = PaintingStyle.stroke..strokeWidth = 5);

  final picture = recorder.endRecording();
  final image = await picture.toImage(size.toInt(), size.toInt());
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  final bytes = byteData!.buffer.asUint8List();

  final descriptor = BitmapDescriptor.bytes(bytes, width: 48, height: 48);
  _navIconCache[cacheKey] = descriptor;
  return descriptor;
}

// ─── Live user profile marker (delegated to MarkerIconService) ───────────────
Future<BitmapDescriptor> _getLiveUserMarkerIcon({
  required String? avatarUrl,
  required String displayName,
  String? groupColorHex,
}) => MarkerIconService.instance.getLiveUserMarker(
  avatarUrl: avatarUrl,
  displayName: displayName,
  groupColorHex: groupColorHex,
);

Future<BitmapDescriptor> _getSosUserMarkerIcon({
  required String? avatarUrl,
  required String displayName,
}) => MarkerIconService.instance.getSosMarker(
  avatarUrl: avatarUrl,
  displayName: displayName,
);

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

// ─── Offline Marker for PLZ users ─────────────────────────────────────────────
final Map<String, BitmapDescriptor> _offlineMarkerCache = {};

/// Creates marker icon for offline/PLZ-based users.
/// [isMe] = ROT Home-Icon (groß, hervorgehoben), others = Blauer Pfeil (klein).
/// Manuell per Path gezeichnet (kein Material Icons Font nötig).
/// Fallback: Google default marker falls Canvas-Rendering fehlschlägt.
Future<BitmapDescriptor> _getOfflineArrowIcon({bool isMe = false}) async {
  final key = isMe ? 'home_me' : 'arrow_other';
  if (_offlineMarkerCache.containsKey(key)) return _offlineMarkerCache[key]!;

  try {
    final double size = isMe ? 128 : 80;
    final color = isMe ? const Color(0xFFE53935) : const Color(0xFF1976D2);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size, size));
    final center = Offset(size / 2, size / 2);
    final radius = size / 2 - (isMe ? 6 : 2);

    if (isMe) {
      // Glow-Effekt (roter Schatten)
      canvas.drawCircle(
        center, radius + 8,
        Paint()
          ..color = const Color(0xFFE53935).withValues(alpha: 0.30)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    // Hintergrund-Kreis
    canvas.drawCircle(center, radius, Paint()..color = color);
    // Weißer Rand
    canvas.drawCircle(
      center, radius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = isMe ? 5 : 3,
    );

    final iconPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final cx = size / 2;
    final cy = size / 2;

    if (isMe) {
      // ★ HOME-ICON für eigenen Standort
      final s = size * 0.38; // Icon-Größe relativ zum Kreis

      // Dach (Dreieck)
      final roofPath = Path()
        ..moveTo(cx, cy - s * 0.55) // Spitze oben
        ..lineTo(cx - s * 0.55, cy - s * 0.05) // Links unten
        ..lineTo(cx + s * 0.55, cy - s * 0.05) // Rechts unten
        ..close();
      canvas.drawPath(roofPath, iconPaint);

      // Haus-Körper (Rechteck)
      final bodyRect = Rect.fromLTRB(
        cx - s * 0.40, cy - s * 0.08,
        cx + s * 0.40, cy + s * 0.50,
      );
      canvas.drawRect(bodyRect, iconPaint);

      // Tür (kleines Rechteck, rot = Hintergrundfarbe)
      final doorPaint = Paint()..color = color;
      final doorRect = Rect.fromLTRB(
        cx - s * 0.12, cy + s * 0.15,
        cx + s * 0.12, cy + s * 0.50,
      );
      canvas.drawRRect(
        RRect.fromRectAndCorners(doorRect, topLeft: const Radius.circular(3), topRight: const Radius.circular(3)),
        doorPaint,
      );
    } else {
      // ★ HOME-ICON auch für andere User (blau, kleiner)
      final s = size * 0.36;

      // Dach (Dreieck)
      final roofPath = Path()
        ..moveTo(cx, cy - s * 0.55)
        ..lineTo(cx - s * 0.55, cy - s * 0.05)
        ..lineTo(cx + s * 0.55, cy - s * 0.05)
        ..close();
      canvas.drawPath(roofPath, iconPaint);

      // Haus-Körper (Rechteck)
      final bodyRect = Rect.fromLTRB(
        cx - s * 0.40, cy - s * 0.08,
        cx + s * 0.40, cy + s * 0.50,
      );
      canvas.drawRect(bodyRect, iconPaint);

      // Tür (kleines Rechteck, blau = Hintergrundfarbe)
      final doorPaint = Paint()..color = color;
      final doorRect = Rect.fromLTRB(
        cx - s * 0.12, cy + s * 0.15,
        cx + s * 0.12, cy + s * 0.50,
      );
      canvas.drawRRect(
        RRect.fromRectAndCorners(doorRect, topLeft: const Radius.circular(2), topRight: const Radius.circular(2)),
        doorPaint,
      );
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) throw Exception('toByteData returned null');
    final bytes = byteData.buffer.asUint8List();

    final bitmapSize = isMe ? 44.0 : 26.0;
    final descriptor = BitmapDescriptor.bytes(bytes, width: bitmapSize, height: bitmapSize);
    _offlineMarkerCache[key] = descriptor;
    debugPrint('[MarkerIcon] Created $key icon (${size.toInt()}px → ${bitmapSize}px)');
    return descriptor;
  } catch (e) {
    // Fallback: Standard Google Marker
    debugPrint('[MarkerIcon] Custom icon failed, using fallback: $e');
    final fallback = BitmapDescriptor.defaultMarkerWithHue(
      isMe ? BitmapDescriptor.hueRed : BitmapDescriptor.hueAzure,
    );
    _offlineMarkerCache[key] = fallback;
    return fallback;
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// MAIN SCREEN
// ═════════════════════════════════════════════════════════════════════════════

class CommunityMapScreen extends ConsumerStatefulWidget {
  const CommunityMapScreen({super.key});

  @override
  ConsumerState<CommunityMapScreen> createState() => _CommunityMapScreenState();
}

class _CommunityMapScreenState extends ConsumerState<CommunityMapScreen> {
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
  // Polylines entfernt (keine Navigation mehr)
  Set<Circle> _cachedDangerZones = {};

  // Country policy state
  String? _detectedCountryCode;
  bool _countryDetectionInProgress = false;
  DateTime? _lastCountryCheck;

  // Distance-based marker opacity refresh
  DateTime? _lastMarkerOpacityRefresh;

  // Live GPS
  StreamSubscription<Map<String, LiveUserPosition>>? _liveSub;
  Map<String, LiveUserPosition> _liveUsers = {};
  final Map<String, BitmapDescriptor> _liveUserIcons = {};
  final Map<String, BitmapDescriptor> _sosUserIcons = {}; // SOS-Version der Profilbilder
  Set<String> _followingIds = {}; // IDs der gefolgten User — nur diese sehen Live-Marker

  // Location Engine (GPS pipeline with Kalman smoothing)
  LocationEngine? _locationEngine;
  StreamSubscription<SmoothedPosition>? _navSmoothedStream;
  StreamSubscription<SmoothedPosition>? _bgLocationStream; // Background blitzer checks (non-nav mode)

  // Blitzer warning state
  String? _blitzerWarning;
  Timer? _blitzerWarningTimer;

  // Map view mode (normal with dark style as default)
  MapType _mapType = MapType.normal;
  bool _is3D = false;

  Color _cachedAccentColor = AppTheme.accentDark;
  Community? _cachedCommunity;

  // Community-specific vehicle icon
  BitmapDescriptor? _navMarkerIcon;

  bool _showProfileBubble = false; // Profil-Bubble über dem Marker
  LiveUserPosition? _selectedLiveUser; // Angeklickter Live-User für Bubble
  int _profileTotalLikes = 0; // Eigene Gesamtlikes für Profil-Bubble

  // Supabase Realtime: live sync of blitzer reports across users
  RealtimeChannel? _blitzerRealtimeChannel;
  // Polling-Fallback: regelmäßig Reports neu laden (30s)
  Timer? _reportPollingTimer;

  // Extra guard: set to true in dispose() to block ALL async callbacks
  bool _disposed = false;

  // GPS is NOT active by default — user sees PLZ position first
  bool _gpsActive = false;

  // Group ride filter — only show group members on map
  bool _groupFilterActive = false;

  // PLZ-Position speichern für "zurück zu PLZ" bei GPS-Toggle-Off
  LatLng? _plzPosition;
  double _plzZoom = 14.0;

  // SOS State
  bool _sosActive = false;
  Timer? _sosBlinkTimer;
  bool _sosBlinkVisible = true;

  // Auto-hide UI on map interaction (zoom/pan/rotate)
  bool _mapInteracting = false;
  bool _isProgrammaticMove = false;
  Timer? _mapIdleTimer;

  // GPS ON/OFF overlay — IMMER sichtbar als Badge auf dem Button

  // Visibility overlay (centered, tap to dismiss)
  bool _showVisibilityBanner = false;

  // Privacy Prompt: nur 1x pro Session fragen
  bool _hasBeenPromptedThisSession = false;

  // ── Heading rotation (compass-based map bearing) ──
  StreamSubscription<double>? _headingSub;
  StreamSubscription<Position>? _headingGpsSub;
  double _currentHeading = 0;
  Timer? _headingFollowTimer;
  bool _headingFollowActive = false;

  // ── Vosk wake word: "Hi Moto" voice assistant ──
  bool _voskInitialized = false;
  bool _wakeWordActive = false;
  bool _wakeWordTriggered = false;

  // ── Community User Map (PLZ-based offline markers) ──
  Set<Marker> _communityUserMarkers = {};
  bool _showCommunityUsers = true; // Toggleable layer
  int _communityUserCount = 0;
  List<Map<String, dynamic>> _communityUsersData = []; // Raw user data for list sheet

  @override
  void initState() {
    super.initState();

    // Sofort Karte anzeigen mit PLZ-basierter Position (kein GPS nötig)
    _initFromUserPlz();

    // ★ Bei Erst-Auth ODER PLZ-Änderung die Karte neu positionieren
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || !mounted) return;
      ref.listen(authNotifierProvider, (prev, next) {
        if (next is Authenticated) {
          if (prev is! Authenticated) {
            // ★ Erst-Auth → PLZ DIREKT laden (ohne addPostFrameCallback-Delay!)
            debugPrint('[Map] Auth ready → init PLZ position DIREKT');
            _doInitPlzPosition();
            // NavIcon nochmal laden mit echtem Avatar
            _preloadNavIcon();
          } else if (next.user.postalCode != prev.user.postalCode) {
            debugPrint('[Map] PLZ changed: ${prev.user.postalCode} → ${next.user.postalCode}');
            _doInitPlzPosition();
          }
        }
      });
    });

    _loadFollowingIds();
    _listenToLiveUsers();
    _autoStartLive();
    // _loadCommunityUsers() wird jetzt am Ende von _initFromUserPlz() aufgerufen
    // damit _plzPosition schon gesetzt ist
    _preloadMarkerIcons();

    // Initialize audio service early so tones are ready for all modes
    AlertAudioService.instance.init();

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

    // ── Vosk: "Hi Moto" wake word voice assistant ──
    _initVoskWakeWord();
  }

  @override
  void dispose() {
    _disposed = true;
    _reportPollingTimer?.cancel();
    _blitzerRealtimeChannel?.unsubscribe();
    _liveSub?.cancel();
    _bgLocationStream?.cancel();
    _blitzerWarningTimer?.cancel();
    _sosBlinkTimer?.cancel();
    _mapIdleTimer?.cancel();
    _locationEngine?.stop();
    _stopHeadingFollow();
    // Live service keeps running so GPS restores when coming back to map
    _mapController?.dispose();
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
          icon: _gpsActive ? Icons.my_location_rounded : Icons.gps_off_rounded,
          label: _gpsActive ? 'GPS aus' : 'GPS an',
          color: _gpsActive ? Colors.blue : Colors.green,
          onTap: () async {
            if (_disposed || !mounted) return;
            if (_gpsActive) {
              _stopGps();
            } else {
              await _startGps();
              if (mounted) _registerSpeedDialItems();
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
          icon: Icons.settings_rounded,
          label: 'Karten-Einst.',
          color: Colors.grey,
          onTap: () { if (_disposed || !mounted) return; context.push('/map-settings'); },
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
    // ★ SOFORT Placeholder setzen — BEVOR community check!
    // Damit der Marker bei GPS ON direkt sichtbar ist (grüner Punkt)
    if (_navMarkerIcon == null) {
      _navMarkerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      _rebuildCachedMarkers();
      if (mounted && !_disposed) setState(() {});
      debugPrint('[NavIcon] Placeholder gesetzt (community noch nicht geladen)');
    }

    final community = ref.read(communityProvider);
    _cachedCommunity = community;
    if (community == null) {
      debugPrint('[NavIcon] Community null — nur Placeholder, warte auf Community');
      return;
    }

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
    debugPrint('[NavIcon] Profilbild geladen (avatar: ${avatarUrl != null})');
    // Marker mit echtem Profilbild neu aufbauen
    _rebuildCachedMarkers();
    setState(() {});
  }

  // ─── Cached marker/polyline rebuilders ────────────────────────────────

  void _rebuildCachedMarkers() {
    if (_disposed || !mounted) return;
    final all = <Marker>{..._blitzerMarkers};

    // PLZ-Marker: eigene rot, andere blau — IMMER sichtbar
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    if (_showCommunityUsers) {
      for (final marker in _communityUserMarkers) {
        all.add(marker);
      }
    }

    // Live-User Marker: bei GPS ON alle zeigen, bei GPS OFF nur SOS-User
    for (final user in _liveUsers.values) {
      // Eigenen User überspringen — wird als my_vehicle Marker gehandhabt
      if (user.userId == currentUserId) continue;
      // Bei GPS OFF nur SOS-User zeigen
      if (!_gpsActive && !user.sos) continue;

      final isSos = user.sos;

      // Icon-Auswahl: SOS blinkt zwischen SOS-Profilbild und normalem Profilbild
      BitmapDescriptor markerIcon;
      if (isSos) {
        if (_sosBlinkVisible) {
          markerIcon = _sosUserIcons[user.userId] ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
        } else {
          markerIcon = _liveUserIcons[user.userId] ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
        }
      } else {
        markerIcon = _liveUserIcons[user.userId] ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      }

      final inRide = user.activeGroupId != null;
      all.add(Marker(
        markerId: MarkerId('live_${user.userId}'),
        position: LatLng(user.lat, user.lng),
        infoWindow: InfoWindow(
          title: isSos
              ? '🆘 SOS — ${user.displayName}'
              : inRide
                  ? '${user.displayName} (Gruppenfahrt)'
                  : '${user.displayName} (Live)',
          snippet: isSos ? 'Braucht Hilfe!' : '${user.speed.toStringAsFixed(0)} km/h',
        ),
        icon: markerIcon,
        anchor: const Offset(0.5, 0.5),
        flat: !isSos,
        zIndex: isSos ? 100 : (inRide ? 15 : 10),
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

    // Eigenes Profilbild-Marker NUR bei GPS ON (oder SOS)
    // Bei GPS OFF zeigt der PLZ-Pfeil-Marker den eigenen Standort
    if (_currentPosition != null && _navMarkerIcon != null && (_gpsActive || _sosActive)) {
      final ownSos = _sosActive;

      // Bei SOS: zwischen SOS-Icon und normalem Icon wechseln
      BitmapDescriptor ownIcon;
      if (ownSos) {
        final uid = Supabase.instance.client.auth.currentUser?.id;
        final sosIcon = uid != null ? _sosUserIcons[uid] : null;
        if (sosIcon != null) {
          // SOS-Icon geladen → zwischen SOS (rot) und normal (grün) blinken
          ownIcon = _sosBlinkVisible ? sosIcon : _navMarkerIcon!;
        } else {
          // SOS-Icon noch nicht geladen → Sichtbarkeit blinken
          ownIcon = _navMarkerIcon!;
        }
      } else {
        ownIcon = _navMarkerIcon!;
      }

      all.add(Marker(
        markerId: const MarkerId('my_vehicle'),
        position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        icon: ownIcon,
        rotation: 0,
        anchor: const Offset(0.5, 0.5),
        flat: !ownSos,
        zIndex: ownSos ? 100 : 30,
        // Bei SOS ohne SOS-Icon: Sichtbarkeit blinken
        visible: ownSos && _sosUserIcons[Supabase.instance.client.auth.currentUser?.id] == null
            ? _sosBlinkVisible : true,
        onTap: () {
          if (mounted) {
            setState(() => _showProfileBubble = !_showProfileBubble);
          }
        },
      ));
    }

    _cachedAllMarkers = all;

    // SOS-Kreise: Große rote pulsierende Kreise um SOS-User
    // Werden zu den bestehenden DangerZones hinzugefügt
    final sosCircles = <Circle>{};
    // Eigener SOS-Kreis
    if (_sosActive && _currentPosition != null) {
      sosCircles.add(Circle(
        circleId: const CircleId('sos_circle_self'),
        center: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        radius: _sosBlinkVisible ? 300 : 150,
        fillColor: Colors.red.withValues(alpha: _sosBlinkVisible ? 0.15 : 0.08),
        strokeColor: Colors.red.withValues(alpha: _sosBlinkVisible ? 0.7 : 0.3),
        strokeWidth: _sosBlinkVisible ? 3 : 1,
        zIndex: 50,
      ));
    }
    for (final user in _liveUsers.values) {
      if (user.sos) {
        sosCircles.add(Circle(
          circleId: CircleId('sos_circle_${user.userId}'),
          center: LatLng(user.lat, user.lng),
          radius: _sosBlinkVisible ? 300 : 150,
          fillColor: Colors.red.withValues(alpha: _sosBlinkVisible ? 0.15 : 0.08),
          strokeColor: Colors.red.withValues(alpha: _sosBlinkVisible ? 0.7 : 0.3),
          strokeWidth: _sosBlinkVisible ? 3 : 1,
          zIndex: 50,
        ));
      }
    }
    // Merge SOS circles mit bestehenden DangerZones
    if (sosCircles.isNotEmpty) {
      _cachedDangerZones = {..._cachedDangerZones.where((c) => !c.circleId.value.startsWith('sos_')), ...sosCircles};
    } else {
      _cachedDangerZones = _cachedDangerZones.where((c) => !c.circleId.value.startsWith('sos_')).toSet();
    }
  }

  // ─── Live GPS ──────────────────────────────────────────────────────────

  /// Lade die Following-IDs: nur gefolgte User werden als Live-Marker angezeigt.
  Future<void> _loadFollowingIds() async {
    try {
      final profileRepo = ref.read(profileRepositoryProvider);
      final community = ref.read(communityProvider)?.name;
      _followingIds = await profileRepo.getFollowingIds(community: community);
      debugPrint('[Map] Following IDs loaded: ${_followingIds.length}');
    } catch (e) {
      debugPrint('[Map] Failed to load following IDs: $e');
    }
  }

  /// Filtert Live-User: nur gefolgte + SOS-User + eigener User.
  Map<String, LiveUserPosition> _filterLiveUsers(Map<String, LiveUserPosition> allUsers) {
    final service = ref.read(liveLocationServiceProvider);
    final myGroupId = service.activeGroupId;

    // If group filter is active and user is in a group ride, show only group members
    if (_groupFilterActive && myGroupId != null) {
      return Map.fromEntries(
        allUsers.entries.where((e) => e.value.activeGroupId == myGroupId),
      );
    }
    // Otherwise show ALL live users
    return Map.from(allUsers);
  }

  /// Load all profile icons for [users] first, then update the map.
  /// This prevents showing the default green arrow while the icon is loading.
  Future<void> _loadIconsThenApply(Map<String, LiveUserPosition> users) async {
    for (final user in users.values) {
      // Cache key includes group color so marker updates when ride starts/stops
      final iconKey = user.activeGroupId != null
          ? '${user.userId}_${user.groupColor}'
          : user.userId;
      if (!_liveUserIcons.containsKey(iconKey)) {
        try {
          final icon = await _getLiveUserMarkerIcon(
            avatarUrl: user.avatarUrl,
            displayName: user.displayName,
            groupColorHex: user.activeGroupId != null ? user.groupColor : null,
          );
          if (_disposed || !mounted) return;
          _liveUserIcons[iconKey] = icon;
        } catch (_) {}
      }
      // Map userId → current icon key for marker lookup
      _liveUserIcons[user.userId] = _liveUserIcons[iconKey]!;
    }
    if (_disposed || !mounted) return;
    _liveUsers = _filterLiveUsers(users);
    _rebuildCachedMarkers();
    setState(() {});
  }

  void _listenToLiveUsers() {
    final service = ref.read(liveLocationServiceProvider);
    // Seed with current snapshot after loading icons to avoid green arrow flash
    final initialUsers = _filterLiveUsers(
      Map<String, LiveUserPosition>.from(service.nearbyUsers));
    if (initialUsers.isNotEmpty) {
      _loadIconsThenApply(initialUsers);
    }
    _liveSub = service.nearbyUsersStream.listen((allUsers) async {
      if (_disposed || !mounted) return;
      final users = _filterLiveUsers(allUsers);

      // Preload profile icons for ALL users BEFORE updating the map,
      // so we never show the default green arrow fallback.
      for (final user in users.values) {
        // Key includes group color so icon refreshes when ride starts/stops
        final iconKey = user.activeGroupId != null
            ? '${user.userId}_${user.groupColor}'
            : user.userId;
        if (!_liveUserIcons.containsKey(iconKey)) {
          try {
            final icon = await _getLiveUserMarkerIcon(
              avatarUrl: user.avatarUrl,
              displayName: user.displayName,
              groupColorHex: user.activeGroupId != null ? user.groupColor : null,
            );
            if (_disposed || !mounted) return;
            _liveUserIcons[iconKey] = icon;
          } catch (_) {}
        }
        // Always update userId → current icon
        if (_liveUserIcons.containsKey(iconKey)) {
          _liveUserIcons[user.userId] = _liveUserIcons[iconKey]!;
        }
      }
      // Preload SOS icons for users with active SOS
      for (final user in users.values) {
        if (user.sos && !_sosUserIcons.containsKey(user.userId)) {
          try {
            final sosIcon = await _getSosUserMarkerIcon(
              avatarUrl: user.avatarUrl,
              displayName: user.displayName,
            );
            if (_disposed || !mounted) return;
            _sosUserIcons[user.userId] = sosIcon;
          } catch (_) {}
        }
      }

      // Clean up icons for users no longer live
      _liveUserIcons.removeWhere((id, _) => !users.containsKey(id));
      _sosUserIcons.removeWhere((id, _) => !users.containsKey(id));

      // Check if a NEW SOS appeared from another user → play alarm
      // WICHTIG: Vergleich BEVOR _liveUsers überschrieben wird!
      final previousSosUsers = _liveUsers.values.where((u) => u.sos).map((u) => u.userId).toSet();
      final currentSosUsers = users.values.where((u) => u.sos).map((u) => u.userId).toSet();

      // Update _liveUsers only after icons are ready → no green arrow flash
      _liveUsers = users;
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      final newSosUsers = currentSosUsers.difference(previousSosUsers);
      // Nur Alarm wenn es ein NEUER SOS ist und nicht vom eigenen User
      if (newSosUsers.isNotEmpty && !newSosUsers.contains(currentUserId)) {
        AlertAudioService.instance.playSosAlarm();
        // SnackBar: welcher User hat SOS gesendet
        final sosUser = users.values.firstWhere((u) => newSosUsers.contains(u.userId));
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(children: [
                const Icon(Icons.sos, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text('🆘 ${sosUser.displayName} braucht Hilfe!',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
              ]),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }

      // Start SOS blink timer if any user has SOS active (including self)
      final anyoneSos = currentSosUsers.isNotEmpty;
      if (anyoneSos && _sosBlinkTimer == null) {
        _sosBlinkTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
          if (!mounted || _disposed) {
            _sosBlinkTimer?.cancel();
            _sosBlinkTimer = null;
            return;
          }
          _sosBlinkVisible = !_sosBlinkVisible;
          _rebuildCachedMarkers();
          setState(() {});
        });
      } else if (!anyoneSos && !_sosActive && _sosBlinkTimer != null) {
        _sosBlinkTimer?.cancel();
        _sosBlinkTimer = null;
        _sosBlinkVisible = true;
      }

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

      // Pfeil-Icons vorladen (einmalig, gecacht)
      final arrowMe = await _getOfflineArrowIcon(isMe: true);
      final arrowOther = await _getOfflineArrowIcon(isMe: false);
      if (_disposed || !mounted) return;

      final markers = <Marker>{};
      final usersData = <Map<String, dynamic>>[];

      // PLZs die async geocodiert werden müssen (kein Sync-Fallback)
      final pendingGeocode = <Map<String, dynamic>>[];

      // ★ PHASE 1: Alle User sammeln und nach PLZ gruppieren
      final resolvedUsers = <Map<String, dynamic>>[];
      for (final profile in data) {
        final postalCode = profile['postal_code'] as String?;
        if (postalCode == null || postalCode.isEmpty) continue;

        final isMe = profile['id'] == currentUserId;
        // Eigenen User nur als PLZ-Marker anzeigen wenn GPS OFF
        if (isMe && _gpsActive) continue;

        // Sync-Lookup (Cache + PLZ-Regionszuordnung DE)
        LatLng? coords = _plzToCoordsSync(postalCode);

        // Eigener User: _plzPosition aus _initFromUserPlz() nutzen (präziser)
        if (coords == null && isMe && _plzPosition != null) {
          coords = _plzPosition;
        }

        if (coords != null) {
          resolvedUsers.add({
            ...profile,
            '_coords': coords,
            '_isMe': isMe,
          });
        } else {
          pendingGeocode.add(profile);
        }
      }

      // ★ PHASE 2: User mit gleicher PLZ kreisförmig aufteilen
      final plzGroups = <String, List<Map<String, dynamic>>>{};
      for (final u in resolvedUsers) {
        final plz = (u['postal_code'] as String).trim();
        plzGroups.putIfAbsent(plz, () => []).add(u);
      }

      for (final entry in plzGroups.entries) {
        final group = entry.value;
        final centerCoords = group.first['_coords'] as LatLng;

        for (int i = 0; i < group.length; i++) {
          final profile = group[i];
          final isMe = profile['_isMe'] as bool;
          final displayName = profile['display_name'] ?? profile['username'] ?? 'User';
          final postalCode = profile['postal_code'] as String;

          // ★ Offset berechnen: kreisförmig um den PLZ-Mittelpunkt
          LatLng markerPos;
          if (group.length == 1) {
            markerPos = centerCoords; // Einzelner User → kein Offset
          } else {
            // Radius ~300m in Grad (ca. 0.003°), kreisförmig verteilt
            const radius = 0.003;
            final angle = (2 * pi * i) / group.length;
            final offsetLat = radius * cos(angle);
            final offsetLng = radius * sin(angle);
            markerPos = LatLng(
              centerCoords.latitude + offsetLat,
              centerCoords.longitude + offsetLng,
            );
          }

          usersData.add({
            ...profile,
            'lat': markerPos.latitude,
            'lng': markerPos.longitude,
            'is_me': isMe,
          });
          markers.add(Marker(
            markerId: MarkerId('plz_${profile['id']}'),
            position: markerPos,
            infoWindow: InfoWindow(
              title: isMe ? '$displayName (Du)' : displayName as String,
              snippet: 'PLZ: $postalCode',
            ),
            icon: isMe ? arrowMe : arrowOther,
            alpha: isMe ? 0.9 : 0.6,
            anchor: const Offset(0.5, 0.5),
            flat: true,
            zIndex: isMe ? 5 : 1,
          ));
        }
      }

      if (_disposed || !mounted) return;
      setState(() {
        _communityUserMarkers = markers;
        _communityUserCount = markers.length;
        _communityUsersData = usersData;
      });
      _rebuildCachedMarkers();
      debugPrint('[CommunityUsers] ${markers.length} markers loaded (${pendingGeocode.length} pending geocode)');

      // Async Geocoding für fehlende PLZs (im Hintergrund)
      if (pendingGeocode.isNotEmpty) {
        _geocodePendingUsers(pendingGeocode, arrowMe, arrowOther, currentUserId);
      }
    } catch (e) {
      debugPrint('[CommunityUsers] Error loading: $e');
    }
  }

  /// Async Geocoding für User-PLZs die kein Sync-Fallback haben.
  Future<void> _geocodePendingUsers(
    List<Map<String, dynamic>> profiles,
    BitmapDescriptor arrowMe,
    BitmapDescriptor arrowOther,
    String? currentUserId,
  ) async {
    for (final profile in profiles) {
      if (_disposed || !mounted) return;
      final postalCode = profile['postal_code'] as String?;
      if (postalCode == null || postalCode.isEmpty) continue;

      final coords = await _geocodePlz(postalCode);
      if (coords == null || _disposed || !mounted) continue;

      final displayName = profile['display_name'] ?? profile['username'] ?? 'User';
      final isMe = profile['id'] == currentUserId;

      final marker = Marker(
        markerId: MarkerId('plz_${profile['id']}'),
        position: coords,
        infoWindow: InfoWindow(
          title: isMe ? '$displayName (Du)' : displayName as String,
          snippet: 'PLZ: $postalCode',
        ),
        icon: isMe ? arrowMe : arrowOther,
        alpha: isMe ? 0.9 : 0.6,
        anchor: const Offset(0.5, 0.5),
        flat: true,
        zIndex: isMe ? 5 : 1,
      );

      setState(() {
        _communityUserMarkers = {..._communityUserMarkers, marker};
        _communityUserCount = _communityUserMarkers.length;
        _communityUsersData = [
          ..._communityUsersData,
          {...profile, 'lat': coords.latitude, 'lng': coords.longitude, 'is_me': isMe},
        ];
      });
      _rebuildCachedMarkers();
    }
  }

  /// Geocode PLZ weltweit via Nominatim (OpenStreetMap).
  /// Cached pro PLZ um wiederholte API-Calls zu vermeiden.
  static final Map<String, LatLng> _plzGeoCache = {};

  /// Geocode eine PLZ via Nominatim API (async, cached).
  /// Default: Deutschland. Andere Länder über [countryCode] möglich.
  Future<LatLng?> _geocodePlz(String plz, {String countryCode = 'de'}) async {
    if (plz.isEmpty) return null;
    final trimmed = plz.trim();

    // Cache check (inkl. Land)
    final cacheKey = '${trimmed}_$countryCode';
    if (_plzGeoCache.containsKey(cacheKey)) return _plzGeoCache[cacheKey];

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?postalcode=${Uri.encodeComponent(trimmed)}&countrycodes=$countryCode&format=json&limit=1',
      );
      final response = await http.get(uri, headers: {
        'User-Agent': 'BikergamApp/1.0',
      });

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        if (results.isNotEmpty) {
          final lat = double.tryParse(results[0]['lat'].toString());
          final lng = double.tryParse(results[0]['lon'].toString());
          if (lat != null && lng != null) {
            final coords = LatLng(lat, lng);
            _plzGeoCache[cacheKey] = coords;
            debugPrint('[Map] Geocoded PLZ "$trimmed" ($countryCode) → $lat, $lng');
            return coords;
          }
        }
      }
      debugPrint('[Map] Geocode failed for PLZ "$trimmed" (status=${response.statusCode})');
    } catch (e) {
      debugPrint('[Map] Geocode error for PLZ "$trimmed": $e');
    }
    return null;
  }

  /// Schnelle Offline-PLZ-Konvertierung für Batch-Marker (Community-Users).
  /// Nutzt Nominatim-Cache wenn vorhanden, sonst einfache Regionszuordnung.
  LatLng? _plzToCoordsSync(String plz) {
    if (plz.isEmpty) return null;
    final trimmed = plz.trim();

    // Erst Cache von Nominatim prüfen (mit und ohne Land-Suffix)
    if (_plzGeoCache.containsKey(trimmed)) return _plzGeoCache[trimmed];
    // ★ Auch mit Länder-Suffix suchen (z.B. "10115_de")
    for (final entry in _plzGeoCache.entries) {
      if (entry.key.startsWith('${trimmed}_')) return entry.value;
    }

    // Fallback: Regionszuordnung für rein numerische PLZs
    final code = int.tryParse(trimmed.replaceAll(RegExp(r'[^0-9]'), ''));
    if (code == null) return null;

    // Deutsche PLZ (5-stellig, 01000-99999)
    if (trimmed.length == 5 && code >= 1000 && code <= 99999) {
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

    // Nicht-deutsche PLZ (AT/CH/LI) → Nominatim liefert präzise Coords
    return null;
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

  /// First map open per app session → OFF.
  /// Tab switches (map disposed + rebuilt) → restore if service still live.
  static bool _sessionFirstOpen = true;

  void _autoStartLive() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_disposed || !mounted) return;

      if (_sessionFirstOpen) {
        _sessionFirstOpen = false;
        debugPrint('[LiveGPS] First map open this session → GPS OFF');
        // Stop any leftover live service from previous session
        final service = ref.read(liveLocationServiceProvider);
        if (service.isLive) {
          service.goOffline();
          ref.read(isLiveProvider.notifier).set(false);
        }
        return;
      }

      // Subsequent opens (tab switch) → restore if service still live
      final service = ref.read(liveLocationServiceProvider);
      if (service.isLive) {
        debugPrint('[LiveGPS] Tab switch → restoring GPS ON');
        await _startGps(centerCamera: false);
        if (_disposed || !mounted) return;
        setState(() {});
      }
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
      await _startGps(); // GPS starten wenn noch nicht aktiv
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
    // ★ GPS wurde ausgeschaltet — keine stale Events verarbeiten
    if (!_gpsActive) return;

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

    // ★ Marker-Position aktualisieren (my_vehicle Marker bewegt sich)
    _rebuildCachedMarkers();
    if (mounted && !_disposed) setState(() {});

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

  /// PLZ des Users, um Änderungen zu erkennen
  String? _lastPlz;

  /// Wrapper für initState — nutzt addPostFrameCallback.
  void _initFromUserPlz() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || !mounted) return;
      _doInitPlzPosition();
    });
  }

  /// ★ Kern-Logik: PLZ-Position laden und Karte zentrieren.
  /// Kann direkt aufgerufen werden (z.B. vom Auth-Listener).
  Future<void> _doInitPlzPosition() async {
    if (_disposed || !mounted) return;
    final authState = ref.read(authNotifierProvider);
    if (authState is Authenticated) {
      final user = authState.user;
      final plz = user.postalCode;
      debugPrint('████ [Map] PLZ_DEBUG: user=${user.username}, plz="$plz", _gpsActive=$_gpsActive, _locationReady=$_locationReady ████');

      // ══════ SOFORT: PLZ-Position sync setzen ══════
      bool syncPlzOk = false;
      if (plz != null && plz.isNotEmpty) {
        final syncCoords = _plzToCoordsSync(plz);
        if (syncCoords != null) {
          _plzPosition = syncCoords;
          _plzZoom = 14.0;
          syncPlzOk = true;
          debugPrint('[Map] PLZ sync sofort: $plz → ${syncCoords.latitude}, ${syncCoords.longitude}');
          _applyHomePosition(syncCoords);
        }
      }

      // ══════ SCHRITT 1: Land per GPS erkennen (schnell) ══════
      String countryCode = 'de';
      try {
        Position? gpsPos = await Geolocator.getLastKnownPosition();
        if (gpsPos != null && !_disposed && mounted) {
          final geocoding = GeocodingService();
          final cc = await geocoding.reverseGeocodeCountryCode(
            gpsPos.latitude, gpsPos.longitude,
          );
          if (cc != null && cc.isNotEmpty) {
            countryCode = cc.toLowerCase();
            _detectedCountryCode = cc;
            debugPrint('[Map] Land erkannt: $countryCode');
          }
        }
      } catch (e) {
        debugPrint('[Map] Land-Erkennung fehlgeschlagen: $e');
      }
      if (_disposed || !mounted) return;

      // ══════ SCHRITT 2: PLZ-Geocoding mit erkanntem Land ══════
      if (plz != null && plz.isNotEmpty) {
        if (_lastPlz == plz && _plzPosition != null) {
          _applyHomePosition(_plzPosition!);
          _loadCommunityUsers();
          return;
        }
        _lastPlz = plz;
        final coords = await _geocodePlz(plz, countryCode: countryCode);
        if (_disposed || !mounted) return;
        if (coords != null) {
          debugPrint('[Map] ★ PLZ $plz ($countryCode) → ${coords.latitude}, ${coords.longitude}');
          _plzPosition = coords;
          _plzZoom = 14.0;
          _applyHomePosition(coords);
          _loadCommunityUsers();
          return;
        }
        // ★ Nominatim fehlgeschlagen ABER Sync-PLZ war OK → Sync-Coords behalten!
        if (syncPlzOk) {
          debugPrint('[Map] ★ Nominatim failed, keeping sync PLZ coords: ${_plzPosition}');
          _loadCommunityUsers();
          return;
        }
      }

      // ══════ SCHRITT 3: Home-Koordinaten aus DB (NUR wenn keine PLZ verfügbar) ══════
      if (user.homeLat != null && user.homeLng != null) {
        final coords = LatLng(user.homeLat!, user.homeLng!);
        debugPrint('[Map] Using stored home: ${coords.latitude}, ${coords.longitude}');
        _plzPosition = coords;
        _plzZoom = 14.0;
        _lastPlz = plz ?? '';
        _applyHomePosition(coords);
        _loadCommunityUsers();
        return;
      }

      // ══════ SCHRITT 4: GPS-Position als Fallback ══════
      try {
        Position? gpsPos = await Geolocator.getLastKnownPosition();
        gpsPos ??= await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 5),
          ),
        );
        if (_disposed || !mounted) return;
        final coords = LatLng(gpsPos.latitude, gpsPos.longitude);
        debugPrint('[Map] GPS fallback: ${coords.latitude}, ${coords.longitude}');
        _plzPosition = coords;
        _plzZoom = 14.0;
        _applyHomePosition(coords);
        _loadCommunityUsers();
        return;
      } catch (e) {
        debugPrint('[Map] GPS fallback failed: $e');
      }
    }
    // ★ Auth noch nicht fertig → Karte NICHT anzeigen (Loading bleibt).
    // Auth-Listener wird _doInitPlzPosition() erneut aufrufen wenn Auth bereit.
    debugPrint('[Map] Auth not ready → waiting (loading spinner stays)');
    // Safety-Timeout: nach 8s trotzdem anzeigen falls Auth/Geocoding hängt
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted && !_disposed && !_locationReady) {
        debugPrint('[Map] Timeout 8s → showing map (plzPosition=$_plzPosition)');
        // Don't override _plzPosition — initialCameraPosition handles null via _defaultCenter
        setState(() {
          _locationReady = true;
          _locationFailed = false;
        });
        _loadReports();
        _loadCommunityUsers();
      }
    });
  }

  /// Gemeinsame Logik: Home-Position auf Karte setzen + Kamera zentrieren.
  void _applyHomePosition(LatLng coords) {
    if (_disposed || !mounted) return;
    setState(() {
      if (!_gpsActive) {
        _currentPosition = Position(
          latitude: coords.latitude, longitude: coords.longitude,
          timestamp: DateTime.now(), accuracy: 5000,
          altitude: 0, altitudeAccuracy: 0,
          heading: 0, headingAccuracy: 0,
          speed: 0, speedAccuracy: 0,
        );
      }
      _plzPosition = coords;
      _locationReady = true;
      _locationFailed = false;
    });
    if (!_gpsActive) {
      debugPrint('[Map] _applyHomePosition: centering on ${coords.latitude}, ${coords.longitude}');
      // ★ moveCamera (sofort, zuverlässig) statt animateCamera
      try {
        _mapController?.moveCamera(CameraUpdate.newLatLngZoom(coords, _plzZoom));
      } catch (e) {
        debugPrint('[Map] _applyHomePosition: moveCamera failed: $e');
      }
      // Retry nach 500ms falls Map noch nicht fertig war
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !_disposed && !_gpsActive && _mapController != null) {
          _mapController!.animateCamera(CameraUpdate.newLatLngZoom(coords, _plzZoom));
        }
      });
    }
    _detectCountryFromPosition(coords.latitude, coords.longitude);
    _loadReports();
  }

  /// GPS on-demand starten — wird aufgerufen wenn User "Online gehen" wählt
  /// oder den GPS-Button auf der Karte drückt.
  /// [centerCamera] = false bei Auto-Start (PLZ-Zentrierung beibehalten)
  Future<void> _startGps({bool centerCamera = true}) async {
    if (_gpsActive) return; // Bereits aktiv
    try {
      debugPrint('[Map] _startGps START');

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[Map] GPS service disabled');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('GPS ist deaktiviert. Bitte in den Einstellungen aktivieren.')),
          );
        }
        return;
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        debugPrint('[Map] GPS permission denied');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('GPS-Berechtigung wurde verweigert.')),
          );
        }
        return;
      }

      // Initialize LocationEngine (Kalman-smoothed GPS pipeline)
      _locationEngine = ref.read(locationEngineProvider);
      await _locationEngine!.start(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      );

      // Background listener for blitzer checks
      _bgLocationStream?.cancel();
      _bgLocationStream = _locationEngine!.positionStream.listen(_onBgLocationUpdate);

      _gpsActive = true;
      debugPrint('[Map] GPS activated');

      // Start compass heading follow (always active when GPS is on)
      _startHeadingFollow();

      // ★ Eigenen PLZ-Marker entfernen (GPS-Marker übernimmt)
      _loadCommunityUsers();

      // ★ SOFORT Marker neu aufbauen damit my_vehicle Marker erscheint
      if (_currentPosition != null && _navMarkerIcon != null) {
        _rebuildCachedMarkers();
        setState(() {});
        debugPrint('[NavIcon] ★ GPS ON → Marker sofort aufgebaut (icon=${_navMarkerIcon != null})');
      }

      // Letzte bekannte Position nur verwenden wenn frisch (< 2 Min)
      bool gpsPositionSet = false;
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && mounted) {
        final age = lastKnown.timestamp != null
            ? DateTime.now().difference(lastKnown.timestamp!)
            : const Duration(hours: 1); // kein Timestamp → als stale behandeln

        if (age.inSeconds < 120) {
          _currentPosition = Position(
            latitude: lastKnown.latitude, longitude: lastKnown.longitude,
            timestamp: lastKnown.timestamp, accuracy: lastKnown.accuracy,
            altitude: lastKnown.altitude, altitudeAccuracy: lastKnown.altitudeAccuracy,
            heading: lastKnown.heading, headingAccuracy: lastKnown.headingAccuracy,
            speed: lastKnown.speed, speedAccuracy: lastKnown.speedAccuracy,
          );
          gpsPositionSet = true;
          // ★ Marker SOFORT rebuilden mit Position → my_vehicle sichtbar
          _rebuildCachedMarkers();
          setState(() {});
          debugPrint('[NavIcon] ★ lastKnown → Marker rebuilt at ${lastKnown.latitude.toStringAsFixed(4)},${lastKnown.longitude.toStringAsFixed(4)}');
          if (centerCamera) {
            _mapController?.animateCamera(CameraUpdate.newCameraPosition(
              CameraPosition(
                target: LatLng(lastKnown.latitude, lastKnown.longitude),
                zoom: _is3D ? 18 : 15,
                bearing: _is3D ? _currentHeading : 0,
                tilt: _is3D ? 65 : 0,
              ),
            ));
          }
          _detectCountryFromPosition(lastKnown.latitude, lastKnown.longitude);
          // ★ Blitzer sofort für lastKnown Position laden
          debugPrint('[Map] ★ GPS ON → loading blitzers for lastKnown ${lastKnown.latitude.toStringAsFixed(4)},${lastKnown.longitude.toStringAsFixed(4)}');
          _isLoadingReports = false;
          _loadReports();
        } else {
          debugPrint('[Map] lastKnownPosition stale (${age.inSeconds}s) — skipped, waiting for fresh GPS');
        }
      }

      // Auf erste Kalman-gefilterte Position warten
      SmoothedPosition? smoothedPos;
      try {
        smoothedPos = await _locationEngine!.positionStream.first.timeout(
          const Duration(seconds: 8),
        );
      } catch (_) {
        debugPrint('[Map] Timeout waiting for smoothed position');
      }

      if (!mounted || _disposed) return;

      if (smoothedPos != null) {
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
        _currentPosition = pos;
        gpsPositionSet = true;
        // ★ Marker mit genauer Position rebuilden
        _rebuildCachedMarkers();
        setState(() {});
        debugPrint('[NavIcon] ★ smoothedPos → Marker rebuilt at ${pos.latitude.toStringAsFixed(4)},${pos.longitude.toStringAsFixed(4)}');
        // ★ Blitzer neu laden für die echte GPS-Position (nicht PLZ)
        // Force reload: reset loading flag first to bypass guard
        _isLoadingReports = false;
        _loadReports();
        if (centerCamera) {
          _mapController?.animateCamera(CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(pos.latitude, pos.longitude),
              zoom: _is3D ? 18 : 15,
              bearing: _is3D ? _currentHeading : 0,
              tilt: _is3D ? 65 : 0,
            ),
          ));
        }
      } else if (!gpsPositionSet) {
        debugPrint('[Map] ★ No smoothedPos AND no lastKnown → blitzers not reloaded for GPS');
      }
    } catch (e) {
      debugPrint('[Map] GPS error: $e');
    }
  }

  /// GPS ausschalten und zurück zur PLZ-Position navigieren.
  void _stopGps() {
    if (!_gpsActive) return;
    debugPrint('[Map] _stopGps — returning to PLZ position');

    // GPS-Streams stoppen
    _bgLocationStream?.cancel();
    _bgLocationStream = null;
    _locationEngine?.stop();
    _locationEngine = null;

    // Stop heading follow
    _stopHeadingFollow();

    // SOS deaktivieren falls aktiv
    if (_sosActive) _deactivateSos();

    // ★ Live-Standort abmelden → andere User sehen mich nicht mehr (grünes Profilbild weg)
    final service = ref.read(liveLocationServiceProvider);
    if (service.isLive) {
      service.goOffline();
      ref.read(isLiveProvider.notifier).set(false);
      debugPrint('[Map] _stopGps: goOffline() → nicht mehr sichtbar für andere');
    }

    // Falls _plzPosition noch nicht gesetzt → Sync-Fallback
    if (_plzPosition == null) {
      final authState = ref.read(authNotifierProvider);
      if (authState is Authenticated) {
        final plz = authState.user.postalCode;
        if (plz != null && plz.isNotEmpty) {
          _plzPosition = _plzToCoordsSync(plz);
          debugPrint('[Map] _stopGps: PLZ sync fallback → $_plzPosition');
        }
      }
    }

    final targetPos = _plzPosition;
    debugPrint('[Map] _stopGps: centering on $targetPos (zoom: $_plzZoom)');

    setState(() {
      _gpsActive = false;
      if (targetPos != null) {
        _currentPosition = Position(
          latitude: targetPos.latitude,
          longitude: targetPos.longitude,
          timestamp: DateTime.now(), accuracy: 5000,
          altitude: 0, altitudeAccuracy: 0,
          heading: 0, headingAccuracy: 0,
          speed: 0, speedAccuracy: 0,
        );
      }
    });

    // Marker neu aufbauen (eigener PLZ-Marker erscheint wieder wenn GPS OFF)
    _loadCommunityUsers();
    _rebuildCachedMarkers();

    // ★ Kamera smooth zur PLZ-Position animieren + Bearing auf Nord (0°) zurücksetzen
    if (targetPos != null && _mapController != null) {
      debugPrint('[Map] _stopGps: animateCamera → ${targetPos.latitude}, ${targetPos.longitude} zoom=$_plzZoom, bearing=0');
      _mapController!.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(
          target: targetPos,
          zoom: _plzZoom,
          bearing: 0,  // ★ Karte zurück auf Nord drehen
          tilt: 0,     // ★ 3D-Neigung zurücksetzen
        ),
      ));
    } else {
      debugPrint('[Map] _stopGps: WARN targetPos=$targetPos, controller=$_mapController');
    }

    _registerSpeedDialItems();
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
          debugPrint('[Blitzer] Requesting OSM cameras at ${_currentPosition!.latitude.toStringAsFixed(4)},${_currentPosition!.longitude.toStringAsFixed(4)} gpsActive=$_gpsActive');
          final allCameras = await OsmBlitzerService.instance.getAllGermany();
          // Nur Blitzer im 5km Radius anzeigen
          final lat = _currentPosition!.latitude;
          final lon = _currentPosition!.longitude;
          final osmCameras = allCameras.where((c) =>
              OsmBlitzerService.distanceApprox(c.latitude, c.longitude, lat, lon) <= 5000).toList();
          osmReports = osmCameras.map((c) => BlitzerReport.fromOsm(c)).toList();
          debugPrint('[Blitzer] OSM: ${allCameras.length} total DE, ${osmCameras.length} within 5km');
        } catch (e) {
          debugPrint('[Blitzer] OSM load error: $e');
        }
      } else {
        debugPrint('[Blitzer] _currentPosition is null → skipping OSM load');
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

      // Don't overwrite existing reports with empty data (e.g. when screen is in background)
      if (merged.isEmpty && _reports.isNotEmpty) {
        debugPrint('[Blitzer] Poll returned 0 reports but we have ${_reports.length} — keeping existing');
        _isLoadingReports = false;
        return;
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
          opacity = 0.4; // > 10 km: faint but visible
        } else if (distM > 5000) {
          opacity = 0.55; // 5-10 km: semi-transparent
        } else if (distM > 2000) {
          opacity = 0.7; // 2-5 km: mostly visible
        } else if (distM > 500) {
          opacity = 0.85; // 500m-2km: clearly visible
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

    debugPrint('[Blitzer] Built ${markers.length} distance-based markers from ${_reports.length} reports');
    if (!_disposed && mounted) {
      _blitzerMarkers = markers;
      _rebuildCachedMarkers();
      debugPrint('[Blitzer] _cachedAllMarkers now has ${_cachedAllMarkers.length} total markers (${_blitzerMarkers.length} blitzer)');
      setState(() {});
    }
  }

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

  // ─── Community Users Sheet ──────────────────────────────────────────

  void _showCommunityUsersSheet(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final mutedColor = isDark ? Colors.white70 : Colors.black54;
    final accentColor = _cachedAccentColor;

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
              Text('$_communityUserCount Biker', style: GoogleFonts.inter(
                fontSize: 18, fontWeight: FontWeight.w700, color: textColor,
              )),
              const Spacer(),
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
                        setState(() { _selectedLiveUser = u; _showProfileBubble = false; });
                        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(u.lat, u.lng), 15));
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.green.withValues(alpha: 0.2),
                            backgroundImage: u.avatarUrl != null && u.avatarUrl!.isNotEmpty ? NetworkImage(u.avatarUrl!) : null,
                            child: u.avatarUrl == null || u.avatarUrl!.isEmpty
                                ? Text(u.displayName.isNotEmpty ? u.displayName[0].toUpperCase() : '?',
                                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.green))
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(u.displayName, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                              if (u.speed > 1)
                                Text('${u.speed.toStringAsFixed(0)} km/h', style: GoogleFonts.inter(fontSize: 11, color: Colors.green)),
                            ],
                          )),
                          const Icon(Icons.gps_fixed_rounded, size: 16, color: Colors.green),
                        ]),
                      ),
                    ),
                  Divider(height: 1, indent: 16, endIndent: 16, color: mutedColor.withValues(alpha: 0.1)),
                ],
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
                  for (final u in offlineUsers)
                    InkWell(
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        final lat = u['lat'] as double;
                        final lng = u['lng'] as double;
                        if (!_showCommunityUsers) {
                          setState(() => _showCommunityUsers = true);
                          _rebuildCachedMarkers();
                        }
                        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(lat, lng), 13));
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
                          Expanded(child: Text(
                            u['is_me'] == true
                                ? '${u['display_name'] ?? u['username'] ?? 'User'} (Du)'
                                : (u['display_name'] ?? u['username'] ?? 'User') as String,
                            style: GoogleFonts.inter(
                              fontSize: 14, fontWeight: FontWeight.w600,
                              color: u['is_me'] == true ? accentColor : textColor,
                            ),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          )),
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
            ),
          ),
        ]),
      ),
    );
  }

  // ─── Create Report Sheet ──────────────────────────────────────────────

  void _showCreateReportSheet() {
    ref.read(blitzerSpeedDialProvider.notifier).close();

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
    // Always black behind map — prevents beige bleed-through
    const scaffoldBg = Colors.black;

    final isLive = ref.watch(isLiveProvider);
    final liveCount = _liveUsers.length + (isLive ? 1 : 0);

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

    // ★ PLZ-Position hat Vorrang für initialCameraPosition (OFF-Start)
    final initialTarget = _plzPosition
        ?? (_currentPosition != null ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude) : _defaultCenter);
    final initialZoom = _plzPosition != null ? _plzZoom : (_currentPosition != null ? 15.0 : 6.0);

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Stack(
        children: [
          // ── Google Map (stable, no dynamic params) ──
          GoogleMap(
            key: const ValueKey('community_map'),
            initialCameraPosition: CameraPosition(target: initialTarget, zoom: initialZoom),
            onMapCreated: (c) {
              _mapController = c;
              debugPrint('[Map] onMapCreated: _plzPosition=$_plzPosition, _gpsActive=$_gpsActive');
              // ★ PLZ-Position IMMER setzen beim ersten Render
              // (Auto-Start nutzt centerCamera:false, bewegt Kamera nicht)
              if (_plzPosition != null) {
                debugPrint('[Map] onMapCreated: moveCamera → ${_plzPosition!.latitude}, ${_plzPosition!.longitude}');
                // Sofort
                try { _mapController!.moveCamera(CameraUpdate.newLatLngZoom(_plzPosition!, _plzZoom)); } catch (_) {}
                // Retry nach 300ms
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (mounted && !_disposed && _mapController != null) {
                    _mapController!.moveCamera(
                      CameraUpdate.newLatLngZoom(_plzPosition!, _plzZoom),
                    );
                  }
                });
              }
            },
            myLocationEnabled: _navMarkerIcon == null, // Blauer Punkt nur wenn Profil-Icon noch nicht geladen
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            markers: _cachedAllMarkers,
            polylines: const {},
            circles: _cachedDangerZones,
            mapType: _mapType,
            padding: EdgeInsets.only(
              bottom: 120 + MediaQuery.of(context).padding.bottom, // push Google logo behind bottom nav
            ),
            style: _darkMapStyle, // Always dark — matches app theme
            onCameraMoveStarted: () {
              // Detect user gesture (pan/zoom) — pause driving mode follow
              final drivingState = ref.read(drivingModeProvider);
              if (drivingState.isActive) {
                ref.read(drivingModeProvider.notifier).onUserPannedMap();
              }
              // Auto-hide UI on user interaction
              _mapIdleTimer?.cancel();
              if (!_isProgrammaticMove && !_mapInteracting) {
                setState(() => _mapInteracting = true);
              }
            },
            onCameraMove: (_) {
              // Keep hiding while user is still moving
              _mapIdleTimer?.cancel();
            },
            onCameraIdle: () {
              // Delay fade-in so UI doesn't flicker during multi-gesture
              _mapIdleTimer?.cancel();
              _mapIdleTimer = Timer(const Duration(milliseconds: 400), () {
                if (mounted && _mapInteracting) setState(() => _mapInteracting = false);
              });
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
          _buildPolicyBanner(accentColor, brightness),

          // ══════════════════════════════════════════════════════════════
          // PROFIL-BUBBLE — erscheint wenn man auf den Profil-Marker tippt
          // ══════════════════════════════════════════════════════════════
          if (_showProfileBubble && !_mapInteracting && ref.watch(authNotifierProvider) is Authenticated)
            MapProfileBubble(
              user: (ref.watch(authNotifierProvider) as Authenticated).user,
              accentColor: accentColor,
              totalLikes: _profileTotalLikes,
              onDismiss: () => setState(() => _showProfileBubble = false),
            ),

          // ══════════════════════════════════════════════════════════════
          // LIVE-USER BUBBLE — erscheint wenn man auf einen Live-User tippt
          // ══════════════════════════════════════════════════════════════
          if (_selectedLiveUser != null && !_mapInteracting)
            LiveUserBubble(
              user: _selectedLiveUser!,
              accentColor: accentColor,
              onDismiss: () => setState(() => _selectedLiveUser = null),
            ),

          // ══════════════════════════════════════════════════════════════
          // GROUP RIDE FILTER CHIP
          // ══════════════════════════════════════════════════════════════
          if (ref.read(liveLocationServiceProvider).activeGroupId != null)
            Positioned(
              bottom: 130 + MediaQuery.of(context).padding.bottom,
              left: 16,
              child: AnimatedOpacity(
                opacity: _mapInteracting ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(
                  ignoring: _mapInteracting,
                  child: FilterChip(
                    selected: _groupFilterActive,
                    avatar: Icon(
                      Icons.groups_rounded,
                      size: 16,
                      color: _groupFilterActive ? Colors.white : Colors.orange,
                    ),
                    label: Text(
                      _groupFilterActive ? 'Nur Gruppe' : 'Alle anzeigen',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _groupFilterActive ? Colors.white : null,
                      ),
                    ),
                    selectedColor: Colors.orange,
                    backgroundColor: Colors.black.withOpacity(0.6),
                    side: BorderSide(
                        color: _groupFilterActive
                            ? Colors.orange
                            : Colors.white.withOpacity(0.3)),
                    onSelected: (v) {
                      setState(() => _groupFilterActive = v);
                      // Re-filter live users
                      final service = ref.read(liveLocationServiceProvider);
                      final current = Map<String, LiveUserPosition>.from(
                          service.nearbyUsers);
                      _liveUsers = _filterLiveUsers(current);
                      _rebuildCachedMarkers();
                    },
                  ),
                ),
              ),
            ),

          // ══════════════════════════════════════════════════════════════
          // MAP BOTTOM BAR (Online, Gruppen, POIs, Melden)
          // ══════════════════════════════════════════════════════════════
          MapBottomBar(
            onlineCount: liveCount,
            isLive: isLive,
            accentColor: accentColor,
            mapInteracting: _mapInteracting,
            onOnlineTap: () => _showCommunityUsersSheet(brightness),
            onGroupsTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const GroupsListSheet(),
              );
            },
            onPoiTap: () {
              // TODO Phase 5: POI-Layer-Toggles öffnen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('POIs — kommt bald!')),
              );
            },
            onReportTap: _showCreateReportSheet,
          ),

          // ── GPS Toggle Button mit permanentem ON/OFF Badge ──
          Positioned(
            right: 16,
            bottom: 130 + MediaQuery.of(context).padding.bottom,
            child: AnimatedOpacity(
              opacity: _mapInteracting ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: _mapInteracting,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ON/OFF Badge — IMMER sichtbar
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _gpsActive ? Colors.blue : const Color(0xFFB71C1C),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: (_gpsActive ? Colors.blue : const Color(0xFFB71C1C)).withValues(alpha: 0.5),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        _gpsActive ? 'ON' : 'OFF',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    // GPS Button
                    _mapButton(
                      icon: _gpsActive ? Icons.my_location_rounded : Icons.location_searching_rounded,
                      color: _gpsActive ? Colors.blue : accentColor,
                      brightness: brightness,
                      onTap: () async {
                        if (_gpsActive) {
                          _stopGps();
                        } else {
                          // ★ Banner SOFORT zeigen (bevor GPS-Lock)
                          setState(() => _showVisibilityBanner = true);
                          Future.delayed(const Duration(seconds: 5), () {
                            if (mounted) setState(() => _showVisibilityBanner = false);
                          });

                          _isProgrammaticMove = true;
                          await _startGps();
                          if (!mounted) return;
                          // ★ Live gehen damit andere User mich sehen
                          final authState = ref.read(authNotifierProvider);
                          if (authState is Authenticated) {
                            await _startLiveWithStats(authState.user);
                            if (!mounted) return;
                            ref.read(isLiveProvider.notifier).set(true);
                          }
                          _registerSpeedDialItems();
                          if (_currentPosition != null) {
                            _mapController?.animateCamera(CameraUpdate.newCameraPosition(
                              CameraPosition(
                                target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                                zoom: 15.0,
                                bearing: 0,
                                tilt: 0,
                              ),
                            ));
                          }
                          Future.delayed(const Duration(milliseconds: 800), () => _isProgrammaticMove = false);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── SOS Button (Long-Press 3s) ──
          Positioned(
            left: 16,
            bottom: 180 + MediaQuery.of(context).padding.bottom,
            child: AnimatedOpacity(
              opacity: _mapInteracting ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: _mapInteracting,
                child: _buildSosButton(brightness),
              ),
            ),
          ),

          // ── Blitzer Alert Banner (ALWAYS visible) ──
          if (_blitzerWarning != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 60,
              left: 20, right: 20,
              child: BlitzerAlertBanner(warning: _blitzerWarning!),
            ),

          // ── "Hi Moto" Wake Word Indicator ──
          if (_wakeWordTriggered)
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: accentColor.withValues(alpha: 0.5), blurRadius: 16),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.mic, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text('Moto hört zu...', style: GoogleFonts.inter(
                        color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600,
                      )),
                    ],
                  ),
                ),
              ),
            ),

          // ── Visibility Banner (zentriert, Tap zum Schließen) ──
          if (_showVisibilityBanner)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _showVisibilityBanner = false),
                behavior: HitTestBehavior.translucent,
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade700,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withValues(alpha: 0.4),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.visibility_rounded, color: Colors.white, size: 36),
                        const SizedBox(height: 12),
                        Text(
                          'Du bist jetzt sichtbar!',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Alle User können deinen Standort sehen,\nsolange GPS auf ON steht.',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Tippen zum Schließen',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
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

  // ─── SOS Button + Logic ───────────────────────────────────────────────

  Widget _buildSosButton(Brightness brightness) {
    final bgColor = brightness == Brightness.dark
        ? Colors.black.withValues(alpha: 0.75)
        : Colors.white.withValues(alpha: 0.92);

    if (_sosActive) {
      // SOS aktiv → pulsierender roter Button, Tap zum Deaktivieren
      return GestureDetector(
        onTap: _showDeactivateSosDialog,
        child: AnimatedOpacity(
          opacity: _sosBlinkVisible ? 1.0 : 0.4,
          duration: const Duration(milliseconds: 300),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.red.shade700,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.red.withValues(alpha: 0.5), blurRadius: 12, spreadRadius: 2),
              ],
            ),
            child: const Center(
              child: Icon(Icons.sos, color: Colors.white, size: 24),
            ),
          ),
        ),
      );
    }

    // SOS inaktiv → Long-Press zum Aktivieren
    return _SosLongPressButton(
      brightness: brightness,
      bgColor: bgColor,
      onSosActivated: _activateSos,
    );
  }

  void _activateSos() {
    if (_disposed || !mounted) return;
    HapticFeedback.heavyImpact();

    // SOS-Alarmton abspielen
    AlertAudioService.instance.playSosAlarm();

    setState(() {
      _sosActive = true;
      _sosBlinkVisible = true;
    });

    // SOS-Icon für eigenen User vorladen
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId != null && !_sosUserIcons.containsKey(currentUserId)) {
      final authState = ref.read(authNotifierProvider);
      final avatarUrl = authState is Authenticated ? authState.user.avatarUrl : null;
      final displayName = authState is Authenticated ? authState.user.displayName : null;
      _getSosUserMarkerIcon(avatarUrl: avatarUrl, displayName: displayName ?? '?').then((icon) {
        if (mounted && !_disposed) {
          _sosUserIcons[currentUserId] = icon;
        }
      });
    }

    // Blink-Timer starten (500ms toggle)
    _sosBlinkTimer?.cancel();
    _sosBlinkTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted || _disposed) {
        _sosBlinkTimer?.cancel();
        return;
      }
      _sosBlinkVisible = !_sosBlinkVisible;
      _rebuildCachedMarkers();
      setState(() {});
    });

    // SOS über Presence broadcasten
    try {
      ref.read(liveLocationServiceProvider).setSosActive(true);
    } catch (e) {
      debugPrint('[Map] SOS broadcast error: $e');
    }

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.sos, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('SOS gesendet! Andere Biker sehen deinen Standort.',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _deactivateSos() {
    _sosBlinkTimer?.cancel();
    _sosBlinkTimer = null;

    if (mounted) {
      setState(() {
        _sosActive = false;
        _sosBlinkVisible = true;
      });
    }

    // SOS-Status über Presence zurücksetzen
    try {
      ref.read(liveLocationServiceProvider).setSosActive(false);
    } catch (e) {
      debugPrint('[Map] SOS deactivate broadcast error: $e');
    }
  }

  void _showDeactivateSosDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('SOS deaktivieren?'),
        content: const Text('Möchtest du den SOS-Alarm beenden?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _deactivateSos();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('SOS deaktiviert'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('SOS beenden'),
          ),
        ],
      ),
    );
  }

  // _buildLiveUserBubble → extracted to widgets/live_user_bubble.dart
  // _buildProfileBubble → extracted to widgets/map_profile_bubble.dart

  void _toggle3D() {
    if (_disposed || !mounted) return;
    setState(() => _is3D = !_is3D);
    _registerSpeedDialItems(); // Update labels
    // Camera zoom/tilt adapts automatically in heading follow timer
    // Auto-switch to satellite in 3D for better topography
    if (_is3D && _mapType == MapType.normal) {
      setState(() => _mapType = MapType.hybrid);
    }
  }

  /// Start continuous heading rotation (compass-based map bearing).
  /// Uses HeadingSensorService with gyro+magnetometer fusion for smooth rotation.
  /// Creates a dedicated high-frequency GPS stream (distanceFilter: 1m) for heading.
  void _startHeadingFollow() {
    if (_headingFollowActive) return;
    _headingFollowActive = true;

    // Start sensor fusion (gyro + magnetometer)
    final headingService = HeadingSensorService.instance;
    headingService.start();
    _headingSub = headingService.headingStream.listen((heading) {
      _currentHeading = heading;
    });

    // High-frequency GPS stream for heading data (1m filter = fast updates)
    _headingGpsSub?.cancel();
    _headingGpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1,
      ),
    ).listen((pos) {
      if (_disposed || !mounted) return;
      final speedKmh = pos.speed * 3.6;
      HeadingSensorService.instance.updateFromGps(
        gpsHeading: pos.heading,
        speedKmh: speedKmh,
      );
      // Update position for camera target
      _currentPosition = pos;
    });

    // 30fps camera rotation timer
    _headingFollowTimer?.cancel();
    _headingFollowTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (_disposed || !mounted || !_gpsActive) return;
      if (_mapController == null || _currentPosition == null) return;

      final heading = HeadingSensorService.instance.isGyroAvailable
          ? _currentHeading
          : (_currentPosition!.heading >= 0 ? _currentPosition!.heading : _currentHeading);

      _isProgrammaticMove = true;
      _mapController!.moveCamera(CameraUpdate.newCameraPosition(CameraPosition(
        target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        zoom: _is3D ? 18 : 16,
        tilt: _is3D ? 65 : 30,
        bearing: heading,
      )));
      _isProgrammaticMove = false;
    });
    debugPrint('[Map] Heading follow started (3D compass rotation)');
  }

  /// Stop heading follow and reset to north-up.
  void _stopHeadingFollow() {
    _headingFollowActive = false;
    _headingFollowTimer?.cancel();
    _headingFollowTimer = null;
    _headingSub?.cancel();
    _headingSub = null;
    _headingGpsSub?.cancel();
    _headingGpsSub = null;
    HeadingSensorService.instance.stop();
    _isProgrammaticMove = false;
    debugPrint('[Map] Heading follow stopped');
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
  static const String _darkMapStyle = '''[
    {"elementType":"geometry","stylers":[{"color":"#1d2c4d"}]},
    {"elementType":"labels.text.fill","stylers":[{"color":"#8ec3b9"}]},
    {"elementType":"labels.text.stroke","stylers":[{"color":"#1a3646"}]},
    {"featureType":"administrative.country","elementType":"geometry.stroke","stylers":[{"color":"#4b6878"}]},
    {"featureType":"administrative.land_parcel","elementType":"labels.text.fill","stylers":[{"color":"#64779e"}]},
    {"featureType":"administrative.province","elementType":"geometry.stroke","stylers":[{"color":"#4b6878"}]},
    {"featureType":"landscape.man_made","elementType":"geometry.stroke","stylers":[{"color":"#334e87"}]},
    {"featureType":"landscape.natural","elementType":"geometry","stylers":[{"color":"#023e58"}]},
    {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#283d6a"}]},
    {"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#6f9ba5"}]},
    {"featureType":"poi","elementType":"labels.text.stroke","stylers":[{"color":"#1d2c4d"}]},
    {"featureType":"poi.park","elementType":"geometry.fill","stylers":[{"color":"#023e58"}]},
    {"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#3C7680"}]},
    {"featureType":"road","elementType":"geometry","stylers":[{"color":"#304a7d"}]},
    {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#98a5be"}]},
    {"featureType":"road","elementType":"labels.text.stroke","stylers":[{"color":"#1d2c4d"}]},
    {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#2c6675"}]},
    {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#255763"}]},
    {"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#b0d5ce"}]},
    {"featureType":"road.highway","elementType":"labels.text.stroke","stylers":[{"color":"#023e58"}]},
    {"featureType":"transit","elementType":"labels.text.fill","stylers":[{"color":"#98a5be"}]},
    {"featureType":"transit","elementType":"labels.text.stroke","stylers":[{"color":"#1d2c4d"}]},
    {"featureType":"transit.line","elementType":"geometry.fill","stylers":[{"color":"#283d6a"}]},
    {"featureType":"transit.station","elementType":"geometry","stylers":[{"color":"#3a4762"}]},
    {"featureType":"water","elementType":"geometry","stylers":[{"color":"#0e1626"}]},
    {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#4e6d70"}]}
  ]''';

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

  // ═══════════════════════════════════════════════════
  //  VOSK WAKE WORD — "Hi Moto" voice assistant
  // ═══════════════════════════════════════════════════

  Future<void> _initVoskWakeWord() async {
    final vosk = VoskWakeWordService.instance;
    final ok = await vosk.init();
    if (!ok || !mounted) return;
    _voskInitialized = true;

    vosk.onEvent = (event, text) {
      if (!mounted || _disposed) return;
      switch (event) {
        case VoskWakeEvent.wakeWordDetected:
          debugPrint('[MapVosk] Wake word!');
          HapticFeedback.heavyImpact();
          setState(() {
            _wakeWordTriggered = true;
            _wakeWordActive = true;
          });
          VoskWakeWordService.instance.setPaused(true);
          TtsAlertService.instance.speakText('Ja Racer?').then((_) async {
            await Future.delayed(const Duration(milliseconds: 1200));
            if (mounted) VoskWakeWordService.instance.setPaused(false);
          });
          break;
        case VoskWakeEvent.commandRecognized:
          debugPrint('[MapVosk] Command: "$text"');
          setState(() => _wakeWordTriggered = false);
          _processMapVoiceCommand(text);
          break;
        case VoskWakeEvent.commandTimeout:
          debugPrint('[MapVosk] Timeout');
          setState(() => _wakeWordTriggered = false);
          break;
      }
    };

    await vosk.startListening();
    if (mounted) {
      setState(() => _wakeWordActive = true);
      debugPrint('[MapVosk] Listening — say "Hi Moto"!');
    }
  }

  void _mapSpeakWithVoskPause(String text, {bool priority = false}) {
    VoskWakeWordService.instance.setPaused(true);
    final speak = priority
        ? TtsAlertService.instance.speakPriority(text)
        : TtsAlertService.instance.speakText(text);
    speak.then((_) async {
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) VoskWakeWordService.instance.setPaused(false);
    });
  }

  Future<void> _processMapVoiceCommand(String text) async {
    final command = VoiceCommandService.parse(text);
    switch (command.intent) {
      case VoiceIntent.searchPoi:
        final label = command.poiLabel ?? text;
        _mapSpeakWithVoskPause('Suche nach $label in der Nähe...');
        break;
      case VoiceIntent.reportBlitzer:
        if (_currentPosition != null) {
          _mapSpeakWithVoskPause('Warnung melden! Öffne Meldedialog.');
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (mounted) _showCreateReportSheet();
          });
        } else {
          _mapSpeakWithVoskPause('Kein GPS Signal für eine Meldung.');
        }
        break;
      case VoiceIntent.showBlitzer:
        _announceMapBlitzers();
        break;
      case VoiceIntent.toggleCamera:
      case VoiceIntent.toggleMic:
      case VoiceIntent.endRide:
        _mapSpeakWithVoskPause('Das geht nur während einer Gruppenfahrt, Racer.');
        break;
      case VoiceIntent.activateSos:
        if (!_sosActive) {
          _activateSos();
          _mapSpeakWithVoskPause('SOS aktiviert! Alle werden benachrichtigt.');
        } else {
          _mapSpeakWithVoskPause('SOS ist bereits aktiv.');
        }
        break;
      case VoiceIntent.stopNavigation:
        _mapSpeakWithVoskPause('Keine Navigation aktiv auf der Karte.');
        break;
      case VoiceIntent.aiQuery:
        VoskWakeWordService.instance.setPaused(true);
        try {
          final fastAnswer = await FastAnswerService.instance.tryAnswer(
            query: command.query ?? text,
            lat: _currentPosition?.latitude ?? 0,
            lon: _currentPosition?.longitude ?? 0,
            speedKmh: _currentPosition?.speed ?? 0,
            heading: _currentPosition?.heading ?? 0,
            isNavigating: false,
          );
          if (fastAnswer != null) {
            debugPrint('[MapVosk] FAST ANSWER: $fastAnswer');
            await TtsAlertService.instance.speakPriority(fastAnswer);
          } else {
            TtsAlertService.instance.speakText('Moment...');
            final aiResponse = await BikerAiService.instance.query(
              text: command.query ?? text,
              lat: _currentPosition?.latitude ?? 0,
              lon: _currentPosition?.longitude ?? 0,
              speed: (_currentPosition?.speed ?? 0) * 3.6,
              heading: _currentPosition?.heading ?? 0,
              isNavigating: false,
            );
            if (aiResponse != null) {
              await TtsAlertService.instance.speakPriority(aiResponse.response);
            } else {
              await TtsAlertService.instance.speakText('Entschuldigung, versuche es nochmal.');
            }
          }
        } catch (e) {
          debugPrint('[MapVosk] AI error: $e');
          await TtsAlertService.instance.speakText('Entschuldigung, ich konnte das nicht beantworten.');
        } finally {
          await Future.delayed(const Duration(milliseconds: 1500));
          if (mounted) VoskWakeWordService.instance.setPaused(false);
        }
        break;
      case VoiceIntent.unknown:
        debugPrint('[MapVosk] Unknown: "$text"');
        break;
    }
  }

  void _announceMapBlitzers() {
    VoskWakeWordService.instance.setPaused(true);
    if (_currentPosition == null) {
      TtsAlertService.instance.speakText('Kein GPS Signal.').then((_) async {
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) VoskWakeWordService.instance.setPaused(false);
      });
      return;
    }
    if (_reports.isEmpty) {
      TtsAlertService.instance.speakPriority(
        'Keine Sorge Racer, aktuell sind keine Warnungen in der Nähe bekannt. '
        'Ich melde dir automatisch alles auf der Strecke!',
      ).then((_) async {
        await Future.delayed(const Duration(milliseconds: 3000));
        if (mounted) VoskWakeWordService.instance.setPaused(false);
      });
      return;
    }
    final lat = _currentPosition!.latitude;
    final lon = _currentPosition!.longitude;
    final withDist = _reports.map((b) {
      final d = Geolocator.distanceBetween(lat, lon, b.latitude, b.longitude);
      return (report: b, distance: d);
    }).toList()..sort((a, b) => a.distance.compareTo(b.distance));
    final top3 = withDist.take(3).toList();
    String distShort(double m) => m < 1000
        ? '${(m / 100).round() * 100} Meter'
        : '${(m / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
    String typeLabel(String type) => switch (type) {
      'fixed' => 'Feste Radarfalle',
      'mobile' => 'Mobile Kontrolle',
      'police' => 'Polizeikontrolle',
      _ => 'Warnung',
    };
    final ttsItems = <String>[];
    for (int i = 0; i < top3.length; i++) {
      final b = top3[i];
      ttsItems.add('${i + 1}: ${typeLabel(b.report.type)} in ${distShort(b.distance)}');
    }
    final tts = 'Hier die nächsten ${top3.length} Warnungen: '
        '${ttsItems.join('. ')}. Ride on!';
    TtsAlertService.instance.speakPriority(tts);
    int polls = 0;
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      polls++;
      if (!mounted || _disposed || polls > 40) {
        timer.cancel();
        VoskWakeWordService.instance.setPaused(false);
        return;
      }
      if (!TtsAlertService.instance.isSpeaking) {
        timer.cancel();
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) VoskWakeWordService.instance.setPaused(false);
        });
      }
    });
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// MAP PROFILE AVATAR — always visible on community map, links to profile
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


// _BlitzerAlertBanner → extracted to widgets/blitzer_alert_banner.dart

/// SOS Long-Press Button mit kreisförmigem Progress-Ring (3 Sekunden).
/// Eigenes StatefulWidget wegen AnimationController (braucht TickerProvider).
class _SosLongPressButton extends StatefulWidget {
  final Brightness brightness;
  final Color bgColor;
  final VoidCallback onSosActivated;

  const _SosLongPressButton({
    required this.brightness,
    required this.bgColor,
    required this.onSosActivated,
  });

  @override
  State<_SosLongPressButton> createState() => _SosLongPressButtonState();
}

class _SosLongPressButtonState extends State<_SosLongPressButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _pressing = false;

  static const _sosHoldDuration = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _sosHoldDuration,
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // 3 Sekunden gehalten → SOS auslösen!
        setState(() => _pressing = false);
        _controller.reset();
        widget.onSosActivated();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPressStart() {
    setState(() => _pressing = true);
    HapticFeedback.mediumImpact();
    _controller.forward(from: 0);
  }

  void _onPressEnd() {
    if (_pressing) {
      setState(() => _pressing = false);
      _controller.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => _onPressStart(),
      onLongPressEnd: (_) => _onPressEnd(),
      onLongPressCancel: _onPressEnd,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _pressing
                  ? Colors.red.shade700.withValues(alpha: 0.15)
                  : widget.bgColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: widget.brightness == Brightness.light
                  ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2))]
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Progress-Ring während Long-Press
                if (_pressing)
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      value: _controller.value,
                      strokeWidth: 3,
                      color: Colors.red.shade700,
                      backgroundColor: Colors.red.shade100.withValues(alpha: 0.3),
                    ),
                  ),
                // SOS Icon
                Icon(
                  Icons.sos,
                  color: _pressing ? Colors.red.shade700 : Colors.red.shade400,
                  size: 22,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}


