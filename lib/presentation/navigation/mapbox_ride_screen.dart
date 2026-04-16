import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../feed/widgets/create_post_sheet.dart';
import '../../core/community.dart';
import '../../providers/auth/auth_notifier.dart';
import '../../providers/auth/auth_state.dart';
import '../../providers/core/providers.dart';
import '../../providers/map/live_location_provider.dart';
import '../../providers/navigation_state.dart';
import '../../services/live_location_service.dart';
import '../../data/repositories/blitzer_repository.dart';
import '../../services/blitzer_alert_service.dart';
import '../../services/destination_info_service.dart';
import '../../services/geocoding_service.dart';
import '../../services/osm_blitzer_service.dart';
import '../../services/osrm_service.dart';
import '../../services/here_speed_limit_service.dart';
import '../../services/speed_limit_service.dart';
import '../../services/tts_alert_service.dart';
import '../../services/voice_command_service.dart';
import '../../services/vosk_wake_word_service.dart';
import '../../services/poi_search_service.dart';
import '../../data/repositories/ride_repository.dart';
import '../../providers/map/map_settings_provider.dart';
import '../../core/api_config.dart';
import '../widgets/bug_report_sheet.dart';
import '../widgets/online_status_avatar.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

// Token moved to ApiConfig to avoid secret-scanning blocks.
String get _mapboxToken => ApiConfig.mapboxPublicToken;

/// Full Mapbox ride screen — replaces GroupRideScreen's map.
/// Includes: Map, Search, Route Preview, Navigation, Blitzer, Hi Moto, Speed.
class MapboxRideScreen extends ConsumerStatefulWidget {
  final int? groupId; // null = Freie Fahrt (Solo), set = Gruppen-Modus
  const MapboxRideScreen({super.key, this.groupId});

  /// Globaler Notifier: Wenn gesetzt, fliegt die Karte beim nächsten Frame zum POI.
  /// Wird von message_bubble.dart (Location-Tap) gesetzt.
  static ValueNotifier<({double lat, double lon, String name, String type})?> pendingPoiFlyTo = ValueNotifier(null);

  @override
  ConsumerState<MapboxRideScreen> createState() => _MapboxRideScreenState();
}

class _MapboxRideScreenState extends ConsumerState<MapboxRideScreen>
    with TickerProviderStateMixin {
  // ── Theme helpers ──
  bool _lastIsDark = true; // cached to survive deactivation
  bool get _isDark {
    if (!mounted) return _lastIsDark;
    final v = Theme.of(context).brightness == Brightness.dark;
    _lastIsDark = v;
    return v;
  }
  Color get _cardBg => _isDark ? const Color(0xF0111111) : const Color(0xF0FFFFFF);
  Color get _cardBorder => _isDark ? Colors.white10 : Colors.black12;
  Color get _textPrimary => _isDark ? Colors.white : Colors.black87;
  Color get _textSecondary => _isDark ? Colors.white70 : Colors.black54;
  Color get _textMuted => _isDark ? Colors.white38 : Colors.black38;
  Color get _iconMuted => _isDark ? Colors.white54 : Colors.black45;
  Color get _iconFaint => _isDark ? Colors.white24 : Colors.black26;
  Color get _dividerColor => _isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.08);
  Color get _shadowColor => _isDark ? Colors.black.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.15);
  Color get _bubbleBg => _isDark ? const Color(0xFF1B1F2B) : Colors.white;

  /// Dynamic top padding — pushes puck to bottom (Waze-style).
  /// Cached after first build, used in async methods like _onMapCreated.
  double _cachedPuckPad = 600;

  MapboxMap? _mapboxMap;
  StreamSubscription<geo.Position>? _positionSub;
  Timer? _followTimer;
  Timer? _speedLimitTimer;

  // ── Map Tutorial ──
  bool _tutorialActive = false;
  int _tutorialStep = 0; // 0 = Home-Puck, 1 = GPS Toggle, 2 = POIs
  Timer? _tutorialAutoTimer;
  late final AnimationController _tutorialAnimCtrl;

  // ── GPS ──
  double _lat = 51.0, _lng = 7.0, _speed = 0, _heading = 0;
  double _displaySpeed = 0; // EMA-smoothed speed for display
  bool _gpsReady = false;
  double? _plzLat, _plzLng; // PLZ fallback position

  // ── Zuhause-Button Pulse (neue User) ──
  bool _homeSaved = true; // assume saved, flip in _checkHomeSaved()

  // ── Search ──
  bool _searchOpen = false;
  bool _recentScrolling = false;
  bool _searchDropdownOpen = false;
  bool _searchPanelHidden = true; // Default: eingeklappt, nur schmale Bar
  Timer? _resumeFollowTimer;
  int _activePointers = 0; // Track multi-touch for zoom gestures
  final _searchController = TextEditingController();
  List<GeocodingResult> _searchResults = [];
  List<Map<String, dynamic>> _searchHistory = [];
  Timer? _searchDebounce;
  final _geocoding = GeocodingService();

  // ── Route ──
  RouteMode _routeMode = RouteMode.biker;
  OsrmRoute? _currentRoute;
  List<OsrmRoute> _allRoutes = [];
  int _selectedRouteIdx = 0;
  List<LatLng> _routePoints = [];
  bool _isCalculating = false;
  LatLng? _destination;
  String? _destName;

  // ── Navigation ──
  bool _isNavigating = false;
  bool _arrivalAnnounced = false;
  bool _pedestrianSpeedWarned = false;
  double _debugZoomOverride = 0; // 0 = auto, >0 = manual override
  bool _isFollowing = true;
  int _compassIdx = 0; // 0=N, 1=O, 2=S, 3=W — shows which direction is UP on screen
  static const _compassLabels = ['N', 'O', 'S', 'W'];
  static const _compassBearings = [180.0, 270.0, 0.0, 90.0];
  bool _is3D = false; // 2D (top-down) vs 3D (perspective)
  int _soundMode = 2; // 0=stumm, 1=nur Warnungen, 2=alle Töne
  bool _puckBearingOn = true; // Puck bearing (disabled when stopped to prevent jitter)
  int _currentStepIndex = 0;
  final Set<String> _announcedThresholds = {};
  String _lastTtsInstruction = '';
  DateTime _lastTtsTime = DateTime(2000);
  String? _nextInstruction;
  String? _currentManeuver;
  String? _currentStepRef;      // Road reference for badge (A 3, B 229)
  String? _currentDestinations; // Exit destinations
  double _remainingDistKm = 0;
  int _remainingMin = 0;
  double _distToManeuver = 9999; // Meters to next maneuver point

  // ── Off-route ──
  int _offRouteCount = 0;
  bool _isRerouting = false;
  DateTime? _lastRerouteAt;
  static const Duration _rerouteCooldown = Duration(seconds: 10);

  // ── GPS signal ──
  DateTime _lastGpsTime = DateTime.now();
  bool get _gpsLost => DateTime.now().difference(_lastGpsTime).inSeconds > 15;

  // ── Speed limit ──
  int? _speedLimit;
  bool _isSpeeding = false;
  DateTime _lastSpeedWarning = DateTime(2000); // Cooldown for speed warnings
  String? _roadName;

  // ── Blitzer ──
  List<BlitzerReport> _blitzerReports = [];
  int _routeBlitzerCount = 0; // Blitzer along the calculated route
  String? _blitzerWarning;
  bool _blitzerLoaded = false;
  final _blitzerAlertService = BlitzerAlertService();

  // ── Hi Moto ──
  bool _hiMotoActive = false;
  String? _hiMotoFeedback;
  // Tappable voice option buttons (shown as overlay when Hi Moto asks a question)
  List<(String label, VoidCallback onTap)> _voiceButtons = [];
  // POI selection popup state
  List<Map<String, dynamic>> _poiPopupItems = [];
  String _poiPopupTitle = '';
  void Function(VoskWakeEvent, String)? _prevVoskHandler;

  // ── Destination Info ──
  DestinationInfo? _destInfo;

  // ── POI ──
  Map<String, List<PoiResult>> _poiResults = {};
  String? _activePoiCategory; // currently shown POI layer
  bool _poiLoading = false;
  String? _poiError;          // shown as overlay pill (auto-dismiss)
  Timer? _poiErrorTimer;
  PoiResult? _highlightedPoi; // pulsing ring on map
  Timer? _highlightTimer;
  DateTime? _lastPoiNetworkError; // cooldown after network failure

  // ── Ride Distance Tracking (for KM stats) ──
  double _totalDrivenMeters = 0;
  double _prevLat = 0, _prevLng = 0;
  DateTime? _rideStartedAt;

  // ── GPS Live Toggle ──
  bool _gpsLive = false; // Is the user broadcasting GPS to others?

  // ── Live Users on Map ──
  PointAnnotationManager? _userAnnotationManager;
  StreamSubscription<Map<String, LiveUserPosition>>? _liveUsersSub;
  final Map<String, Uint8List> _userIconCache = {}; // userId → PNG bytes
  final Map<String, String> _markerUserIdMap = {}; // annotationId → userId

  // ── PLZ Home Marker ──
  PointAnnotationManager? _plzAnnotationManager;

  // ── Services ──
  final _osrm = OsrmService();

  @override
  void initState() {
    super.initState();
    MapboxOptions.setAccessToken(_mapboxToken);
    WakelockPlus.enable();
    // POI FlyTo Listener (aus Chat Location-Nachrichten)
    MapboxRideScreen.pendingPoiFlyTo.addListener(_onPendingPoiFlyTo);
    // Tutorial animation controller (bouncing arrow)
    _tutorialAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _checkMapTutorial();
    // Sync route mode from global state (set by community switch)
    _routeMode = NavigationState.instance.routeMode;
    NavigationState.instance.addListener(_onGlobalModeChanged);
    _initHiMoto();
    _loadSearchHistory();
    _checkHomeSaved();
    // ★ Respect global service state (MainShell may have started goLive)
    final liveSvc = ref.read(liveLocationServiceProvider);
    _gpsLive = liveSvc.isLive;
    if (_gpsLive) {
      // Already live (started by MainShell or previous toggle) — keep it
      Future(() => ref.read(isLiveProvider.notifier).set(true));
      debugPrint('[Map] GPS already live from global service — keeping');
    } else {
      // Start listen-only mode to see other online users even with GPS OFF
      final authState = ref.read(authNotifierProvider);
      if (authState is Authenticated && !liveSvc.isListening) {
        liveSvc.startListening(userId: authState.user.id);
      }
    }
    // GPS stream always runs (needed for navigation, speed, etc.)
    _initGps();
    // Map starts at PLZ (GPS OFF) or at real position (GPS ON)
    if (!_gpsLive) {
      _initPlzPosition();
    }
  }

  void _onGlobalModeChanged() {
    if (!mounted) return;
    final globalMode = NavigationState.instance.routeMode;
    debugPrint('[MapboxRide] Global mode changed: $globalMode (local: $_routeMode)');
    if (globalMode != _routeMode) {
      setState(() => _routeMode = globalMode);
      _updatePuckColor();
      // Re-register icon with new vehicle shape
      _navPuckIconRegistered = false;
      _applyCustomPuck();
    }
  }

  /// TTS wrapper: only speaks if sound mode allows it.
  /// [isWarning] = true for blitzer/police alerts, false for nav turn instructions.
  void _ttsSpeak(String text, {bool isWarning = false, bool priority = false}) {
    if (_soundMode == 0) return; // Stumm
    if (_soundMode == 1 && !isWarning) return; // Nur Warnungen — skip nav sounds
    if (priority) {
      TtsAlertService.instance.speakPriority(text);
    } else {
      TtsAlertService.instance.speakQueued(text);
    }
  }

  @override
  // ── Map Tutorial (Onboarding) ──

  Future<void> _checkMapTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('map_tutorial_v2_seen') ?? false;
    debugPrint('[Tutorial] check: seen=$seen, gpsLive=$_gpsLive, mounted=$mounted');
    if (!seen && !_gpsLive && mounted) {
      // Wait for map to load before showing tutorial
      Future.delayed(const Duration(seconds: 2), () {
        debugPrint('[Tutorial] delayed: mounted=$mounted, isNav=$_isNavigating, gpsLive=$_gpsLive');
        if (mounted && !_isNavigating && !_gpsLive) {
          debugPrint('[Tutorial] ✓ Activating tutorial!');
          setState(() {
            _tutorialActive = true;
            _tutorialStep = 0;
          });
        }
      });
    }
  }

  void _startTutorialAutoAdvance() {
    // No auto-advance — user must tap "Weiter" or "Nicht mehr anzeigen"
  }

  void _nextTutorialStep() {
    if (_tutorialStep < 2) {
      setState(() => _tutorialStep++);
    } else {
      // User completed all steps → mark as seen permanently
      _dismissTutorial(neverShow: true);
    }
  }

  void _dismissTutorial({required bool neverShow}) async {
    _tutorialAutoTimer?.cancel();
    if (mounted) setState(() => _tutorialActive = false);
    if (neverShow) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('map_tutorial_v2_seen', true);
    }
  }

  Widget _buildTutorialOverlay() {
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    final bp = MediaQuery.of(context).padding.bottom;
    final tp = MediaQuery.of(context).padding.top;

    // GPS toggle position: right column at right:12, bottom:(50+bp)
    // GPS is last in column (bottom element) → its center Y from screen bottom:
    // column bottom: 50 + bp, GPS height: 72, center = 50 + bp + 36
    final gpsBottomCenter = 50.0 + bp + 36;

    // Tutorial content per step
    final titles = [
      'Das ist dein Zuhause',
      'GPS Live-Position',
      'POIs in der Nähe',
    ];
    final subtitles = [
      'Deine Position basierend auf deiner PLZ.',
      'Damit wird deine tatsächliche Position\ngezeigt. Alle User können dich sehen!',
      'Aktiviere zuerst GPS, damit POIs\nan deinem Standort angezeigt werden!',
    ];
    final buttonLabel = _tutorialStep < 2 ? 'Weiter' : 'Verstanden';
    // Steps 0+1: text top, arrow bottom. Step 2: arrow top, text bottom.
    final textOnTop = _tutorialStep <= 1;

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {}, // Block taps on background, only buttons work
        child: Container(
          color: Colors.black.withValues(alpha: 0.55),
          child: Stack(children: [
            // ── Text bubble + Controls (TOP for steps 0-1, BOTTOM for step 2) ──
            Positioned(
              left: 24, right: 24,
              top: textOnTop ? tp + 70 : null,
              bottom: textOnTop ? null : bp + 90,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _tutorialBubble(titles[_tutorialStep], subtitles[_tutorialStep]),
                const SizedBox(height: 14),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _tutorialDot(0),
                  const SizedBox(width: 8),
                  _tutorialDot(1),
                  const SizedBox(width: 8),
                  _tutorialDot(2),
                ]),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _modeColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _nextTutorialStep,
                    child: Text(buttonLabel,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _dismissTutorial(neverShow: true),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text('Nicht mehr anzeigen',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5), fontSize: 13,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.white.withValues(alpha: 0.5),
                      )),
                  ),
                ),
              ]),
            ),

            // ── Step 0: Bouncing arrow ↓ → PLZ home marker ──
            if (_tutorialStep == 0)
              Positioned(
                left: screenW / 2 - 24,
                bottom: bp + 120,
                child: AnimatedBuilder(
                  animation: _tutorialAnimCtrl,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(0, _tutorialAnimCtrl.value * 18),
                    child: child,
                  ),
                  child: Icon(Icons.keyboard_double_arrow_down_rounded,
                    color: _modeColor, size: 48,
                    shadows: const [Shadow(color: Colors.black87, blurRadius: 16)]),
                ),
              ),

            // ── Step 1: Bouncing arrow → → GPS toggle ──
            if (_tutorialStep == 1)
              Positioned(
                right: 70,
                bottom: gpsBottomCenter - 30,
                child: AnimatedBuilder(
                  animation: _tutorialAnimCtrl,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(_tutorialAnimCtrl.value * 14, 0),
                    child: child,
                  ),
                  child: const Icon(Icons.keyboard_double_arrow_right_rounded,
                    color: Colors.greenAccent, size: 48,
                    shadows: [Shadow(color: Colors.black87, blurRadius: 16)]),
                ),
              ),

            // ── Step 2: Bouncing arrow ↑ → POIs button (search panel, 3rd button) ──
            // POIs button: in quick-nav row, 3rd of 4 items, ~55% from left
            if (_tutorialStep == 2)
              Positioned(
                left: screenW * 0.52,
                top: tp + 155,
                child: AnimatedBuilder(
                  animation: _tutorialAnimCtrl,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(0, -_tutorialAnimCtrl.value * 16),
                    child: child,
                  ),
                  child: Icon(Icons.keyboard_double_arrow_up_rounded,
                    color: Colors.orangeAccent, size: 48,
                    shadows: const [Shadow(color: Colors.black87, blurRadius: 16)]),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _tutorialBubble(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xF0111111),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _modeColor.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 20),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(title, style: const TextStyle(
          color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold,
        )),
        const SizedBox(height: 6),
        Text(subtitle, style: const TextStyle(
          color: Colors.white70, fontSize: 14, height: 1.4,
        )),
      ]),
    );
  }

  String _poiCategoryLabel(String? id) => switch (id) {
    'fuel' => 'Tankstellen',
    'workshop' => 'Werkstätten',
    'biker_shop' => 'Biker Shops',
    'auto_shop' => 'Auto Shops',
    'restaurant' => 'Restaurants',
    'cafe' => 'Cafés',
    'bank' => 'Banken',
    'hospital' => 'Krankenhäuser',
    'grocery' => 'Lebensmittel',
    'pharmacy' => 'Apotheken',
    _ => 'POIs',
  };

  Widget _tutorialDot(int step) {
    final active = _tutorialStep == step;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: active ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: active ? _modeColor : Colors.white30,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  void dispose() {
    MapboxRideScreen.pendingPoiFlyTo.removeListener(_onPendingPoiFlyTo);
    _tutorialAutoTimer?.cancel();
    _poiErrorTimer?.cancel();
    _highlightTimer?.cancel();
    _pulseTimer?.cancel();
    _removeHighlightLayer();
    _tutorialAnimCtrl.dispose();
    _saveRideIfMeaningful(); // Persist driven KM for stats
    NavigationState.instance.removeListener(_onGlobalModeChanged);
    _positionSub?.cancel();
    _followTimer?.cancel();
    _speedLimitTimer?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    _restoreVosk();
    _liveUsersSub?.cancel();
    _userMarkerDebounce?.cancel();
    _removeNavPuckAnnotation(); // Clean up route-snapped puck
    onlineUsersNotifier.removeListener(_onFollowingChanged);
    NavigationState.instance.stopNavigation(); // Restore bars if screen exits
    WakelockPlus.disable();
    super.dispose();
  }

  /// Save the driven distance as a ride entry (for KM stats & XP).
  /// Only saves if > 0.5 km and > 60 seconds.
  void _saveRideIfMeaningful() {
    final distKm = _totalDrivenMeters / 1000.0;
    if (distKm < 0.5 || _rideStartedAt == null) return;
    final duration = DateTime.now().difference(_rideStartedAt!);
    if (duration.inSeconds < 60) return;
    final avgSpeed = distKm / (duration.inSeconds / 3600.0);
    // Fire-and-forget — screen is being disposed
    RideRepository().saveRide(
      startedAt: _rideStartedAt!,
      endedAt: DateTime.now(),
      distanceKm: distKm,
      durationSeconds: duration.inSeconds,
      avgSpeedKmh: avgSpeed.clamp(0, 300),
    ).then((_) => debugPrint('[Ride] Saved ${distKm.toStringAsFixed(1)} km'))
     .catchError((e) => debugPrint('[Ride] Save failed: $e'));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  GPS LIVE TOGGLE
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _toggleGpsLive() async {
    final service = ref.read(liveLocationServiceProvider);
    if (service.isLive) {
      // Go offline
      await service.goOffline();
      if (!mounted) return;
      ref.read(isLiveProvider.notifier).set(false);
      setState(() => _gpsLive = false);
      // Fly back to PLZ position (Userkarte) + show home marker + follower markers
      if (_mapboxMap != null && _plzLat != null && _plzLng != null) {
        final authState = ref.read(authNotifierProvider);
        final plz = (authState is Authenticated) ? authState.user.postalCode ?? '' : '';
        _addPlzHomeMarker(_plzLat!, _plzLng!, plz);
        _loadFollowedUserPlzMarkers(); // Follower-Marker wieder laden
        _mapboxMap!.flyTo(
          CameraOptions(
            center: Point(coordinates: Position(10.4, 50.3)),
            zoom: 5.3, bearing: 0, pitch: 0,
          ),
          MapAnimationOptions(duration: 1000),
        );
      }
    } else {
      // Go live — broadcast position to followers
      final authState = ref.read(authNotifierProvider);
      if (authState is! Authenticated) return;
      final user = authState.user;
      final community = ref.read(communityProvider);

      // Load stats
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
      } catch (_) {}

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
      if (!mounted) return;
      ref.read(isLiveProvider.notifier).set(true);
      setState(() => _gpsLive = true);
      _removePlzHomeMarker(); // Hide home when GPS ON

      // Fly to actual GPS position
      if (_gpsReady) {
        // GPS stream already delivered a fix — fly immediately
        debugPrint('[Map] GPS toggle ON — flying to ${_lat.toStringAsFixed(5)}, ${_lng.toStringAsFixed(5)}');
        _mapboxMap?.flyTo(
          CameraOptions(
            center: Point(coordinates: Position(_lng, _lat)),
            zoom: 16, bearing: 0, pitch: 0,
            padding: MbxEdgeInsets(top: _cachedPuckPad, left: 0, bottom: 0, right: 0),
          ),
          MapAnimationOptions(duration: 1000),
        );
      } else {
        // GPS stream hasn't delivered yet — try getCurrentPosition, else wait
        debugPrint('[Map] GPS not ready yet — trying getCurrentPosition...');
        try {
          final freshPos = await geo.Geolocator.getCurrentPosition(
            locationSettings: const geo.LocationSettings(
              accuracy: geo.LocationAccuracy.high,
              timeLimit: Duration(seconds: 10),
            ),
          );
          _lat = freshPos.latitude;
          _lng = freshPos.longitude;
          _gpsReady = true;
          debugPrint('[Map] GPS toggle fresh: ${_lat.toStringAsFixed(5)}, ${_lng.toStringAsFixed(5)}');
          if (_mapboxMap != null && mounted) {
            _mapboxMap!.flyTo(
              CameraOptions(
                center: Point(coordinates: Position(_lng, _lat)),
                zoom: 16, bearing: 0, pitch: 0,
                padding: MbxEdgeInsets(top: _cachedPuckPad, left: 0, bottom: 0, right: 0),
              ),
              MapAnimationOptions(duration: 1000),
            );
          }
        } catch (e) {
          debugPrint('[Map] GPS getCurrentPosition failed: $e — waiting for stream...');
          // Don't fly to PLZ coords! Wait for GPS stream to deliver a real fix.
          // The _startGpsStream listener will flyTo when first fix arrives.
          _waitAndFlyToGps();
        }
      }
      // Show visibility banner
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Du bist jetzt sichtbar für deine Follower!'),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        ));
      }
    }
  }

  /// Wait up to 10s for GPS to become ready, then fly to position.
  Future<void> _waitAndFlyToGps() async {
    for (int i = 0; i < 20; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted || !_gpsLive) return; // User toggled off or left screen
      if (_gpsReady) {
        _mapboxMap?.flyTo(
          CameraOptions(
            center: Point(coordinates: Position(_lng, _lat)),
            zoom: 16, bearing: 0, pitch: 0,
            padding: MbxEdgeInsets(top: _cachedPuckPad, left: 0, bottom: 0, right: 0),
          ),
          MapAnimationOptions(duration: 1000),
        );
        return;
      }
    }
    debugPrint('[Map] GPS not ready after 10s — skipping fly');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  PLZ POSITION (Userkarte — Toggle OFF)
  // ═══════════════════════════════════════════════════════════════════════════

  void _initPlzPosition() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final authState = ref.read(authNotifierProvider);
      if (authState is! Authenticated) return;
      final plz = authState.user.postalCode;
      if (plz == null || plz.isEmpty) return;

      // 1. Quick sync approximation for instant display
      final syncCoords = _plzToCoordsSync(plz);
      if (syncCoords != null) {
        _plzLat = syncCoords.latitude;
        _plzLng = syncCoords.longitude;
        _lat = syncCoords.latitude;
        _lng = syncCoords.longitude;
        debugPrint('[Map] PLZ sync: $plz → ${syncCoords.latitude}, ${syncCoords.longitude}');
        _flyToPlzAndShowMarker(plz);
      }

      // 2. Async Photon for exact coordinates (overrides sync if successful)
      final exactCoords = await _plzToCoordsByPhoton(plz);
      if (exactCoords != null && mounted) {
        _plzLat = exactCoords.latitude;
        _plzLng = exactCoords.longitude;
        _lat = exactCoords.latitude;
        _lng = exactCoords.longitude;
        debugPrint('[Map] PLZ Photon (exakt): $plz → ${exactCoords.latitude}, ${exactCoords.longitude}');
        // Nur Marker-Position aktualisieren, kein erneuter Fly/Reload
        _addPlzHomeMarker(_plzLat!, _plzLng!, plz);
      }
    });
  }

  void _flyToPlzAndShowMarker(String plz) {
    if (_mapboxMap == null || _plzLat == null || _plzLng == null) return;
    // DACH-Übersicht: ganz Deutschland + Schweiz + ein wenig Italien
    _mapboxMap!.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(10.4, 50.3)),
        zoom: 5.3, bearing: 0, pitch: 0,
      ),
      MapAnimationOptions(duration: 800),
    );
    _addPlzHomeMarker(_plzLat!, _plzLng!, plz);
    _loadFollowedUserPlzMarkers();
    if (mounted) setState(() {});
  }

  /// Check if user has saved a Zuhause address (for pulse hint on button)
  Future<void> _checkHomeSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('nav_home');
    if (mounted && saved == null) {
      setState(() => _homeSaved = false);
    }
  }

  /// Sync PLZ → LatLng for German postal codes (offline, instant).
  LatLng? _plzToCoordsSync(String plz) {
    if (plz.isEmpty) return null;
    final trimmed = plz.trim();
    final code = int.tryParse(trimmed.replaceAll(RegExp(r'[^0-9]'), ''));
    if (code == null) return null;

    // Deutsche PLZ (5-stellig)
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

    // Schweizer PLZ (4-stellig, 1000-9999)
    if (trimmed.length == 4 && code >= 1000 && code <= 9999) {
      final region = code ~/ 1000;
      return switch (region) {
        1 => LatLng(46.52 + (code % 1000) * 0.0005, 6.63 + (code % 1000) * 0.0005),  // Westschweiz
        2 => LatLng(47.05 + (code % 1000) * 0.0004, 6.95 + (code % 1000) * 0.0004),  // Jura/Biel
        3 => LatLng(46.85 + (code % 1000) * 0.0005, 7.30 + (code % 1000) * 0.0004),  // Bern
        4 => LatLng(47.45 + (code % 1000) * 0.0003, 7.55 + (code % 1000) * 0.0003),  // Basel
        5 => LatLng(47.35 + (code % 1000) * 0.0003, 7.90 + (code % 1000) * 0.0004),  // Aargau
        6 => LatLng(46.95 + (code % 1000) * 0.0004, 8.20 + (code % 1000) * 0.0005),  // Zentralschweiz
        7 => LatLng(46.70 + (code % 1000) * 0.0004, 9.50 + (code % 1000) * 0.0005),  // Graubünden
        8 => LatLng(47.30 + (code % 1000) * 0.0003, 8.40 + (code % 1000) * 0.0004),  // Zürich
        9 => LatLng(47.35 + (code % 1000) * 0.0003, 9.20 + (code % 1000) * 0.0004),  // Ostschweiz
        _ => const LatLng(46.95, 7.45),  // Bern Default
      };
    }

    // Österreichische PLZ (4-stellig, 1000-9999) — gleiche Struktur wie CH
    // aber andere Regionen → Photon-Fallback nutzen
    return null;
  }

  /// Exakte PLZ-Geocodierung via Photon API (für CH/AT/DE — alle Länder)
  /// Nutzt Location-Bias aus Sync-Koordinaten, um DACH-Region zu priorisieren.
  Future<LatLng?> _plzToCoordsByPhoton(String plz) async {
    try {
      final trimmed = plz.trim();
      // Country suffix für eindeutigen Treffer
      String country = '';
      if (trimmed.length == 5) {
        country = ' Deutschland';
      } else if (trimmed.length == 4) {
        final code = int.tryParse(trimmed) ?? 0;
        // Schweiz: 1000-9999, Österreich: 1010-9992
        // Bias via sync-Koordinaten entscheidet
        country = (_plzLat != null && _plzLat! > 47.0 && _plzLng != null && _plzLng! < 10.5)
            ? ' Schweiz' : ' Österreich';
      }

      // Location-Bias: Sync-Koordinaten oder Mitte DACH
      final biasLat = _plzLat ?? 47.5;
      final biasLon = _plzLng ?? 9.0;

      final query = Uri.encodeComponent('$trimmed$country');
      final url = Uri.parse(
        'https://photon.komoot.io/api/?q=$query&limit=3&lang=de&lat=$biasLat&lon=$biasLon',
      );
      final resp = await http.get(url, headers: {
        'User-Agent': 'Motorinu-App/1.6 (Android; contact@bikergram.com)',
      }).timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final features = data['features'] as List? ?? [];
        // Find best match: prefer results in DACH region (lat 45-55, lon 5-17)
        for (final f in features) {
          final coords = f['geometry']['coordinates'] as List;
          final lat = (coords[1] as num).toDouble();
          final lon = (coords[0] as num).toDouble();
          if (lat >= 45.0 && lat <= 55.0 && lon >= 5.0 && lon <= 17.0) {
            debugPrint('[PLZ] Photon: $trimmed$country → $lat, $lon');
            return LatLng(lat, lon);
          }
        }
        // Fallback: first result if any
        if (features.isNotEmpty) {
          final coords = features[0]['geometry']['coordinates'] as List;
          final lat = (coords[1] as num).toDouble();
          final lon = (coords[0] as num).toDouble();
          debugPrint('[PLZ] Photon fallback: $trimmed → $lat, $lon');
          return LatLng(lat, lon);
        }
      }
    } catch (e) {
      debugPrint('[PLZ] Photon error: $e');
    }
    return null;
  }

  // ── PLZ Home Marker ──

  Future<void> _addPlzHomeMarker(double lat, double lng, String plz) async {
    if (_mapboxMap == null) return;
    _plzAnnotationManager ??= await _mapboxMap!.annotations
        .createPointAnnotationManager(id: 'plz-home');
    await _plzAnnotationManager!.deleteAll();

    // Tap on home marker → open own profile
    _plzAnnotationManager!.addOnPointAnnotationClickListener(
      _HomeMarkerClickListener(() {
        if (!mounted) return;
        context.push('/profile');
      }),
    );

    final iconBytes = await _buildHomeMarkerIcon();
    if (!mounted) return;

    await _plzAnnotationManager!.create(PointAnnotationOptions(
      geometry: Point(coordinates: Position(lng, lat)),
      image: iconBytes,
      iconSize: 1.0,
      iconAnchor: IconAnchor.CENTER,
      textField: 'PLZ $plz',
      textSize: 11,
      textColor: Colors.white.value.toInt(),
      textHaloColor: Colors.black.value.toInt(),
      textHaloWidth: 1.5,
      textOffset: [0.0, 3.5],
    ));
  }

  Future<Uint8List> _buildHomeMarkerIcon() async {
    const size = 120.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size, size));

    // Outer ring (mode color)
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2,
      Paint()..color = _modeColor,
    );
    // White ring
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2 - 3,
      Paint()..color = Colors.white,
    );

    // Try to draw profile picture
    ui.Image? avatarImg;
    try {
      final authState = ref.read(authNotifierProvider);
      if (authState is Authenticated && authState.user.avatarUrl != null) {
        final url = authState.user.avatarUrl!;
        final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          final codec = await ui.instantiateImageCodec(response.bodyBytes);
          final frame = await codec.getNextFrame();
          avatarImg = frame.image;
        }
      }
    } catch (_) {}

    if (avatarImg != null) {
      // Clip avatar to circle
      final avatarRadius = size / 2 - 5;
      canvas.save();
      canvas.clipPath(Path()..addOval(Rect.fromCircle(
        center: const Offset(size / 2, size / 2), radius: avatarRadius)));
      canvas.drawImageRect(
        avatarImg,
        Rect.fromLTWH(0, 0, avatarImg.width.toDouble(), avatarImg.height.toDouble()),
        Rect.fromCircle(center: const Offset(size / 2, size / 2), radius: avatarRadius),
        Paint(),
      );
      canvas.restore();
    } else {
      // Fallback: dark circle with house icon
      final innerBg = _isDark ? const Color(0xFF1B1F2B) : const Color(0xFFF5F5F5);
      canvas.drawCircle(const Offset(size / 2, size / 2), size / 2 - 5, Paint()..color = innerBg);
      // House icon
      final paint = Paint()..color = _modeColor..style = PaintingStyle.fill;
      final path = Path();
      path.moveTo(size * 0.5, size * 0.25);
      path.lineTo(size * 0.28, size * 0.48);
      path.lineTo(size * 0.72, size * 0.48);
      path.close();
      canvas.drawPath(path, paint);
      canvas.drawRect(Rect.fromLTRB(size * 0.32, size * 0.48, size * 0.68, size * 0.72), paint);
      canvas.drawRect(Rect.fromLTRB(size * 0.43, size * 0.55, size * 0.57, size * 0.72), Paint()..color = innerBg);
    }

    // Small house badge (bottom-right corner)
    final badgeCenter = const Offset(size * 0.78, size * 0.78);
    canvas.drawCircle(badgeCenter, 16, Paint()..color = _modeColor);
    canvas.drawCircle(badgeCenter, 13, Paint()..color = Colors.white);
    // Tiny house in badge
    final bp = Paint()..color = _modeColor..style = PaintingStyle.fill;
    final bPath = Path();
    bPath.moveTo(badgeCenter.dx, badgeCenter.dy - 8);
    bPath.lineTo(badgeCenter.dx - 7, badgeCenter.dy - 1);
    bPath.lineTo(badgeCenter.dx + 7, badgeCenter.dy - 1);
    bPath.close();
    canvas.drawPath(bPath, bp);
    canvas.drawRect(Rect.fromLTRB(
      badgeCenter.dx - 5, badgeCenter.dy - 1,
      badgeCenter.dx + 5, badgeCenter.dy + 7), bp);

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  void _removePlzHomeMarker() {
    _plzAnnotationManager?.deleteAll();
    _removeFollowedPlzLayers();
  }

  // ── FOLLOWED USERS PLZ MARKERS (GeoJsonSource + Clustering) ──
  bool _followedPlzLayerInitialized = false;
  final Map<String, Map<String, dynamic>> _followedUserProfiles = {};

  Future<void> _loadFollowedUserPlzMarkers() async {
    if (_mapboxMap == null) return;
    final authState = ref.read(authNotifierProvider);
    if (authState is! Authenticated) return;
    final myId = authState.user.id;

    try {
      final supabase = Supabase.instance.client;
      // Get followed user IDs
      final followsRes = await supabase
          .from('follows')
          .select('following_id')
          .eq('follower_id', myId);
      final followedIds = (followsRes as List).map((r) => r['following_id'] as String).toList();
      if (followedIds.isEmpty) {
        debugPrint('[FollowedPLZ] No followed users');
        return;
      }

      // Get profiles with PLZ + avatar
      final profilesRes = await supabase
          .from('profiles')
          .select('id, username, avatar_url, postal_code')
          .inFilter('id', followedIds);
      final profiles = profilesRes as List;
      debugPrint('[FollowedPLZ] ${profiles.length} followed profiles loaded');

      // Clean up old layers
      await _removeFollowedPlzLayers();
      _followedUserProfiles.clear();

      final style = _mapboxMap!.style;
      final features = <String>[];
      // Cache für Photon-Ergebnisse pro PLZ (um nicht mehrfach gleiche PLZ abzufragen)
      final plzCache = <String, LatLng?>{};

      for (final p in profiles) {
        final plz = p['postal_code'] as String?;
        if (plz == null || plz.isEmpty) continue;

        final userId = p['id'] as String;
        final username = p['username'] as String? ?? '?';
        final avatarUrl = p['avatar_url'] as String?;

        // Exakte Koordinaten via Photon (gecacht pro PLZ)
        LatLng? coords;
        if (plzCache.containsKey(plz)) {
          coords = plzCache[plz];
        } else {
          coords = await _plzToCoordsByPhoton(plz);
          coords ??= _plzToCoordsSync(plz);
          plzCache[plz] = coords;
          // Kurze Pause um Photon nicht zu überlasten
          await Future.delayed(const Duration(milliseconds: 80));
        }
        if (coords == null || !mounted) continue;

        // Same-PLZ Offset: Wenn mehrere User gleiche PLZ haben → kleiner Kreis
        final sameCount = features.where((f) => f.contains('"plz":"$plz"')).length;
        double lat = coords.latitude;
        double lng = coords.longitude;
        if (sameCount > 0) {
          final angle = sameCount * (2 * math.pi / 8);
          lat += 0.045 * math.cos(angle);  // ~5km Spreizung
          lng += 0.055 * math.sin(angle);
        }

        _followedUserProfiles[userId] = Map<String, dynamic>.from(p);

        // Build and register custom icon image
        final iconBytes = await _buildFollowedMarkerIcon(avatarUrl, username);
        if (!mounted) return;

        final imageId = 'followed-avatar-$userId';
        try {
          await style.addStyleImage(
            imageId, 2.0,
            MbxImage(width: 100, height: 100, data: iconBytes),
            false, [], [], null,
          );
        } catch (_) {}

        // GeoJSON Feature
        final escapedUsername = username.replaceAll('"', '\\"').replaceAll('\n', ' ');
        features.add(
          '{"type":"Feature",'
          '"properties":{"userId":"$userId","username":"$escapedUsername","icon":"$imageId","plz":"$plz"},'
          '"geometry":{"type":"Point","coordinates":[$lng,$lat]}}'
        );
      }

      if (features.isEmpty) return;
      if (!mounted) return;

      // GeoJSON Source mit Clustering
      final geoJson = '{"type":"FeatureCollection","features":[${features.join(',')}]}';
      await style.addSource(GeoJsonSource(
        id: 'followed-plz-source',
        data: geoJson,
        cluster: true,
        clusterRadius: 50,
        clusterMaxZoom: 16,
        clusterMinPoints: 2,
      ));

      final modeColorInt = _modeColor.value.toInt();

      // Layer 1: Cluster circles
      await style.addLayer(CircleLayer(
        id: 'followed-plz-cluster-circles',
        sourceId: 'followed-plz-source',
        circleColor: modeColorInt,
        circleRadius: 22.0,
        circleStrokeColor: 0xFFFFFFFF,
        circleStrokeWidth: 3.0,
        circleOpacity: 0.85,
      ));
      await style.setStyleLayerProperty(
        'followed-plz-cluster-circles', 'filter', '["has", "point_count"]',
      );

      // Layer 2: Cluster count text
      await style.addLayer(SymbolLayer(
        id: 'followed-plz-cluster-count',
        sourceId: 'followed-plz-source',
        textColor: 0xFFFFFFFF,
        textSize: 14.0,
        textAllowOverlap: true,
      ));
      await style.setStyleLayerProperty(
        'followed-plz-cluster-count', 'filter', '["has", "point_count"]',
      );
      await style.setStyleLayerProperty(
        'followed-plz-cluster-count', 'text-field', '["get", "point_count_abbreviated"]',
      );

      // Layer 3: Individual user icons
      await style.addLayer(SymbolLayer(
        id: 'followed-plz-user-icons',
        sourceId: 'followed-plz-source',
        iconSize: 0.5,
        iconAllowOverlap: true,
        iconAnchor: IconAnchor.CENTER,
      ));
      await style.setStyleLayerProperty(
        'followed-plz-user-icons', 'filter', '["!", ["has", "point_count"]]',
      );
      await style.setStyleLayerProperty(
        'followed-plz-user-icons', 'icon-image', '["get", "icon"]',
      );

      // Layer 4: Username labels
      await style.addLayer(SymbolLayer(
        id: 'followed-plz-user-labels',
        sourceId: 'followed-plz-source',
        textSize: 10.0,
        textColor: 0xFFFFFFFF,
        textHaloColor: 0xFF000000,
        textHaloWidth: 1.2,
        textAnchor: TextAnchor.TOP,
        textAllowOverlap: true,
      ));
      await style.setStyleLayerProperty(
        'followed-plz-user-labels', 'filter', '["!", ["has", "point_count"]]',
      );
      await style.setStyleLayerProperty(
        'followed-plz-user-labels', 'text-field', '["get", "username"]',
      );
      await style.setStyleLayerProperty(
        'followed-plz-user-labels', 'text-offset', '[0, 3.5]',
      );

      _followedPlzLayerInitialized = true;
      debugPrint('[FollowedPLZ] Drew ${features.length} markers with clustering');

      // Kein automatischer Camera-Fit — DACH-Übersicht bleibt bestehen
    } catch (e) {
      debugPrint('[FollowedPLZ] Error: $e');
    }
  }

  /// Berechnet Bounding Box aller Follower + eigene Position → Camera fitten
  void _fitCameraToAllMarkers(List<String> geoFeatures) {
    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;

    // Eigene Position einbeziehen
    if (_plzLat != null && _plzLng != null) {
      minLat = math.min(minLat, _plzLat!);
      maxLat = math.max(maxLat, _plzLat!);
      minLng = math.min(minLng, _plzLng!);
      maxLng = math.max(maxLng, _plzLng!);
    }

    // Alle Follower-Positionen aus den GeoJSON-Features extrahieren
    final coordsRegex = RegExp(r'"coordinates":\[([-\d.]+),([-\d.]+)\]');
    for (final f in geoFeatures) {
      final match = coordsRegex.firstMatch(f);
      if (match != null) {
        final lng = double.tryParse(match.group(1)!) ?? 0;
        final lat = double.tryParse(match.group(2)!) ?? 0;
        minLat = math.min(minLat, lat);
        maxLat = math.max(maxLat, lat);
        minLng = math.min(minLng, lng);
        maxLng = math.max(maxLng, lng);
      }
    }

    if (minLat >= maxLat || minLng >= maxLng) return;

    // Padding: oben mehr (für Suchleiste), unten mehr (für Buttons)
    _mapboxMap!.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(
          (minLng + maxLng) / 2,
          (minLat + maxLat) / 2,
        )),
        // Zoom berechnen basierend auf Spread
        zoom: _zoomForBounds(maxLat - minLat, maxLng - minLng),
        bearing: 0, pitch: 0,
        padding: MbxEdgeInsets(top: 120, left: 30, bottom: 180, right: 30),
      ),
      MapAnimationOptions(duration: 1200),
    );
  }

  /// Berechnet Zoom-Level für gegebenen Lat/Lng-Spread
  double _zoomForBounds(double latSpread, double lngSpread) {
    final spread = math.max(latSpread, lngSpread);
    if (spread > 15) return 3.0;
    if (spread > 10) return 4.0;
    if (spread > 5) return 5.0;
    if (spread > 2) return 6.0;
    if (spread > 1) return 7.0;
    if (spread > 0.5) return 8.0;
    if (spread > 0.2) return 10.0;
    if (spread > 0.05) return 12.0;
    return 13.0;
  }

  /// Zeigt Bottom Sheet mit den Usern eines Clusters
  void _showClusterUsersSheet(List<String> userIds) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _isDark ? const Color(0xFF1A1A2E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final bp = MediaQuery.of(ctx).padding.bottom;
        return Padding(
          padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: bp + 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Handle
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: _textMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            // Title
            Row(children: [
              Icon(Icons.group_rounded, color: _modeColor, size: 22),
              const SizedBox(width: 8),
              Text('${userIds.length} Biker in der Nähe', style: TextStyle(
                color: _textPrimary, fontSize: 17, fontWeight: FontWeight.bold,
              )),
            ]),
            const SizedBox(height: 12),
            // User list
            ...userIds.map((uid) {
              final profile = _followedUserProfiles[uid];
              if (profile == null) return const SizedBox.shrink();
              final username = profile['username'] as String? ?? '?';
              final avatarUrl = profile['avatar_url'] as String?;
              final plz = profile['postal_code'] as String? ?? '';
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/profile/$uid');
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Row(children: [
                    // Avatar mit Online-Status Ring (grün/rot)
                    OnlineStatusAvatar(
                      userId: uid,
                      avatarUrl: avatarUrl,
                      size: 48,
                      fallbackIcon: Text(username[0].toUpperCase(), style: TextStyle(
                        color: _modeColor, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    // Name + PLZ
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(username, style: TextStyle(
                          color: _textPrimary, fontSize: 15, fontWeight: FontWeight.w600,
                        )),
                        if (plz.isNotEmpty)
                          Text('PLZ $plz', style: TextStyle(
                            color: _textMuted, fontSize: 12,
                          )),
                      ],
                    )),
                    // Arrow
                    Icon(Icons.chevron_right_rounded, color: _iconMuted, size: 22),
                  ]),
                ),
              );
            }),
          ]),
        );
      },
    );
  }

  Future<void> _removeFollowedPlzLayers() async {
    if (_mapboxMap == null) return;
    final style = _mapboxMap!.style;
    for (final id in [
      'followed-plz-user-labels',
      'followed-plz-user-icons',
      'followed-plz-cluster-count',
      'followed-plz-cluster-circles',
    ]) {
      try { await style.removeStyleLayer(id); } catch (_) {}
    }
    try { await style.removeStyleSource('followed-plz-source'); } catch (_) {}
    _followedPlzLayerInitialized = false;
  }

  Future<Uint8List> _buildFollowedMarkerIcon(String? avatarUrl, String username) async {
    const size = 100.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size, size));

    // Outer ring
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2, Paint()..color = _modeColor);
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2 - 3, Paint()..color = Colors.white);

    // Try avatar
    ui.Image? avatarImg;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(avatarUrl)).timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          final codec = await ui.instantiateImageCodec(response.bodyBytes);
          final frame = await codec.getNextFrame();
          avatarImg = frame.image;
        }
      } catch (_) {}
    }

    if (avatarImg != null) {
      final r = size / 2 - 5;
      canvas.save();
      canvas.clipPath(Path()..addOval(Rect.fromCircle(center: const Offset(size / 2, size / 2), radius: r)));
      canvas.drawImageRect(
        avatarImg,
        Rect.fromLTWH(0, 0, avatarImg.width.toDouble(), avatarImg.height.toDouble()),
        Rect.fromCircle(center: const Offset(size / 2, size / 2), radius: r),
        Paint(),
      );
      canvas.restore();
    } else {
      // Fallback: initial letter
      final innerBg = _isDark ? const Color(0xFF1B1F2B) : const Color(0xFFF5F5F5);
      canvas.drawCircle(const Offset(size / 2, size / 2), size / 2 - 5, Paint()..color = innerBg);
      final tp = TextPainter(
        text: TextSpan(text: username[0].toUpperCase(), style: TextStyle(color: _modeColor, fontSize: 36, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((size - tp.width) / 2, (size - tp.height) / 2));
    }

    // House badge (bottom-right)
    final bc = const Offset(size * 0.78, size * 0.78);
    canvas.drawCircle(bc, 14, Paint()..color = _modeColor);
    canvas.drawCircle(bc, 11, Paint()..color = Colors.white);
    final bp2 = Paint()..color = _modeColor..style = PaintingStyle.fill;
    final bPath = Path()
      ..moveTo(bc.dx, bc.dy - 7)
      ..lineTo(bc.dx - 6, bc.dy - 1)
      ..lineTo(bc.dx + 6, bc.dy - 1)
      ..close();
    canvas.drawPath(bPath, bp2);
    canvas.drawRect(Rect.fromLTRB(bc.dx - 4, bc.dy - 1, bc.dx + 4, bc.dy + 5), bp2);

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  GPS (Live-Karte — Toggle ON)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _initGps() async {
    try {
      // Ensure GPS permission before trying position
      var perm = await geo.Geolocator.checkPermission();
      if (perm == geo.LocationPermission.denied) {
        perm = await geo.Geolocator.requestPermission();
      }
      if (perm == geo.LocationPermission.deniedForever ||
          perm == geo.LocationPermission.denied) {
        debugPrint('[GPS] Permission denied: $perm — starting stream anyway');
        _startGpsStream(); // Stream will deliver once permission is granted
        return;
      }

      final pos = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.bestForNavigation,
          timeLimit: Duration(seconds: 15),
        ),
      );
      _lat = pos.latitude;
      _lng = pos.longitude;
      _gpsReady = true;
      debugPrint('[GPS] Init success: ${_lat.toStringAsFixed(5)}, ${_lng.toStringAsFixed(5)}');
      _startGpsStream();
      _loadBlitzers();
      _startSpeedLimitPolling();
      // Only fly to GPS position if toggle is ON (Live-Karte)
      // If OFF, _initPlzPosition handles camera
      if (_gpsLive && _mapboxMap != null) {
        _mapboxMap!.flyTo(
          CameraOptions(
            center: Point(coordinates: Position(_lng, _lat)),
            zoom: 16, bearing: 0, pitch: 0,
            padding: MbxEdgeInsets(top: _cachedPuckPad, left: 0, bottom: 0, right: 0),
          ),
          MapAnimationOptions(duration: 800),
        );
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('[GPS] Init error: $e — starting stream anyway');
      // Always start stream even if initial position fails
      _startGpsStream();
    }
  }

  void _startGpsStream() {
    _positionSub = geo.Geolocator.getPositionStream(
      locationSettings: const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
      ),
    ).listen((geo.Position pos) {
      _lastGpsTime = DateTime.now();

      // ── First GPS fix: mark gpsReady and fly if GPS toggle is ON ──
      if (!_gpsReady) {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _gpsReady = true;
        debugPrint('[GPS] Stream: first fix ${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}');
        if (_gpsLive && _mapboxMap != null && mounted) {
          _mapboxMap!.flyTo(
            CameraOptions(
              center: Point(coordinates: Position(_lng, _lat)),
              zoom: 16, bearing: 0, pitch: 0,
              padding: MbxEdgeInsets(top: _cachedPuckPad, left: 0, bottom: 0, right: 0),
            ),
            MapAnimationOptions(duration: 1000),
          );
        }
        if (mounted) setState(() {});
      }

      // ── Position drift filter: lock position when standing still ──
      // GPS drifts 50-200m in urban areas when stationary (multipath)
      final rawKmh = (pos.speed >= 0 && pos.accuracy < 30)
          ? (pos.speed * 3.6).clamp(0.0, 300.0)
          : 0.0;
      final threshold = _routeMode == RouteMode.pedestrian ? 1.5 : 1.5;
      final isMoving = rawKmh >= threshold;

      if (isMoving) {
        // Moving → always update position
        // ── Accumulate driven distance ──
        if (_prevLat != 0 && _prevLng != 0) {
          final segDist = geo.Geolocator.distanceBetween(
              _prevLat, _prevLng, pos.latitude, pos.longitude);
          // Sanity: only count segments < 500m (filter GPS jumps)
          if (segDist < 500) {
            _totalDrivenMeters += segDist;
          }
        }
        _prevLat = pos.latitude;
        _prevLng = pos.longitude;
        _rideStartedAt ??= DateTime.now();

        _lat = pos.latitude;
        _lng = pos.longitude;
        // Custom vehicle puck should always rotate with heading when moving
        if (!_puckBearingOn) {
          _puckBearingOn = true;
          _mapboxMap?.location.updateSettings(LocationComponentSettings(
            puckBearingEnabled: true,
            puckBearing: PuckBearing.HEADING,
            locationPuck: _cachedLocationPuck, // keep custom puck!
          ));
        }
      } else {
        // Standing still → only update if jump > 30m (real repositioning)
        final drift = geo.Geolocator.distanceBetween(_lat, _lng, pos.latitude, pos.longitude);
        if (drift > 30) {
          // Likely a GPS correction, not drift — accept once
          _lat = pos.latitude;
          _lng = pos.longitude;
        }
        // Disable puck bearing when stopped (prevents compass jitter)
        if (_puckBearingOn) {
          _puckBearingOn = false;
          _mapboxMap?.location.updateSettings(LocationComponentSettings(
            puckBearingEnabled: false,
            locationPuck: _cachedLocationPuck, // keep custom puck!
          ));
        }
      }

      // ── Speed: use rawKmh + threshold from drift filter above ──
      if (!isMoving) {
        _speed = 0;
        _displaySpeed = 0; // Instant zero — no lag at red lights
      } else {
        _speed = rawKmh;
        // EMA display: adaptive lerp based on delta magnitude
        // Higher lerp = faster response, near-instant for big changes
        final delta = (rawKmh - _displaySpeed).abs();
        final double lerp;
        if (delta > 10) {
          lerp = 0.98; // Hard brake or quick acceleration → near-instant
        } else if (delta > 5) {
          lerp = 0.95; // Medium change → very fast
        } else if (rawKmh > _displaySpeed) {
          lerp = 0.93; // Normal acceleration — snappy
        } else {
          lerp = 0.92; // Normal deceleration — fast tracking
        }
        _displaySpeed += (rawKmh - _displaySpeed) * lerp;
      }
      // Update heading: lower threshold for pedestrians (3 km/h), higher for vehicles (8 km/h)
      final headingThreshold = _routeMode == RouteMode.pedestrian ? 3.0 : 8.0;
      if (pos.heading >= 0 && rawKmh > headingThreshold) _heading = pos.heading;

      // Warn if pedestrian mode but driving speed
      if (_routeMode == RouteMode.pedestrian && rawKmh > 50 && _isNavigating) {
        if (!_pedestrianSpeedWarned) {
          _pedestrianSpeedWarned = true;
          _ttsSpeak('Achtung, du fährst über 50 Kilometer pro Stunde im Fußgänger-Modus. Wechsle zu Biker oder Auto.', isWarning: true);
        }
      } else if (rawKmh < 30) {
        _pedestrianSpeedWarned = false;
      }

      if (_isNavigating) {
        _onNavTick();
        _checkBlitzers();
        _trimPassedRoutePoints();
        _updateSnapLine();
        _updateNavPuck();
      }

      // Speeding check — ignore speed limit 0 (unlimited/unknown), skip for pedestrians
      // Cooldown: only warn once per 60 seconds to avoid spam on Autobahn
      if (_speedLimit != null && _speedLimit! > 0 && _routeMode != RouteMode.pedestrian) {
        final was = _isSpeeding;
        _isSpeeding = _speed > (_speedLimit! + 5);
        if (_isSpeeding && !was && DateTime.now().difference(_lastSpeedWarning).inSeconds > 60) {
          _lastSpeedWarning = DateTime.now();
          _ttsSpeak('Achtung! Tempolimit $_speedLimit überschritten.', isWarning: true, priority: true);
        }
      } else {
        _isSpeeding = false;
      }

      if (mounted) setState(() {});
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  SEARCH
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('nav_search_history') ?? [];
    final seen = <String>{};
    final deduped = <String>[];
    _searchHistory = list.map((s) {
      final parts = s.split('|||');
      if (parts.length >= 4) {
        return {'raw': s, 'name': parts[0], 'subtitle': parts[1],
          'lat': double.tryParse(parts[2]) ?? 0.0, 'lng': double.tryParse(parts[3]) ?? 0.0};
      }
      return <String, dynamic>{};
    }).where((m) {
      if (m.isEmpty) return false;
      final key = (m['name'] as String).toLowerCase().trim();
      if (seen.contains(key)) return false;
      seen.add(key);
      deduped.add(m['raw'] as String);
      return true;
    }).map((m) => {
      'name': m['name'], 'subtitle': m['subtitle'], 'lat': m['lat'], 'lng': m['lng'],
    }).toList();
    // Persist deduped list (removes existing duplicates like 3x Saarbrückerstraße)
    if (deduped.length < list.length) {
      await prefs.setStringList('nav_search_history', deduped);
    }
  }

  Future<void> _saveToHistory(String name, String sub, double lat, double lng) async {
    final prefs = await SharedPreferences.getInstance();
    final entry = '$name|||$sub|||$lat|||$lng';
    final list = prefs.getStringList('nav_search_history') ?? [];
    // Remove duplicates: same name OR same coordinates (within 50m)
    list.removeWhere((s) {
      final parts = s.split('|||');
      if (parts.length < 4) return false;
      if (parts[0] == name) return true;
      final eLat = double.tryParse(parts[2]) ?? 0;
      final eLng = double.tryParse(parts[3]) ?? 0;
      return (eLat - lat).abs() < 0.0005 && (eLng - lng).abs() < 0.0005; // ~50m
    });
    list.insert(0, entry);
    if (list.length > 10) list.removeLast();
    await prefs.setStringList('nav_search_history', list);
    // Also deduplicate in-memory list
    _searchHistory.removeWhere((h) =>
      h['name'] == name ||
      ((h['lat'] as double) - lat).abs() < 0.0005 && ((h['lng'] as double) - lng).abs() < 0.0005);
    _searchHistory.insert(0, {'name': name, 'subtitle': sub, 'lat': lat, 'lng': lng});
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.trim().length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final results = await _geocoding.searchPlace(
          query,
          near: LatLng(_lat, _lng),
        );
        if (mounted) setState(() => _searchResults = results);
      } catch (_) {}
    });
  }

  bool _autoStartNav = false;

  void _selectDestination(double lat, double lng, String name, {bool autoStart = false}) {
    _autoStartNav = autoStart;
    _destination = LatLng(lat, lng);
    _destName = name;
    _lastTrimIndex = 0;
    _destInfo = null;
    // Load destination info (population, country, blitzer count) in background
    DestinationInfoService().fetchAll(
      cityName: name,
      location: LatLng(lat, lng),
      onUpdate: (updated) { if (mounted) setState(() => _destInfo = updated); },
    ).then((info) {
      if (mounted) setState(() => _destInfo = info);
    });
    _searchOpen = false;
    _searchDropdownOpen = false;
    _searchController.clear();
    _searchResults = [];
    _saveToHistory(name, '', lat, lng);
    setState(() {});
    _calcRoute();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  ROUTING
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _calcRoute() async {
    if (_destination == null) return;
    // Wait for GPS if not ready (max 5s)
    if (!_gpsReady) {
      for (int i = 0; i < 50; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (_gpsReady) break;
      }
      if (!_gpsReady) {
        debugPrint('[Route] GPS not ready after 5s, using default position');
      }
    }
    setState(() => _isCalculating = true);

    // Apply route avoidance options from settings
    final settings = ref.read(blitzerSettingsProvider).value;
    if (settings != null) {
      // avoidTolls removed — not useful in DE, breaks public OSRM fallback
      _osrm.avoidFerries = settings.avoidFerries;
      _osrm.avoidMotorways = settings.avoidMotorways;
    }

    try {
      final routes = await _osrm.getAllRoutes(
        LatLng(_lat, _lng), _destination!,
        mode: _routeMode,
      );
      debugPrint('[Route] Got ${routes.length} routes from (${_lat.toStringAsFixed(4)},${_lng.toStringAsFixed(4)}) to (${_destination!.latitude.toStringAsFixed(4)},${_destination!.longitude.toStringAsFixed(4)})');
      if (routes.isEmpty) {
        debugPrint('[Route] No routes found!');
        setState(() => _isCalculating = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Keine Route gefunden. Ziel zu weit oder nicht erreichbar.'),
            backgroundColor: Colors.red.shade700, behavior: SnackBarBehavior.floating,
          ));
        }
        return;
      }

      _allRoutes = routes;
      _selectedRouteIdx = _routeMode == RouteMode.biker && routes.length > 1
          ? routes.length - 1 : 0; // Biker: scenic (longest), others: fastest
      _currentRoute = routes[_selectedRouteIdx];
      _routePoints = _currentRoute!.polylinePoints;

      await _drawRoutes();
      await _fitToRoute();

      // Count blitzer along the route (max 100m from route line)
      _countRouteBlitzers();

      setState(() => _isCalculating = false);

      // Auto-start navigation if triggered from voice/popup
      if (_autoStartNav) {
        _autoStartNav = false;
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && _currentRoute != null) _startNavigation();
        });
      }
    } catch (e) {
      setState(() => _isCalculating = false);
      debugPrint('[Route] Error: $e');
    }
  }

  Future<void> _drawRoutes() async {
    if (_mapboxMap == null) return;
    final style = _mapboxMap!.style;

    // Remove old layers
    for (int i = 0; i < 5; i++) {
      try { await style.removeStyleLayer('route-$i'); } catch (_) {}
      try { await style.removeStyleLayer('route-border-$i'); } catch (_) {}
      try { await style.removeStyleSource('route-src-$i'); } catch (_) {}
    }

    for (int i = 0; i < _allRoutes.length; i++) {
      final pts = _allRoutes[i].polylinePoints;
      final coords = pts.map((p) => '[${p.longitude},${p.latitude}]').join(',');
      final geo = '{"type":"Feature","geometry":{"type":"LineString","coordinates":[$coords]}}';
      final isSelected = i == _selectedRouteIdx;

      await style.addSource(GeoJsonSource(id: 'route-src-$i', data: geo));

      // Border
      await style.addLayer(LineLayer(
        id: 'route-border-$i',
        sourceId: 'route-src-$i',
        lineColor: isSelected ? 0xFF006064 : 0xFF333333,
        lineWidth: isSelected ? 10.0 : 6.0,
        lineOpacity: isSelected ? 0.6 : 0.3,
        lineCap: LineCap.ROUND,
        lineJoin: LineJoin.ROUND,
      ));

      // Fill
      await style.addLayer(LineLayer(
        id: 'route-$i',
        sourceId: 'route-src-$i',
        lineColor: isSelected ? _colorForMode(_routeMode).value : 0xFF666666,
        lineWidth: isSelected ? 6.0 : 4.0,
        lineOpacity: isSelected ? 0.9 : 0.4,
        lineCap: LineCap.ROUND,
        lineJoin: LineJoin.ROUND,
      ));
    }

    // Add destination marker
    if (_destination != null) {
      await _addDestinationMarker(_destination!.latitude, _destination!.longitude);
    }
  }

  PointAnnotationManager? _destAnnotationManager;

  Future<void> _addDestinationMarker(double lat, double lng) async {
    if (_mapboxMap == null) return;
    _destAnnotationManager ??= await _mapboxMap!.annotations
        .createPointAnnotationManager(id: 'destination');
    await _destAnnotationManager!.deleteAll();

    final iconBytes = await _buildDestMarkerIcon();
    if (!mounted) return;

    await _destAnnotationManager!.create(PointAnnotationOptions(
      geometry: Point(coordinates: Position(lng, lat)),
      image: iconBytes,
      iconSize: 1.0,
      iconAnchor: IconAnchor.BOTTOM,
    ));
  }

  Future<Uint8List> _buildDestMarkerIcon() async {
    const w = 144.0;
    const h = 176.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));

    // Flagpole (stick)
    final polePaint = Paint()..color = Colors.grey.shade700..strokeWidth = 5;
    canvas.drawLine(const Offset(36, 16), const Offset(36, h - 8), polePaint);

    // Flag body (checkered pattern)
    const flagLeft = 36.0;
    const flagTop = 16.0;
    const flagW = 88.0;
    const flagH = 64.0;
    const cellSize = 16.0;

    // Flag background
    canvas.drawRect(
      Rect.fromLTWH(flagLeft, flagTop, flagW, flagH),
      Paint()..color = Colors.white,
    );

    // Checkered squares
    final blackPaint = Paint()..color = Colors.black;
    for (int row = 0; row < (flagH / cellSize).ceil(); row++) {
      for (int col = 0; col < (flagW / cellSize).ceil(); col++) {
        if ((row + col) % 2 == 0) {
          final x = flagLeft + col * cellSize;
          final y = flagTop + row * cellSize;
          canvas.drawRect(
            Rect.fromLTWH(x, y, cellSize.clamp(0, flagLeft + flagW - x), cellSize.clamp(0, flagTop + flagH - y)),
            blackPaint,
          );
        }
      }
    }

    // Flag border
    canvas.drawRect(
      Rect.fromLTWH(flagLeft, flagTop, flagW, flagH),
      Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 1.5,
    );

    // Ground dot
    canvas.drawCircle(Offset(36, h - 8), 7, Paint()..color = _modeColor);

    final picture = recorder.endRecording();
    final img = await picture.toImage(w.toInt(), h.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  void _removeDestinationMarker() {
    _destAnnotationManager?.deleteAll();
  }

  Future<void> _fitToRoute() async {
    if (_mapboxMap == null || _routePoints.isEmpty) return;

    // Hide TopBar during route preview for full map visibility
    NavigationState.instance.startNavigation();

    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (final p in _routePoints) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }
    // Include current position
    minLat = math.min(minLat, _lat);
    maxLat = math.max(maxLat, _lat);
    minLng = math.min(minLng, _lng);
    maxLng = math.max(maxLng, _lng);

    // Calculate zoom from bounding box — smooth logarithmic scale
    final latDiff = maxLat - minLat;
    final lngDiff = maxLng - minLng;
    final maxDiff = math.max(latDiff, lngDiff);
    // log2-based zoom: more accurate across all route sizes
    // 360° at zoom 0, halves per zoom level → zoom = log2(360/maxDiff) - padding
    final zoom = maxDiff > 0
        ? (math.log(360.0 / maxDiff) / math.ln2 - 1.2).clamp(3.0, 16.0)
        : 14.0;

    await _mapboxMap!.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(
          (minLng + maxLng) / 2, (minLat + maxLat) / 2)),
        zoom: zoom,
        bearing: 0,
        pitch: 0,
        padding: MbxEdgeInsets(top: 80, left: 50, bottom: 300, right: 50),
      ),
      MapAnimationOptions(duration: 800),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  NAVIGATION
  // ═══════════════════════════════════════════════════════════════════════════

  void _startNavigation() {
    if (_currentRoute == null) return;
    _currentStepIndex = 0;
    _announcedThresholds.clear();
    _offRouteCount = 0;
    _arrivalAnnounced = false;
    _isNavigating = true;
    _lastTrimIndex = 0;
    // Initialize snap position to current GPS BEFORE any snap/trim call
    _snapLat = _lat;
    _snapLng = _lng;
    _setNavPuckMode(true); // Hide native puck, show route-snapped marker
    // Immediately snap to route so puck starts on the line
    _updateSnapLine();
    _updateNavPuck();
    NavigationState.instance.startNavigation(); // Hide TopBar + BottomNav
    _remainingDistKm = _currentRoute!.distanceKm;
    _remainingMin = (_currentRoute!.durationSeconds / 60).round();

    final first = _currentRoute!.steps.isNotEmpty
        ? _currentRoute!.steps.first.instruction : 'Route gestartet';
    if (_currentRoute!.steps.isNotEmpty) {
      _currentManeuver = _currentRoute!.steps.first.maneuver;
      _currentStepRef = _currentRoute!.steps.first.ref;
      _currentDestinations = _currentRoute!.steps.first.destinations;
    }
    _ttsSpeak('Navigation gestartet. $first');

    _nextInstruction = first;

    // Calculate initial heading from snap point toward route ahead (~200m)
    if (_routePoints.length >= 2) {
      // Find the closest route point to GPS
      int startIdx = 0;
      double minDist = double.infinity;
      for (int i = 0; i < _routePoints.length; i++) {
        final d = geo.Geolocator.distanceBetween(
          _lat, _lng, _routePoints[i].latitude, _routePoints[i].longitude);
        if (d < minDist) { minDist = d; startIdx = i; }
      }
      // Find a point ~200m ahead on the route
      int aheadIdx = startIdx;
      double dist = 0;
      for (int i = startIdx; i < _routePoints.length - 1; i++) {
        dist += geo.Geolocator.distanceBetween(
          _routePoints[i].latitude, _routePoints[i].longitude,
          _routePoints[i + 1].latitude, _routePoints[i + 1].longitude);
        aheadIdx = i + 1;
        if (dist >= 200) break;
      }
      final p0 = _routePoints[startIdx];
      final p1 = _routePoints[aheadIdx];
      final dy = p1.latitude - p0.latitude;
      final dx = p1.longitude - p0.longitude;
      _heading = (math.atan2(dx, dy) * 180 / math.pi + 360) % 360;
    }

    // Initialize camera interpolation at start position
    _camLat = _snapLat != 0 ? _snapLat : _lat;
    _camLng = _snapLng != 0 ? _snapLng : _lng;
    _camBearing = _heading;

    // Show traffic layer during navigation
    try { _mapboxMap?.style.setStyleLayerProperty('traffic-layer', 'visibility', '"visible"'); } catch (_) {}

    // Immediate flyTo: orient camera in route direction with nav zoom
    _mapboxMap?.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(_camLng, _camLat)),
        zoom: 16.5,
        bearing: _heading,
        pitch: 35.0,
        padding: MbxEdgeInsets(top: _cachedPuckPad, left: 0, bottom: 0, right: 0),
      ),
      MapAnimationOptions(duration: 800),
    );

    _startFollow();
    setState(() {});
  }

  // Interpolation state for smooth camera
  double _camLat = 0, _camLng = 0, _camBearing = 0, _camZoom = 13.0, _camPitch = 0.0;
  double _targetLat = 0, _targetLng = 0, _targetBearing = 0;

  void _startFollow() {
    _isFollowing = true;
    _followTimer?.cancel();

    if (_isNavigating) {
      // NAVIGATION: 60fps-like interpolated camera (every 33ms)
      _followTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
        if (!_isFollowing || _mapboxMap == null || !mounted) return;

        // Update target from GPS/snap every tick
        if (_routePoints.isNotEmpty) {
          _updateSnapLine();
          _trimPassedRoutePoints();
          _updateNavPuck(); // Move puck to snapped position on route
        }

        _targetLat = _snapLat != 0 ? _snapLat : _lat;
        _targetLng = _snapLng != 0 ? _snapLng : _lng;
        // Use route bearing for camera (smoother than GPS heading on curves)
        _targetBearing = _routeBearing != 0 ? _routeBearing : _heading;

        // ── Dynamic zoom + pitch (Waze-style) ──
        // Closer when slow, farther when fast, 3D tilt when stopped/slow
        final bool isStopped = _displaySpeed < 5;
        final bool isManeuverClose = _distToManeuver < 150;
        final bool isManeuverVeryClose = _distToManeuver < 60;
        final bool isTurnManeuver = _currentManeuver != null &&
            _currentManeuver != 'continue' &&
            _currentManeuver != 'straight' &&
            _currentManeuver != 'new-name' &&
            _currentManeuver != 'depart';

        double targetZoom;
        double targetPitch;
        if (isStopped) {
          targetZoom = 20.0;
          targetPitch = 45.0;
        } else if (_displaySpeed < 10) {
          targetZoom = 19.0;
          targetPitch = 35.0;
        } else if (_displaySpeed < 20) {
          targetZoom = 18.0;
          targetPitch = 25.0;
        } else if (_displaySpeed < 30) {
          targetZoom = 17.0;
          targetPitch = 15.0;
        } else if (_displaySpeed < 40) {
          targetZoom = 16.0;
          targetPitch = 0.0;
        } else if (_displaySpeed < 60) {
          targetZoom = 15.0;
          targetPitch = 0.0;
        } else if (_displaySpeed < 100) {
          targetZoom = 12.0;
          targetPitch = 0.0;
        } else if (_displaySpeed < 120) {
          targetZoom = 12.0;
          targetPitch = 0.0;
        } else {
          targetZoom = 12.0;  // Autobahn schnell
          targetPitch = 0.0;
        }

        // In 3D mode: force 55° pitch, ignore speed-based pitch
        if (_is3D) {
          targetPitch = 55.0;
        }

        // Smooth zoom + pitch transition (prevent jarring jumps)
        _camZoom += (targetZoom - _camZoom) * 0.06;
        _camPitch += (targetPitch - _camPitch) * (_is3D ? 0.15 : 0.04);

        // Lerp factor: higher at higher zoom to prevent puck drift
        final double lerpFactor;
        if (_camZoom >= 15.0) {
          lerpFactor = 0.25; // Very snappy at high zoom
        } else if (_camZoom >= 14.0) {
          lerpFactor = 0.18; // Snappy to reduce visible drift
        } else if (_displaySpeed > 80) {
          lerpFactor = 0.12;
        } else if (_displaySpeed > 40) {
          lerpFactor = 0.10;
        } else {
          lerpFactor = 0.08;
        }

        // Snap-Reset: wenn Kamera zu weit vom Puck weg (> 200m),
        // sofort hart zentrieren — verhindert dass Puck aus dem Bild wandert.
        final lagDist = geo.Geolocator.distanceBetween(
            _camLat, _camLng, _targetLat, _targetLng);
        if (lagDist > 200) {
          _camLat = _targetLat;
          _camLng = _targetLng;
        } else {
          _camLat += (_targetLat - _camLat) * lerpFactor;
          _camLng += (_targetLng - _camLng) * lerpFactor;
        }

        // Bearing lerp — faster at high zoom for smoother feel
        final bearingLerp = _camZoom >= 14.0 ? 0.15 : 0.10;
        double bDiff = _targetBearing - _camBearing;
        if (bDiff > 180) bDiff -= 360;
        if (bDiff < -180) bDiff += 360;
        _camBearing = (_camBearing + bDiff * bearingLerp) % 360;

        final zoom = _camZoom;

        _mapboxMap!.setCamera(
          CameraOptions(
            center: Point(coordinates: Position(_camLng, _camLat)),
            zoom: zoom,
            bearing: _camBearing,
            pitch: _camPitch,
            padding: MbxEdgeInsets(top: _cachedPuckPad, left: 0, bottom: 0, right: 0),
          ),
        );
      });
    } else {
      // NON-NAVIGATION: slower flyTo (every 1.5s)
      _followTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
        if (!_isFollowing || _mapboxMap == null || !mounted) return;
        final zoom = 16.0;
        _mapboxMap!.flyTo(
          CameraOptions(
            center: Point(coordinates: Position(_lng, _lat)),
            zoom: zoom,
            bearing: 0,
            pitch: 0,
            padding: MbxEdgeInsets(top: _cachedPuckPad, left: 0, bottom: 0, right: 0),
          ),
          MapAnimationOptions(duration: 1500),
        );
      });
    }
  }

  void _onNavTick() {
    if (_currentRoute == null) return;

    // Off-route detection — speed-adaptive thresholds
    // Autobahn needs huge tolerance (4 lanes + GPS drift + construction zones)
    final double offThreshold;
    final double resetThreshold;
    final int requiredTicks;
    if (_routeMode == RouteMode.pedestrian) {
      offThreshold = 40.0;
      resetThreshold = 25.0;
      requiredTicks = 4;
    } else if (_displaySpeed > 100) {
      // Autobahn schnell: construction splits, GPS drift at high speed
      offThreshold = 120.0;
      resetThreshold = 70.0;
      requiredTicks = 6;
    } else if (_displaySpeed > 80) {
      // Autobahn normal
      offThreshold = 100.0;
      resetThreshold = 60.0;
      requiredTicks = 5;
    } else if (_displaySpeed > 50) {
      // Bundesstraße
      offThreshold = 50.0;
      resetThreshold = 30.0;
      requiredTicks = 4;
    } else {
      // City — 30m wie gewünscht
      offThreshold = 30.0;
      resetThreshold = 18.0;
      requiredTicks = 3;
    }
    final dRoute = _minDistToRoute();
    // Cooldown: mindestens 10s zwischen Reroutes (vermeidet Dauer-Neuberechnung)
    final cooldownOk = _lastRerouteAt == null ||
        DateTime.now().difference(_lastRerouteAt!) > _rerouteCooldown;
    if (dRoute > offThreshold && !_isRerouting && _displaySpeed > 0 && cooldownOk) {
      _offRouteCount++;
      if (_offRouteCount >= requiredTicks) { _offRouteCount = 0; _reroute(); return; }
    } else if (dRoute < resetThreshold) { _offRouteCount = 0; }

    // Steps — OSRM step.location is where the maneuver happens (turn point).
    // We measure distance to the NEXT step's location to know when to advance.
    // "depart" step is skipped immediately since we're already moving.
    final steps = _currentRoute!.steps;

    // Auto-skip "depart" step (Step 0) — it's just the start point
    if (steps.isNotEmpty && _currentStepIndex < steps.length) {
      final curManeuver = steps[_currentStepIndex].maneuver ?? '';
      if (curManeuver == 'depart' && _currentStepIndex + 1 < steps.length) {
        _currentStepIndex++;
      }
    }

    if (steps.isNotEmpty && _currentStepIndex < steps.length) {
      final step = steps[_currentStepIndex];
      // Distance to THIS step's maneuver point (where you need to turn)
      final d = geo.Geolocator.distanceBetween(
          _lat, _lng, step.location.latitude, step.location.longitude);
      _distToManeuver = d;

      // ── TTS at threshold crossings (one-time) ──
      final curManeuver = step.maneuver ?? '';
      final isBoringStep = curManeuver == 'continue' || curManeuver == 'new-name' || curManeuver == 'straight';

      // ── TTS: MAX 2 announcements per turn (Vorwarnung + Jetzt) ──
      // Skip boring steps (geradeaus) completely — no TTS for those.
      if (!isBoringStep) {
        String? th, dt;
        if (d <= 40) {
          th = 'now'; dt = 'Jetzt';
        } else if (d <= 300 && _displaySpeed <= 60) {
          // City/slow: one early warning at ~300m
          th = 'early'; dt = 'In ${(d / 50).round() * 50} Metern';
        } else if (d <= 600 && _displaySpeed > 60) {
          // Fast roads: one early warning at ~600m
          th = 'early'; dt = 'In ${(d / 100).round() * 100} Metern';
        }

        if (th != null) {
          final key = '$_currentStepIndex:$th';
          if (!_announcedThresholds.contains(key)) {
            _announcedThresholds.add(key);
            final enriched = _enrichInstruction(step);
            final msg = '$dt, $enriched';
            final now = DateTime.now();
            if (enriched != _lastTtsInstruction ||
                now.difference(_lastTtsTime).inSeconds > 30) {
              _lastTtsInstruction = step.instruction;
              _lastTtsTime = now;
              _ttsSpeak(msg);
            }
          }
        }
      }

      // ── Motivations-Sprüche bei langer Stille (> 3 Min) ──
      if (_displaySpeed > 30) {
        final silenceDur = DateTime.now().difference(_lastTtsTime).inSeconds;
        if (silenceDur > 180) {
          const sprueche = [
            'Racer, bleib konzentriert und fahr vorsichtig!',
            'Alles klar? Genieß die Fahrt!',
            'Du machst das super, weiter so!',
            'Augen auf die Straße, Racer!',
            'Noch ${0} Kilometer bis zum Ziel, weiter geht\'s!',
          ];
          final idx = DateTime.now().second % (sprueche.length - 1); // skip template
          String msg = sprueche[idx];
          if (idx == sprueche.length - 1) {
            msg = 'Noch ${_remainingDistKm.toStringAsFixed(0)} Kilometer bis zum Ziel, weiter geht\'s!';
          }
          _lastTtsTime = DateTime.now();
          _ttsSpeak(msg);
        }
      }

      // ── Banner: always update with live distance ──
      final liveDistText = d <= 40
          ? 'Jetzt'
          : d < 1000
              ? 'In ${(d / 10).round() * 10} m'
              : 'In ${(d / 1000).toStringAsFixed(1)} km';

      // If current step is a boring "continue/straight/new-name" and far away (>600m),
      // look ahead to the next real turn and show that instead
      final curM = step.maneuver ?? '';
      final isBoring = curM == 'continue' || curM == 'new-name' || curM == 'straight';
      if (isBoring && d > 600) {
        // Find next real maneuver
        String? nextRealInstruction;
        String? nextRealManeuver;
        double extraDist = d;
        for (int j = _currentStepIndex + 1; j < steps.length; j++) {
          final ns = steps[j];
          final nm = ns.maneuver ?? '';
          if (nm != 'continue' && nm != 'new-name' && nm != 'straight' && nm != 'depart') {
            // Calculate total distance to this step
            for (int k = _currentStepIndex; k < j; k++) {
              if (k + 1 < steps.length) {
                extraDist += geo.Geolocator.distanceBetween(
                  steps[k].location.latitude, steps[k].location.longitude,
                  steps[k + 1].location.latitude, steps[k + 1].location.longitude,
                );
              }
            }
            final distText = extraDist < 1000
                ? 'In ${(extraDist / 10).round() * 10} m'
                : 'In ${(extraDist / 1000).toStringAsFixed(1)} km';
            nextRealInstruction = '$distText — ${_enrichInstruction(ns)}';
            nextRealManeuver = nm;
            break;
          }
        }
        if (nextRealInstruction != null) {
          _nextInstruction = nextRealInstruction;
          _currentManeuver = nextRealManeuver;
          // Find the lookahead step to get its ref
          for (int j = _currentStepIndex + 1; j < steps.length; j++) {
            final ns = steps[j];
            final nm = ns.maneuver ?? '';
            if (nm != 'continue' && nm != 'straight' && nm != 'new-name' && nm != 'depart') {
              _currentStepRef = ns.ref;
              _currentDestinations = ns.destinations;
              break;
            }
          }
        } else {
          _nextInstruction = '$liveDistText — ${_enrichInstruction(step)}';
          _currentManeuver = curM;
          _currentStepRef = step.ref;
          _currentDestinations = step.destinations;
        }
      } else {
        _nextInstruction = '$liveDistText — ${_enrichInstruction(step)}';
        _currentManeuver = curM;
        _currentStepRef = step.ref;
        _currentDestinations = step.destinations;
      }

      // Advance step when close to the maneuver point (within 40m)
      // BUT only if moving (>5 km/h) — prevents jumping ahead while standing still at start
      // OR when we've clearly passed it (next step is closer than current)
      bool shouldAdvance = d <= 40 && _displaySpeed > 5;
      if (!shouldAdvance && _currentStepIndex + 1 < steps.length) {
        final nextStep = steps[_currentStepIndex + 1];
        final dNext = geo.Geolocator.distanceBetween(
          _lat, _lng, nextStep.location.latitude, nextStep.location.longitude);
        // If next step is closer than current step → we passed the current turn
        if (dNext < d && d > 60) shouldAdvance = true;
      }
      if (shouldAdvance) {
        _currentStepIndex++;
        // Skip boring intermediate steps (depart, continue, straight, new-name)
        // so banner immediately shows the next REAL maneuver
        while (_currentStepIndex < steps.length) {
          final nextM = steps[_currentStepIndex].maneuver ?? '';
          final isBoring = nextM == 'depart' || nextM == 'continue' || nextM == 'straight' || nextM == 'new-name';
          if (!isBoring) break;
          // Only skip if the next step is also close (< 500m) or there's another step after
          if (_currentStepIndex + 1 < steps.length) {
            final skipDist = steps[_currentStepIndex].distanceMeters;
            if (skipDist < 500) {
              _currentStepIndex++;
              continue;
            }
          }
          break; // Don't skip if it's the last step or > 500m
        }
        if (_currentStepIndex < steps.length) {
          final advStep = steps[_currentStepIndex];
          _nextInstruction = advStep.instruction;
          _currentManeuver = advStep.maneuver;
          _currentStepRef = advStep.ref;
          _currentDestinations = advStep.destinations;
        }
      }
    }

    // Arrival + Remaining distance/time from route steps (not air distance)
    if (_destination != null) {
      final dd = geo.Geolocator.distanceBetween(_lat, _lng, _destination!.latitude, _destination!.longitude);
      if (dd < 30 && !_arrivalAnnounced) {
        _arrivalAnnounced = true;
        _ttsSpeak('Ziel erreicht. ${_destName ?? ""}');
        _isNavigating = false;
        _followTimer?.cancel();
      }
      // Calculate remaining distance from route steps (more accurate than air distance)
      double remainM = 0;
      if (steps.isNotEmpty && _currentStepIndex < steps.length) {
        // Distance to current step's maneuver point
        remainM += geo.Geolocator.distanceBetween(
          _lat, _lng, steps[_currentStepIndex].location.latitude, steps[_currentStepIndex].location.longitude);
        // Sum all remaining steps' distances
        for (int i = _currentStepIndex; i < steps.length; i++) {
          remainM += steps[i].distanceMeters;
        }
      } else {
        remainM = dd;
      }
      _remainingDistKm = remainM / 1000;
      // Use OSRM estimated duration from remaining steps
      double remainSec = 0;
      for (int i = _currentStepIndex; i < steps.length; i++) {
        remainSec += steps[i].durationSeconds;
      }
      _remainingMin = (remainSec / 60).round();
      if (_remainingMin < 1 && remainM > 50) _remainingMin = 1;
    }
  }

  /// Project GPS position onto nearest route segment (snap-to-route).
  /// Returns null if too far from route (>50m) — use raw GPS instead.
  LatLng? _snapToRoute(double lat, double lng) {
    double minDist = double.infinity;
    LatLng? closest;

    for (int i = 0; i < _routePoints.length - 1; i++) {
      final a = _routePoints[i];
      final b = _routePoints[i + 1];

      // Project point onto line segment a→b
      final dx = b.longitude - a.longitude;
      final dy = b.latitude - a.latitude;
      final lenSq = dx * dx + dy * dy;
      if (lenSq == 0) continue;

      var t = ((lng - a.longitude) * dx + (lat - a.latitude) * dy) / lenSq;
      t = t.clamp(0.0, 1.0);

      final projLat = a.latitude + t * dy;
      final projLng = a.longitude + t * dx;

      final d = geo.Geolocator.distanceBetween(lat, lng, projLat, projLng);
      if (d < minDist) {
        minDist = d;
        closest = LatLng(projLat, projLng);
      }
    }

    // Only snap if within 50m of route
    return (minDist <= 50 && closest != null) ? closest : null;
  }

  double _minDistToRoute() {
    double min = double.infinity;
    // Check EVERY point, not every 3rd — critical for curves
    for (int i = _lastTrimIndex; i < _routePoints.length; i++) {
      final d = geo.Geolocator.distanceBetween(_lat, _lng, _routePoints[i].latitude, _routePoints[i].longitude);
      if (d < min) min = d;
      // Early exit if distance starts increasing significantly
      if (d > min + 200) break;
    }
    return min;
  }

  /// Remove route points that the user has already passed.
  /// This makes the route line "disappear" behind the puck.
  int _lastTrimIndex = 0;
  void _trimPassedRoutePoints() {
    if (_routePoints.length < 2 || _mapboxMap == null) return;
    // Don't trim with uninitialized coordinates
    if (_snapLat == 0 && _snapLng == 0 && _lat == 0 && _lng == 0) return;

    // Use snap position (on route) instead of raw GPS for accurate trimming
    final useLat = (_snapLat != 0) ? _snapLat : _lat;
    final useLng = (_snapLng != 0) ? _snapLng : _lng;

    // Find closest point on route
    double minDist = double.infinity;
    int closestIdx = _lastTrimIndex;
    final start = (_lastTrimIndex > 5) ? _lastTrimIndex - 5 : 0;
    for (int i = start; i < _routePoints.length; i++) {
      final d = geo.Geolocator.distanceBetween(useLat, useLng, _routePoints[i].latitude, _routePoints[i].longitude);
      if (d < minDist) {
        minDist = d;
        closestIdx = i;
      }
      if (d > minDist + 50) break;
    }

    if (closestIdx > _lastTrimIndex) {
      _lastTrimIndex = closestIdx;
    }
    // Always redraw from snap point — route starts exactly at puck
    final remaining = _routePoints.sublist(_lastTrimIndex);
    if (remaining.length > 1) {
      // Start the line from the exact snap point, then continue with route
      final coords = StringBuffer();
      coords.write('[$_snapLng,$_snapLat]');
      for (final p in remaining) {
        coords.write(',[${p.longitude},${p.latitude}]');
      }
      final geoJson = '{"type":"Feature","geometry":{"type":"LineString","coordinates":[${coords.toString()}]}}';
      try {
        _mapboxMap!.style.setStyleSourceProperty('route-src-$_selectedRouteIdx', 'data', geoJson);
      } catch (_) {}
    }
  }

  double _snapLat = 0, _snapLng = 0; // Snapped position on route
  bool _navPuckHidden = false;

  // ── Route-snapped puck (PointAnnotation) ──
  PointAnnotationManager? _navPuckManager;
  PointAnnotation? _navPuckAnnotation;
  double _routeBearing = 0; // Bearing from route segment (not GPS heading)

  /// Switch puck appearance for navigation vs idle.
  /// During navigation: hide native LocationPuck2D, show PointAnnotation on route.
  /// Idle: restore native LocationPuck2D, remove PointAnnotation.
  void _setNavPuckMode(bool navigating) {
    if (_mapboxMap == null) return;
    if (navigating && !_navPuckHidden) {
      _navPuckHidden = true;
      _createNavPuckAnnotation();
    } else if (!navigating && _navPuckHidden) {
      _navPuckHidden = false;
      _removeNavPuckAnnotation();
      // Restore native puck
      _navPuckIconRegistered = false;
      _applyCustomPuck();
    }
  }

  /// Create route-snapped PointAnnotation puck
  Future<void> _createNavPuckAnnotation() async {
    if (_mapboxMap == null) return;
    try {
      // Hide native LocationPuck2D
      await _mapboxMap!.location.updateSettings(LocationComponentSettings(
        enabled: false,
      ));

      // Generate puck image
      final bytes = await _generatePuckPng();
      if (bytes == null) return;
      _lastPuckBytes = bytes;

      // Create annotation manager
      _navPuckManager = await _mapboxMap!.annotations
          .createPointAnnotationManager(id: 'nav-puck');

      // Allow overlap so puck is always visible above other markers
      await _navPuckManager!.setIconAllowOverlap(true);
      await _navPuckManager!.setIconIgnorePlacement(true);

      // Create annotation at snapped position
      _navPuckAnnotation = await _navPuckManager!.create(PointAnnotationOptions(
        geometry: Point(coordinates: Position(
          _snapLng != 0 ? _snapLng : _lng,
          _snapLat != 0 ? _snapLat : _lat,
        )),
        image: bytes,
        iconSize: 1.1, // Double size for visibility
        iconRotate: _heading,
      ));

      debugPrint('[NavPuck] PointAnnotation created at snap position');
    } catch (e) {
      debugPrint('[NavPuck] Error creating annotation: $e');
      // Fallback: re-enable native puck
      _navPuckIconRegistered = false;
      _applyCustomPuck();
    }
  }

  /// Remove route-snapped PointAnnotation puck
  Future<void> _removeNavPuckAnnotation() async {
    try {
      if (_navPuckAnnotation != null && _navPuckManager != null) {
        await _navPuckManager!.delete(_navPuckAnnotation!);
      }
      if (_navPuckManager != null) {
        await _mapboxMap?.annotations.removeAnnotationManager(_navPuckManager!);
      }
    } catch (_) {}
    _navPuckAnnotation = null;
    _navPuckManager = null;

    // Re-enable native LocationPuck2D
    try {
      await _mapboxMap?.location.updateSettings(LocationComponentSettings(
        enabled: true,
        puckBearingEnabled: true,
        puckBearing: PuckBearing.HEADING,
        locationPuck: _cachedLocationPuck,
      ));
    } catch (_) {}
  }

  bool _navPuckIconRegistered = false;
  Uint8List? _lastPuckBytes; // Cache to avoid re-setting same image
  LocationPuck? _cachedLocationPuck; // Cache full LocationPuck to prevent reset

  ui.Image? _cachedAvatarImg; // Cached profile image to avoid re-downloading

  /// Generate puck PNG bytes — profile photo in circle with colored ring
  Future<Uint8List?> _generatePuckPng() async {
    const px = 380;
    const r = 80.0; // avatar radius
    const border = 12.0; // colored ring width
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, px.toDouble(), px.toDouble()));
    final cx = px / 2.0;
    final cy = px / 2.0;
    final modeColor = Color(_modeColor.value);

    // Load avatar once and cache
    if (_cachedAvatarImg == null) {
      try {
        final authState = ref.read(authNotifierProvider);
        if (authState is Authenticated && authState.user.avatarUrl != null) {
          final url = authState.user.avatarUrl!;
          final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
          if (response.statusCode == 200) {
            final codec = await ui.instantiateImageCodec(response.bodyBytes);
            final frame = await codec.getNextFrame();
            _cachedAvatarImg = frame.image;
          }
        }
      } catch (e) {
        debugPrint('[NavPuck] Avatar load error: $e');
      }
    }

    // Outer accuracy ring (translucent)
    canvas.drawCircle(Offset(cx, cy), 164,
      Paint()..color = modeColor.withValues(alpha: 0.12));
    canvas.drawCircle(Offset(cx, cy), 164,
      Paint()..color = modeColor.withValues(alpha: 0.25)..style = PaintingStyle.stroke..strokeWidth = 3);

    // Shadow under circle
    canvas.drawCircle(Offset(cx, cy + 6), r + border,
      Paint()..color = Colors.black.withValues(alpha: 0.35)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));

    // Colored ring border
    canvas.drawCircle(Offset(cx, cy), r + border, Paint()..color = modeColor);
    // White inner border
    canvas.drawCircle(Offset(cx, cy), r + 1, Paint()..color = Colors.white);

    if (_cachedAvatarImg != null) {
      // Clip avatar to circle and draw
      canvas.save();
      canvas.clipPath(Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r)));
      canvas.drawImageRect(
        _cachedAvatarImg!,
        Rect.fromLTWH(0, 0, _cachedAvatarImg!.width.toDouble(), _cachedAvatarImg!.height.toDouble()),
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        Paint(),
      );
      canvas.restore();
    } else {
      // Fallback: colored circle with first letter
      canvas.drawCircle(Offset(cx, cy), r, Paint()..color = modeColor);
      try {
        final authState = ref.read(authNotifierProvider);
        if (authState is Authenticated) {
          final letter = (authState.user.username ?? 'B')[0].toUpperCase();
          final tp = TextPainter(
            text: TextSpan(text: letter, style: const TextStyle(color: Colors.white, fontSize: 64, fontWeight: FontWeight.bold)),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
        }
      } catch (_) {}
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(px, px);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;
    return byteData.buffer.asUint8List();
  }

  /// Apply custom vehicle puck icon as native LocationPuck2D
  Future<void> _applyCustomPuck() async {
    if (_mapboxMap == null) return;
    try {
      final bytes = await _generatePuckPng();
      if (bytes == null) return;
      _lastPuckBytes = bytes;

      // Scale puck smaller when zoomed out, larger when zoomed in
      const scaleExpr = '["interpolate",["linear"],["zoom"],'
          '12,0.35,'
          '14,0.5,'
          '16,0.7,'
          '18,0.9,'
          '20,1.1]';

      _cachedLocationPuck = LocationPuck(
        locationPuck2D: LocationPuck2D(
          topImage: bytes,
          bearingImage: bytes,
          shadowImage: Uint8List(0), // no shadow — we draw our own
          opacity: 1.0,
          scaleExpression: scaleExpr,
        ),
      );

      await _mapboxMap!.location.updateSettings(LocationComponentSettings(
        enabled: true,
        puckBearingEnabled: true,
        puckBearing: PuckBearing.HEADING,
        locationPuck: _cachedLocationPuck,
      ));
      _navPuckIconRegistered = true;
      debugPrint('[NavPuck] Custom LocationPuck2D applied for mode=$_routeMode');
    } catch (e) {
      debugPrint('[NavPuck] Error applying custom puck: $e');
    }
  }

  /// Map zoom → nav puck icon scale (smaller when zoomed out).
  double _navPuckScale(double zoom) {
    if (zoom >= 20) return 1.1;
    if (zoom >= 18) return 0.9;
    if (zoom >= 16) return 0.7;
    if (zoom >= 14) return 0.5;
    return 0.35;
  }

  /// Update route-snapped puck position and bearing.
  /// Called every GPS tick during navigation.
  void _updateNavPuck() {
    if (_navPuckAnnotation == null || _navPuckManager == null) return;
    if (_snapLat == 0 && _snapLng == 0) return;

    // Calculate bearing from route direction (next route point after snap)
    _updateRouteBearing();

    try {
      _navPuckAnnotation!.geometry = Point(coordinates: Position(_snapLng, _snapLat));
      _navPuckAnnotation!.iconRotate = _routeBearing;
      _navPuckAnnotation!.iconSize = _navPuckScale(_camZoom);
      _navPuckManager!.update(_navPuckAnnotation!);
    } catch (e) {
      debugPrint('[NavPuck] Update error: $e');
    }
  }

  /// Calculate bearing from current snap position to next route point.
  /// This gives a smoother bearing than GPS heading since it follows the road.
  void _updateRouteBearing() {
    if (_routePoints.isEmpty) {
      _routeBearing = _heading;
      return;
    }
    // Find the route point just ahead of current snap position
    final searchStart = (_lastTrimIndex > 0) ? _lastTrimIndex : 0;
    for (int i = searchStart; i < _routePoints.length - 1; i++) {
      final p = _routePoints[i];
      final d = geo.Geolocator.distanceBetween(_snapLat, _snapLng, p.latitude, p.longitude);
      if (d < 30) {
        // Found nearby point — use bearing to next point
        final next = _routePoints[i + 1];
        final dLng = (next.longitude - p.longitude) * math.pi / 180;
        final lat1 = p.latitude * math.pi / 180;
        final lat2 = next.latitude * math.pi / 180;
        final y = math.sin(dLng) * math.cos(lat2);
        final x = math.cos(lat1) * math.sin(lat2) -
            math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
        _routeBearing = (math.atan2(y, x) * 180 / math.pi + 360) % 360;
        return;
      }
    }
    // Fallback: use GPS heading
    _routeBearing = _heading;
  }

  /// Find nearest point on route and snap camera to it
  void _updateSnapLine() {
    if (_routePoints.isEmpty || _mapboxMap == null || !_isNavigating) return;
    // Find nearest route point — search ALL points (not just from trimIndex)
    // to handle GPS jumps and ensure we always find the closest point
    double minD = double.infinity;
    int nearIdx = 0;
    final searchStart = (_lastTrimIndex > 10) ? _lastTrimIndex - 10 : 0;
    for (int i = searchStart; i < _routePoints.length; i++) {
      final d = geo.Geolocator.distanceBetween(_lat, _lng, _routePoints[i].latitude, _routePoints[i].longitude);
      if (d < minD) { minD = d; nearIdx = i; }
      if (d > minD + 100) break; // wider search window
    }
    // Only snap if within reasonable distance (200m) — beyond that, GPS is too far off
    if (minD < 200) {
      _snapLat = _routePoints[nearIdx].latitude;
      _snapLng = _routePoints[nearIdx].longitude;
    }

    // Draw connector line from GPS to snapped point (only if > 15m off route)
    if (minD < 15) {
      try { _mapboxMap!.style.setStyleSourceProperty('snap-line-src', 'data',
        '{"type":"Feature","geometry":{"type":"LineString","coordinates":[]}}'); } catch (_) {}
      return;
    }
    final geoJson = '{"type":"Feature","geometry":{"type":"LineString","coordinates":'
        '[[$_lng,$_lat],[$_snapLng,$_snapLat]]}}';
    try {
      _mapboxMap!.style.setStyleSourceProperty('snap-line-src', 'data', geoJson);
    } catch (_) {
      try {
        _mapboxMap!.style.addSource(GeoJsonSource(id: 'snap-line-src', data: geoJson));
        _mapboxMap!.style.addLayer(LineLayer(
          id: 'snap-line-layer',
          sourceId: 'snap-line-src',
          lineColor: _modeColor.value,
          lineWidth: 2.0,
          lineDasharray: [4.0, 4.0],
          lineOpacity: 0.6,
        ));
      } catch (_) {}
    }
  }

  Future<void> _reroute() async {
    _isRerouting = true;
    _lastRerouteAt = DateTime.now();
    TtsAlertService.instance.clearQueue();
    _ttsSpeak('Route wird neu berechnet.');

    // Clear stale instruction while rerouting — so turn-arrow doesn't show
    // the wrong direction (user saw "left" while actually going right etc.)
    _nextInstruction = 'Neue Route wird berechnet …';
    _currentManeuver = null;
    _currentStepRef = null;
    _currentDestinations = null;
    _distToManeuver = 0;
    if (mounted) setState(() {});

    // Immediately clear old route lines from map
    if (_mapboxMap != null) {
      final style = _mapboxMap!.style;
      for (int i = 0; i < 5; i++) {
        try { await style.removeStyleLayer('route-$i'); } catch (_) {}
        try { await style.removeStyleLayer('route-border-$i'); } catch (_) {}
        try { await style.removeStyleSource('route-src-$i'); } catch (_) {}
      }
    }

    if (_destination == null) { _isRerouting = false; return; }

    try {
      // Use single route for faster reroute (no alternatives needed mid-nav)
      final route = await _osrm.getRoute(
        LatLng(_lat, _lng), _destination!,
        mode: _routeMode,
      );
      if (route == null || !mounted) { _isRerouting = false; return; }

      _allRoutes = [route];
      _selectedRouteIdx = 0;
      _currentRoute = route;
      _routePoints = _currentRoute!.polylinePoints;
      _lastTrimIndex = 0;
      _currentStepIndex = 0;
      _announcedThresholds.clear();
      _remainingDistKm = _currentRoute!.distanceKm;
      _remainingMin = (_currentRoute!.durationSeconds / 60).round();

      await _drawRoutes();
      // DON'T call _fitToRoute() — stay in nav view, don't zoom out

      if (_currentRoute!.steps.isNotEmpty) {
        _nextInstruction = _currentRoute!.steps.first.instruction;
        _currentManeuver = _currentRoute!.steps.first.maneuver;
        _currentStepRef = _currentRoute!.steps.first.ref;
        _currentDestinations = _currentRoute!.steps.first.destinations;
      }

      _ttsSpeak('Neue Route berechnet.');
      _startFollow(); // Resume following
      setState(() {});
    } catch (e) {
      debugPrint('[Reroute] Error: $e');
    }

    _isRerouting = false;
  }

  void _stopNavigation() {
    _followTimer?.cancel();
    _isNavigating = false;
    _setNavPuckMode(false); // Restore native puck
    NavigationState.instance.stopNavigation(); // Show TopBar + BottomNav again
    _ttsSpeak('Navigation beendet.');
    _removeBlitzerFromMap(); // Blitzer-Punkte nur während Navigation sichtbar
    setState(() {});
  }

  void _clearRoute() {
    _currentRoute = null;
    _allRoutes = [];
    _routePoints = [];
    _destination = null;
    _destName = null;
    _isNavigating = false;
    _setNavPuckMode(false); // Restore native puck
    _followTimer?.cancel();
    NavigationState.instance.stopNavigation(); // Show TopBar + BottomNav again
    // Remove route layers + destination marker
    if (_mapboxMap != null) {
      for (int i = 0; i < 5; i++) {
        try { _mapboxMap!.style.removeStyleLayer('route-$i'); } catch (_) {}
        try { _mapboxMap!.style.removeStyleLayer('route-border-$i'); } catch (_) {}
        try { _mapboxMap!.style.removeStyleSource('route-src-$i'); } catch (_) {}
      }
    }
    _removeDestinationMarker();
    _routeBlitzerCount = 0;
    _destInfo = null;
    // Hide traffic layer when not navigating
    try { _mapboxMap?.style.setStyleLayerProperty('traffic-layer', 'visibility', '"none"'); } catch (_) {}
    // Reset blitzers to local radius only (remove route-extended ones)
    _reloadLocalBlitzers();
    setState(() {});
  }

  /// Reload blitzers for local 15km radius only (after route cleared)
  void _reloadLocalBlitzers() async {
    try {
      final cams = await OsmBlitzerService.instance.getAllGermany();
      _blitzerReports = cams
          .where((c) => OsmBlitzerService.distanceApprox(c.latitude, c.longitude, _lat, _lng) <= 30000)
          .map((c) => BlitzerReport.fromOsm(c))
          .toList();
      _drawBlitzerOnMap();
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  SPEED LIMIT + BLITZER
  // ═══════════════════════════════════════════════════════════════════════════

  void _startSpeedLimitPolling() {
    _speedLimitTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted) return;
      try {
        // Priority 0: Navigation step maxspeed (from OSRM route — exact match)
        // Only use when actually navigating AND the step already has a maxspeed.
        if (_isNavigating &&
            _currentRoute != null &&
            _currentStepIndex < _currentRoute!.steps.length) {
          final stepLimit = _currentRoute!.steps[_currentStepIndex].maxspeedKmh;
          if (stepLimit != null) {
            // 0 = "none" (Autobahn unlimited)
            if (mounted) {
              setState(() { _speedLimit = stepLimit; });
            }
            return;
          }
        }

        // Priority 1: HERE API (automotive-grade, 1000 req/day free)
        final hereLimit = await HereSpeedLimitService.instance.getSpeedLimit(
          _lat, _lng, heading: _heading,
        );
        if (hereLimit != null && mounted) {
          setState(() { _speedLimit = hereLimit; });
          return;
        }

        // Priority 2: Overpass API fallback (radius-based, less accurate)
        SpeedLimitService.instance.setCurrentSpeed(_displaySpeed);
        final r = await SpeedLimitService.instance.getSpeedLimit(_lat, _lng);
        if (mounted) {
          int? limit = r.effectiveLimitKmh;
          if (limit != null && limit > 0 && limit <= 50 && _speed > 80) {
            limit = null;
          }
          setState(() { _speedLimit = limit; _roadName = r.roadName; });
        }
      } catch (_) {}
    });
  }

  /// Count AND load blitzer along the route polyline (within 100m)
  void _countRouteBlitzers() async {
    if (_routePoints.isEmpty) { _routeBlitzerCount = 0; return; }
    try {
      final cams = await OsmBlitzerService.instance.getAllGermany();
      final routeBlitzers = <BlitzerReport>[];
      // Sample route every Nth point for performance
      final step = (_routePoints.length / 300).ceil().clamp(1, 50);
      for (final cam in cams) {
        for (int i = 0; i < _routePoints.length; i += step) {
          final d = geo.Geolocator.distanceBetween(
            cam.latitude, cam.longitude,
            _routePoints[i].latitude, _routePoints[i].longitude,
          );
          if (d <= 150) {
            routeBlitzers.add(BlitzerReport.fromOsm(cam));
            break;
          }
        }
      }
      _routeBlitzerCount = routeBlitzers.length;
      // Merge route blitzers with local blitzers (deduplicate)
      final existing = _blitzerReports.map((b) => '${b.latitude.toStringAsFixed(4)},${b.longitude.toStringAsFixed(4)}').toSet();
      for (final rb in routeBlitzers) {
        final key = '${rb.latitude.toStringAsFixed(4)},${rb.longitude.toStringAsFixed(4)}';
        if (!existing.contains(key)) {
          _blitzerReports.add(rb);
          existing.add(key);
        }
      }
      debugPrint('[Blitzer] Route: $_routeBlitzerCount, Total on map: ${_blitzerReports.length}');
      _drawBlitzerOnMap();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _loadBlitzers() async {
    try {
      // 1. Load OSM fixed cameras
      final cams = await OsmBlitzerService.instance.getAllGermany();
      debugPrint('[Blitzer] OSM total: ${cams.length}, GPS: $_lat, $_lng');
      // Use real GPS position, not PLZ — only filter if GPS is valid (not 0,0)
      final filterLat = _lat.abs() > 1 ? _lat : (_plzLat ?? _lat);
      final filterLng = _lng.abs() > 1 ? _lng : (_plzLng ?? _lng);
      _blitzerReports = cams
          .where((c) => OsmBlitzerService.distanceApprox(c.latitude, c.longitude, filterLat, filterLng) <= 30000)
          .map((c) => BlitzerReport.fromOsm(c))
          .toList();
      debugPrint('[Blitzer] In 15km radius: ${_blitzerReports.length}');
      _blitzerLoaded = true;
      // 2. Load community reports from Supabase (mobile, police, etc.)
      _loadCommunityBlitzers();
      // 3. Draw all on map
      _drawBlitzerOnMap();
    } catch (_) {}
  }

  // User-reported blitzer markers (via Hi Moto voice command)
  final List<Map<String, dynamic>> _userReportMarkers = [];

  // Color map for different report types
  static const _reportColors = <String, int>{
    'mobile':       0xFFFFEB3B, // Yellow — mobile blitzer
    'fixed':        0xFFFF5722, // Deep orange — fixed blitzer
    'police':       0xFF42A5F5, // Blue — police
    'hazard':       0xFFFF9800, // Orange — hazard
    'construction': 0xFFFF9800, // Orange — construction
    'traffic':      0xFFE53935, // Red — traffic jam
  };

  // Emoji for different report types (used as map marker text)
  static const _reportEmoji = <String, String>{
    'mobile':       '📸',
    'fixed':        '📷',
    'police':       '🚔',
    'hazard':       '⚠️',
    'construction': '🚧',
    'traffic':      '🚗',
  };

  void _addUserReportMarker(String type, String label) async {
    // Offset if another marker is already nearby (avoid overlap)
    double markerLat = _lat, markerLng = _lng;
    for (final m in _userReportMarkers) {
      final d = geo.Geolocator.distanceBetween(
        markerLat, markerLng, m['lat'] as double, m['lng'] as double,
      );
      if (d < 30) {
        // Shift ~25m in a unique direction based on marker count
        final angle = (_userReportMarkers.length * 90) * math.pi / 180;
        markerLat += (25 / 111320) * math.cos(angle);
        markerLng += (25 / (111320 * math.cos(_lat * math.pi / 180))) * math.sin(angle);
      }
    }

    _userReportMarkers.add({
      'lat': markerLat, 'lng': markerLng,
      'label': label, 'type': type,
      'heading': _heading,
      'time': DateTime.now().millisecondsSinceEpoch,
      'isMine': true,
    });

    // Traffic jam → only draw line on route during navigation
    if (type == 'traffic' && _isNavigating && _routePoints.isNotEmpty) {
      _drawTrafficLine(_lat, _lng, _heading, _userReportMarkers.length - 1);
    }

    _redrawUserReportMarkers();
    debugPrint('[Report] User reported: $label ($type) at $_lat, $_lng');
  }

  /// Draw traffic line along route until next intersection/maneuver
  Future<void> _drawTrafficLine(double lat, double lng, double heading, int idx) async {
    if (_mapboxMap == null) return;
    final style = _mapboxMap!.style;
    final sourceId = 'traffic-line-$idx';
    final layerId = 'traffic-line-layer-$idx';

    // Find next intersection from route steps
    double maxDist = 500; // default 500m
    if (_currentRoute != null && _currentRoute!.steps.isNotEmpty) {
      final steps = _currentRoute!.steps;
      // Find end of current step (= next intersection/maneuver)
      if (_currentStepIndex < steps.length) {
        final step = steps[_currentStepIndex];
        maxDist = step.distanceMeters.clamp(100, 3000); // min 100m, max 3km
      }
    }

    // Find nearest route point to GPS, then walk along route for maxDist
    int nearestIdx = 0;
    double nearestDist = double.infinity;
    for (int i = 0; i < _routePoints.length; i++) {
      final d = geo.Geolocator.distanceBetween(
        lat, lng, _routePoints[i].latitude, _routePoints[i].longitude);
      if (d < nearestDist) { nearestDist = d; nearestIdx = i; }
    }

    final segCoords = <String>[];
    double totalDist = 0;
    double prevLat = lat, prevLng = lng;
    // Start from nearest route point, walk forward
    for (int i = nearestIdx; i < _routePoints.length; i++) {
      final p = _routePoints[i];
      segCoords.add('[${p.longitude},${p.latitude}]');
      totalDist += geo.Geolocator.distanceBetween(prevLat, prevLng, p.latitude, p.longitude);
      prevLat = p.latitude; prevLng = p.longitude;
      if (totalDist >= maxDist) break;
    }
    if (segCoords.length < 2) return;
    final coords = segCoords;

    final geoJson = '{"type":"Feature","geometry":{"type":"LineString","coordinates":[${coords.join(',')}]}}';

    try { await style.removeStyleLayer(layerId); } catch (_) {}
    try { await style.removeStyleSource(sourceId); } catch (_) {}

    await style.addSource(GeoJsonSource(id: sourceId, data: geoJson));

    // Mode-aware color: red for biker, blue for auto
    final color = _routeMode == RouteMode.auto ? 0xFF2196F3 : 0xFFE53935;

    // Bigger + more opaque so it stays visible over road labels/shields
    await style.addLayer(LineLayer(
      id: layerId,
      sourceId: sourceId,
      lineColor: color,
      lineWidth: 11.0,
      lineOpacity: 0.92,
      lineCap: LineCap.ROUND,
      lineJoin: LineJoin.ROUND,
    ));

    // Move layer to the very top so nothing (shields, labels) covers it
    try {
      await style.moveStyleLayer(layerId, null);
    } catch (_) {}
  }

  // Register emoji as Mapbox image (renders reliably on all devices)
  Future<Uint8List> _emojiToImage(String emoji, Color bgColor, {int size = 160, bool square = false}) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final s = size.toDouble();
    final r = square ? 12.0 : s / 2; // rounded rect radius vs circle

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(4, 4, s - 8, s - 8),
      Radius.circular(square ? 12 : s),
    );

    // Drop shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final shadowRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(4, 7, s - 8, s - 8),
      Radius.circular(square ? 12 : s),
    );
    canvas.drawRRect(shadowRect, shadowPaint);

    // Background
    final bgPaint = Paint()..color = bgColor;
    canvas.drawRRect(rect, bgPaint);

    // White border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawRRect(rect, borderPaint);

    // Emoji text centered (bigger)
    final tp = TextPainter(
      text: TextSpan(text: emoji, style: TextStyle(fontSize: s * 0.55)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((s - tp.width) / 2, (s - tp.height) / 2));

    final img = await recorder.endRecording().toImage(size, size);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  bool _reportImagesRegistered = false;

  Future<void> _registerReportImages() async {
    if (_reportImagesRegistered || _mapboxMap == null) return;
    _reportImagesRegistered = true;

    final types = {
      'mobile': ('📸', const Color(0xFFFFEB3B)),
      'fixed': ('📷', const Color(0xFFFF5722)),
      'police': ('🚔', const Color(0xFF42A5F5)),
      'hazard': ('⚠️', const Color(0xFFFF9800)),
      'construction': ('🚧', const Color(0xFFFF9800)),
      'traffic': ('🚗', const Color(0xFFE53935)),
    };

    // Blitzer types get square icons, others stay round
    const squareTypes = {'mobile', 'fixed'};

    for (final entry in types.entries) {
      final isSquare = squareTypes.contains(entry.key);
      final bytes = await _emojiToImage(entry.value.$1, entry.value.$2, square: isSquare);
      await _mapboxMap!.style.addStyleImage(
        'report-${entry.key}', 2.0,
        MbxImage(width: 160, height: 160, data: bytes),
        false, [], [], null,
      );
    }
  }

  Future<void> _redrawUserReportMarkers() async {
    if (_mapboxMap == null) return;
    final style = _mapboxMap!.style;

    // Ensure report images are registered
    await _registerReportImages();

    // Clean up old layers
    for (final id in ['user-report-icons', 'user-report-labels', 'user-report-circles']) {
      try { await style.removeStyleLayer(id); } catch (_) {}
    }
    try { await style.removeStyleSource('user-report-source'); } catch (_) {}

    // All markers as point icons (traffic also gets a pin in free ride)
    final pointMarkers = _userReportMarkers.toList();
    if (pointMarkers.isEmpty) return;

    final features = pointMarkers.map((m) {
      final name = (m['label'] as String).replaceAll('"', '\\"');
      final t = m['type'] as String;
      return '{"type":"Feature",'
          '"properties":{"name":"$name","type":"$t","icon":"report-$t"},'
          '"geometry":{"type":"Point","coordinates":[${m['lng']},${m['lat']}]}}';
    }).join(',');

    final geoJson = '{"type":"FeatureCollection","features":[$features]}';
    await style.addSource(GeoJsonSource(id: 'user-report-source', data: geoJson));

    // Icon markers (emoji images) — must be above blitzer circles
    try {
      await style.addLayer(SymbolLayer(
        id: 'user-report-icons',
        sourceId: 'user-report-source',
        iconSize: 0.85, // Bigger for visibility
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
        iconAnchor: IconAnchor.CENTER,
      ));
      await style.setStyleLayerProperty('user-report-icons', 'icon-image', '["get", "icon"]');
    } catch (_) {}

    // Label below icon
    try {
      await style.addLayer(SymbolLayer(
        id: 'user-report-labels',
        sourceId: 'user-report-source',
        textSize: 11.0,
        textColor: _isDark ? 0xFFFFFFFF : 0xFF000000,
        textHaloColor: _isDark ? 0xFF000000 : 0xFFFFFFFF,
        textHaloWidth: 1.2,
        textAnchor: TextAnchor.TOP,
        textAllowOverlap: true,
      ));
      await style.setStyleLayerProperty('user-report-labels', 'text-field', '["get", "name"]');
      await style.setStyleLayerProperty('user-report-labels', 'text-offset', '[0, 2.0]');
    } catch (_) {}
  }

  // Keep old method name for backward compat
  void _addUserBlitzerMarker(String label) => _addUserReportMarker('mobile', label);

  // ── Map Tap → check if user tapped on a marker (own report OR OSM blitzer) ──
  /// Tap auf Cluster → Zoom erweitern, Tap auf User → Profil öffnen
  Future<bool> _handleFollowedPlzTap(MapContentGestureContext ctx) async {
    if (_mapboxMap == null) return false;
    final touchPos = ctx.touchPosition;
    final geometry = RenderedQueryGeometry.fromScreenBox(
      ScreenBox(
        min: ScreenCoordinate(x: touchPos.x - 30, y: touchPos.y - 30),
        max: ScreenCoordinate(x: touchPos.x + 30, y: touchPos.y + 30),
      ),
    );

    // 1. Check cluster circles → Zoom in
    try {
      final clusterFeatures = await _mapboxMap!.queryRenderedFeatures(
        geometry,
        RenderedQueryOptions(layerIds: ['followed-plz-cluster-circles']),
      );
      if (clusterFeatures.isNotEmpty && clusterFeatures.first != null) {
        final feature = clusterFeatures.first!.queriedFeature.feature;
        final props = feature['properties'] as Map?;
        if (props != null && props.containsKey('point_count')) {
          // Ganzes Feature an Mapbox übergeben (nicht nur properties!)
          final featureMap = feature.cast<String?, Object?>();
          final geom = feature['geometry'] as Map?;
          if (geom == null) return true;
          final coords = geom['coordinates'] as List;
          final clusterLng = (coords[0] as num).toDouble();
          final clusterLat = (coords[1] as num).toDouble();

          try {
            final expansionResult = await _mapboxMap!.getGeoJsonClusterExpansionZoom(
              'followed-plz-source', featureMap,
            );
            final targetZoom = (expansionResult.value as num?)?.toDouble() ?? 14.0;
            debugPrint('[FollowedPLZ] Cluster tap → zoom to $targetZoom');
            _mapboxMap!.flyTo(
              CameraOptions(
                center: Point(coordinates: Position(clusterLng, clusterLat)),
                zoom: targetZoom + 0.5,
              ),
              MapAnimationOptions(duration: 500),
            );
          } catch (e) {
            debugPrint('[FollowedPLZ] Expansion zoom error: $e, zooming +2');
            // Fallback: einfach +2 Zoom-Stufen
            final cam = await _mapboxMap!.getCameraState();
            _mapboxMap!.flyTo(
              CameraOptions(
                center: Point(coordinates: Position(clusterLng, clusterLat)),
                zoom: cam.zoom + 2,
              ),
              MapAnimationOptions(duration: 500),
            );
          }
          return true;
        }
      }
    } catch (e) {
      debugPrint('[FollowedPLZ] Cluster query error: $e');
    }

    // 2. Check individual user icons
    try {
      final userFeatures = await _mapboxMap!.queryRenderedFeatures(
        geometry,
        RenderedQueryOptions(layerIds: ['followed-plz-user-icons']),
      );
      if (userFeatures.isNotEmpty && userFeatures.first != null) {
        final props = userFeatures.first!.queriedFeature.feature['properties'] as Map?;
        final userId = props?['userId'] as String?;
        if (userId != null && mounted) {
          context.push('/profile/$userId');
          return true;
        }
      }
    } catch (e) {
      debugPrint('[FollowedPLZ] User query error: $e');
    }

    return false;
  }

  void _onMapTap(MapContentGestureContext ctx) async {
    final coord = ctx.point.coordinates;
    final tapLat = coord.lat.toDouble();
    final tapLng = coord.lng.toDouble();

    // 0. Check followed-user PLZ markers (cluster or individual)
    if (_followedPlzLayerInitialized) {
      final handled = await _handleFollowedPlzTap(ctx);
      if (handled) return;
    }

    // 0b. Check if tap is on/near the puck → open profile
    final puckLat = _isNavigating ? _snapLat : _lat;
    final puckLng = _isNavigating ? _snapLng : _lng;
    final puckDist = geo.Geolocator.distanceBetween(tapLat, tapLng, puckLat, puckLng);
    if (puckDist < 40) {
      context.push('/profile');
      return;
    }

    // 1. Check own report markers first (can delete)
    int? closestIdx;
    double closestDist = 80; // max tap radius in meters
    for (int i = 0; i < _userReportMarkers.length; i++) {
      final m = _userReportMarkers[i];
      if (m['isMine'] != true) continue;
      final d = geo.Geolocator.distanceBetween(
        tapLat, tapLng, m['lat'] as double, m['lng'] as double,
      );
      if (d < closestDist) {
        closestDist = d;
        closestIdx = i;
      }
    }

    if (closestIdx != null) {
      _showReportActionSheet(closestIdx);
      return;
    }

    // 2. Check OSM/community blitzer markers (info only)
    BlitzerReport? closestBlitzer;
    double blitzerDist = 150; // wider tap radius for blitzer icons
    for (final b in _blitzerReports) {
      final d = geo.Geolocator.distanceBetween(
        tapLat, tapLng, b.latitude, b.longitude,
      );
      if (d < blitzerDist) {
        blitzerDist = d;
        closestBlitzer = b;
      }
    }

    if (closestBlitzer != null) {
      _showBlitzerInfoSheet(closestBlitzer, blitzerDist);
      return;
    }

    // 3. Check POI markers
    PoiResult? closestPoi;
    double poiDist = 150; // tap radius in meters
    for (final entry in _poiResults.entries) {
      for (final poi in entry.value) {
        final d = geo.Geolocator.distanceBetween(tapLat, tapLng, poi.lat, poi.lon);
        if (d < poiDist) {
          poiDist = d;
          closestPoi = poi;
        }
      }
    }
    if (closestPoi != null) {
      final catColor = switch (closestPoi.type) {
        'fuel' => const Color(0xFFFF9800),
        'workshop' => const Color(0xFF9C27B0),
        'biker_shop' => const Color(0xFFE53935),
        'auto_shop' => const Color(0xFF2196F3),
        'restaurant' => const Color(0xFF4CAF50),
        'cafe' => const Color(0xFF795548),
        'bank' => const Color(0xFF607D8B),
        'hospital' => const Color(0xFFE91E63),
        'grocery' => const Color(0xFF8BC34A),
        'pharmacy' => const Color(0xFF00BCD4),
        _ => _modeColor,
      };
      // Suchleiste ausblenden, damit POI sichtbar wird
      setState(() => _searchPanelHidden = true);
      _flyToPoiAndHighlight(closestPoi, catColor, withSheet: true);
      _showPoiDetailSheet(closestPoi);
      return;
    }
  }

  /// Show info bottom sheet for OSM/community blitzer
  void _showBlitzerInfoSheet(BlitzerReport blitzer, double tapDist) async {
    final distToMe = geo.Geolocator.distanceBetween(
      _lat, _lng, blitzer.latitude, blitzer.longitude,
    );
    final distText = distToMe < 1000
        ? '${distToMe.round()} m entfernt'
        : '${(distToMe / 1000).toStringAsFixed(1)} km entfernt';
    final typeText = blitzer.typeLabel;
    final emoji = blitzer.isOsm ? '📷' : '📸';

    // Check if this is the current user's report (can delete)
    final currentUserId = ref.read(authNotifierProvider) is Authenticated
        ? (ref.read(authNotifierProvider) as Authenticated).user.id
        : null;
    final isMine = !blitzer.isOsm && currentUserId != null && blitzer.userId == currentUserId;

    // Reverse geocode for city/PLZ
    String locationText = '';
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=${blitzer.latitude}&lon=${blitzer.longitude}&format=json&zoom=16&addressdetails=1',
      );
      final resp = await http.get(url, headers: {'User-Agent': 'Bikergram/1.0'});
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final addr = data['address'] as Map<String, dynamic>?;
        if (addr != null) {
          final road = addr['road'] ?? '';
          final plz = addr['postcode'] ?? '';
          final city = addr['city'] ?? addr['town'] ?? addr['village'] ?? '';
          final parts = <String>[if (road.isNotEmpty) road, if (plz.isNotEmpty) '$plz $city' else if (city.isNotEmpty) city];
          locationText = parts.join(', ');
        }
      }
    } catch (_) {}

    showModalBottomSheet(
      context: context,
      backgroundColor: _isDark ? const Color(0xFF1A1A2E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Text(emoji, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(typeText, style: TextStyle(
                    color: _isDark ? Colors.white : Colors.black87,
                    fontSize: 18, fontWeight: FontWeight.bold,
                  )),
                  const SizedBox(height: 4),
                  Text(distText, style: TextStyle(
                    color: _modeColor,
                    fontSize: 15, fontWeight: FontWeight.w600,
                  )),
                  if (locationText.isNotEmpty)
                    Text('📍 $locationText', style: TextStyle(
                      color: _isDark ? Colors.white70 : Colors.black54,
                      fontSize: 14,
                    ))
                  else if (blitzer.roadRef != null && blitzer.roadRef!.isNotEmpty)
                    Text('Straße: ${blitzer.roadRef}', style: TextStyle(
                      color: _isDark ? Colors.white70 : Colors.black54,
                      fontSize: 14,
                    )),
                  if (blitzer.speedLimit != null && blitzer.speedLimit! > 0)
                    Text('Tempolimit: ${blitzer.speedLimit} km/h', style: TextStyle(
                      color: _isDark ? Colors.white54 : Colors.black54,
                      fontSize: 14,
                    )),
                ],
              )),
            ]),
            const SizedBox(height: 16),
            // Navigate to blitzer button
            Row(children: [
              Expanded(child: ElevatedButton.icon(
                icon: const Icon(Icons.my_location_rounded),
                label: const Text('Auf Karte zeigen'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _modeColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _mapboxMap?.flyTo(
                    CameraOptions(
                      center: Point(coordinates: Position(blitzer.longitude, blitzer.latitude)),
                      zoom: 17, bearing: 0, pitch: 0,
                    ),
                    MapAnimationOptions(duration: 1200),
                  );
                },
              )),
              if (isMine) ...[
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.delete_rounded),
                  label: const Text('Löschen'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    try {
                      await Supabase.instance.client
                          .from('blitzer_reports')
                          .delete()
                          .eq('id', blitzer.id);
                      _blitzerReports.removeWhere((b) => b.id == blitzer.id);
                      _drawBlitzerOnMap();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Meldung gelöscht')),
                      );
                    } catch (e) {
                      debugPrint('[Blitzer] Delete failed: $e');
                    }
                  },
                ),
              ],
            ]),
          ]),
        ),
      ),
    );
  }

  /// Show detail bottom sheet when user taps a POI marker on the map.
  void _showPoiDetailSheet(PoiResult poi) async {
    // Recalculate distance from current position
    final distToMe = geo.Geolocator.distanceBetween(_lat, _lng, poi.lat, poi.lon);
    final distText = distToMe < 1000
        ? '${distToMe.round()} m'
        : '${(distToMe / 1000).toStringAsFixed(1)} km';

    // Category icon + color
    final catIcon = switch (poi.type) {
      'fuel' => Icons.local_gas_station_rounded,
      'workshop' => Icons.build_rounded,
      'biker_shop' => Icons.two_wheeler_rounded,
      'auto_shop' => Icons.directions_car_rounded,
      'restaurant' => Icons.restaurant_rounded,
      'cafe' => Icons.coffee_rounded,
      'bank' => Icons.account_balance_rounded,
      'hospital' => Icons.local_hospital_rounded,
      'grocery' => Icons.shopping_cart_rounded,
      'pharmacy' => Icons.local_pharmacy_rounded,
      _ => Icons.place_rounded,
    };
    final catColor = switch (poi.type) {
      'fuel' => const Color(0xFFFF9800),
      'workshop' => const Color(0xFF9C27B0),
      'biker_shop' => const Color(0xFFE53935),
      'auto_shop' => const Color(0xFF2196F3),
      'restaurant' => const Color(0xFF4CAF50),
      'cafe' => const Color(0xFF795548),
      'bank' => const Color(0xFF607D8B),
      'hospital' => const Color(0xFFE91E63),
      'grocery' => const Color(0xFF8BC34A),
      'pharmacy' => const Color(0xFF00BCD4),
      _ => _modeColor,
    };
    final catLabel = switch (poi.type) {
      'fuel' => 'Tankstelle',
      'workshop' => 'Werkstatt',
      'biker_shop' => 'Biker Shop',
      'auto_shop' => 'Auto Shop',
      'restaurant' => 'Restaurant',
      'cafe' => 'Café',
      'bank' => 'Bank',
      'hospital' => 'Krankenhaus',
      'grocery' => 'Lebensmittel',
      'pharmacy' => 'Apotheke',
      _ => 'POI',
    };

    // Load rating from Supabase
    double? avgRating;
    int ratingCount = 0;
    try {
      final ratings = await Supabase.instance.client
          .from('poi_ratings')
          .select('rating')
          .eq('poi_name', poi.name)
          .eq('poi_type', poi.type);
      if (ratings is List && ratings.isNotEmpty) {
        ratingCount = ratings.length;
        final sum = ratings.fold<double>(0, (s, r) => s + ((r['rating'] as num?)?.toDouble() ?? 0));
        avgRating = sum / ratingCount;
      }
    } catch (_) {}

    if (!mounted) return;

    // Suchleiste ausblenden damit POI mittig sichtbar ist
    setState(() => _searchPanelHidden = true);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _isDark ? const Color(0xF0111111) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        // Format brand: replace semicolons with comma+space
        final brandText = poi.brand?.replaceAll(';', ', ');
        final bp = MediaQuery.of(ctx).padding.bottom;
        return Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: bp + 70),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Handle
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: _textPrimary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header: Icon + Name + Category
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: _modeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(catIcon, color: _modeColor, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(poi.name, style: TextStyle(
                      color: _textPrimary,
                      fontSize: 18, fontWeight: FontWeight.bold,
                    )),
                    const SizedBox(height: 2),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _modeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(catLabel, style: TextStyle(
                          color: _modeColor, fontSize: 12, fontWeight: FontWeight.w600,
                        )),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.near_me_rounded, size: 14, color: _modeColor),
                      const SizedBox(width: 3),
                      Text(distText, style: TextStyle(
                        color: _modeColor, fontSize: 14, fontWeight: FontWeight.w600,
                      )),
                    ]),
                  ],
                )),
              ]),

              const SizedBox(height: 16),

              // Scrollable info rows
              Flexible(child: SingleChildScrollView(child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (poi.address != null && poi.address!.isNotEmpty)
                    _poiInfoRow(Icons.location_on_rounded, poi.address!, _isDark),
                  if (poi.openingHours != null && poi.openingHours!.isNotEmpty)
                    _poiInfoRow(Icons.access_time_rounded, poi.openingHours!, _isDark),
                  if (poi.phone != null && poi.phone!.isNotEmpty)
                    _poiInfoRow(Icons.phone_rounded, poi.phone!, _isDark, isTappable: true),
                  if (brandText != null && brandText.isNotEmpty)
                    _poiInfoRow(Icons.business_rounded, brandText, _isDark),
                  if (avgRating != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        const Icon(Icons.star_rounded, size: 18, color: Colors.amber),
                        const SizedBox(width: 8),
                        Text(
                          '${avgRating.toStringAsFixed(1)} ($ratingCount ${ratingCount == 1 ? 'Bewertung' : 'Bewertungen'})',
                          style: TextStyle(
                            color: _textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ]),
                    ),
                ],
              ))),

              const SizedBox(height: 14),

              // Buttons: Karte + Navi + Rate + Teilen
              Row(children: [
                // Auf Karte zeigen
                Expanded(child: ElevatedButton.icon(
                  icon: const Icon(Icons.map_rounded, size: 18),
                  label: const Text('Karte', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _cardBg,
                    foregroundColor: _textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: _cardBorder),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _flyToPoiAndHighlight(poi, catColor);
                  },
                )),
                const SizedBox(width: 6),
                // Navigieren
                Expanded(child: ElevatedButton.icon(
                  icon: const Icon(Icons.navigation_rounded, size: 18),
                  label: const Text('Navi', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _modeColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _selectDestination(poi.lat, poi.lon, poi.name);
                  },
                )),
                const SizedBox(width: 6),
                // Bewerten
                Expanded(child: ElevatedButton.icon(
                  icon: const Icon(Icons.star_rounded, size: 18),
                  label: const Text('Rate', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _cardBg,
                    foregroundColor: _textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: _cardBorder),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showPoiRatingSheet(poi);
                  },
                )),
                const SizedBox(width: 6),
                // Teilen → WhatsApp, Facebook, Feed, etc.
                Expanded(child: ElevatedButton.icon(
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Teilen', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _cardBg,
                    foregroundColor: _textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: _cardBorder),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _sharePoiDetails(poi, catLabel, distText, avgRating, ratingCount);
                  },
                )),
              ]),
              ]),
          );
      },
    ).then((_) {});
  }

  /// POI teilen: Feed / Story / User / Extern
  void _sharePoiDetails(PoiResult poi, String catLabel, String distText, double? avgRating, int ratingCount) {
    // Share-Text aufbauen
    final mapsUrl = 'https://www.google.com/maps/search/?api=1&query=${poi.lat},${poi.lon}';
    final buf = StringBuffer();
    buf.writeln('${poi.name}');
    buf.writeln('$catLabel · $distText');
    if (poi.address != null && poi.address!.isNotEmpty) {
      buf.writeln(poi.address!);
    }
    if (avgRating != null) {
      buf.writeln('${avgRating.toStringAsFixed(1)} ($ratingCount ${ratingCount == 1 ? 'Bewertung' : 'Bewertungen'})');
    }
    buf.writeln();
    buf.writeln(mapsUrl);
    buf.writeln();
    buf.writeln('Gefunden mit Motorinu');
    final shareText = buf.toString();

    // Suchleiste ausblenden
    setState(() => _searchPanelHidden = true);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _isDark ? const Color(0xF0111111) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final bp = MediaQuery.of(ctx).padding.bottom;
        return Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: bp + 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Handle
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: _textPrimary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Titel
            Text('POI teilen', style: TextStyle(
              color: _textPrimary, fontSize: 20, fontWeight: FontWeight.bold,
            )),
            const SizedBox(height: 10),
            // POI-Vorschau
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _modeColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _modeColor.withValues(alpha: 0.2)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(poi.name, style: TextStyle(
                  color: _textPrimary, fontSize: 16, fontWeight: FontWeight.w600,
                )),
                const SizedBox(height: 4),
                Text('$catLabel · $distText',
                  style: TextStyle(color: _textSecondary, fontSize: 13),
                ),
                if (poi.address != null && poi.address!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(poi.address!,
                    style: TextStyle(color: _textSecondary, fontSize: 13),
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 20),
            // Share-Optionen: 2x2 Grid
            Row(children: [
              _shareOption(ctx, Icons.dynamic_feed_rounded, 'Feed', 'Im Feed posten', _modeColor, () {
                Navigator.pop(ctx);
                CreatePostScreen.show(context,
                  source: PostMediaSource.textOnly,
                  initialText: shareText,
                );
              }),
              const SizedBox(width: 10),
              _shareOption(ctx, Icons.auto_stories_rounded, 'Story', 'Als Story teilen', Colors.purple, () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: shareText));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('POI-Text kopiert — erstelle eine Story und füge ihn ein!'), duration: Duration(seconds: 3)),
                );
              }),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              _shareOption(ctx, Icons.send_rounded, 'An User', 'Im Chat senden', Colors.blue, () {
                Navigator.pop(ctx);
                _showPoiUserPicker(poi, catLabel);
              }),
              const SizedBox(width: 10),
              _shareOption(ctx, Icons.share_rounded, 'Extern', 'WhatsApp, Facebook...', Colors.green, () {
                Navigator.pop(ctx);
                Share.share(shareText);
              }),
            ]),
          ]),
        );
      },
    ).then((_) {});
  }

  Widget _shareOption(BuildContext ctx, IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(
                    color: _textPrimary, fontSize: 14, fontWeight: FontWeight.w600,
                  )),
                  Text(subtitle, style: TextStyle(
                    color: _textSecondary, fontSize: 11,
                  ), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              )),
            ]),
          ),
        ),
      ),
    );
  }

  /// Follower-Picker: Mehrere User auswählen → POI als Location-Nachricht senden
  void _showPoiUserPicker(PoiResult poi, String catLabel) async {
    // 1. Follower-IDs laden
    final profileRepo = ref.read(profileRepositoryProvider);
    final followingIds = await profileRepo.getFollowingIds();
    if (followingIds.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Du folgst noch niemandem — folge Usern um POIs zu teilen!')),
        );
      }
      return;
    }

    // 2. Profile für alle Follower laden
    final profiles = await Supabase.instance.client
        .from('profiles')
        .select('id, username, display_name, avatar_url')
        .inFilter('id', followingIds.toList())
        .order('username');

    if (!mounted || profiles is! List || profiles.isEmpty) return;

    final selected = <String>{};
    var isSending = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _isDark ? const Color(0xF0111111) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setPickerState) => Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16, top: 16,
            bottom: MediaQuery.of(ctx).padding.bottom + 16,
          ),
          child: Column(children: [
            // Handle
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: _textPrimary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Text('POI an User senden', style: TextStyle(
              color: _textPrimary, fontSize: 18, fontWeight: FontWeight.bold,
            )),
            const SizedBox(height: 4),
            Text('${poi.name} · $catLabel', style: TextStyle(
              color: _modeColor, fontSize: 13, fontWeight: FontWeight.w500,
            )),
            const SizedBox(height: 14),
            // User-Liste
            Expanded(child: ListView.builder(
              itemCount: profiles.length,
              itemBuilder: (_, i) {
                final p = profiles[i] as Map<String, dynamic>;
                final uid = p['id'] as String;
                final uname = p['username'] as String? ?? '?';
                final dname = p['display_name'] as String?;
                final avatar = p['avatar_url'] as String?;
                final isChecked = selected.contains(uid);

                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundColor: _modeColor.withValues(alpha: 0.2),
                    backgroundImage: avatar != null && avatar.isNotEmpty
                        ? NetworkImage(avatar)
                        : null,
                    child: avatar == null || avatar.isEmpty
                        ? Text(uname[0].toUpperCase(), style: TextStyle(color: _modeColor, fontWeight: FontWeight.bold))
                        : null,
                  ),
                  title: Text(dname ?? uname, style: TextStyle(
                    color: _textPrimary, fontSize: 14, fontWeight: FontWeight.w600,
                  )),
                  subtitle: dname != null
                      ? Text('@$uname', style: TextStyle(color: _textSecondary, fontSize: 12))
                      : null,
                  trailing: Checkbox(
                    value: isChecked,
                    activeColor: _modeColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: (_) {
                      setPickerState(() {
                        if (isChecked) { selected.remove(uid); }
                        else { selected.add(uid); }
                      });
                    },
                  ),
                  onTap: () {
                    setPickerState(() {
                      if (isChecked) { selected.remove(uid); }
                      else { selected.add(uid); }
                    });
                  },
                );
              },
            )),
            const SizedBox(height: 12),
            // Senden-Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: isSending
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, size: 20),
                label: Text(
                  selected.isEmpty
                      ? 'User auswählen'
                      : 'An ${selected.length} User senden',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: selected.isEmpty ? Colors.grey : _modeColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: selected.isEmpty || isSending ? null : () async {
                  setPickerState(() => isSending = true);
                  final msgRepo = ref.read(messageRepositoryProvider);
                  final body = '${poi.name}\n$catLabel${poi.address != null ? '\n${poi.address}' : ''}';
                  int sent = 0;
                  for (final uid in selected) {
                    try {
                      final convId = await msgRepo.getOrCreateConversation(uid);
                      await msgRepo.sendMessage(
                        convId,
                        body,
                        messageType: 'location',
                        locationLat: poi.lat,
                        locationLng: poi.lon,
                        locationName: poi.name,
                      );
                      sent++;
                    } catch (e) {
                      debugPrint('[POI Share] Fehler bei $uid: $e');
                    }
                  }
                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('POI an $sent User gesendet!'), duration: const Duration(seconds: 2)),
                    );
                  }
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _poiInfoRow(IconData icon, String text, bool isDark, {bool isTappable = false}) {
    final row = Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: isTappable
              ? const Color(0xFF4FC3F7)
              : (isDark ? Colors.white38 : Colors.black38)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(
            color: isTappable
                ? const Color(0xFF4FC3F7)
                : (isDark ? Colors.white70 : Colors.black54),
            fontSize: 14,
            decoration: isTappable ? TextDecoration.underline : null,
            decorationColor: isTappable ? const Color(0xFF4FC3F7) : null,
          ))),
        ],
      ),
    );
    if (!isTappable) return row;
    return GestureDetector(
      onTap: () {
        final cleaned = text.replaceAll(RegExp(r'[^\d+]'), '');
        launchUrl(Uri.parse('tel:$cleaned'));
      },
      child: row,
    );
  }

  void _showReportActionSheet(int markerIdx) {
    final marker = _userReportMarkers[markerIdx];
    final label = marker['label'] as String;
    final type = marker['type'] as String;
    final emoji = _reportEmoji[type] ?? '📍';
    final time = DateTime.fromMillisecondsSinceEpoch(marker['time'] as int);
    final ago = DateTime.now().difference(time);
    final agoText = ago.inMinutes < 60
        ? 'vor ${ago.inMinutes} Min.'
        : 'vor ${ago.inHours} Std.';

    showModalBottomSheet(
      context: context,
      backgroundColor: _isDark ? const Color(0xFF1A1A2E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Header
            Row(children: [
              Text(emoji, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(
                    color: _isDark ? Colors.white : Colors.black87,
                    fontSize: 18, fontWeight: FontWeight.bold,
                  )),
                  Text('Gemeldet $agoText', style: TextStyle(
                    color: _isDark ? Colors.white54 : Colors.black54,
                    fontSize: 13,
                  )),
                ],
              )),
            ]),
            const SizedBox(height: 20),

            // Delete button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _deleteUserReport(markerIdx);
                },
                icon: const Icon(Icons.delete_outline, color: Colors.white),
                label: const Text('Meldung löschen', style: TextStyle(color: Colors.white, fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Cancel
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Zurück', style: TextStyle(
                  color: _isDark ? Colors.white54 : Colors.black54, fontSize: 15,
                )),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _deleteUserReport(int idx) {
    if (idx < 0 || idx >= _userReportMarkers.length) return;
    final marker = _userReportMarkers[idx];
    final label = marker['label'] as String;
    final type = marker['type'] as String;

    // Remove traffic line if it was a traffic report
    if (type == 'traffic' && _mapboxMap != null) {
      try { _mapboxMap!.style.removeStyleLayer('traffic-line-layer-$idx'); } catch (_) {}
      try { _mapboxMap!.style.removeStyleSource('traffic-line-$idx'); } catch (_) {}
    }

    // Remove from local list
    _userReportMarkers.removeAt(idx);
    debugPrint('[Report] Deleted: $label');

    // Redraw markers on map
    _redrawUserReportMarkers();

    // Delete from Supabase if it has an ID
    final reportId = marker['supabaseId'];
    if (reportId != null) {
      _blitzerRepo.deleteReport(reportId as int).catchError((e) {
        debugPrint('[Report] Supabase delete error: $e');
      });
    }

    // Feedback
    HapticFeedback.mediumImpact();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$label gelöscht'),
        duration: const Duration(seconds: 2),
        backgroundColor: _modeColor,
      ));
    }
  }

  final _blitzerRepo = BlitzerRepository();

  Future<void> _saveBlitzerToSupabase(String type, String label) async {
    try {
      final report = await _blitzerRepo.createReport(
        latitude: _lat,
        longitude: _lng,
        type: type,
        description: 'Hi Moto: $label',
      );
      debugPrint('[Blitzer] Saved to Supabase: id=${report.id}');
      // Store Supabase ID in the last added marker (for deletion)
      if (_userReportMarkers.isNotEmpty) {
        _userReportMarkers.last['supabaseId'] = report.id;
      }
      // Add to local blitzer list so it shows on map + alerts work
      _blitzerReports.add(report);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$label gespeichert (+10 XP)'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      debugPrint('[Blitzer] Supabase save failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Speichern fehlgeschlagen: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ));
      }
    }
  }

  /// Load community blitzer reports from Supabase + OSM cameras.
  Future<void> _loadCommunityBlitzers() async {
    try {
      final communityReports = await _blitzerRepo.getNearbyReports(
        latitude: _lat, longitude: _lng, radiusKm: 10,
      );
      // Merge with OSM reports (avoid duplicates)
      final merged = <BlitzerReport>[...communityReports];
      for (final osm in _blitzerReports) {
        if (osm.isOsm) merged.add(osm);
      }
      _blitzerReports = merged;
      _drawBlitzerOnMap();
      debugPrint('[Blitzer] Loaded ${communityReports.length} community + ${_blitzerReports.where((r) => r.isOsm).length} OSM reports');
    } catch (e) {
      debugPrint('[Blitzer] Community load failed: $e');
    }
  }

  Future<void> _removeBlitzerFromMap() async {
    if (_mapboxMap == null) return;
    final style = _mapboxMap!.style;
    try { await style.removeStyleLayer('blitzer-circles'); } catch (_) {}
    try { await style.removeStyleLayer('blitzer-labels'); } catch (_) {}
    try { await style.removeStyleSource('blitzer-source'); } catch (_) {}
  }

  Future<void> _drawBlitzerOnMap() async {
    if (_mapboxMap == null || _blitzerReports.isEmpty) return;

    // Blitzer-Punkte nur während Navigation auf der Karte anzeigen.
    // Daten bleiben geladen (für Warnungen), aber visuell stören sie nicht.
    if (!_isNavigating) {
      _removeBlitzerFromMap();
      return;
    }

    final style = _mapboxMap!.style;

    try { await style.removeStyleLayer('blitzer-circles'); } catch (_) {}
    try { await style.removeStyleLayer('blitzer-labels'); } catch (_) {}
    try { await style.removeStyleSource('blitzer-source'); } catch (_) {}

    // Only draw OSM blitzers as red circles — community reports have their own emoji markers
    final osmOnly = _blitzerReports.where((b) => b.isOsm).toList();
    if (osmOnly.isEmpty) return;
    final features = osmOnly.map((b) {
      final name = b.typeLabel.replaceAll('"', '\\"');
      return '{"type":"Feature",'
          '"properties":{"name":"$name"},'
          '"geometry":{"type":"Point","coordinates":[${b.longitude},${b.latitude}]}}';
    }).join(',');

    final geoJson = '{"type":"FeatureCollection","features":[$features]}';
    await style.addSource(GeoJsonSource(id: 'blitzer-source', data: geoJson));

    await style.addLayer(CircleLayer(
      id: 'blitzer-circles',
      sourceId: 'blitzer-source',
      circleRadius: 10.0,
      circleColor: 0xFFFF1744, // Bright red
      circleStrokeColor: 0xFFFFFFFF,
      circleStrokeWidth: 3.0,
      circleOpacity: 0.9,
    ));

    // Labels only at high zoom (≥14) — avoids map clutter
    try {
      await style.addLayer(SymbolLayer(
        id: 'blitzer-labels',
        sourceId: 'blitzer-source',
        textSize: 10.0,
        textColor: 0xFFFF8A80,
        textHaloColor: 0xFF000000,
        textHaloWidth: 1.2,
        textAnchor: TextAnchor.TOP,
        textOptional: true,
        minZoom: 16.0, // Only show labels when very zoomed in
      ));
      await _mapboxMap!.style.setStyleLayerProperty(
        'blitzer-labels', 'text-field', '["get", "name"]',
      );
      await _mapboxMap!.style.setStyleLayerProperty(
        'blitzer-labels', 'text-offset', '[0, 1.2]',
      );
    } catch (_) {}

    debugPrint('[Blitzer] Drew ${_blitzerReports.length} blitzer markers on map');
  }

  /// Check if a blitzer is AHEAD of us (not behind) using heading.
  bool _isAhead(double bLat, double bLng) {
    // Calculate bearing from user to blitzer
    final dLng = (bLng - _lng) * math.pi / 180;
    final lat1 = _lat * math.pi / 180;
    final lat2 = bLat * math.pi / 180;
    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    final bearingToBlitzer = (math.atan2(y, x) * 180 / math.pi + 360) % 360;

    // Difference between our heading and direction to blitzer
    double diff = (bearingToBlitzer - _heading).abs();
    if (diff > 180) diff = 360 - diff;
    // If blitzer is within ±90° of our heading → it's ahead
    return diff < 90;
  }

  void _checkBlitzers() {
    if (!_blitzerLoaded || _blitzerReports.isEmpty) return;
    // Don't warn when standing still — avoid spam at red lights near cameras
    if (_speed < 10) return;
    try {
      final result = _blitzerAlertService.checkAlerts(
        pos: geo.Position(latitude: _lat, longitude: _lng, timestamp: DateTime.now(),
          accuracy: 10, altitude: 0, heading: _heading, speed: _speed / 3.6,
          speedAccuracy: 0, altitudeAccuracy: 0, headingAccuracy: 0),
        reports: _blitzerReports,
        settings: const BlitzerSettings(),
        currentSpeedKmh: _speed,
      );
      if (result.newAlerts.isNotEmpty) {
        final alert = result.newAlerts.first;
        final bLat = alert.report.latitude;
        final bLng = alert.report.longitude;

        // 1) Skip if blitzer is BEHIND us (already passed)
        if (!_isAhead(bLat, bLng)) return;

        // 2) Skip user-reported blitzers (we just passed those ourselves)
        final isUserReported = _userReportMarkers.any((m) =>
          geo.Geolocator.distanceBetween(
            m['lat'] as double, m['lng'] as double, bLat, bLng,
          ) < 50
        );
        if (isUserReported) return;

        // 3) Only alert if blitzer is on/near the route
        bool onRoute = false;
        if (_isNavigating && _routePoints.isNotEmpty) {
          for (int i = 0; i < _routePoints.length; i += 3) {
            final d = geo.Geolocator.distanceBetween(
              bLat, bLng, _routePoints[i].latitude, _routePoints[i].longitude,
            );
            if (d < 30) { onRoute = true; break; }
          }
        } else {
          onRoute = true; // Free drive: alert if nearby
        }

        if (onRoute) {
          final w = alert.warningText;
          setState(() => _blitzerWarning = w);
          _ttsSpeak(w, isWarning: true, priority: true);
          Future.delayed(const Duration(seconds: 8), () {
            if (mounted) setState(() => _blitzerWarning = null);
          });
        }
      }
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  HI MOTO
  // ═══════════════════════════════════════════════════════════════════════════

  void _initHiMoto() async {
    final v = VoskWakeWordService.instance;
    if (!await v.init()) return;
    _prevVoskHandler = v.onEvent;
    bool _waitingForCommand = false;
    v.onEvent = (event, text) {
      if (!mounted) return;
      switch (event) {
        case VoskWakeEvent.wakeWordDetected:
          HapticFeedback.heavyImpact();
          TtsAlertService.instance.clearQueue();
          TtsAlertService.instance.stop();
          setState(() { _hiMotoActive = true; _hiMotoFeedback = 'Ich höre...'; });
          // Wait 2s to see if command follows in same sentence
          // If yes → process directly. If no → say "Ja Racer?"
          _waitingForCommand = true;
          Future.delayed(const Duration(milliseconds: 2000), () {
            if (_waitingForCommand && mounted) {
              _waitingForCommand = false;
              // No command followed → ask user
              v.setPaused(true);
              TtsAlertService.instance.speakText('Ja Racer?').then((_) async {
                // Wait 3s after TTS to avoid echo pickup
                await Future.delayed(const Duration(milliseconds: 3000));
                v.setPaused(false);
              });
            }
          });
          break;
        case VoskWakeEvent.commandRecognized:
          _waitingForCommand = false; // Command arrived — skip "Ja Racer?"
          setState(() => _hiMotoActive = false);
          _processVoice(text);
          break;
        case VoskWakeEvent.commandTimeout:
          _waitingForCommand = false;
          setState(() { _hiMotoActive = false; _hiMotoFeedback = null; });
          break;
      }
    };
    await v.startListening();
  }

  void _restoreVosk() {
    if (_prevVoskHandler != null) VoskWakeWordService.instance.onEvent = _prevVoskHandler;
  }

  // ── Pending POI for "Soll ich navigieren?" follow-up ──
  Map<String, dynamic>? _pendingPoiNav;
  List<Map<String, dynamic>> _pendingPoiAlternatives = []; // remaining POIs to offer

  void _processVoice(String text) {
    final cmd = VoiceCommandService.parse(text);
    setState(() => _hiMotoFeedback = '"$text"');
    final v = VoskWakeWordService.instance;

    void say(String msg, {VoidCallback? then}) {
      v.setPaused(true);
      HapticFeedback.mediumImpact(); // Haptic on every response
      TtsAlertService.instance.speakText(msg).then((_) async {
        // Brief pause to avoid TTS echo, then listen immediately
        await Future.delayed(const Duration(milliseconds: 800));
        v.setPaused(false);
        then?.call();
      });
    }

    /// Ask "Soll ich navigieren?" and listen for Ja/Nein (+ show tappable buttons)
    void askNavigate(double lat, double lng, String name) {
      _pendingPoiNav = {'lat': lat, 'lng': lng, 'name': name};
      // Show tappable Ja/Nein buttons
      setState(() {
        _voiceButtons = [
          ('✅ Ja', () => _processVoice('ja')),
          ('❌ Nein', () => _processVoice('nein')),
        ];
      });
      say('Soll ich zu $name navigieren?', then: () {
        v.directListenMode = true;
        Future.delayed(const Duration(seconds: 10), () {
          if (_pendingPoiNav != null) {
            _pendingPoiNav = null;
            v.directListenMode = false;
            setState(() => _voiceButtons = []);
          }
        });
      });
    }

    // ── POI Popup selection by number ("eins/zwei/drei" or "1/2/3") ──
    if (_poiPopupItems.isNotEmpty) {
      final lower = text.toLowerCase().trim();
      int? idx;
      if (lower.contains('eins') || lower.contains('1') || lower.contains('erste')) idx = 0;
      else if (lower.contains('zwei') || lower.contains('2') || lower.contains('zweite')) idx = 1;
      else if (lower.contains('drei') || lower.contains('3') || lower.contains('dritte')) idx = 2;
      else if (cmd.intent == VoiceIntent.confirmNo || lower.contains('abbrechen') || lower.contains('nichts')) {
        setState(() { _poiPopupItems = []; _poiPopupTitle = ''; });
        v.directListenMode = false;
        say('Alles klar.');
        return;
      }

      if (idx != null && idx < _poiPopupItems.length) {
        final poi = _poiPopupItems[idx];
        setState(() { _poiPopupItems = []; _poiPopupTitle = ''; });
        v.directListenMode = false;
        say('Route zu ${poi['name']} wird berechnet.');
        _selectDestination(poi['lat'] as double, poi['lng'] as double, poi['name'] as String, autoStart: true);
      }
      return; // Don't process further while popup is open
    }

    // ── When waiting for Ja/Nein, ONLY accept yes/no — ignore everything else ──
    if (_pendingPoiNav != null) {
      if (cmd.intent == VoiceIntent.confirmYes) {
        v.directListenMode = false;
        final p = _pendingPoiNav!;
        _pendingPoiNav = null;
        _pendingPoiAlternatives.clear();
        setState(() => _voiceButtons = []);
        say('Route wird berechnet.');
        _selectDestination(p['lat'] as double, p['lng'] as double, p['name'] as String);
      } else if (cmd.intent == VoiceIntent.confirmNo) {
        _pendingPoiNav = null;
        setState(() => _voiceButtons = []);
        // Offer next alternative if available
        if (_pendingPoiAlternatives.isNotEmpty) {
          final next = _pendingPoiAlternatives.removeAt(0);
          final name = next['name'] as String;
          final dist = next['dist'] as String;
          _pendingPoiNav = next;
          say('Wie wäre es mit $name, $dist?', then: () {
            v.directListenMode = true;
            Future.delayed(const Duration(seconds: 10), () {
              if (_pendingPoiNav != null) {
                _pendingPoiNav = null;
                _pendingPoiAlternatives.clear();
                v.directListenMode = false;
              }
            });
          });
        } else {
          v.directListenMode = false;
          say('Alles klar, keine Auswahl.');
        }
      } else {
        // Ignore noise/other commands while waiting for Ja/Nein
        debugPrint('[HiMoto] Ignored during Ja/Nein: "${cmd.intent}" ("$text")');
      }
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) setState(() => _hiMotoFeedback = null);
      });
      return;
    }

    switch (cmd.intent) {
      // ── Yes/No without pending question ──
      case VoiceIntent.confirmYes:
        say('Alles klar.');
        break;
      case VoiceIntent.confirmNo:
        say('Alles klar.');
        break;

      // ── Navigation ──
      case VoiceIntent.stopNavigation:
        say('Navigation wird beendet.');
        _stopNavigation();
        break;

      case VoiceIntent.announceRoute:
        if (_isNavigating && _currentRoute != null) {
          final dist = _remainingDistKm >= 1
              ? '${_remainingDistKm.toStringAsFixed(1)} Kilometer'
              : '${(_remainingDistKm * 1000).round()} Meter';
          final time = _fmtTime(_remainingMin);
          final next = _nextInstruction ?? 'Geradeaus weiter';
          say('Noch $dist, $time. $next');
        } else {
          say('Keine aktive Navigation.');
        }
        break;

      // ── POI Search with follow-up nav question ──
      case VoiceIntent.searchPoi:
        say('Suche nach ${cmd.poiLabel ?? cmd.query}.');
        _voiceSearchPoi(cmd.query ?? 'Tankstelle', cmd.poiLabel ?? 'POI', askNavigate);
        break;

      // ── Events search ──
      case VoiceIntent.searchEvents:
        say('Suche nach Treffen in der Nähe.');
        _voiceSearchEvents(askNavigate);
        break;

      // ── Reports (Blitzer, Police, Hazard, Traffic) ──
      case VoiceIntent.reportBlitzer:
        final isFixed = cmd.blitzerType == 'fixed';
        final label = isFixed ? 'Fester Blitzer' : 'Mobiler Blitzer';
        final type = isFixed ? 'fixed' : 'mobile';
        say('$label gemeldet.');
        HapticFeedback.heavyImpact();
        _addUserReportMarker(type, label);
        _saveBlitzerToSupabase(type, label);
        break;

      case VoiceIntent.reportPolice:
        say('Polizeikontrolle gemeldet.');
        HapticFeedback.heavyImpact();
        _addUserReportMarker('police', 'Polizei');
        _saveBlitzerToSupabase('police', 'Polizeikontrolle');
        break;

      case VoiceIntent.reportHazard:
        final label = cmd.blitzerType == 'construction' ? 'Baustelle' : 'Gefahrenstelle';
        final type = cmd.blitzerType ?? 'hazard';
        say('$label gemeldet.');
        HapticFeedback.heavyImpact();
        _addUserReportMarker(type, label);
        _saveBlitzerToSupabase(type, label);
        break;

      case VoiceIntent.reportTraffic:
        say('Stau gemeldet.');
        HapticFeedback.heavyImpact();
        _addUserReportMarker('traffic', 'Stau');
        _saveBlitzerToSupabase('traffic', 'Stau');
        break;

      // ── Tab switching ──
      case VoiceIntent.switchTab:
        final route = cmd.query;
        if (route != null && mounted) {
          final tabName = switch (route) {
            '/feed' => 'Feed', '/map' => 'Karte',
            '/garage' => 'Garage', '/profile' => 'Profil',
            _ => 'Tab',
          };
          say('Wechsle zu $tabName.');
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) context.go(route);
          });
        }
        break;

      // ── Bonus: Thank Moto ──
      case VoiceIntent.thankMoto:
        final responses = [
          'Immer gern, Racer!',
          'Kein Ding, fahr sicher!',
          'Jederzeit, Bruder!',
          'Gerne! Ride safe!',
          'Für dich immer, Racer!',
          'Passt! Gib Gas!',
        ];
        say(responses[DateTime.now().millisecond % responses.length]);
        break;

      // ── Bonus: Weather ──
      case VoiceIntent.askWeather:
        _voiceAskWeather(say);
        break;

      // ── Bonus: Speed query ──
      case VoiceIntent.askSpeed:
        final speed = _displaySpeed.round();
        final limit = _speedLimit != null && _speedLimit! > 0 ? ', Tempolimit $_speedLimit' : '';
        say('Du fährst $speed km/h$limit.');
        break;

      // ── Bonus: Location query ──
      case VoiceIntent.askLocation:
        final road = _roadName ?? 'unbekannte Straße';
        say('Du bist auf der $road.');
        break;

      // ── SOS ──
      case VoiceIntent.activateSos:
        say('SOS wird aktiviert!');
        HapticFeedback.heavyImpact();
        break;

      // ── Navigate to address ──
      case VoiceIntent.navigateTo:
        if (cmd.query != null && cmd.query!.isNotEmpty) {
          say('Suche Route zu ${cmd.query}.');
          _voiceNavigateTo(cmd.query!);
        } else {
          say('Wohin soll ich navigieren?');
        }
        break;

      // ── Unknown ──
      case VoiceIntent.unknown:
        say('Wie bitte, Racer?');
        break;

      default:
        say('Verstanden: $text');
    }

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) setState(() => _hiMotoFeedback = null);
    });
  }

  // Map voice query to PoiCategory
  static final _voicePoiCategoryMap = <String, PoiCategory>{
    'Tankstelle': PoiCategory.fuel,
    'Motorrad Werkstatt': PoiCategory.workshop,
    'Supermarkt': PoiCategory.grocery,
    'Restaurant': PoiCategory.restaurant,
    'Bar': PoiCategory.restaurant,
    'Café': PoiCategory.cafe,
    'Biker Shop': PoiCategory.bikerShop,
    'Auto Shop': PoiCategory.autoShop,
    'Apotheke': PoiCategory.pharmacy,
    'Lebensmittel': PoiCategory.grocery,
    'Krankenhaus': PoiCategory.hospital,
    'Bank': PoiCategory.bank,
  };

  // ── Voice POI Search: find nearest, announce, ask nav ──
  Future<void> _voiceSearchPoi(String query, String label, Function(double, double, String) askNav) async {
    try {
      final category = _voicePoiCategoryMap[query] ?? PoiCategory.fuel;
      debugPrint('[HiMoto] POI search: $query ($label) at $_lat,$_lng radius=${category.radiusMeters}');

      // Try normal radius first, then wider if no results
      var results = await PoiSearchService.instance.search(
        lat: _lat, lon: _lng, category: category, limit: 3,
      );
      debugPrint('[HiMoto] POI results (normal): ${results.length}');

      // Retry with 2x radius if nothing found
      if (results.isEmpty) {
        debugPrint('[HiMoto] Retrying with wider radius...');
        final wider = PoiCategory(
          id: category.id,
          label: category.label,
          labelPlural: category.labelPlural,
          overpassTag: category.overpassTag,
          overpassTag2: category.overpassTag2,
          googleType: category.googleType,
          radiusMeters: category.radiusMeters * 2,
        );
        results = await PoiSearchService.instance.search(
          lat: _lat, lon: _lng, category: wider, limit: 3,
        );
        debugPrint('[HiMoto] POI results (wider): ${results.length}');
      }

      if (results.isEmpty) {
        final v = VoskWakeWordService.instance;
        v.setPaused(true);
        await TtsAlertService.instance.speakText('Keine $label in der Nähe gefunden.');
        await Future.delayed(const Duration(milliseconds: 1500));
        v.setPaused(false);
        return;
      }

      // Build POI list for popup
      final poiItems = <Map<String, dynamic>>[];
      for (final r in results) {
        final dt = r.distanceM >= 1000
            ? '${(r.distanceM / 1000).toStringAsFixed(1)} km'
            : '${r.distanceM.round()} m';
        poiItems.add({
          'lat': r.lat, 'lng': r.lon,
          'name': r.name, 'dist': dt,
          'distM': r.distanceM,
        });
      }

      // Show popup with all results (tappable + voice "eins/zwei/drei")
      setState(() {
        _poiPopupTitle = label;
        _poiPopupItems = poiItems;
      });

      // TTS announces the options
      final v = VoskWakeWordService.instance;
      await Future.delayed(const Duration(milliseconds: 1500));
      final announce = poiItems.asMap().entries.map((e) =>
        '${e.key + 1}. ${e.value['name']}, ${e.value['dist']}').join('. ');
      v.setPaused(true);
      await TtsAlertService.instance.speakText('$announce. Welche Nummer?');
      await Future.delayed(const Duration(milliseconds: 800));
      v.setPaused(false);

      // Enable direct listen for number selection
      v.directListenMode = true;
      // Auto-dismiss after 15 seconds
      Future.delayed(const Duration(seconds: 15), () {
        if (_poiPopupItems.isNotEmpty) {
          setState(() { _poiPopupItems = []; _poiPopupTitle = ''; });
          v.directListenMode = false;
        }
      });
    } catch (e) {
      debugPrint('[HiMoto] POI search error: $e');
      final v = VoskWakeWordService.instance;
      v.setPaused(true);
      await TtsAlertService.instance.speakText('Suche fehlgeschlagen. Versuche es nochmal.');
      await Future.delayed(const Duration(milliseconds: 1500));
      v.setPaused(false);
    }
  }

  // ── Voice Events Search ──
  Future<void> _voiceSearchEvents(Function(double, double, String) askNav) async {
    try {
      final supabase = Supabase.instance.client;
      final now = DateTime.now().toIso8601String();
      final data = await supabase
          .from('meetups')
          .select()
          .gte('starts_at', now)
          .order('starts_at')
          .limit(3);
      if (data.isEmpty) {
        TtsAlertService.instance.speakText('Keine Treffen in der Nähe gefunden.');
        return;
      }
      final first = data.first;
      final title = first['title'] as String? ?? 'Treffen';
      final loc = first['location_text'] as String? ?? '';
      final lat = (first['latitude'] as num?)?.toDouble();
      final lng = (first['longitude'] as num?)?.toDouble();

      await Future.delayed(const Duration(milliseconds: 1500));
      if (lat != null && lng != null) {
        askNav(lat, lng, '$title in $loc');
      } else {
        TtsAlertService.instance.speakText('Nächstes Treffen: $title in $loc.');
      }
    } catch (e) {
      debugPrint('[HiMoto] Events search error: $e');
      TtsAlertService.instance.speakText('Suche fehlgeschlagen.');
    }
  }

  // ── Voice Navigate to address ──
  Future<void> _voiceNavigateTo(String address) async {
    try {
      final results = await _geocodeAddress(address);
      if (results != null) {
        _selectDestination(results.$1, results.$2, address);
      } else {
        TtsAlertService.instance.speakText('Adresse nicht gefunden.');
      }
    } catch (e) {
      debugPrint('[HiMoto] Navigate error: $e');
    }
  }

  // ── Voice Weather ──
  void _voiceAskWeather(void Function(String, {VoidCallback? then}) say) async {
    try {
      final url = 'https://api.open-meteo.com/v1/forecast?latitude=$_lat&longitude=$_lng&current=temperature_2m,weather_code,wind_speed_10m';
      final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final current = data['current'];
        final temp = (current['temperature_2m'] as num).round();
        final wind = (current['wind_speed_10m'] as num).round();
        final code = current['weather_code'] as int;
        final desc = _weatherCodeToGerman(code);
        say('$desc, $temp Grad, Wind $wind km/h.');
      } else {
        say('Wetterdaten nicht verfügbar.');
      }
    } catch (e) {
      say('Wetterdaten nicht verfügbar.');
    }
  }

  String _weatherCodeToGerman(int code) {
    if (code == 0) return 'Klar';
    if (code <= 3) return 'Bewölkt';
    if (code <= 49) return 'Neblig';
    if (code <= 59) return 'Nieselregen';
    if (code <= 69) return 'Regen';
    if (code <= 79) return 'Schnee';
    if (code <= 82) return 'Regenschauer';
    if (code <= 86) return 'Schneeschauer';
    if (code >= 95) return 'Gewitter';
    return 'Wechselhaft';
  }

  // ── Geocode an address string to lat/lng ──
  Future<(double, double)?> _geocodeAddress(String address) async {
    try {
      final url = 'https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(address)}&limit=1&countrycodes=de';
      final resp = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'Bikergram/1.0',
      }).timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as List;
        if (data.isNotEmpty) {
          final lat = double.parse(data.first['lat'] as String);
          final lng = double.parse(data.first['lon'] as String);
          return (lat, lng);
        }
      }
    } catch (e) {
      debugPrint('[Geocode] Error: $e');
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  MAP
  // ═══════════════════════════════════════════════════════════════════════════

  void _onMapCreated(MapboxMap map) async {
    _mapboxMap = map;

    // Hide Mapbox ornaments: compass, scale bar, logo, attribution
    map.compass.updateSettings(CompassSettings(enabled: false));
    map.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    map.logo.updateSettings(LogoSettings(
      marginTop: 800, // Push far down (effectively hidden behind bottom bar)
    ));
    map.attribution.updateSettings(AttributionSettings(
      marginTop: 800,
    ));

    // Globe projection — shows earth as 3D sphere when zoomed out
    try {
      await map.style.setProjection(
        StyleProjection(name: StyleProjectionName.globe),
      );
      debugPrint('[Map] Globe projection enabled');
    } catch (e) {
      debugPrint('[Map] Globe projection error: $e');
    }

    // Remove any built-in traffic layers from the Mapbox style
    try {
      final style = map.style;
      final layers = await style.getStyleLayers();
      for (final layer in layers) {
        final id = layer?.id ?? '';
        if (id.contains('traffic') || id.contains('incident')) {
          await style.setStyleLayerProperty(id, 'visibility', '"none"');
          debugPrint('[Traffic] Hid built-in layer: $id');
        }
      }
    } catch (e) {
      debugPrint('[Traffic] Error hiding layers: $e');
    }

    // Location Puck — custom vehicle icon per mode (red biker, blue car, green pedestrian)
    await _applyCustomPuck();

    // Fly to initial position when map loads
    if (_gpsLive && _gpsReady) {
      // GPS Toggle ON → fly to live GPS position (puck at bottom-center)
      await map.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(_lng, _lat)),
          zoom: 16, bearing: 0, pitch: 0,
          padding: MbxEdgeInsets(top: _cachedPuckPad, left: 0, bottom: 0, right: 0),
        ),
        MapAnimationOptions(duration: 800),
      );
    } else if (_plzLat != null && _plzLng != null) {
      // GPS Toggle OFF → DACH-Übersicht: ganz Deutschland + Schweiz + ein wenig Italien
      final authState = ref.read(authNotifierProvider);
      final plz = (authState is Authenticated) ? authState.user.postalCode ?? '' : '';
      _addPlzHomeMarker(_plzLat!, _plzLng!, plz);
      await map.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(10.4, 50.3)),
          zoom: 5.3, bearing: 0, pitch: 0,
        ),
        MapAnimationOptions(duration: 800),
      );
      _loadFollowedUserPlzMarkers();
    } else if (_gpsReady) {
      // Fallback: no PLZ → use GPS position
      await map.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(_lng, _lat)),
          zoom: 14, bearing: 0, pitch: 0,
        ),
        MapAnimationOptions(duration: 800),
      );
    }

    // Initialize live user annotation manager
    _initLiveUserLayer();

    // Search panel is collapsed by default — user opens it via compact bar
  }

  void _updatePuckColor() {
    if (_mapboxMap == null) return;
    // Re-generate and apply custom puck with new mode color
    _navPuckIconRegistered = false;
    _applyCustomPuck();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  LIVE USER MARKERS
  // ═══════════════════════════════════════════════════════════════════════════

  void _initLiveUserLayer() async {
    if (_mapboxMap == null) return;
    _userAnnotationManager = await _mapboxMap!.annotations
        .createPointAnnotationManager(id: 'live-users');

    // Tap on user marker → open profile
    _userAnnotationManager!.addOnPointAnnotationClickListener(
      _UserMarkerClickListener(
        markerUserIdMap: _markerUserIdMap,
        onUserTapped: (userId) {
          if (mounted) context.push('/profile/$userId');
        },
      ),
    );

    // Subscribe to live user updates
    final service = ref.read(liveLocationServiceProvider);
    _liveUsersSub = service.nearbyUsersStream.listen((allUsers) {
      if (!mounted) return;
      _updateLiveUserMarkers(allUsers);
    });

    // Seed with current snapshot
    final snapshot = service.nearbyUsers;
    if (snapshot.isNotEmpty) {
      _updateLiveUserMarkers(snapshot);
    }

    // Also listen to onlineUsersNotifier changes (e.g. after follow/unfollow)
    // This ensures markers update when following list changes, not just GPS stream
    onlineUsersNotifier.addListener(_onFollowingChanged);
  }

  void _onFollowingChanged() {
    if (!mounted || _userAnnotationManager == null) return;
    final service = ref.read(liveLocationServiceProvider);
    final allUsers = service.nearbyUsers;
    if (allUsers.isNotEmpty) {
      _updateLiveUserMarkers(allUsers);
    }
  }

  Timer? _userMarkerDebounce;

  void _updateLiveUserMarkers(Map<String, LiveUserPosition> allUsers) {
    // Debounce to avoid excessive updates
    _userMarkerDebounce?.cancel();
    _userMarkerDebounce = Timer(const Duration(seconds: 1), () {
      if (!mounted || _userAnnotationManager == null) return;
      _applyLiveUserMarkers(allUsers);
    });
  }

  Future<void> _applyLiveUserMarkers(Map<String, LiveUserPosition> allUsers) async {
    if (_userAnnotationManager == null || !mounted) return;

    final currentUserId = ref.read(authNotifierProvider) is Authenticated
        ? (ref.read(authNotifierProvider) as Authenticated).user.id
        : null;
    final community = ref.read(communityProvider)?.name ?? 'bikergram';

    // Filter: same community, not myself, only followed users, recent (< 5 min)
    final followingIds = onlineUsersNotifier.value.keys.toSet();
    final now = DateTime.now();
    final filtered = allUsers.entries.where((e) {
      final age = now.difference(e.value.lastUpdate).inMinutes;
      return e.value.community == community &&
          e.key != currentUserId &&
          followingIds.contains(e.key) &&
          age < 5; // Only show users updated within last 5 minutes
    }).toList();

    // Clear existing annotations and rebuild
    await _userAnnotationManager!.deleteAll();
    _markerUserIdMap.clear();

    for (final entry in filtered) {
      final user = entry.value;
      try {
        // Get or build icon
        Uint8List? iconBytes = _userIconCache[user.userId];
        if (iconBytes == null) {
          iconBytes = await _buildUserMarkerIcon(
            user.displayName ?? 'User',
            user.avatarUrl,
            user.sos,
          );
          if (!mounted) return;
          _userIconCache[user.userId] = iconBytes;
        }

        final annotation = await _userAnnotationManager!.create(PointAnnotationOptions(
          geometry: Point(coordinates: Position(user.lng, user.lat)),
          image: iconBytes,
          iconSize: 1.2, // Bigger icons on map
          iconAnchor: IconAnchor.BOTTOM,
          textField: user.displayName ?? '',
          textSize: 12,
          textColor: Colors.white.value.toInt(),
          textHaloColor: Colors.black.value.toInt(),
          textHaloWidth: 1.5,
          textOffset: [0.0, 1.0],
        ));
        // Track annotation → userId for click handler
        _markerUserIdMap[annotation.id] = entry.key;
      } catch (e) {
        debugPrint('[LiveUsers] Failed to add marker for ${user.userId}: $e');
      }
    }
  }

  /// Build a circular profile picture marker as PNG bytes for Mapbox.
  Future<Uint8List> _buildUserMarkerIcon(String name, String? avatarUrl, bool isSos) async {
    const size = 120.0; // Bigger marker icons
    const borderWidth = 5.0;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size, size));

    // Border circle (green for normal, red for SOS)
    final borderColor = isSos ? Colors.red : _modeColor;
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2,
      Paint()..color = borderColor,
    );

    // Inner circle (clip area for avatar)
    final innerRadius = size / 2 - borderWidth;
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      innerRadius,
      Paint()..color = const Color(0xFF1B1F2B),
    );

    // Try to load avatar image
    ui.Image? avatarImage;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      try {
        final imageProvider = CachedNetworkImageProvider(avatarUrl);
        final completer = Completer<ui.Image>();
        final stream = imageProvider.resolve(ImageConfiguration.empty);
        late ImageStreamListener listener;
        listener = ImageStreamListener(
          (info, _) {
            if (!completer.isCompleted) completer.complete(info.image);
            stream.removeListener(listener);
          },
          onError: (e, _) {
            if (!completer.isCompleted) completer.completeError(e);
            stream.removeListener(listener);
          },
        );
        stream.addListener(listener);
        avatarImage = await completer.future.timeout(const Duration(seconds: 3));
      } catch (_) {}
    }

    if (avatarImage != null) {
      // Draw avatar clipped to circle
      canvas.save();
      canvas.clipPath(Path()..addOval(Rect.fromCircle(
        center: const Offset(size / 2, size / 2),
        radius: innerRadius,
      )));
      final src = Rect.fromLTWH(0, 0, avatarImage.width.toDouble(), avatarImage.height.toDouble());
      final dst = Rect.fromCircle(center: const Offset(size / 2, size / 2), radius: innerRadius);
      canvas.drawImageRect(avatarImage, src, dst, Paint());
      canvas.restore();
    } else {
      // Fallback: Initial letter
      final textPainter = TextPainter(
        text: TextSpan(
          text: name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(
        (size - textPainter.width) / 2,
        (size - textPainter.height) / 2,
      ));
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  IconData _maneuverIcon(String? m) {
    if (m == null) return Icons.navigation;
    if (m.contains('left')) return Icons.turn_left;
    if (m.contains('right')) return Icons.turn_right;
    if (m.contains('uturn')) return Icons.u_turn_left;
    if (m.contains('roundabout') || m.contains('rotary')) return Icons.roundabout_left;
    if (m.contains('arrive')) return Icons.flag;
    return Icons.straight;
  }

  /// German road sign badge: A=blue, B=yellow, L/K=white
  Widget? _buildRoadBadge(String? ref) {
    if (ref == null || ref.isEmpty) return null;
    // Parse road type from ref: "A 3", "B 229", "L 188", "K 5"
    final match = RegExp(r'^([ABLK])\s*(\d+)').firstMatch(ref.trim());
    if (match == null) return null;
    final type = match.group(1)!;
    final num = match.group(2)!;

    Color bgColor;
    Color textColor;
    switch (type) {
      case 'A': bgColor = const Color(0xFF003399); textColor = Colors.white; // Autobahn blau
      case 'B': bgColor = const Color(0xFFFFCC00); textColor = Colors.black; // Bundesstraße gelb
      default:  bgColor = Colors.white; textColor = Colors.black; // L/K weiß
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: textColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Text('$type$num',
        style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
    );
  }

  Color get _modeColor => switch (_routeMode) {
    RouteMode.biker => const Color(0xFFE53935),       // Red
    RouteMode.auto => const Color(0xFF2196F3),         // Blue
    RouteMode.bicycle => const Color(0xFFFF9800),      // Orange
    RouteMode.pedestrian => const Color(0xFF4CAF50),   // Green
  };

  String _compassLabel(double bearing) {
    final b = bearing % 360;
    if (b < 45 || b >= 315) return 'N';
    if (b < 135) return 'O';
    if (b < 225) return 'S';
    return 'W';
  }

  String _fmtDist(double km) => km >= 1 ? '${km.toStringAsFixed(1)} km' : '${(km * 1000).round()} m';

  String _fmtTime(int minutes) {
    if (minutes < 60) return '$minutes Min.';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (m == 0) return '$h Std.';
    return '$h Std. $m Min.';
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  POI SEARCH + MAP MARKERS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Gibt die beste Suchposition zurück:
  /// GPS ON → aktuelle GPS-Position (_lat, _lng)
  /// GPS OFF → PLZ aus dem Profil (_plzLat, _plzLng)
  Future<(double, double)> _getSearchPosition() async {
    // GPS an und echte Position vorhanden
    if (_gpsLive && _lat.abs() > 1 && _lng.abs() > 1) {
      return (_lat, _lng);
    }
    // GPS aus → PLZ-Position aus dem Profil
    if (_plzLat != null && _plzLng != null) {
      debugPrint('[POI] GPS off → nutze PLZ-Position: $_plzLat, $_plzLng');
      return (_plzLat!, _plzLng!);
    }
    // Letzter Fallback: aktuelle _lat/_lng (Default oder letzte bekannte)
    return (_lat, _lng);
  }

  Future<void> _searchPoiAndShowOnMap(PoiCategory category) async {
    // ── Cooldown: prevent hammering servers after network failure ──
    if (_lastPoiNetworkError != null) {
      final elapsed = DateTime.now().difference(_lastPoiNetworkError!).inSeconds;
      if (elapsed < 5) {
        final remaining = 5 - elapsed;
        _showPoiError('Bitte $remaining Sek. warten...');
        return;
      }
      _lastPoiNetworkError = null;
    }

    setState(() {
      _poiLoading = true;
      _poiError = null;
      _activePoiCategory = category.id;
    });
    _poiErrorTimer?.cancel();

    try {
      // Suchposition: GPS oder Kartenzentrum
      final (searchLat, searchLon) = await _getSearchPosition();

      // If we already have results from auto-load, use them
      var results = _poiResults[category.id];
      if (results == null || results.isEmpty) {
        results = await PoiSearchService.instance.search(
          lat: searchLat, lon: searchLon,
          category: category,
          limit: 15,
        );
        _poiResults[category.id] = results;
      }

      if (results.isEmpty) {
        _showPoiError('Keine ${category.labelPlural} in der Nähe gefunden');
      } else {
        // Draw markers on map for this category
        await _drawPoiMarkers(results, category);
        // Show bottom sheet with POI list (no TTS — manual tap, not voice)
        if (mounted) _showPoiListSheet(results, category);
      }
    } on PoiNetworkException {
      debugPrint('[POI] Network error for ${category.id}');
      _lastPoiNetworkError = DateTime.now();
      _showPoiError('Kein Internet — erneut in 5 Sek.');
    } catch (e) {
      debugPrint('[POI] Search error: $e');
      _showPoiError('Suche fehlgeschlagen — bitte erneut versuchen');
    }

    if (mounted) setState(() => _poiLoading = false);
  }

  /// Show a styled error pill at the top of the screen, auto-dismiss after 5s.
  void _showPoiError(String msg) {
    if (!mounted) return;
    _poiErrorTimer?.cancel();
    setState(() => _poiError = msg);
    _poiErrorTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _poiError = null);
    });
  }

  void _showPoiCategorySheet() {
    if (!mounted) return;
    setState(() => _searchDropdownOpen = false);

    final isBiker = _routeMode == RouteMode.biker;

    // Row 1: vehicle-specific
    final row1 = isBiker
        ? [(PoiCategory.bikerShop, Icons.two_wheeler, 'Biker Shops', const Color(0xFFE53935)),
           (PoiCategory.autoShop, Icons.directions_car, 'Auto Shops', const Color(0xFF2196F3)),
           (PoiCategory.workshop, Icons.build_rounded, 'Werkstätten', const Color(0xFF9C27B0))]
        : [(PoiCategory.autoShop, Icons.directions_car, 'Auto Shops', const Color(0xFF2196F3)),
           (PoiCategory.bikerShop, Icons.two_wheeler, 'Biker Shops', const Color(0xFFE53935)),
           (PoiCategory.workshop, Icons.build_rounded, 'Werkstätten', const Color(0xFF9C27B0))];

    // Row 2: fuel + food
    const row2 = [
      (PoiCategory.fuel, Icons.local_gas_station, 'Tankstellen', Color(0xFFFF9800)),
      (PoiCategory.restaurant, Icons.restaurant, 'Restaurants', Color(0xFF4CAF50)),
      (PoiCategory.grocery, Icons.shopping_cart_rounded, 'Lebensmittel', Color(0xFF8BC34A)),
    ];

    // Row 3: social + health
    const row3Special = [
      // Treffen + Gruppen are navigation links, not POI categories
      ('treffen', Icons.event_rounded, 'Treffen', Color(0xFFFF5722)),
      ('gruppen', Icons.groups_rounded, 'Gruppen', Color(0xFFFFCC00)),
      ('hospital', Icons.local_hospital_rounded, 'Krankenhäuser', Color(0xFFE91E63)),
    ];

    // Row 4: more services
    const row4 = [
      (PoiCategory.pharmacy, Icons.local_pharmacy_rounded, 'Apotheken', Color(0xFF00BCD4)),
      (PoiCategory.bank, Icons.account_balance_rounded, 'Banken', Color(0xFF607D8B)),
      (PoiCategory.cafe, Icons.coffee_rounded, 'Cafés', Color(0xFF795548)),
    ];

    final allPoiCategories = [...row1, ...row2, ...row4];

    final outerContext = context;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _isDark ? const Color(0xF0111111) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        final bp = MediaQuery.of(context).padding.bottom;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: Padding(
            padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: bp + 60),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Handle
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: _textPrimary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text('POIs in der Nähe', style: TextStyle(color: _textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              Flexible(child: SingleChildScrollView(child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Row 1
                  _poiGridRow(row1.map((c) => _poiTile(c.$1, c.$2, c.$3, c.$4)).toList()),
                  const SizedBox(height: 10),
                  // Row 2
                  _poiGridRow(row2.map((c) => _poiTile(c.$1, c.$2, c.$3, c.$4)).toList()),
                  const SizedBox(height: 10),
                  // Row 3 (special: Treffen, Gruppen, Krankenhäuser)
                  _poiGridRow([
                    _poiSpecialTile(Icons.event_rounded, 'Treffen', const Color(0xFFFF5722),
                      () { Navigator.pop(context); outerContext.push('/events'); }),
                    _poiSpecialTile(Icons.groups_rounded, 'Gruppen', const Color(0xFFFFCC00),
                      () { Navigator.pop(context); outerContext.push('/groups'); }),
                    _poiTile(PoiCategory.hospital, Icons.local_hospital_rounded, 'Krankenhäuser', const Color(0xFFE91E63)),
                  ]),
                  const SizedBox(height: 10),
                  // Row 4
                  _poiGridRow(row4.map((c) => _poiTile(c.$1, c.$2, c.$3, c.$4)).toList()),
                ],
              ))),
            ]),
          ),
        );
      },
    );
  }

  Widget _poiGridRow(List<Widget> tiles) => Row(
    children: <Widget>[
      Expanded(child: tiles[0]),
      const SizedBox(width: 10),
      Expanded(child: tiles[1]),
      const SizedBox(width: 10),
      Expanded(child: tiles[2]),
    ],
  );

  Widget _poiTile(PoiCategory cat, IconData icon, String label, Color color) =>
    GestureDetector(
      onTap: () { Navigator.pop(context); _searchPoiAndShowOnMap(cat); },
      child: AspectRatio(
        aspectRatio: 1.05,
        child: Container(
          decoration: BoxDecoration(
            color: _isDark ? const Color(0xFF1E1E2A) : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ),
    );

  Widget _poiSpecialTile(IconData icon, String label, Color color, VoidCallback onTap) =>
    GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 1.05,
        child: Container(
          decoration: BoxDecoration(
            color: _isDark ? const Color(0xFF1E1E2A) : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center),
          ]),
        ),
      ),
    );

  /// Fly camera to a POI and add a pulsing highlight ring on the map itself.
  /// Highlight stays until another POI is selected or user taps empty map.
  /// Wird aufgerufen wenn jemand im Chat auf eine Location-Nachricht tippt
  void _onPendingPoiFlyTo() {
    final pending = MapboxRideScreen.pendingPoiFlyTo.value;
    if (pending == null || _mapboxMap == null) return;
    MapboxRideScreen.pendingPoiFlyTo.value = null; // einmalig konsumieren

    // PoiResult aus den Daten erstellen
    final poi = PoiResult(
      name: pending.name,
      lat: pending.lat,
      lon: pending.lon,
      distanceM: geo.Geolocator.distanceBetween(_lat, _lng, pending.lat, pending.lon),
      type: pending.type.isNotEmpty ? pending.type : 'restaurant',
    );

    // Suchleiste weg, zum POI fliegen, Detail-Sheet öffnen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _searchPanelHidden = true);
      _flyToPoiAndHighlight(poi, _modeColor, withSheet: true);
      _showPoiDetailSheet(poi);
    });
  }

  void _flyToPoiAndHighlight(PoiResult poi, Color color, {bool withSheet = false}) {
    _mapboxMap?.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(poi.lon, poi.lat)),
        // POI mittig zwischen App-Bar (oben ~100px) und Sheet (unten ~420px)
        padding: withSheet
            ? MbxEdgeInsets(top: 100, left: 0, bottom: 420, right: 0)
            : null,
        zoom: 16, bearing: 0, pitch: 0,
      ),
      MapAnimationOptions(duration: 800),
    );
    _highlightTimer?.cancel();
    setState(() => _highlightedPoi = poi);
    _addHighlightLayer(poi);
  }

  Timer? _pulseTimer;
  bool _pulseOn = true;

  /// Highlight-Ring direkt auf der Mapbox-Karte am POI — blinkt sanft.
  Future<void> _addHighlightLayer(PoiResult poi) async {
    if (_mapboxMap == null) return;
    final style = _mapboxMap!.style;
    await _removeHighlightLayer();

    final geoJson = '{"type":"FeatureCollection","features":[{"type":"Feature",'
        '"properties":{},'
        '"geometry":{"type":"Point","coordinates":[${poi.lon},${poi.lat}]}}]}';

    try {
      await style.addSource(GeoJsonSource(id: 'poi-highlight-src', data: geoJson));

      // Blinkender Ring um den POI-Marker
      await style.addLayer(CircleLayer(
        id: 'poi-highlight-ring',
        sourceId: 'poi-highlight-src',
        circleRadius: 28.0,
        circleColor: 0x00000000, // transparent fill
        circleStrokeWidth: 3.5,
        circleStrokeColor: _modeColor.value,
        circleOpacity: 0.9,
      ));

      debugPrint('[POI] Highlight ring added for ${poi.name}');
    } catch (e) {
      debugPrint('[POI] Highlight layer error: $e');
      return;
    }

    // Blink: toggle ring visibility alle 700ms
    _pulseOn = true;
    _pulseTimer?.cancel();
    _pulseTimer = Timer.periodic(const Duration(milliseconds: 700), (_) async {
      if (_mapboxMap == null || _highlightedPoi == null) {
        _pulseTimer?.cancel();
        return;
      }
      _pulseOn = !_pulseOn;
      try {
        await _mapboxMap!.style.setStyleLayerProperty(
          'poi-highlight-ring', 'visibility', _pulseOn ? 'visible' : 'none',
        );
      } catch (_) {}
    });
  }

  Future<void> _removeHighlightLayer() async {
    _pulseTimer?.cancel();
    if (_mapboxMap == null) return;
    final style = _mapboxMap!.style;
    try { await style.removeStyleLayer('poi-highlight-label'); } catch (_) {}
    try { await style.removeStyleLayer('poi-highlight-dot'); } catch (_) {}
    try { await style.removeStyleLayer('poi-highlight-ring'); } catch (_) {}
    try { await style.removeStyleSource('poi-highlight-src'); } catch (_) {}
  }

  /// Pulsing ring overlay — centered on screen (camera already flew to POI).
  /// Uses the existing _tutorialAnimCtrl for the pulse animation.
  Widget _buildPoiHighlightRing() {
    final poi = _highlightedPoi!;
    final catColor = switch (poi.type) {
      'fuel' => const Color(0xFFFF9800),
      'workshop' => const Color(0xFF9C27B0),
      'biker_shop' => const Color(0xFFE53935),
      'auto_shop' => const Color(0xFF2196F3),
      'restaurant' => const Color(0xFF4CAF50),
      'cafe' => const Color(0xFF795548),
      'bank' => const Color(0xFF607D8B),
      'hospital' => const Color(0xFFE91E63),
      'grocery' => const Color(0xFF8BC34A),
      'pharmacy' => const Color(0xFF00BCD4),
      _ => _modeColor,
    };

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: false,
        child: Stack(
          children: [
            // Transparent background — taps pass through to map
            const Positioned.fill(child: SizedBox.shrink()),
            // Ring + label — centered, tappable
            Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  final p = _highlightedPoi;
                  _highlightTimer?.cancel();
                  _removeHighlightLayer();
                  setState(() => _highlightedPoi = null);
                  if (p != null) _showPoiDetailSheet(p);
                },
                child: AnimatedBuilder(
                  animation: _tutorialAnimCtrl,
                  builder: (_, __) {
                    final t = _tutorialAnimCtrl.value;
                    final scale = 0.7 + (t * 0.6);
                    final opacity = 1.0 - (t * 0.5);
                    return Padding(
                      padding: const EdgeInsets.all(20), // bigger tap area
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // POI name label
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: catColor,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(color: catColor.withValues(alpha: 0.4), blurRadius: 12)],
                            ),
                            child: Text(poi.name, style: const TextStyle(
                              color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold,
                            )),
                          ),
                          // Pulsing ring
                          Transform.scale(
                            scale: scale,
                            child: Container(
                              width: 60, height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: catColor.withValues(alpha: opacity), width: 3),
                                boxShadow: [BoxShadow(color: catColor.withValues(alpha: 0.3 * opacity), blurRadius: 20, spreadRadius: 5)],
                              ),
                              child: Center(
                                child: Container(
                                  width: 14, height: 14,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: catColor,
                                    boxShadow: [BoxShadow(color: catColor.withValues(alpha: 0.6), blurRadius: 8)],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPoiListSheet(List<PoiResult> results, PoiCategory category) async {
    if (!mounted) return;
    final color = switch (category.id) {
      'fuel' => const Color(0xFFFF9800),
      'workshop' => const Color(0xFF9C27B0),
      'biker_shop' => const Color(0xFFE53935),
      'auto_shop' => const Color(0xFF2196F3),
      'restaurant' => const Color(0xFF4CAF50),
      'cafe' => const Color(0xFF795548),
      'hospital' => const Color(0xFFE91E63),
      'bank' => const Color(0xFF607D8B),
      'grocery' => const Color(0xFF8BC34A),
      'pharmacy' => const Color(0xFF00BCD4),
      _ => Colors.white,
    };

    // Load ratings for all POIs in one query
    final Map<String, ({double avg, int count})> ratingMap = {};
    try {
      final names = results.map((r) => r.name).toList();
      final ratings = await Supabase.instance.client
          .from('poi_ratings')
          .select('poi_name, rating')
          .inFilter('poi_name', names);
      if (ratings is List) {
        final grouped = <String, List<int>>{};
        for (final r in ratings) {
          final name = r['poi_name'] as String;
          grouped.putIfAbsent(name, () => []).add(r['rating'] as int);
        }
        for (final entry in grouped.entries) {
          final sum = entry.value.fold<int>(0, (s, v) => s + v);
          ratingMap[entry.key] = (avg: sum / entry.value.length, count: entry.value.length);
        }
      }
    } catch (_) {}

    if (!mounted) return;

    // Mutable copies für StatefulBuilder (Pull-to-Refresh)
    var currentResults = List<PoiResult>.from(results);
    var currentRatings = Map<String, ({double avg, int count})>.from(ratingMap);
    var isRefreshing = false;

    final bp = MediaQuery.of(context).padding.bottom;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _isDark ? const Color(0xF0111111) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - 50),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
        padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: bp + 60),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            )),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: Text('${category.labelPlural} in der Nähe',
                style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold))),
              if (isRefreshing)
                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: color))
              else
                Text('↓ Ziehen = Aktualisieren', style: TextStyle(color: _textSecondary, fontSize: 10)),
            ]),
            const SizedBox(height: 12),
            Flexible(child: RefreshIndicator(
              color: color,
              onRefresh: () async {
                setSheetState(() => isRefreshing = true);
                // Cache für diese Kategorie löschen → frische Suche
                PoiSearchService.instance.clearCache();
                try {
                  final (sLat, sLon) = await _getSearchPosition();
                  final newResults = await PoiSearchService.instance.search(
                    lat: sLat, lon: sLon, category: category, limit: 10,
                  );
                  if (newResults.isNotEmpty) {
                    // Ratings nachladen
                    final newRatings = <String, ({double avg, int count})>{};
                    try {
                      final names = newResults.map((r) => r.name).toList();
                      final ratings = await Supabase.instance.client
                          .from('poi_ratings')
                          .select('poi_name, rating')
                          .inFilter('poi_name', names);
                      if (ratings is List) {
                        final grouped = <String, List<int>>{};
                        for (final r in ratings) {
                          final name = r['poi_name'] as String;
                          grouped.putIfAbsent(name, () => []).add(r['rating'] as int);
                        }
                        for (final entry in grouped.entries) {
                          final sum = entry.value.fold<int>(0, (s, v) => s + v);
                          newRatings[entry.key] = (avg: sum / entry.value.length, count: entry.value.length);
                        }
                      }
                    } catch (_) {}

                    setSheetState(() {
                      currentResults = newResults;
                      currentRatings = newRatings;
                      isRefreshing = false;
                    });
                    // POI-Marker auf Karte aktualisieren
                    _poiResults[category.id] = newResults;
                    _drawPoiMarkers(newResults, category);
                  } else {
                    setSheetState(() => isRefreshing = false);
                  }
                } catch (_) {
                  setSheetState(() => isRefreshing = false);
                }
              },
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: currentResults.length.clamp(0, 10),
                itemBuilder: (_, i) {
                final r = currentResults[i];
                final rating = currentRatings[r.name];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: ListTile(
                    dense: true,
                    leading: CircleAvatar(backgroundColor: color, radius: 18,
                      child: Icon(_poiIcon(category.id), color: Colors.white, size: 18)),
                    title: Text(r.name, style: TextStyle(color: _textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.distanceText, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
                        if (rating != null)
                          GestureDetector(
                            onTap: () {
                              Navigator.pop(ctx);
                              _showPoiRatingSheet(r);
                            },
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              ...List.generate(5, (s) => Icon(
                                s < rating.avg.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                                color: Colors.amber, size: 12,
                              )),
                              const SizedBox(width: 4),
                              Text('${rating.avg.toStringAsFixed(1)} (${rating.count})',
                                style: TextStyle(color: _textSecondary, fontSize: 10)),
                            ]),
                          ),
                        if (r.address != null)
                          Text(r.address!, style: TextStyle(color: _textSecondary, fontSize: 11),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (r.openingHours != null)
                          Text('🕐 ${r.openingHours}', style: TextStyle(color: _textSecondary, fontSize: 11),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      GestureDetector(
                        onTap: () { Navigator.pop(ctx); _showPoiRatingSheet(r); },
                        child: const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          _flyToPoiAndHighlight(r, color);
                        },
                        child: Icon(Icons.map_rounded, color: color, size: 20),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          TtsAlertService.instance.stop();
                          _selectDestination(r.lat, r.lon, r.name);
                        },
                        child: Icon(Icons.navigation_rounded, color: color, size: 20),
                      ),
                    ]),
                  ),
                );
              },
            ))),
          ],
        ),
      )),
    ).whenComplete(() {
      TtsAlertService.instance.stop();
    });
  }

  IconData _poiIcon(String type) => switch (type) {
    'fuel' => Icons.local_gas_station,
    'workshop' => Icons.build,
    'biker_shop' => Icons.two_wheeler,
    'auto_shop' => Icons.directions_car,
    'restaurant' => Icons.restaurant,
    'cafe' => Icons.coffee_rounded,
    'bank' => Icons.account_balance_rounded,
    'hospital' => Icons.local_hospital_rounded,
    'grocery' => Icons.shopping_cart_rounded,
    'pharmacy' => Icons.local_pharmacy_rounded,
    _ => Icons.place,
  };

  Future<void> _drawPoiMarkers(List<PoiResult> results, PoiCategory category) async {
    if (_mapboxMap == null) return;
    final style = _mapboxMap!.style;

    // Remove old POI layer
    try { await style.removeStyleLayer('poi-labels'); } catch (_) {}
    try { await style.removeStyleLayer('poi-circles'); } catch (_) {}
    try { await style.removeStyleSource('poi-source'); } catch (_) {}

    if (results.isEmpty) return;

    // Build GeoJSON FeatureCollection
    final features = results.map((r) => '{"type":"Feature",'
        '"properties":{"name":"${r.name.replaceAll('"', '\\"')}","dist":"${r.distanceText}"},'
        '"geometry":{"type":"Point","coordinates":[${r.lon},${r.lat}]}}').join(',');
    final geoJson = '{"type":"FeatureCollection","features":[$features]}';

    await style.addSource(GeoJsonSource(id: 'poi-source', data: geoJson));

    // Circle markers
    final poiColor = switch (category.id) {
      'fuel' => 0xFFFF9800,       // Orange
      'workshop' => 0xFF9C27B0,   // Purple
      'biker_shop' => 0xFFE53935, // Red
      'auto_shop' => 0xFF2196F3,  // Blue
      'restaurant' => 0xFF4CAF50, // Green
      'cafe' => 0xFF795548,       // Brown
      'bank' => 0xFFFFC107,       // Amber
      'hospital' => 0xFFE91E63,   // Pink
      'grocery' => 0xFF8BC34A,    // Light Green
      'pharmacy' => 0xFF00BCD4,   // Cyan
      _ => 0xFFFFFFFF,
    };

    await style.addLayer(CircleLayer(
      id: 'poi-circles',
      sourceId: 'poi-source',
      circleRadius: 8.0,
      circleColor: poiColor,
      circleStrokeColor: 0xFFFFFFFF,
      circleStrokeWidth: 2.0,
      circleOpacity: 0.9,
    ));

    // Text labels
    await style.addLayer(SymbolLayer(
      id: 'poi-labels',
      sourceId: 'poi-source',
      textField: '{name}',
      textSize: 11.0,
      textColor: 0xFFFFFFFF,
      textHaloColor: 0xFF000000,
      textHaloWidth: 1.5,
      textOffset: [0.0, 1.5],
      textAnchor: TextAnchor.TOP,
      textMaxWidth: 10.0,
    ));
  }

  /// Load ALL POI categories and show them on the map automatically.
  Future<void> _loadAllPoisOnMap() async {
    if (_mapboxMap == null) return;

    // Use GPS position if available, otherwise PLZ fallback
    final lat = _gpsReady && _lat.abs() > 1 ? _lat : (_plzLat ?? _lat);
    final lon = _gpsReady && _lng.abs() > 1 ? _lng : (_plzLng ?? _lng);
    if (lat.abs() < 1 && lon.abs() < 1) return; // No valid position

    try {
      final allResults = await PoiSearchService.instance.searchAll(
        lat: lat, lon: lon,
        limitPerCategory: 10,
      );

      _poiResults = allResults;

      // Build one big GeoJSON with all POIs, each with a "type" property for styling
      final features = <String>[];
      for (final entry in allResults.entries) {
        for (final r in entry.value) {
          final escapedName = r.name.replaceAll('"', '\\"').replaceAll('\n', ' ');
          features.add(
            '{"type":"Feature",'
            '"properties":{"name":"$escapedName","dist":"${r.distanceText}","poiType":"${r.type}"},'
            '"geometry":{"type":"Point","coordinates":[${r.lon},${r.lat}]}}'
          );
        }
      }

      if (features.isEmpty) return;

      final geoJson = '{"type":"FeatureCollection","features":[${features.join(',')}]}';
      final style = _mapboxMap!.style;

      // Remove old layers
      try { await style.removeStyleLayer('poi-labels'); } catch (_) {}
      try { await style.removeStyleLayer('poi-circles'); } catch (_) {}
      try { await style.removeStyleSource('poi-source'); } catch (_) {}

      await style.addSource(GeoJsonSource(id: 'poi-source', data: geoJson));

      // Circles: simple color, no expressions (more reliable)
      await style.addLayer(CircleLayer(
        id: 'poi-circles',
        sourceId: 'poi-source',
        circleRadius: 8.0,
        circleColor: 0xFFFF9800, // Orange default
        circleStrokeColor: 0xFFFFFFFF,
        circleStrokeWidth: 2.0,
        circleOpacity: 0.95,
        minZoom: 11.0, // Erst ab Zoom 11 anzeigen
      ));

      // Try to set per-type colors via raw expression
      try {
        await _mapboxMap!.style.setStyleLayerProperty(
          'poi-circles', 'circle-color',
          '["match", ["get", "poiType"], '
          '"fuel", "#FF9800", '        // Orange
          '"workshop", "#9C27B0", '    // Purple
          '"biker_shop", "#E53935", '  // Red
          '"auto_shop", "#2196F3", '   // Blue
          '"restaurant", "#4CAF50", '  // Green
          '"cafe", "#795548", '        // Brown
          '"bank", "#FFC107", '        // Amber
          '"hospital", "#E91E63", '    // Pink
          '"grocery", "#8BC34A", '     // Light Green
          '"pharmacy", "#00BCD4", '    // Cyan
          '"#FFFFFF"]',
        );
      } catch (e) {
        debugPrint('[POI] Color expression failed (using default orange): $e');
      }

      // Labels: use expression format for textField
      try {
        await style.addLayer(SymbolLayer(
          id: 'poi-labels',
          sourceId: 'poi-source',
          textSize: 10.0,
          textColor: 0xFFFFFFFF,
          textHaloColor: 0xFF000000,
          textHaloWidth: 1.0,
          textAnchor: TextAnchor.TOP,
          textMaxWidth: 8.0,
          textOptional: true,
          iconAllowOverlap: true,
        ));
        // Set textField via raw property (more reliable than constructor)
        await _mapboxMap!.style.setStyleLayerProperty(
          'poi-labels', 'text-field', '["get", "name"]',
        );
        await _mapboxMap!.style.setStyleLayerProperty(
          'poi-labels', 'text-offset', '[0, 1.5]',
        );
      } catch (e) {
        debugPrint('[POI] Labels layer failed: $e');
      }

      debugPrint('[POI] Loaded ${features.length} POIs on map');
    } catch (e) {
      debugPrint('[POI] Auto-load error: $e');
    }
  }

  void _clearPoiMarkers() async {
    setState(() => _activePoiCategory = null);
    if (_mapboxMap == null) return;
    final style = _mapboxMap!.style;
    try { await style.removeStyleLayer('poi-labels'); } catch (_) {}
    try { await style.removeStyleLayer('poi-circles'); } catch (_) {}
    try { await style.removeStyleSource('poi-source'); } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    // Watch community → auto-sync route mode
    final community = ref.watch(communityProvider);
    final expectedMode = community == Community.cargram ? RouteMode.auto : RouteMode.biker;
    if (_routeMode != expectedMode && !_isNavigating && _currentRoute == null) {
      // Only auto-sync when not actively navigating (user may have manually switched)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _routeMode != expectedMode && !_isNavigating && _currentRoute == null) {
          setState(() => _routeMode = expectedMode);
          NavigationState.instance.setRouteMode(expectedMode);
          _updatePuckColor();
        }
      });
    }

    // Check for pending navigation target (from Events/Treffen)
    final pendingTarget = ref.watch(focusMapTargetProvider);
    if (pendingTarget != null && pendingTarget.navigateTo && _mapboxMap != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(focusMapTargetProvider.notifier).clear();
        _selectDestination(
          pendingTarget.position.latitude,
          pendingTarget.position.longitude,
          pendingTarget.displayName ?? 'Ziel',
        );
      });
    }

    final bp = MediaQuery.of(context).padding.bottom;
    // Cache screen-dependent puck padding for async methods
    _cachedPuckPad = MediaQuery.of(context).size.height * 0.65;

    return Scaffold(
      body: Stack(
        children: [
          // ── MAP (Listener detects touch → auto-hide search panel) ──
          Listener(
            onPointerDown: (_) {
              _activePointers++;
              // Touch klappt Suchleiste ein (bleibt eingeklappt bis User öffnet)
              if (!_isNavigating && _currentRoute == null && !_searchPanelHidden) {
                setState(() => _searchPanelHidden = true);
              }
              // Pause follow during touch (allows zoom/pan)
              if (_isNavigating && _isFollowing) {
                _isFollowing = false;
                _resumeFollowTimer?.cancel();
              }
            },
            onPointerUp: (_) {
              _activePointers = (_activePointers - 1).clamp(0, 10);
              // Resume follow 5s after last finger lifts
              if (_activePointers == 0 && _isNavigating && !_isFollowing) {
                _resumeFollowTimer?.cancel();
                _resumeFollowTimer = Timer(const Duration(seconds: 5), () {
                  if (mounted && _isNavigating) {
                    _isFollowing = true;
                  }
                });
              }
            },
            onPointerCancel: (_) {
              _activePointers = (_activePointers - 1).clamp(0, 10);
            },
            child: MapWidget(
              key: const ValueKey('mapbox-ride'),
              onMapCreated: _onMapCreated,
              onTapListener: _onMapTap,
              styleUri: Theme.of(context).brightness == Brightness.dark
                  ? 'mapbox://styles/mapbox/navigation-night-v1'
                  : 'mapbox://styles/mapbox/navigation-day-v1',
              cameraOptions: CameraOptions(
                center: Point(coordinates: Position(_lng, _lat)),
                zoom: 15, pitch: _isNavigating ? 55 : 0,
              ),
            ),
          ),
          // Transparent overlay to detect taps during navigation → show bars briefly
          if (_isNavigating && !NavigationState.instance.barsVisible)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapUp: (_) => NavigationState.instance.showBarsBriefly(),
              ),
            ),

          // ── COMPACT SEARCH BAR (default, eingeklappt) ──
          if (!_isNavigating && _currentRoute == null && !_searchOpen && _searchPanelHidden)
            Positioned(
              top: 0, left: 0, right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 46, 12, 0),
                  child: GestureDetector(
                    onTap: () => setState(() => _searchPanelHidden = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: _cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _cardBorder),
                        boxShadow: [BoxShadow(color: _shadowColor, blurRadius: 16, offset: const Offset(0, 4))],
                      ),
                      child: Row(children: [
                        Icon(Icons.search_rounded, color: _modeColor, size: 22),
                        const SizedBox(width: 10),
                        Expanded(child: Text('Wohin, Racer?', style: TextStyle(color: _textMuted, fontSize: 16))),
                        GestureDetector(
                          onTap: () {
                            // Mic button for voice search
                            setState(() => _searchPanelHidden = false);
                          },
                          child: Icon(Icons.mic_rounded, color: _iconMuted, size: 20),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _triggerSos,
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                            ),
                            child: const Text('SOS', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1)),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
            ),

          // ── SEARCH CARD (expanded: search + quick buttons + recent destinations) ──
          if (!_isNavigating && _currentRoute == null && !_searchOpen && !_searchPanelHidden)
            Positioned(
              top: 0, left: 0, right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 46, 12, 0), // Below global top bar
                  child: Container(
                    decoration: BoxDecoration(
                      color: _cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _cardBorder),
                      boxShadow: [BoxShadow(color: _shadowColor, blurRadius: 16)],
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      // Search bar
                      GestureDetector(
                        onTap: () {
                          NavigationState.instance.startNavigation();
                          setState(() => _searchOpen = true);
                        },
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                          child: Row(children: [
                            Icon(Icons.search, color: _modeColor, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text('Wohin, Racer?', style: TextStyle(color: _textMuted, fontSize: 16)),
                            ),
                            GestureDetector(
                              onTap: _startVoiceSearch,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Icon(Icons.mic_rounded, color: _modeColor, size: 22),
                              ),
                            ),
                            GestureDetector(
                              onTap: _triggerSos,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                                ),
                                child: const Text('SOS', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Close/collapse button
                            GestureDetector(
                              onTap: () => setState(() => _searchPanelHidden = true),
                              child: Icon(Icons.close_rounded, color: _iconMuted, size: 20),
                            ),
                          ]),
                        ),
                      ),
                      // Divider
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Divider(color: _dividerColor, height: 1),
                      ),
                      // Quick buttons row
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                        child: Row(children: [
                          _quickNavBtn(Icons.home_rounded, 'Zuhause', 'nav_home'),
                          const SizedBox(width: 6),
                          _quickNavBtn(Icons.work_rounded, 'Arbeit', 'nav_work'),
                          const SizedBox(width: 6),
                          Expanded(
                            child: GestureDetector(
                              onTap: _showPoiCategorySheet,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _cardBg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: _cardBorder)),
                                child: Column(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(Icons.explore, color: _modeColor.withValues(alpha: 0.7), size: 22),
                                  const SizedBox(height: 4),
                                  Text('POIs', style: TextStyle(color: _iconMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                                ]),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => context.go('/events?tab=treffen'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _cardBg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: _cardBorder)),
                                child: Column(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(Icons.event_rounded, color: _modeColor.withValues(alpha: 0.7), size: 22),
                                  const SizedBox(height: 4),
                                  Text('Treffen', style: TextStyle(color: _iconMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                                ]),
                              ),
                            ),
                          ),
                        ]),
                      ),
                      // Letzte Ziele (inside same card)
                      if (_searchHistory.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Divider(color: _dividerColor, height: 1),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                          child: Row(children: [
                            Icon(Icons.history, color: _iconFaint, size: 16),
                            const SizedBox(width: 8),
                            Text('Letzte Ziele', style: TextStyle(color: _textMuted, fontSize: 14, fontWeight: FontWeight.w600)),
                          ]),
                        ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 280),
                          child: NotificationListener<ScrollNotification>(
                            onNotification: (n) {
                              if (n is ScrollStartNotification && !_recentScrolling) {
                                setState(() => _recentScrolling = true);
                              } else if (n is ScrollEndNotification && _recentScrolling) {
                                setState(() => _recentScrolling = false);
                              }
                              return false;
                            },
                            child: ListView.builder(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: _searchHistory.length,
                            itemBuilder: (_, i) {
                              final h = _searchHistory[i];
                              return InkWell(
                                onTap: () => _selectDestination(h['lat'] as double, h['lng'] as double, h['name'] as String),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                                  child: Row(children: [
                                    Icon(Icons.history, color: _iconFaint, size: 18),
                                    const SizedBox(width: 12),
                                    Expanded(child: Text(
                                      h['name'] as String,
                                      style: TextStyle(color: _textSecondary, fontSize: 16),
                                      overflow: TextOverflow.ellipsis,
                                    )),
                                    Icon(Icons.chevron_right, color: _iconFaint, size: 18),
                                  ]),
                                ),
                              );
                            },
                          ),
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                    ]),
                  ),
                ),
              ),
            ),

          // ── TURN BANNER (during navigation, below TopBar) ──
          if (_nextInstruction != null && _isNavigating)
            Positioned(
              top: 0, left: 0, right: 0,
              child: SafeArea(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: _isDark ? const Color(0xF0111111) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _modeColor, width: 1.5),
                    boxShadow: [
                      BoxShadow(color: _modeColor.withValues(alpha: 0.3), blurRadius: 12),
                      if (!_isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(_maneuverIcon(_currentManeuver), color: _modeColor, size: 32),
                        const SizedBox(width: 12),
                        Expanded(child: Text(_nextInstruction!,
                          style: TextStyle(color: _isDark ? Colors.white : Colors.black87, fontSize: 17, fontWeight: FontWeight.w600),
                          maxLines: 2, overflow: TextOverflow.ellipsis)),
                      ]),
                      // Road badge + destinations
                      if (_currentStepRef != null || _currentDestinations != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6, left: 44),
                          child: Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (_buildRoadBadge(_currentStepRef) != null)
                                _buildRoadBadge(_currentStepRef)!,
                              if (_currentDestinations != null)
                                Flexible(child: Text(
                                  'Richtung ${_currentDestinations!.split(',').first.trim()}',
                                  style: TextStyle(color: (_isDark ? Colors.white : Colors.black87).withValues(alpha: 0.7), fontSize: 13),
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                )),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

          // ── BLITZER WARNING (below turn banner) ──
          if (_blitzerWarning != null)
            Positioned(
              top: (_isNavigating && _nextInstruction != null) ? 140 : 60, left: 12, right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xF0B71C1C), borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.red.withValues(alpha: 0.5), blurRadius: 16)],
                ),
                child: Row(children: [
                  const Text('🚨', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_blitzerWarning!,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600))),
                ]),
              ),
            ),

          // ── GPS LOST indicator ──
          if (_gpsLost)
            Positioned(
              top: (_isNavigating && _nextInstruction != null) ? 200 : 100,
              left: 40, right: 40,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.red.withValues(alpha: 0.4), blurRadius: 12)],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 10, height: 10,
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    const Text('Kein GPS-Signal',
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),

          // ── SPEED LIMIT (left) — only during navigation ──
          if (_isNavigating && _speedLimit != null && _routeMode != RouteMode.pedestrian)
            Positioned(left: 16, bottom: (_currentRoute != null ? 200 : 80) + bp,
              child: _speedLimit == 0 ? _buildUnlimitedSign() : _buildSpeedSign()),

          // ── SPEED BUBBLE (left) — only during navigation ──
          if (_isNavigating)
            Positioned(left: 16, bottom: (_currentRoute != null ? 130 : 10) + bp, child: _buildSpeedBubble()),

          // ── RIGHT CONTROL COLUMN ──
          // All controls in one clean vertical stack
          if (!_searchOpen && !_recentScrolling)
          Positioned(
            right: 12, bottom: (_currentRoute != null ? 110 : 50) + bp,
            child: Column(mainAxisSize: MainAxisSize.min, spacing: 14, children: [
              // Info icon
              GestureDetector(
                onTap: _showHiMotoInfo,
                child: Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _bubbleBg,
                    border: Border.all(color: _modeColor.withValues(alpha: 0.5), width: 1),
                  ),
                  child: Icon(Icons.info_outline, color: _modeColor, size: 14),
                ),
              ),
              // Hi Moto
              _buildHiMotoBtn(),
              // GPS Live Toggle
              _buildGpsToggle(),
              // 3D Toggle (only during nav)
              if (_isNavigating)
                FloatingActionButton.small(
                  heroTag: '3dtoggle',
                  backgroundColor: _bubbleBg,
                  onPressed: () {
                    setState(() => _is3D = !_is3D);
                    _mapboxMap?.flyTo(
                      CameraOptions(
                        center: Point(coordinates: Position(_lng, _lat)),
                        zoom: _displaySpeed > 80 ? 15.5 : _displaySpeed > 40 ? 16.0 : 17.0,
                        bearing: _heading,
                        pitch: _is3D ? 55.0 : 0,
                        padding: MbxEdgeInsets(top: _cachedPuckPad, left: 0, bottom: 0, right: 0),
                      ),
                      MapAnimationOptions(duration: 500),
                    );
                    _startFollow();
                  },
                  child: Text(
                    _is3D ? '2D' : '3D',
                    style: TextStyle(color: _modeColor, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              // Recenter / Compass (only during nav)
              if (_isNavigating)
                FloatingActionButton.small(
                  heroTag: 'recenter',
                  backgroundColor: _bubbleBg,
                  onPressed: () {
                    setState(() {
                      _heading = (_heading + 90) % 360;
                      _camBearing = _heading;
                    });
                    _isFollowing = true;
                    _startFollow();
                  },
                  child: Transform.rotate(
                    angle: (_heading % 360) * math.pi / 180,
                    child: Icon(Icons.navigation, color: _modeColor, size: 22),
                  ),
                ),
            ]),
          ),

          // ── HI MOTO FEEDBACK ──
          if (_hiMotoFeedback != null)
            Positioned(
              right: 80, bottom: (_currentRoute != null ? 210 : 90) + bp,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12)),
                child: Text(_hiMotoFeedback!, style: TextStyle(color: _textSecondary, fontSize: 13)),
              ),
            ),


          // ── VOICE OPTION BUTTONS (tappable Ja/Nein) ──
          if (_voiceButtons.isNotEmpty)
            Positioned(
              left: 16, right: 16,
              bottom: (_currentRoute != null ? 250 : 130) + bp,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _voiceButtons.map((btn) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() => _voiceButtons = []);
                      btn.$2();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _cardBg,
                      foregroundColor: _textPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                        side: BorderSide(color: _modeColor, width: 1.5),
                      ),
                    ),
                    child: Text(btn.$1, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                )).toList(),
              ),
            ),

          // ── POI SELECTION POPUP (3 nearest results — tappable + voice "1/2/3") ──
          if (_poiPopupItems.isNotEmpty)
            Positioned(
              left: 16, right: 16,
              bottom: 100 + bp,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isDark ? const Color(0xFF1A1A2E) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _modeColor, width: 2),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 4))],
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // Header
                  Row(children: [
                    Text(_poiPopupTitle, style: TextStyle(
                      color: _modeColor, fontSize: 18, fontWeight: FontWeight.bold,
                    )),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        setState(() { _poiPopupItems = []; _poiPopupTitle = ''; });
                        TtsAlertService.instance.stop();
                        VoskWakeWordService.instance.directListenMode = false;
                      },
                      child: Icon(Icons.close_rounded, color: _textSecondary, size: 24),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  // POI items
                  ...List.generate(_poiPopupItems.length, (i) {
                    final poi = _poiPopupItems[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            setState(() { _poiPopupItems = []; _poiPopupTitle = ''; });
                            VoskWakeWordService.instance.directListenMode = false;
                            TtsAlertService.instance.speakText('Route zu ${poi['name']} wird berechnet.');
                            _selectDestination(poi['lat'] as double, poi['lng'] as double, poi['name'] as String, autoStart: true);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: _isDark ? const Color(0xFF252540) : const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _modeColor.withValues(alpha: 0.3)),
                            ),
                            child: Row(children: [
                              // Number badge
                              Container(
                                width: 32, height: 32,
                                decoration: BoxDecoration(
                                  color: _modeColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(child: Text('${i + 1}',
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                )),
                              ),
                              const SizedBox(width: 12),
                              // Name
                              Expanded(child: Text(poi['name'] as String,
                                style: TextStyle(color: _textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                              )),
                              // Distance
                              Text(poi['dist'] as String,
                                style: TextStyle(color: _modeColor, fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.navigation_rounded, color: _modeColor, size: 20),
                            ]),
                          ),
                        ),
                      ),
                    );
                  }),
                  // Voice hint
                  Text('Sage "Eins", "Zwei" oder "Drei"',
                    style: TextStyle(color: _textSecondary, fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ]),
              ),
            ),

          // (3D toggle + Recenter moved into right control column above)

          // ── ROUTE PANEL (bottom, when route exists) ──
          if (_currentRoute != null && !_searchOpen)
            _buildRoutePanel(bp),

          // ── SEARCH OVERLAY ──
          if (_searchOpen)
            _buildSearchOverlay(),

          // ── LEFT BOTTOM COLUMN: Sound + BETA + Fehler ──
          Positioned(
            bottom: (_currentRoute != null ? 70 : 10) + bp,
            left: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                // Sound toggle (only during nav)
                if (_isNavigating)
                  GestureDetector(
                    onTap: () {
                      setState(() => _soundMode = (_soundMode + 1) % 3);
                      final notifier = ref.read(blitzerSettingsProvider.notifier);
                      switch (_soundMode) {
                        case 0:
                          notifier.updateSetting((s) => s.copyWith(navSoundEnabled: false, warningSoundEnabled: false));
                          TtsAlertService.instance.stop();
                        case 1:
                          notifier.updateSetting((s) => s.copyWith(navSoundEnabled: false, warningSoundEnabled: true));
                        case 2:
                          notifier.updateSetting((s) => s.copyWith(navSoundEnabled: true, warningSoundEnabled: true));
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _bubbleBg,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(
                          _soundMode == 0 ? Icons.volume_off_rounded
                              : _soundMode == 1 ? Icons.notifications_active_rounded
                              : Icons.volume_up_rounded,
                          color: _soundMode == 0 ? Colors.red : _modeColor,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _soundMode == 0 ? 'Stumm' : _soundMode == 1 ? 'Warnung' : 'Alle',
                          style: TextStyle(color: _soundMode == 0 ? Colors.red : _modeColor, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ]),
                    ),
                  ),
                // BETA + Fehler row
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('BETA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1)),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => BugReportSheet.show(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bug_report_rounded, size: 12, color: Colors.white),
                            SizedBox(width: 3),
                            Text('Fehler', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── POI LOADING INDICATOR ──
          if (_poiLoading)
            Positioned(
              top: MediaQuery.of(context).padding.top + 280,
              left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: _isDark ? const Color(0xF0111111) : const Color(0xF0FFFFFF),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: _modeColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${_poiCategoryLabel(_activePoiCategory)} werden gesucht…',
                      style: TextStyle(
                        color: _isDark ? Colors.white70 : Colors.black54,
                        fontSize: 14, fontWeight: FontWeight.w600,
                      ),
                    ),
                  ]),
                ),
              ),
            ),

          // ── POI ERROR PILL ──
          if (_poiError != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 280,
              left: 24, right: 24,
              child: Center(
                child: GestureDetector(
                  onTap: () => setState(() => _poiError = null),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xF0B71C1C), // dark red
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 12)],
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          _poiError!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13, fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),

          // POI Highlight: nur Mapbox-Layer (blinkender Ring auf der Karte)

          // ── MAP TUTORIAL OVERLAY ──
          if (_tutorialActive) _buildTutorialOverlay(),

          // ── LOADING ──
          if (_isCalculating)
            Center(child: Card(
              color: _isDark ? const Color(0xE6111111) : const Color(0xE6FFFFFF),
              child: Padding(padding: const EdgeInsets.all(24),
                child: CircularProgressIndicator(color: _modeColor)),
            )),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  WIDGETS
  // ═══════════════════════════════════════════════════════════════════════════

  bool _panelExpanded = false;

  Widget _buildRoutePanel(double bp) {
    final route = _currentRoute!;
    final screenH = MediaQuery.of(context).size.height;
    final topPad = MediaQuery.of(context).padding.top;
    // Leave space for GlobalTopBar (~100px from top: statusbar + icons + padding)
    final expandedH = screenH - topPad - 110;

    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: GestureDetector(
        onTap: () => setState(() => _panelExpanded = !_panelExpanded),
        onVerticalDragEnd: (d) {
          if (d.primaryVelocity != null) {
            if (d.primaryVelocity! < -100) setState(() => _panelExpanded = true);
            if (d.primaryVelocity! > 100) setState(() => _panelExpanded = false);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          height: _isNavigating
              ? (_panelExpanded ? math.min(expandedH, 400) : 64)
              : (_panelExpanded ? expandedH : (_destName != null ? 390 : 340)),
          decoration: BoxDecoration(
            color: _isDark ? const Color(0xFF1A1E2E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            // ── Drag handle (hidden during navigation) ──
            if (!_isNavigating)
              Center(child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 50, height: 5,
                    decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(3)),
                  ),
                  const SizedBox(height: 2),
                  Icon(_panelExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                    color: Colors.white24, size: 16),
                ]),
              )),

            // ── Collapsed header ──
            if (!_isNavigating)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // Destination name + info (population, flag, blitzer)
                  if (_destName != null && _destName!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Icon(Icons.flag_rounded, size: 14, color: _modeColor),
                          const SizedBox(width: 6),
                          Expanded(child: Text(_destName!, style: TextStyle(
                            color: _textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                            maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ]),
                        if (_destInfo != null && _destInfo!.hasData)
                          Padding(
                            padding: const EdgeInsets.only(top: 3, left: 20),
                            child: Row(children: [
                              if (_destInfo!.countryFlag != null)
                                Text(_destInfo!.countryFlag!, style: const TextStyle(fontSize: 12)),
                              if (_destInfo!.populationText != null) ...[
                                const SizedBox(width: 4),
                                Icon(Icons.people_outline, size: 11, color: _iconMuted),
                                const SizedBox(width: 2),
                                Text('${_destInfo!.populationText} Einwohner', style: TextStyle(
                                  color: _textMuted, fontSize: 11)),
                              ],
                              if (_routeBlitzerCount > 0) ...[
                                const SizedBox(width: 6),
                                Icon(Icons.speed, size: 11, color: Colors.redAccent),
                                const SizedBox(width: 2),
                                Text('$_routeBlitzerCount Blitzer', style: const TextStyle(
                                  color: Colors.redAccent, fontSize: 11)),
                              ],
                            ]),
                          ),
                      ]),
                    ),
                  // Mode chips
                  Row(children: [
                    _modeChip(RouteMode.biker, Icons.two_wheeler, 'Biker'),
                    const SizedBox(width: 6),
                    _modeChip(RouteMode.auto, Icons.directions_car, 'Auto'),
                    const SizedBox(width: 6),
                    _modeChip(RouteMode.bicycle, Icons.pedal_bike, 'Rad'),
                    const SizedBox(width: 6),
                    _modeChip(RouteMode.pedestrian, Icons.directions_walk, 'Fuß'),
                  ]),
                  const SizedBox(height: 10),
                  // Duration + Distance
                  Row(children: [
                    Flexible(
                      child: Text(route.durationText, style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
                        overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    Text('${route.distanceKm.toStringAsFixed(1)} km', style: TextStyle(color: _iconMuted, fontSize: 14)),
                    const SizedBox(width: 8),
                    // Route type badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: _modeColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        _routeMode == RouteMode.biker ? 'Scenic' : _routeMode == RouteMode.pedestrian ? 'Fuß' : 'Schnell',
                        style: TextStyle(color: _modeColor, fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ]),
                ]),
              ),

            // ── Expanded content ──
            if (_panelExpanded && !_isNavigating)
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  physics: const ClampingScrollPhysics(),
                  children: [
                    // Alternative routes
                    if (_allRoutes.length > 1) ...[
                      Text('Routen', style: TextStyle(color: _iconMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      ...List.generate(_allRoutes.length, (i) {
                        final r = _allRoutes[i];
                        final sel = i == _selectedRouteIdx;
                        return GestureDetector(
                          onTap: () {
                            _selectedRouteIdx = i;
                            _currentRoute = r;
                            _routePoints = r.polylinePoints;
                            _drawRoutes();
                            setState(() {});
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: sel ? _modeColor.withValues(alpha: 0.15) : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: sel ? _modeColor : _cardBorder, width: sel ? 1.5 : 0.5),
                            ),
                            child: Row(children: [
                              Icon(sel ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                                color: sel ? _modeColor : _iconFaint, size: 20),
                              const SizedBox(width: 8),
                              Flexible(child: Text('${r.durationText}  ${r.distanceKm.toStringAsFixed(1)} km',
                                style: TextStyle(color: sel ? _textPrimary : _textSecondary, fontSize: 14, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis)),
                              if (i == 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.blueAccent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                                  child: const Text('Schnell', style: TextStyle(color: Colors.blueAccent, fontSize: 9, fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ]),
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                    ],

                    // Route steps with road signs
                    Text('Abschnitte', style: TextStyle(color: _iconMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    ...List.generate(route.steps.length, (i) {
                      final step = route.steps[i];
                      final road = _classifyRoad(step.instruction);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        child: Row(children: [
                          // Step number
                          SizedBox(width: 22, child: Text('${i + 1}', style: TextStyle(color: _iconFaint, fontSize: 11, fontWeight: FontWeight.w700))),
                          // Maneuver icon
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: _maneuverBgColor(step.maneuver),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(_maneuverIcon(step.maneuver), color: _maneuverFgColor(step.maneuver), size: 20),
                          ),
                          const SizedBox(width: 8),
                          // Road sign
                          Expanded(child: _buildRoadSign(road, step)),
                        ]),
                      );
                    }),
                    const SizedBox(height: 16),
                  ],
                ),
              ),

            // ── Action buttons (always at bottom) ──
            if (!_isNavigating && !_panelExpanded)
              Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, bp + 8),
                child: Row(children: [
                  // Route options button
                  GestureDetector(
                    onTap: _showRouteOptionsSheet,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _isDark ? const Color(0xFF2D3446) : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.tune_rounded, color: _modeColor, size: 22),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: GestureDetector(
                    onTap: _clearRoute,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(color: _isDark ? const Color(0xFF2D3446) : Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
                      child: Center(child: Text('Stop', style: TextStyle(color: _textPrimary, fontSize: 14, fontWeight: FontWeight.w600))),
                    ),
                  )),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: GestureDetector(
                    onTap: _startNavigation,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(color: _modeColor, borderRadius: BorderRadius.circular(12)),
                      child: const Center(child: Text('LOS!', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900))),
                    ),
                  )),
                ]),
              ),

            if (_panelExpanded && !_isNavigating)
              Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, bp + 8),
                child: Row(children: [
                  Expanded(child: GestureDetector(
                    onTap: () => setState(() => _panelExpanded = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(color: _isDark ? const Color(0xFF2D3446) : Colors.grey.shade200, borderRadius: BorderRadius.circular(14)),
                      child: Center(child: Text('Später', style: TextStyle(color: _textPrimary, fontSize: 16, fontWeight: FontWeight.w700))),
                    ),
                  )),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: GestureDetector(
                    onTap: _startNavigation,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(color: _modeColor, borderRadius: BorderRadius.circular(14)),
                      child: const Center(child: Text('LOS!', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900))),
                    ),
                  )),
                ]),
              ),

            // During navigation: mode chips + km/min + close
            if (_isNavigating)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // Drag handle
                  Center(child: Container(
                    width: 36, height: 3, margin: const EdgeInsets.only(bottom: 3),
                    decoration: BoxDecoration(color: _iconFaint, borderRadius: BorderRadius.circular(2)),
                  )),
                  // Row 1: mode icon + dist + time + expand arrow + close
                  Row(children: [
                    Icon(switch (_routeMode) {
                      RouteMode.biker => Icons.two_wheeler,
                      RouteMode.auto => Icons.directions_car,
                      RouteMode.bicycle => Icons.pedal_bike,
                      RouteMode.pedestrian => Icons.directions_walk,
                    }, color: _modeColor, size: 20),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: _panelExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(Icons.expand_less, color: _modeColor, size: 18),
                    ),
                    const SizedBox(width: 4),
                    Text(_fmtDist(_remainingDistKm),
                      style: TextStyle(color: _modeColor, fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Text(_fmtTime(_remainingMin),
                      style: TextStyle(color: _textSecondary, fontSize: 13)),
                    const SizedBox(width: 8),
                    // Arrival time (ETA)
                    Builder(builder: (_) {
                      final eta = DateTime.now().add(Duration(minutes: _remainingMin));
                      return Text('${eta.hour.toString().padLeft(2, '0')}:${eta.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(color: _textSecondary.withValues(alpha: 0.7), fontSize: 12));
                    }),
                    const Spacer(),
                    GestureDetector(
                      onTap: _stopNavigation,
                      child: const Icon(Icons.close, color: Colors.redAccent, size: 18),
                    ),
                  ]),
                ]),
              ),

            // Expanded nav route details (steps list)
            if (_isNavigating && _panelExpanded)
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  itemCount: _currentRoute!.steps.length,
                  itemBuilder: (_, i) {
                    final step = _currentRoute!.steps[i];
                    final roadInfo = _classifyRoad(step.instruction);
                    final isCurrent = i == _currentStepIndex;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isCurrent ? _modeColor.withValues(alpha: 0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: isCurrent ? Border.all(color: _modeColor.withValues(alpha: 0.4)) : null,
                      ),
                      child: Row(children: [
                        Text('${i + 1}', style: TextStyle(
                          color: isCurrent ? _modeColor : _iconMuted, fontSize: 12, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 10),
                        Icon(_maneuverIcon(step.maneuver),
                          color: isCurrent ? _modeColor : _iconMuted, size: 20),
                        const SizedBox(width: 10),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (roadInfo.badge != null)
                              _buildRoadSign(roadInfo, step),
                            Text(step.instruction,
                              style: TextStyle(
                                color: isCurrent ? Colors.black87 : _textSecondary,
                                fontSize: 13, fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          ],
                        )),
                        const SizedBox(width: 8),
                        Text(_fmtDist(step.distanceMeters / 1000),
                          style: TextStyle(color: isCurrent ? _modeColor : _iconMuted, fontSize: 12)),
                      ]),
                    );
                  },
                ),
              ),
          ]),
        ),
      ),
    );
  }

  // ── Road classification for German signs ──
  _RoadInfo _classifyRoad(String instruction) {
    // Autobahn: A1, A3, A44
    final autobahnMatch = RegExp(r'\bA\s?(\d+)\b').firstMatch(instruction);
    if (autobahnMatch != null) {
      return _RoadInfo(badge: 'A${autobahnMatch.group(1)}', type: _SignType.autobahn, road: instruction);
    }
    // Bundesstraße: B7, B42
    final bundesMatch = RegExp(r'\bB\s?(\d+)\b').firstMatch(instruction);
    if (bundesMatch != null) {
      return _RoadInfo(badge: 'B${bundesMatch.group(1)}', type: _SignType.bundesstrasse, road: instruction);
    }
    // Europastraße: E40, E45
    final euroMatch = RegExp(r'\bE\s?(\d+)\b').firstMatch(instruction);
    if (euroMatch != null) {
      return _RoadInfo(badge: 'E${euroMatch.group(1)}', type: _SignType.europastrasse, road: instruction);
    }
    return _RoadInfo(badge: null, type: _SignType.other, road: instruction);
  }

  Widget _buildRoadSign(_RoadInfo info, OsrmStep step) {
    final distText = step.distanceMeters >= 1000
        ? '${(step.distanceMeters / 1000).toStringAsFixed(1)} km'
        : '${step.distanceMeters.round()} m';

    Color bg, textColor, borderColor;
    Color? badgeBg, badgeText;

    switch (info.type) {
      case _SignType.autobahn:
        bg = const Color(0xFF0050A4); textColor = Colors.white; borderColor = Colors.white;
        badgeBg = Colors.white; badgeText = const Color(0xFF0050A4);
      case _SignType.bundesstrasse:
        bg = const Color(0xFFFFCC00); textColor = Colors.black87; borderColor = Colors.black54;
        badgeBg = Colors.black87; badgeText = const Color(0xFFFFCC00);
      case _SignType.europastrasse:
        bg = const Color(0xFF006B3F); textColor = Colors.white; borderColor = Colors.white;
        badgeBg = Colors.white; badgeText = const Color(0xFF006B3F);
      case _SignType.other:
        bg = Colors.white; textColor = Colors.black87; borderColor = Colors.black26;
        badgeBg = null; badgeText = null;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor, width: info.type == _SignType.other ? 1 : 2),
      ),
      child: Row(children: [
        if (info.badge != null && badgeBg != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(4)),
            child: Text(info.badge!, style: TextStyle(color: badgeText, fontSize: 12, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(child: Text(
          () {
            var name = step.instruction.replaceAll(RegExp(r'^(Links|Rechts|Leicht \w+|Scharf \w+|Geradeaus|Weiter|Start|Wenden)\s*(abbiegen\s*)?(auf\s*)?'), '').trim();
            if (name.isEmpty) name = step.instruction; // Fallback: show full instruction
            return name;
          }(),
          style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w700),
          overflow: TextOverflow.ellipsis,
        )),
        const SizedBox(width: 6),
        Text(distText, style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Color _maneuverBgColor(String m) {
    if (m.contains('left') && !m.contains('slight')) return const Color(0xFF1565C0).withValues(alpha: 0.3);
    if (m.contains('right') && !m.contains('slight')) return const Color(0xFF1565C0).withValues(alpha: 0.3);
    if (m.contains('slight')) return const Color(0xFF0097A7).withValues(alpha: 0.3);
    if (m.contains('roundabout') || m.contains('rotary')) return const Color(0xFF6A1B9A).withValues(alpha: 0.3);
    if (m.contains('ramp') || m.contains('merge')) return const Color(0xFFE65100).withValues(alpha: 0.3);
    if (m.contains('uturn')) return const Color(0xFFC62828).withValues(alpha: 0.3);
    return Colors.white.withValues(alpha: 0.08);
  }

  Color _maneuverFgColor(String m) {
    if (m.contains('left') || m.contains('right')) return const Color(0xFF42A5F5);
    if (m.contains('slight')) return const Color(0xFF26C6DA);
    if (m.contains('roundabout') || m.contains('rotary')) return const Color(0xFFCE93D8);
    if (m.contains('ramp') || m.contains('merge')) return const Color(0xFFFF9800);
    if (m.contains('uturn')) return const Color(0xFFEF5350);
    return Colors.white38;
  }

  /// Compact mode chip for during-navigation bottom bar.
  Widget _navModeChip(RouteMode mode, IconData icon, String label) {
    final active = _routeMode == mode;
    final color = _colorForMode(mode);
    final chip = GestureDetector(
      onTap: () {
        if (_routeMode == mode || _isCalculating) return;
        setState(() => _routeMode = mode);
        NavigationState.instance.setRouteMode(mode); // Sync global state (TopBar etc.)
        _updatePuckColor();
        // Re-register puck icon with new vehicle shape
        _navPuckIconRegistered = false;
        _applyCustomPuck();
        if (_destination != null) _calcRoute();
      },
      child: Container(
        padding: label.isEmpty
            ? const EdgeInsets.all(6)
            : const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: active ? Border.all(color: color, width: 1) : null,
        ),
        child: label.isEmpty
            ? Icon(icon, color: active ? color : Colors.white38, size: 16)
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, color: active ? color : Colors.white38, size: 14),
                const SizedBox(width: 4),
                Text(label, style: TextStyle(color: active ? color : Colors.white38,
                  fontSize: 11, fontWeight: active ? FontWeight.w700 : FontWeight.w400)),
              ]),
      ),
    );
    // If label is empty (icon-only mode), don't expand
    return label.isEmpty ? chip : Expanded(child: chip);
  }

  static Color _colorForMode(RouteMode mode) => switch (mode) {
    RouteMode.biker => const Color(0xFFE53935),
    RouteMode.auto => const Color(0xFF2196F3),
    RouteMode.bicycle => const Color(0xFFFF9800),
    RouteMode.pedestrian => const Color(0xFF4CAF50),
  };

  Widget _modeChip(RouteMode mode, IconData icon, String label) {
    final active = _routeMode == mode;
    final color = _colorForMode(mode);
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_routeMode == mode || _isCalculating) return;
          setState(() => _routeMode = mode);
          NavigationState.instance.setRouteMode(mode);
          _updatePuckColor();
          // Re-register puck icon with new vehicle shape
          _navPuckIconRegistered = false;
          _applyCustomPuck();
          _calcRoute();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? color.withValues(alpha: 0.2) : (_isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04)),
            borderRadius: BorderRadius.circular(12),
            border: active ? Border.all(color: color, width: 1.5) : Border.all(color: _isDark ? Colors.white12 : const Color(0xFFE0E0E0), width: 0.5),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: active ? color : (_isDark ? Colors.white54 : const Color(0xFF6C757D)), size: 18),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: active ? color : (_isDark ? Colors.white54 : const Color(0xFF6C757D)),
              fontSize: 13, fontWeight: active ? FontWeight.w700 : FontWeight.w400)),
          ]),
        ),
      ),
    );
  }

  Widget _buildSearchOverlay() {
    return Positioned.fill(
      child: Container(
        color: _isDark ? const Color(0xFF111520) : const Color(0xFFF5F5F5),
        child: SafeArea(
          child: Column(children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: _isDark ? _bubbleBg : const Color(0xFFF1F3F4),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(children: [
                  IconButton(icon: Icon(Icons.arrow_back, color: _iconMuted),
                    onPressed: () {
                      NavigationState.instance.stopNavigation(); // Show TopBar+BottomNav
                      setState(() { _searchOpen = false; _searchResults = []; });
                    }),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      style: TextStyle(color: _textPrimary, fontSize: 16),
                      cursorColor: _modeColor,
                      decoration: InputDecoration(
                        hintText: 'Wohin?', hintStyle: TextStyle(color: _textMuted),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none),
                      onChanged: _onSearchChanged,
                    ),
                  ),
                  Icon(Icons.search, color: _modeColor),
                ]),
              ),
            ),
            const SizedBox(height: 8),

            // Results or history
            Expanded(
              child: _searchResults.isNotEmpty
                  ? ListView.builder(
                      itemCount: _searchResults.length,
                      itemBuilder: (_, i) {
                        final r = _searchResults[i];
                        return ListTile(
                          leading: Icon(r.typeIcon, color: _modeColor, size: 22),
                          title: Text(r.shortName, style: TextStyle(color: _textPrimary, fontSize: 14)),
                          subtitle: r.city != null
                              ? Text(r.city!, style: TextStyle(color: _textMuted, fontSize: 12))
                              : null,
                          onTap: () => _selectDestination(r.location.latitude, r.location.longitude, r.shortName),
                        );
                      },
                    )
                  : SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // Quick buttons: Zuhause, Arbeit, POIs
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                        child: Row(children: [
                          _quickNavBtn(Icons.home_rounded, 'Zuhause', 'nav_home'),
                          const SizedBox(width: 6),
                          _quickNavBtn(Icons.work_rounded, 'Arbeit', 'nav_work'),
                          const SizedBox(width: 6),
                          Expanded(child: GestureDetector(
                            onTap: () { setState(() => _searchOpen = false); _showPoiCategorySheet(); },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _cardBg, borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: _cardBorder)),
                              child: Column(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.explore, color: _modeColor.withValues(alpha: 0.7), size: 22),
                                const SizedBox(height: 4),
                                Text('POIs', style: TextStyle(color: _iconMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                              ]),
                            ),
                          )),
                          const SizedBox(width: 6),
                          Expanded(child: GestureDetector(
                            onTap: () { setState(() => _searchOpen = false); context.go('/events?tab=treffen'); },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _cardBg, borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: _cardBorder)),
                              child: Column(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.event_rounded, color: _modeColor.withValues(alpha: 0.7), size: 22),
                                const SizedBox(height: 4),
                                Text('Treffen', style: TextStyle(color: _iconMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                              ]),
                            ),
                          )),
                        ]),
                      ),
                      // Letzte Ziele
                      if (_searchHistory.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                          child: Text('Letzte Ziele', style: TextStyle(color: _textMuted, fontSize: 13)),
                        ),
                        ...(_searchHistory.take(5).map((h) => ListTile(
                          leading: Icon(Icons.history, color: _iconFaint, size: 20),
                          title: Text(h['name'] as String, style: TextStyle(color: _textSecondary, fontSize: 14)),
                          subtitle: (h['subtitle'] as String).isNotEmpty
                              ? Text(h['subtitle'] as String, style: TextStyle(color: _textMuted, fontSize: 12))
                              : null,
                          onTap: () => _selectDestination(h['lat'] as double, h['lng'] as double, h['name'] as String),
                        ))),
                      ] else
                        Center(child: Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: Text('Ziel eingeben...', style: TextStyle(color: _iconFaint)))),
                    ])),
            ),
          ]),
        ),
      ),
    );
  }

  /// Enrich instruction with explicit direction if OSRM's text doesn't have it
  String _enrichInstruction(OsrmStep step) {
    final m = step.maneuver;
    final instr = step.instruction;

    // Use OSRM instruction's direction (most reliable) — NOT the maneuver key
    String direction = '';
    if (instr.startsWith('Scharf links')) {
      direction = 'Scharf links';
    } else if (instr.startsWith('Scharf rechts')) {
      direction = 'Scharf rechts';
    } else if (instr.startsWith('Links')) {
      direction = 'Links';
    } else if (instr.startsWith('Rechts')) {
      direction = 'Rechts';
    } else if (m.contains('left')) {
      direction = m.contains('sharp') ? 'Scharf links' : 'Links';
    } else if (m.contains('right')) {
      direction = m.contains('sharp') ? 'Scharf rechts' : 'Rechts';
    }

    // Build SHORT road info — only the most useful piece (ref OR name, not both)
    String roadInfo = '';
    final ref = step.ref;
    final name = step.roadName;
    final dest = step.destinations;

    if (ref != null && ref.isNotEmpty) {
      // Highway ref is most useful (A3, B42)
      roadInfo = 'auf die $ref';
    } else if (name != null && name.isNotEmpty) {
      // Road name only if no ref
      roadInfo = 'auf $name';
    }

    // Add destination only if no road info yet, or for ramps
    String destInfo = '';
    if (dest != null && dest.isNotEmpty) {
      final firstDest = dest.split(',').first.split(';').first.trim();
      if (firstDest.isNotEmpty && firstDest != ref && firstDest != name) {
        destInfo = 'Richtung $firstDest';
      }
    }

    // Assemble — keep it SHORT for TTS
    if (direction.isNotEmpty) {
      final suffix = roadInfo.isNotEmpty ? ' $roadInfo' : '';
      final destSuffix = destInfo.isNotEmpty && roadInfo.isEmpty ? ' $destInfo' : '';
      return '$direction abbiegen$suffix$destSuffix';
    }

    // For ramps
    if (m == 'off-ramp' || m == 'on-ramp') {
      final suffix = roadInfo.isNotEmpty ? ' $roadInfo' : (destInfo.isNotEmpty ? ' $destInfo' : '');
      return m == 'off-ramp' ? 'Abfahrt nehmen$suffix' : 'Auffahrt nehmen$suffix';
    }

    if (roadInfo.isNotEmpty) {
      return '$instr $roadInfo';
    }
    return instr;
  }

  /// StVO Zeichen 282 — Ende sämtlicher Streckenverbote (Autobahn unbegrenzt)
  Widget _buildUnlimitedSign() => Container(
    width: 56, height: 56,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white,
      border: Border.all(color: const Color(0xFF222222), width: 2),
      boxShadow: [
        BoxShadow(color: _shadowColor, blurRadius: 10, offset: const Offset(0, 2)),
      ],
    ),
    child: CustomPaint(
      painter: _UnlimitedSignPainter(),
      size: const Size(56, 56),
    ),
  );

  Widget _buildSpeedSign() => AnimatedScale(
    scale: _isSpeeding ? 1.15 : 1.0,
    duration: const Duration(milliseconds: 300),
    child: Container(
      width: 56, height: 56,
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white,
        border: Border.all(color: const Color(0xFFCC0000), width: 5),
        boxShadow: [if (_isSpeeding) BoxShadow(color: Colors.red.withValues(alpha: 0.6), blurRadius: 16)]),
      child: Center(child: Text('$_speedLimit',
        style: TextStyle(color: Colors.black87, fontSize: _speedLimit! >= 100 ? 16 : 20, fontWeight: FontWeight.w900))),
    ),
  );

  Widget _buildSpeedBubble() => AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    width: 64, height: 64,
    decoration: BoxDecoration(shape: BoxShape.circle,
      color: _isSpeeding ? const Color(0xF0C62828) : _bubbleBg.withValues(alpha: 0.94),
      border: Border.all(color: _isSpeeding ? Colors.redAccent : _cardBorder, width: 2),
      boxShadow: [BoxShadow(color: _isSpeeding ? Colors.red.withValues(alpha: 0.5) : _shadowColor, blurRadius: 12)]),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('${_displaySpeed.round()}', style: TextStyle(
        color: _isSpeeding ? Colors.red.shade100 : _textPrimary, fontSize: 22, fontWeight: FontWeight.bold, height: 1)),
      Text('km/h', style: TextStyle(color: _isSpeeding ? Colors.red.shade200 : _iconMuted, fontSize: 9)),
    ]),
  );

  /// Show route options bottom sheet (avoid ferries, motorways)
  void _showRouteOptionsSheet() {
    final settings = ref.read(blitzerSettingsProvider).value ?? const BlitzerSettings();
    bool ferries = settings.avoidFerries;
    bool motorways = settings.avoidMotorways;

    showModalBottomSheet(
      context: context,
      backgroundColor: _isDark ? const Color(0xFF1A1E2E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        Widget optionTile(String label, String subtitle, IconData icon, bool value, ValueChanged<bool> onChanged) {
          return SwitchListTile(
            title: Row(children: [
              Icon(icon, color: _modeColor, size: 20),
              const SizedBox(width: 10),
              Text(label, style: TextStyle(color: _textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
            ]),
            subtitle: Text(subtitle, style: TextStyle(color: _textMuted, fontSize: 12)),
            value: value,
            activeColor: _modeColor,
            onChanged: (v) { setSheet(() => onChanged(v)); },
            dense: true,
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            Text('Routenoptionen', style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            optionTile('Fähren meiden', 'Keine Fähren oder Wasserüberquerungen', Icons.directions_boat_rounded, ferries, (v) => ferries = v),
            optionTile('Autobahn meiden', 'Landstraßen bevorzugen', Icons.block_rounded, motorways, (v) => motorways = v),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _modeColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  // Save and recalculate
                  ref.read(blitzerSettingsProvider.notifier).updateSetting((s) => s.copyWith(
                    avoidFerries: ferries,
                    avoidMotorways: motorways,
                  ));
                  Navigator.pop(ctx);
                  if (_destination != null) _calcRoute();
                },
                child: const Text('Übernehmen', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        );
      }),
    );
  }

  /// Start voice search — opens search and listens for address via Google STT
  void _startVoiceSearch() async {
    HapticFeedback.mediumImpact();
    final speech = stt.SpeechToText();
    final available = await speech.initialize(
      onError: (e) => debugPrint('[VoiceSearch] Error: $e'),
    );
    if (!available) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Spracherkennung nicht verfügbar')),
        );
      }
      return;
    }

    // Show listening dialog
    String recognized = '';
    bool done = false;
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
        if (!done) {
          speech.listen(
            localeId: 'de_DE',
            listenFor: const Duration(seconds: 8),
            onResult: (result) {
              setDlg(() => recognized = result.recognizedWords);
              if (result.finalResult && result.recognizedWords.isNotEmpty) {
                done = true;
                Navigator.of(ctx).pop(result.recognizedWords);
              }
            },
          );
          done = true; // Prevent re-calling listen
        }
        return AlertDialog(
          backgroundColor: _cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Icon(Icons.mic, color: _modeColor, size: 28),
            const SizedBox(width: 8),
            Text('Sprich dein Ziel...', style: TextStyle(color: _textPrimary, fontSize: 18)),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 8),
            Text(
              recognized.isEmpty ? '🎤 Höre zu...' : recognized,
              style: TextStyle(
                color: recognized.isEmpty ? _textMuted : _textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () { speech.stop(); Navigator.of(ctx).pop(null); },
              child: Text('Zurück', style: TextStyle(color: _modeColor)),
            ),
          ]),
        );
      }),
    ).then((result) {
      speech.stop();
      if (result != null && result is String && result.isNotEmpty) {
        // Open search with recognized text
        NavigationState.instance.startNavigation();
        setState(() {
          _searchOpen = true;
          _searchController.text = result;
        });
        _onSearchChanged(result);
      }
    });
  }

  void _triggerSos() {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _isDark ? const Color(0xFF1A1A2E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Text('🆘 ', style: TextStyle(fontSize: 28)),
          Text('SOS Notruf', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Was möchtest du tun?', style: TextStyle(color: _textPrimary, fontSize: 16)),
          const SizedBox(height: 16),
          // Option 1: Call 112
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _callEmergency();
            },
            icon: const Icon(Icons.phone, color: Colors.white),
            label: const Text('112 Notruf anrufen', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 14)),
          )),
          const SizedBox(height: 10),
          // Option 2: Share location
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _shareLocationSos();
            },
            icon: Icon(Icons.share_location, color: _modeColor),
            label: Text('Standort an Kontakte senden', style: TextStyle(color: _textPrimary)),
            style: OutlinedButton.styleFrom(side: BorderSide(color: _modeColor), padding: const EdgeInsets.symmetric(vertical: 14)),
          )),
          const SizedBox(height: 10),
          // Cancel
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Zurück', style: TextStyle(color: _textSecondary)),
          ),
        ]),
      ),
    );
  }

  void _callEmergency() async {
    final uri = Uri(scheme: 'tel', path: '112');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _shareLocationSos() async {
    final mapsUrl = 'https://maps.google.com/?q=$_lat,$_lng';
    final text = 'SOS! Ich brauche Hilfe! Mein Standort: $mapsUrl';
    // Use share intent
    try {
      await Share.share(text, subject: 'SOS Notruf');
    } catch (_) {
      // Fallback: copy to clipboard
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Standort in Zwischenablage kopiert')),
        );
      }
    }
  }

  void _showHiMotoInfo() {
    final bg = _isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final textCol = _isDark ? Colors.white : Colors.black87;
    final subCol = _isDark ? Colors.white54 : Colors.black54;
    final divCol = _isDark ? Colors.white12 : Colors.black12;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(24),
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: divCol, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Row(children: [
              Icon(Icons.mic, color: _modeColor, size: 28),
              const SizedBox(width: 12),
              Text('Hi Moto', style: TextStyle(color: textCol, fontSize: 22, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 8),
            Text('Sage "Hi Moto" und dann deinen Befehl.\nHände am Lenker — alles per Stimme! 🏍️',
              style: TextStyle(color: subCol, fontSize: 14)),
            const SizedBox(height: 20),

            // ── 🔍 SUCHE ──
            _hiMotoSection('🔍 Suche', textCol),
            _hiMotoCmd('⛽', '"Tankstelle"', 'Nächste Tankstelle finden + navigieren', textCol, subCol),
            _hiMotoCmd('🍽️', '"Restaurant" / "Bar" / "Café"', 'Essen & Trinken in der Nähe', textCol, subCol),
            _hiMotoCmd('📅', '"Treffen"', 'Nächste Veranstaltungen finden', textCol, subCol),
            _hiMotoCmd('🔧', '"Werkstatt"', 'Motorrad-Werkstatt finden', textCol, subCol),
            Divider(color: divCol, height: 24),

            // ── 📢 MELDEN ──
            _hiMotoSection('📢 Melden', textCol),
            _hiMotoCmd('📸', '"Blitzer melden"', 'Mobilen Blitzer auf Karte markieren', textCol, subCol),
            _hiMotoCmd('📷', '"Fester Blitzer"', 'Stationären Blitzer melden', textCol, subCol),
            _hiMotoCmd('🚔', '"Polizei melden"', 'Polizeikontrolle markieren', textCol, subCol),
            _hiMotoCmd('🚧', '"Baustelle melden"', 'Baustelle oder Gefahr melden', textCol, subCol),
            _hiMotoCmd('🚗', '"Stau melden"', 'Stau auf der Strecke markieren', textCol, subCol),
            Divider(color: divCol, height: 24),

            // ── 🧭 NAVIGATION ──
            _hiMotoSection('🧭 Navigation', textCol),
            _hiMotoCmd('🗺️', '"Navigiere nach [Ort]"', 'Route zu einer Adresse berechnen', textCol, subCol),
            _hiMotoCmd('🔊', '"Route ansagen"', 'Restzeit + nächste Anweisung hören', textCol, subCol),
            _hiMotoCmd('🛑', '"Navigation stoppen"', 'Aktive Route beenden', textCol, subCol),
            Divider(color: divCol, height: 24),

            // ── 📱 APP ──
            _hiMotoSection('📱 App-Steuerung', textCol),
            _hiMotoCmd('🏠', '"Feed" / "Karte" / "Garage" / "Profil"', 'Tab wechseln', textCol, subCol),
            _hiMotoCmd('🌤️', '"Wetter"', 'Aktuelle Wetterlage ansagen', textCol, subCol),
            _hiMotoCmd('🏎️', '"Wie schnell?"', 'Geschwindigkeit + Tempolimit', textCol, subCol),
            _hiMotoCmd('📍', '"Wo bin ich?"', 'Aktuellen Standort ansagen', textCol, subCol),
            _hiMotoCmd('🆘', '"SOS" / "Hilfe"', 'Notfall aktivieren', textCol, subCol),
            _hiMotoCmd('😊', '"Danke Moto"', 'Moto antwortet mit einem Spruch', textCol, subCol),
            const SizedBox(height: 24),

            // ── Tipps ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _modeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _modeColor.withValues(alpha: 0.3)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('💡 Tipps', style: TextStyle(color: _modeColor, fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('• Bei POI-Suche fragt Moto: "Soll ich navigieren?" → sage "Ja" oder "Nein"\n'
                    '• Andere User sehen deine Meldungen in Echtzeit\n'
                    '• Meldungen verfallen automatisch (Blitzer: 2h, Polizei: 3h)\n'
                    '• Vorbeifahren an Meldungen bestätigt sie automatisch',
                  style: TextStyle(color: subCol, fontSize: 13, height: 1.5)),
              ]),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _hiMotoSection(String title, Color textCol) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(title, style: TextStyle(color: textCol, fontSize: 16, fontWeight: FontWeight.bold)),
  );

  Widget _hiMotoCmd(String emoji, String cmd, String desc, Color textCol, Color subCol) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(emoji, style: const TextStyle(fontSize: 20)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(cmd, style: TextStyle(color: _modeColor, fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(desc, style: TextStyle(color: subCol, fontSize: 12)),
      ])),
    ]),
  );

  Widget _buildHiMotoBtn() => GestureDetector(
    onTap: () {
      TtsAlertService.instance.speakPriority('Hi Moto aktiv.');
      setState(() { _hiMotoActive = true; _hiMotoFeedback = 'Ich höre...'; });
    },
    child: Container(
      width: 56, height: 56,
      decoration: BoxDecoration(shape: BoxShape.circle,
        color: _hiMotoActive ? const Color(0xFF4CAF50) : _bubbleBg,
        border: Border.all(color: _hiMotoActive ? const Color(0xFF4CAF50) : _modeColor, width: 2),
        boxShadow: [if (_hiMotoActive) BoxShadow(color: Colors.green.withValues(alpha: 0.5), blurRadius: 16)]),
      child: Center(child: Text(
        _hiMotoActive ? '🎤' : 'Hi\nMoto',
        textAlign: TextAlign.center,
        style: TextStyle(color: _hiMotoActive ? Colors.white : _modeColor,
          fontSize: _hiMotoActive ? 24 : 11, fontWeight: FontWeight.bold),
      )),
    ),
  );

  bool _gpsToggleBusy = false;

  Widget _buildGpsToggle() => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () async {
      if (_gpsToggleBusy) return; // Debounce
      _gpsToggleBusy = true;
      try {
        await _toggleGpsLive();
      } finally {
        _gpsToggleBusy = false;
      }
    },
    child: SizedBox(
      width: 56, height: 72,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // ON/OFF badge
        Container(
          margin: const EdgeInsets.only(bottom: 3),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _gpsLive ? Colors.green : _modeColor,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            _gpsLive ? 'ON' : 'OFF',
            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
          ),
        ),
        // GPS button
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _bubbleBg,
            border: Border.all(color: _gpsLive ? Colors.green : _modeColor.withValues(alpha: 0.5), width: 2),
            boxShadow: [if (_gpsLive) BoxShadow(color: Colors.green.withValues(alpha: 0.3), blurRadius: 6)],
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(
              _gpsLive ? Icons.my_location_rounded : Icons.location_searching_rounded,
              color: _gpsLive ? Colors.green : _modeColor,
              size: 20,
            ),
            const SizedBox(height: 1),
            Text('GPS', style: TextStyle(
              color: _gpsLive ? Colors.green : _modeColor,
              fontSize: 8, fontWeight: FontWeight.w700,
            )),
          ]),
        ),
      ]),
    ),
  );

  Widget _infoBubble(String val, String label, Color c) => Column(children: [
    Text(val, style: TextStyle(color: c, fontSize: 18, fontWeight: FontWeight.bold)),
    Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
  ]);

  // ── POI Rating Sheet ──
  void _showPoiRatingSheet(PoiResult poi) async {
    if (!mounted) return;
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    // Load existing ratings + user profiles
    int myRating = 0;
    double avgRating = 0;
    int totalRatings = 0;
    final List<Map<String, dynamic>> ratersList = [];

    try {
      final ratings = await supabase
          .from('poi_ratings')
          .select('rating, user_id, created_at, review_text')
          .eq('poi_name', poi.name)
          .order('created_at', ascending: false);

      if (ratings is List && ratings.isNotEmpty) {
        totalRatings = ratings.length;
        final sum = ratings.fold<int>(0, (s, r) => s + (r['rating'] as int));
        avgRating = sum / totalRatings;
        final mine = ratings.where((r) => r['user_id'] == userId);
        if (mine.isNotEmpty) myRating = mine.first['rating'] as int;

        // Load user profiles for raters
        final userIds = ratings.map((r) => r['user_id'] as String).toSet().toList();
        try {
          final profiles = await supabase
              .from('profiles')
              .select('id, username, avatar_url')
              .inFilter('id', userIds);
          final profileMap = <String, Map<String, dynamic>>{};
          if (profiles is List) {
            for (final p in profiles) {
              profileMap[p['id'] as String] = p;
            }
          }
          for (final r in ratings) {
            final uid = r['user_id'] as String;
            final profile = profileMap[uid];
            ratersList.add({
              'rating': r['rating'],
              'user_id': uid,
              'username': profile?['username'] ?? 'Unbekannt',
              'avatar_url': profile?['avatar_url'],
              'review_text': r['review_text'],
              'is_me': uid == userId,
            });
          }
        } catch (_) {
          for (final r in ratings) {
            ratersList.add({
              'rating': r['rating'],
              'user_id': r['user_id'],
              'username': 'User',
              'avatar_url': null,
              'review_text': r['review_text'],
              'is_me': r['user_id'] == userId,
            });
          }
        }
      }
    } catch (_) {}

    if (!mounted) return;

    int selectedRating = myRating;
    String existingReview = '';
    // Load existing review text
    try {
      final myReview = await supabase
          .from('poi_ratings')
          .select('review_text')
          .eq('user_id', userId)
          .eq('poi_name', poi.name)
          .maybeSingle();
      if (myReview != null && myReview['review_text'] != null) {
        existingReview = myReview['review_text'] as String;
      }
    } catch (_) {}

    if (!mounted) return;
    final reviewCtrl = TextEditingController(text: existingReview);

    await showModalBottomSheet(
      context: context,
      backgroundColor: _isDark ? const Color(0xFF1A1A2E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheetState) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        final bottomPadding = MediaQuery.of(ctx).padding.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding + 24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Drag handle
                Container(
                  width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: _textSecondary.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // POI Name
                Text(poi.name, style: TextStyle(
                  color: _textPrimary, fontSize: 18, fontWeight: FontWeight.bold,
                )),
                if (poi.address != null) ...[
                  const SizedBox(height: 4),
                  Text(poi.address!, style: TextStyle(color: _textSecondary, fontSize: 13)),
                ],
                const SizedBox(height: 8),
                // Average rating
                if (totalRatings > 0) Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  ...List.generate(5, (i) => Icon(
                    i < avgRating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: Colors.amber, size: 20,
                  )),
                  const SizedBox(width: 8),
                  Text('${avgRating.toStringAsFixed(1)} ($totalRatings)',
                    style: TextStyle(color: _textSecondary, fontSize: 13)),
                ]) else Text('Noch keine Bewertungen', style: TextStyle(color: _textSecondary, fontSize: 13)),

                const SizedBox(height: 16),
                Text(myRating > 0 ? 'Deine Bewertung ändern:' : 'Jetzt bewerten:',
                  style: TextStyle(color: _textPrimary, fontSize: 14)),
                const SizedBox(height: 8),

                // Star selector
                Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) {
                  final star = i + 1;
                  return GestureDetector(
                    onTap: () => setSheetState(() => selectedRating = star),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        star <= selectedRating ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: Colors.amber, size: 40,
                      ),
                    ),
                  );
                })),

                const SizedBox(height: 16),
                // Review text field
                TextField(
                  controller: reviewCtrl,
                  maxLines: 3,
                  minLines: 2,
                  maxLength: 300,
                  style: TextStyle(color: _textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Schreib eine Bewertung... (optional)',
                    hintStyle: TextStyle(color: _textSecondary.withValues(alpha: 0.6)),
                    filled: true,
                    fillColor: _isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(14),
                    counterStyle: TextStyle(color: _textSecondary, fontSize: 11),
                  ),
                ),

                const SizedBox(height: 12),
                // Submit button
                SizedBox(width: double.infinity, child: ElevatedButton(
                  onPressed: selectedRating > 0 ? () async {
                    try {
                      await supabase.from('poi_ratings').upsert({
                        'user_id': userId,
                        'poi_name': poi.name,
                        'poi_lat': poi.lat,
                        'poi_lng': poi.lon,
                        'poi_type': poi.type,
                        'rating': selectedRating,
                        'review_text': reviewCtrl.text.trim().isEmpty ? null : reviewCtrl.text.trim(),
                      }, onConflict: 'user_id, poi_name');
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('⭐ ${poi.name} mit $selectedRating Sternen bewertet!'),
                          backgroundColor: _modeColor, behavior: SnackBarBehavior.floating),
                      );
                    } catch (e) {
                      debugPrint('[Rating] Error: $e');
                    }
                  } : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _modeColor, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(myRating > 0 ? 'Bewertung ändern' : 'Bewerten'),
                )),

                // Raters list
                if (ratersList.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Divider(color: _textSecondary.withValues(alpha: 0.3)),
                  const SizedBox(height: 8),
                  Text('Bewertungen', style: TextStyle(
                    color: _textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ...ratersList.map((rater) {
                    final stars = rater['rating'] as int;
                    final avatarUrl = rater['avatar_url'] as String?;
                    final reviewText = rater['review_text'] as String?;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.grey[700],
                            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                            child: avatarUrl == null
                                ? const Icon(Icons.person, size: 16, color: Colors.white70)
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(
                            rater['is_me'] == true
                                ? '${rater['username']} (Du)'
                                : rater['username'] as String,
                            style: TextStyle(
                              color: rater['is_me'] == true ? _modeColor : _textPrimary,
                              fontSize: 13, fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          )),
                          ...List.generate(5, (s) => Icon(
                            s < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: Colors.amber, size: 14,
                          )),
                        ]),
                        if (reviewText != null && reviewText.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 42, top: 4),
                            child: Text(reviewText, style: TextStyle(
                              color: _textSecondary, fontSize: 12, fontStyle: FontStyle.italic,
                            )),
                          ),
                      ]),
                    );
                  }),
                ],
              ]),
            ),
          ),
        );
      }),
    );
    // Controller wird vom GC aufgeräumt — dispose() während Sheet-Animation
    // verursacht '_dependents.isEmpty' Assertion Error.
  }

  // ── Save Zuhause/Arbeit dialog ──
  void _showSaveLocationDialog(String label, String prefKey) async {
    final addrCtrl = TextEditingController();
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(prefKey);
    String? existingName;
    if (existing != null) {
      final parts = existing.split('|');
      if (parts.isNotEmpty) existingName = parts[0];
    }

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _isDark ? const Color(0xFF1A1A2E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(existingName != null ? '$label ändern' : '$label speichern', style: TextStyle(
            color: _textPrimary, fontSize: 18, fontWeight: FontWeight.bold,
          )),
          // Show current address if saved
          if (existingName != null) ...[
            const SizedBox(height: 8),
            Text('Aktuell: $existingName', style: TextStyle(
              color: _textSecondary, fontSize: 13,
            )),
          ],
          const SizedBox(height: 16),
          // Option 1: Current location
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            icon: const Icon(Icons.my_location_rounded),
            label: const Text('Aktuellen Standort speichern'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _modeColor, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              // Reverse geocode for actual address
              String displayName = label;
              try {
                final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?lat=$_lat&lon=$_lng&format=json&zoom=18&addressdetails=1');
                final resp = await http.get(url, headers: {'User-Agent': 'Bikergram/1.0'});
                if (resp.statusCode == 200) {
                  final data = json.decode(resp.body);
                  final addr = data['address'] as Map<String, dynamic>?;
                  if (addr != null) {
                    final road = addr['road'] ?? '';
                    final houseNr = addr['house_number'] ?? '';
                    final plz = addr['postcode'] ?? '';
                    final city = addr['city'] ?? addr['town'] ?? addr['village'] ?? '';
                    final parts = <String>[
                      if (road.isNotEmpty) '$road${houseNr.isNotEmpty ? ' $houseNr' : ''}',
                      if (plz.isNotEmpty || city.isNotEmpty) '${plz.isNotEmpty ? '$plz ' : ''}$city',
                    ];
                    if (parts.isNotEmpty) displayName = parts.join(', ');
                  }
                }
              } catch (_) {}
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(prefKey, '$displayName|$_lat|$_lng');
              if (prefKey == 'nav_home' && mounted) setState(() => _homeSaved = true);
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('📍 $label: $displayName'), backgroundColor: _modeColor, behavior: SnackBarBehavior.floating),
              );
            },
          )),
          const SizedBox(height: 12),
          // Option 2: Enter address
          TextField(
            controller: addrCtrl,
            style: TextStyle(color: _textPrimary),
            decoration: InputDecoration(
              hintText: 'Adresse eingeben...',
              hintStyle: TextStyle(color: _textSecondary),
              prefixIcon: Icon(Icons.search_rounded, color: _modeColor),
              filled: true,
              fillColor: _isDark ? const Color(0xFF252540) : const Color(0xFFF5F5F5),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            onSubmitted: (query) async {
              if (query.trim().isEmpty) return;
              Navigator.pop(ctx);
              // Geocode the address
              try {
                final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1&countrycodes=de');
                final resp = await http.get(url, headers: {'User-Agent': 'Bikergram/1.0'});
                if (resp.statusCode == 200) {
                  final results = json.decode(resp.body) as List;
                  if (results.isNotEmpty) {
                    final r = results.first;
                    final lat = double.parse(r['lat']);
                    final lng = double.parse(r['lon']);
                    final name = r['display_name'] as String;
                    final short = name.split(',').take(2).join(',').trim();
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString(prefKey, '$short|$lat|$lng');
                    if (prefKey == 'nav_home' && mounted) setState(() => _homeSaved = true);
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('📍 $label: $short gespeichert!'), backgroundColor: _modeColor, behavior: SnackBarBehavior.floating),
                    );
                  } else {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Adresse nicht gefunden'), behavior: SnackBarBehavior.floating),
                    );
                  }
                }
              } catch (e) {
                debugPrint('[Geocode] Error: $e');
              }
            },
          ),
          // Delete button if already saved
          if (existingName != null) ...[
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: TextButton.icon(
              icon: const Icon(Icons.delete_rounded, color: Colors.red),
              label: const Text('Löschen', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                Navigator.pop(ctx);
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove(prefKey);
                if (prefKey == 'nav_home' && mounted) setState(() => _homeSaved = false);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$label gelöscht'), behavior: SnackBarBehavior.floating),
                );
              },
            )),
          ],
        ]),
      ),
    );
  }

  // ── Waze-style quick nav button (Zuhause, Arbeit, Tanken, Essen) ──
  Widget _quickNavBtn(IconData icon, String label, String? prefKey, {PoiCategory? poiCat}) {
    final isActivePoi = _activePoiCategory == poiCat?.id;
    final shouldPulse = prefKey == 'nav_home' && !_homeSaved;

    Widget button = GestureDetector(
      onTap: () async {
        if (poiCat != null) {
          if (isActivePoi) { _clearPoiMarkers(); return; }
          _searchPoiAndShowOnMap(poiCat);
          return;
        }
        if (prefKey == null) return;
        final prefs = await SharedPreferences.getInstance();
        final saved = prefs.getString(prefKey);
        if (saved != null) {
          final parts = saved.split('|');
          if (parts.length >= 3) {
            final lat = double.tryParse(parts[1]);
            final lng = double.tryParse(parts[2]);
            if (lat != null && lng != null) {
              _selectDestination(lat, lng, parts[0]);
            }
          }
        } else {
          _showSaveLocationDialog(label, prefKey!);
        }
      },
      onLongPress: () async {
        if (prefKey == null) return;
        _showSaveLocationDialog(label, prefKey);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActivePoi ? _modeColor.withValues(alpha: 0.15) : _cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isActivePoi ? _modeColor : _cardBorder),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: isActivePoi ? _modeColor : _modeColor.withValues(alpha: 0.7), size: 22),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(
            color: isActivePoi ? _modeColor : _iconMuted,
            fontSize: 11, fontWeight: FontWeight.w600)),
          // Pulse hint for unsaved Zuhause
          if (shouldPulse) ...[
            const SizedBox(height: 2),
            Text('⏺ Halten', style: TextStyle(
              color: _modeColor.withValues(alpha: 0.8),
              fontSize: 8, fontWeight: FontWeight.w700)),
          ],
        ]),
      ),
    );

    // Wrap with pulsing glow for unsaved home
    if (shouldPulse) {
      button = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 1200),
        builder: (ctx, val, child) {
          // Oscillate: 0→1→0 via sin
          final pulse = math.sin(val * 3.14159 * 2).abs();
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: _modeColor.withValues(alpha: 0.15 + pulse * 0.35),
                  blurRadius: 8 + pulse * 8,
                  spreadRadius: pulse * 3,
                ),
              ],
            ),
            child: child,
          );
        },
        onEnd: () {
          // Repeat animation if still unsaved
          if (mounted && !_homeSaved) setState(() {});
        },
        child: button,
      );
    }

    return Expanded(child: button);
  }
}

enum _SignType { autobahn, bundesstrasse, europastrasse, other }

class _RoadInfo {
  final String? badge;
  final _SignType type;
  final String road;
  const _RoadInfo({this.badge, required this.type, required this.road});
}

/// Click listener for user markers on the map → opens profile.
class _HomeMarkerClickListener extends OnPointAnnotationClickListener {
  final VoidCallback onTap;
  _HomeMarkerClickListener(this.onTap);

  @override
  void onPointAnnotationClick(PointAnnotation annotation) {
    onTap();
  }
}

class _UserMarkerClickListener extends OnPointAnnotationClickListener {
  final Map<String, String> markerUserIdMap;
  final void Function(String userId) onUserTapped;

  _UserMarkerClickListener({
    required this.markerUserIdMap,
    required this.onUserTapped,
  });

  @override
  void onPointAnnotationClick(PointAnnotation annotation) {
    final userId = markerUserIdMap[annotation.id];
    if (userId != null) {
      onUserTapped(userId);
    }
  }
}

/// Painter for the "Unbegrenzt" (no speed limit) sign — diagonal grey stripes
/// StVO Zeichen 282 — "Ende sämtlicher Streckenverbote"
/// Weißer Kreis mit 4 parallelen, diagonalen schwarzen Linien.
class _UnlimitedSignPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = size.width / 2 - 4; // inside the border

    // Clip to circle so lines don't stick out
    canvas.save();
    canvas.clipPath(Path()
      ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: radius)));

    final paint = Paint()
      ..color = const Color(0xFF111111)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.butt
      ..style = PaintingStyle.stroke;

    // 4 parallel diagonals (top-left → bottom-right), evenly spaced
    // Line length across full diameter, spacing ~ radius/2
    final diag = radius * 2.4;
    final spacing = 5.5;
    for (int i = -2; i <= 1; i++) {
      final dx = i * spacing + spacing / 2;
      canvas.drawLine(
        Offset(cx - diag / 2 + dx, cy + diag / 2 + dx),
        Offset(cx + diag / 2 + dx, cy - diag / 2 + dx),
        paint,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
