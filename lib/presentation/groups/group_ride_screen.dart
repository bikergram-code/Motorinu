import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' hide CameraPosition;
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps show CameraPosition;
import 'package:livekit_client/livekit_client.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../services/vosk_wake_word_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../providers/auth/auth_notifier.dart';
import '../../providers/auth/auth_state.dart';
import '../../providers/core/providers.dart';
import '../../providers/groups/group_ride_notifier.dart';
import '../../services/blitzer_alert_service.dart';
import '../../services/destination_info_service.dart';
import '../../services/geocoding_service.dart';
import '../../services/live_location_service.dart';
import '../../services/livekit_service.dart';
import '../../services/marker_icon_service.dart';
import '../../services/osrm_service.dart';
import '../../services/google_routes_service.dart';
import '../../services/speed_limit_service.dart';
import '../../services/tts_alert_service.dart';
import '../../services/heading_sensor_service.dart';
import '../../providers/map/map_settings_provider.dart';
import '../../services/racer_events_service.dart';
import '../../services/voice_command_service.dart';
import '../../services/alert_audio_service.dart';
import '../../data/repositories/blitzer_repository.dart';
import '../../services/osm_blitzer_service.dart';
import '../../services/biker_ai_service.dart';
import '../../services/fast_answer_service.dart';
import '../../services/kalman_filter.dart';
import '../../providers/map/live_location_provider.dart';
import '../../navigation/navigation.dart';

/// Full-screen Group Ride experience.
///
/// Combines: Google Map with live members, Live Video (LiveKit),
/// Blitzer warnings, and shared Navigation.
/// Voice/Chat not needed — bikers use SENA intercoms.
class GroupRideScreen extends ConsumerStatefulWidget {
  final int groupId;

  const GroupRideScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupRideScreen> createState() => _GroupRideScreenState();
}

class _GroupRideScreenState extends ConsumerState<GroupRideScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  GoogleMapController? _mapController;
  bool _showVideoGrid = false;
  late AnimationController _alertPulseController;

  // Speech-to-text for voice POI queries (fallback)
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;
  String _listenText = '';

  // Vosk wake word — always-on offline voice (replaces speech_to_text for wake word)
  bool _voskInitialized = false;

  // Wake word "Hi Moto" — hands-free voice activation
  bool _wakeWordActive = false;
  bool _wakeWordTriggered = false; // true after "hi moto" detected, waiting for command
  Timer? _wakeWordRestartTimer;

  // Map interaction — hide UI while user zooms/pans/rotates
  bool _mapInteracting = false;
  Timer? _mapIdleTimer;

  // SOS State
  bool _sosActive = false;
  Timer? _sosBlinkTimer;
  bool _sosBlinkVisible = true;

  // Pending fuel station voice choice — if non-null, next command is a fuel choice
  List<({String name, double lat, double lon, double distance, double? rating, int? ratingCount})>? _pendingFuelChoices;

  // Pending blitzer report — waiting for type selection (mobil/fest)
  bool _pendingBlitzerType = false;

  // Initial GPS position for map
  LatLng? _initialPosition;
  bool _hasCenteredOnce = false;

  // Destination search
  final TextEditingController _searchController = TextEditingController();

  // Profile picture marker icons (async loaded, fallback to default until ready)
  final Map<String, BitmapDescriptor> _memberMarkerIcons = {};
  final Set<String> _loadingIcons = {};

  // OSRM routing
  final OsrmService _osrmService = OsrmService();
  final GoogleRoutesService _googleRoutes = GoogleRoutesService();
  late final NavEngine _navEngine = NavEngine(osrmService: _osrmService);
  OsrmRoute? _currentRoute;
  bool _isCalculatingRoute = false;
  RouteMode _routeMode = RouteMode.biker;

  // ── Heading-up navigation camera (Waze-style) ──
  StreamSubscription<Position>? _headingGpsSub;
  StreamSubscription<double>? _fusedHeadingSub;
  double _currentHeading = 0;
  double _fusedHeading = 0; // Gyro+GPS fused heading (50Hz)
  final KalmanFilter _navKalman = KalmanFilter(); // Kalman filter for nav position
  LatLng? _currentGpsPos;
  bool _isNavFollowing = true; // auto-follow with heading rotation
  bool _isProgrammaticMove = false;
  DateTime _lastProgrammaticMoveTime = DateTime.fromMillisecondsSinceEpoch(0);
  bool _userTouchingMap = false; // true while user finger is on map
  double _currentZoom = 17.0; // track zoom level so we can preserve it
  bool _isNavigating = false; // true after user taps "LOS!"
  bool _navUiHidden = false; // true = hide search/buttons during navigation
  Timer? _navUiShowTimer; // auto-hide UI after tap
  BitmapDescriptor? _navVehicleIcon; // Waze-style arrow marker
  BitmapDescriptor? _navDotIcon; // Small dot for navigation mode

  // ── Route alternatives ──
  List<OsrmRoute> _alternativeRoutes = [];
  int _selectedRouteIndex = 0;

  // ── Route info panel (persistent, swipeable) ──
  bool _routePanelExpanded = false;
  bool _showRouteSteps = true; // Always show route steps
  List<Widget>? _cachedRouteStepWidgets;
  OsrmRoute? _cachedRouteStepRoute;
  int _cachedFuelCount = -1;
  bool _cachedShowSteps = true;
  RouteMode? _cachedRouteMode;
  final ScrollController _panelScrollController = ScrollController();
  bool _scrolledPastHalf = false; // true when scrolled > 50%

  // ── Route enrichment data ──
  final DestinationInfoService _destInfoService = DestinationInfoService();
  DestinationInfo? _destinationInfo;
  int _routeBlitzerCount = 0;
  List<LatLng> _routeBlitzerPositions = []; // Blitzer marker positions on map
  List<BlitzerReport> _nearbyBlitzerReports = []; // Community blitzers from DB
  DateTime? _lastBlitzerLoad;
  RealtimeChannel? _blitzerRealtimeChannel;
  RoutePois _routePois = RoutePois.empty();
  bool _isLoadingRouteInfo = false;
  String? _lastDestinationName; // Name from search or geocoding

  // ── Country borders along route ──
  // Maps cumulative distance (km) → country code for border detection
  List<_CountrySegment> _routeCountrySegments = [];
  // Which countries are expanded in the route steps list (default: all collapsed)
  final Set<String> _expandedCountries = {};

  // ── Speed limit ──
  SpeedLimitResult _speedLimit = SpeedLimitResult.unknown;
  bool _isSpeeding = false;
  DateTime? _lastSpeedingAlert;

  // ── GPS state ──
  double _gpsSpeedKmh = 0;
  double _smoothedSpeed = 0;
  double _displaySpeed = 0;
  DateTime _lastGpsTimestamp = DateTime.now();
  double _targetHeading = 0;    // heading from GPS/gyro (target for camera)
  bool _hasEverDriven = false;
  int _lastSnapSegIdx = 0;

  // ── 30fps camera loop (Waze-style: smooth bearing, dead-zone) ──
  Timer? _cameraAnimTimer;
  double _smoothBearing = 0;      // interpolated bearing for smooth rotation
  double _committedBearing = 0;   // Waze dead-zone: only updates past threshold
  double _smoothZoom = 17.0;
  bool _navCameraDirty = false;
  LatLng? _smoothCamPos; // EMA-smoothed camera position (anti-stutter)
  LatLng? _lastCamTarget; // last camera target sent to animateCamera
  double _lastCamBearing = -1; // last bearing sent to animateCamera

  // ── Non-nav heading follow (compass rotation without navigation) ──
  Timer? _headingFollowTimer;

  // ── Periodic nav tasks (off-route check, speed limit) ──
  Timer? _navPeriodicTimer;

  // ── Cached snap result (avoid recalculating on same GPS tick) ──
  LatLng? _lastSnapInput;
  LatLng? _lastSnapResult;
  double _lastSnapDist = double.infinity; // distance to route at last snap

  // ── OSRM Map Matching (HMM-based GPS→Road snap) ──
  /// Ring buffer of recent GPS positions for OSRM /match API
  final List<LatLng> _gpsMatchBuffer = [];
  final List<int> _gpsMatchTimestamps = [];
  static const _gpsMatchBufferSize = 8; // Keep last 8 positions
  int _gpsMatchTickCounter = 0;
  static const _gpsMatchInterval = 3; // Call OSRM every 3rd GPS tick (~3Hz → 1 match/sec)
  LatLng? _osrmMatchedPos; // Latest OSRM-matched position (null = no match yet)
  bool _osrmMatchInFlight = false; // Prevent concurrent match requests

  // ── Cached polylines (only rebuild when route changes) ──
  Set<Polyline>? _cachedPolylines;
  OsrmRoute? _cachedPolylineRoute;
  int _cachedPolylineAltCount = -1;

  // ── Turn-by-turn navigation ──
  int _lastAnnouncedStepIndex = -1;
  // (old level indices removed — now using _announcedTtsPairs Set)
  DateTime? _lastNavAnnouncement;

  // ── Next turn display (live during navigation) ──
  OsrmStep? _nextTurnStep;        // next non-straight step
  double _nextTurnDistanceM = 0;  // distance to it in meters
  OsrmStep? _afterNextTurnStep;   // step after next (for "Danach:" preview)

  // ── Off-route detection ──
  int _offRouteCount = 0; // consecutive off-route GPS fixes

  // ── Search overlay ──
  bool _showSearchOverlay = false;
  List<GeocodingResult>? _searchResults;
  bool _isSearching = false;
  Timer? _searchDebounce;
  final TextEditingController _overlaySearchCtrl = TextEditingController();

  // ── Search history ──
  List<Map<String, String>> _searchHistory = [];

  // ── Waze-style dark map theme ──
  static const _darkMapStyle = '''[
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

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _alertPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Load GPS position immediately
    _loadInitialPosition();
    // Load Waze-style vehicle icon
    _loadVehicleIcon();
    // Load search history
    _loadSearchHistory();
    // Initialize speech recognition
    _initSpeech();
    // Start heading-up GPS tracking for Waze-style camera
    _startHeadingTracking();
    // Get initial GPS position immediately (so Hi Moto + center button appear faster)
    _getInitialGps();
    // Calculate route if destination already set (delayed to allow state to load)
    Future.delayed(const Duration(seconds: 2), _calculateExistingRoute);
    // Load nearby community blitzers from DB + Realtime subscription
    // Retry if GPS not ready yet (GPS can take a few seconds)
    Future.delayed(const Duration(seconds: 3), () {
      _loadNearbyBlitzers();
      // Retry after 8s if GPS was null on first attempt
      if (_currentGpsPos == null) {
        Future.delayed(const Duration(seconds: 8), _loadNearbyBlitzers);
      }
    });
    _startBlitzerRealtime();
  }

  Future<void> _loadVehicleIcon() async {
    final authState = ref.read(authNotifierProvider);
    String? avatarUrl;
    String displayName = 'Du';
    if (authState is Authenticated) {
      avatarUrl = authState.user.avatarUrl;
      displayName = authState.user.displayName ?? authState.user.username;
    }
    final modeKey = _routeMode == RouteMode.biker ? 'bike' : _routeMode == RouteMode.pedestrian ? 'pedestrian' : 'car';
    final icon = await MarkerIconService.instance.getNavigationVehicleMarker(
      avatarUrl: avatarUrl,
      displayName: displayName,
      routeModeKey: modeKey,
    );
    if (mounted) setState(() => _navVehicleIcon = icon);
    // Also create small nav dot icon
    _createNavDotIcon();
  }

  Future<void> _createNavDotIcon() async {
    final modeColor = _routeMode == RouteMode.biker
        ? const Color(0xFF00BCD4)
        : _routeMode == RouteMode.pedestrian
            ? const Color(0xFF4CAF50)
            : const Color(0xFF2196F3);
    // ── Waze-style arrow with visible ring ──
    const double size = 80;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));

    // Outer ring — clearly visible circle around the icon
    canvas.drawCircle(const Offset(size / 2, size / 2), 36, Paint()
      ..color = modeColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0);

    // Soft glow behind arrow
    canvas.drawCircle(const Offset(size / 2, size / 2), 30, Paint()
      ..color = modeColor.withValues(alpha: 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));

    // White border (slightly larger)
    final borderPath = Path();
    borderPath.moveTo(size / 2, 10);
    borderPath.lineTo(size / 2 + 20, 58);
    borderPath.lineTo(size / 2, 46);
    borderPath.lineTo(size / 2 - 20, 58);
    borderPath.close();
    canvas.drawPath(borderPath, Paint()..color = Colors.white);

    // Colored arrow fill
    final arrowPath = Path();
    arrowPath.moveTo(size / 2, 14);
    arrowPath.lineTo(size / 2 + 17, 55);
    arrowPath.lineTo(size / 2, 44);
    arrowPath.lineTo(size / 2 - 17, 55);
    arrowPath.close();
    canvas.drawPath(arrowPath, Paint()..color = modeColor);

    final img = await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    if (bytes != null && mounted) {
      setState(() {
        _navDotIcon = BitmapDescriptor.bytes(bytes.buffer.asUint8List());
      });
    }
  }

  Future<void> _loadSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getStringList('nav_search_history') ?? [];
      final loaded = historyJson.map((json) {
        final map = Map<String, dynamic>.from(
          const JsonDecoder().convert(json) as Map,
        );
        return map.map((k, v) => MapEntry(k, v.toString()));
      }).toList();
      if (mounted && loaded.isNotEmpty) {
        setState(() => _searchHistory = loaded);
      } else {
        _searchHistory = loaded;
      }
    } catch (_) {}
  }

  Future<void> _saveSearchHistory(String name, String subtitle, double lat, double lng) async {
    final entry = {'name': name, 'subtitle': subtitle, 'lat': '$lat', 'lng': '$lng'};
    _searchHistory.removeWhere((e) => e['name'] == name);
    _searchHistory.insert(0, entry);
    if (_searchHistory.length > 10) _searchHistory = _searchHistory.sublist(0, 10);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('nav_search_history',
        _searchHistory.map((e) => const JsonEncoder().convert(e)).toList());
    } catch (_) {}
  }

  Future<void> _loadInitialPosition() async {
    try {
      final pos = await Geolocator.getLastKnownPosition();
      if (pos != null && mounted) {
        setState(() => _initialPosition = LatLng(pos.latitude, pos.longitude));
        // If map already created, move camera there
        if (_mapController != null && !_hasCenteredOnce) {
          _hasCenteredOnce = true;
          _mapController!.animateCamera(CameraUpdate.newLatLngZoom(
            _initialPosition!, 14,
          ));
        }
      }
    } catch (e) {
      debugPrint('[GroupRide] GPS position error: $e');
    }
  }

  /// If group already has a destination when joining, calculate route.
  void _calculateExistingRoute() {
    if (!mounted) return;
    final rideState = ref.read(groupRideProvider(widget.groupId));
    final group = rideState.group;
    if (group?.destinationLat != null && group?.destinationLng != null && _currentRoute == null) {
      _calculateRoute(LatLng(group!.destinationLat!, group.destinationLng!));
    }
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: (e) {
        debugPrint('[Speech] Error: $e');
        if (mounted) setState(() => _isListening = false);
      },
      onStatus: (status) {
        debugPrint('[Speech] Status: $status');
      },
    );
    debugPrint('[Speech] Init result: $_speechAvailable');

    // Initialize Vosk for always-on wake word (offline, German)
    _initVosk();
  }

  Future<void> _initVosk() async {
    final ok = await VoskWakeWordService.instance.init();
    if (!mounted) return;
    setState(() => _voskInitialized = ok);
    debugPrint('[Vosk] Init result: $ok');

    if (ok) {
      // Set up event handler — NEVER replace this handler, use state flags instead
      VoskWakeWordService.instance.onEvent = (event, text) {
        if (!mounted) return;
        switch (event) {
          case VoskWakeEvent.wakeWordDetected:
            // If waiting for POI choice, DON'T cancel — user might say "Hi Moto drei"
            debugPrint('[Vosk] Wake word! (pendingChoices=${_pendingFuelChoices != null})');
            HapticFeedback.heavyImpact();

            // ── INTERRUPT: Stop any current TTS immediately ──
            // User said "Hi Moto" again → they want to ask something new
            TtsAlertService.instance.clearQueue();
            TtsAlertService.instance.stop();

            setState(() {
              _wakeWordTriggered = true;
              _wakeWordActive = true;
            });
            // Don't say "Ja?" if user is already in choice mode
            if (_pendingFuelChoices == null && !_pendingBlitzerType) {
              // Pause Vosk during TTS to prevent it from hearing its own "Ja?"
              VoskWakeWordService.instance.setPaused(true);
              TtsAlertService.instance.speakText('Ja Racer?').then((_) async {
                // Wait for TTS to finish + generous buffer for echo/reverb
                await Future.delayed(const Duration(milliseconds: 1200));
                VoskWakeWordService.instance.setPaused(false);
              });
            }
            break;
          case VoskWakeEvent.commandRecognized:
            debugPrint('[Vosk] Command: "$text"');
            setState(() {
              _wakeWordTriggered = false;
              _listenText = text;
            });
            // Off-route reroute choice ("Weiter"/"Zurück") — highest priority
            if (_awaitingRerouteChoice) {
              _handleRerouteChoice(text);
            } else if (_handleNavVoiceCommand(text)) {
              // handled
            } else if (_awaitingOffRouteAnswer) {
              _handleOffRouteVoiceAnswer(text);
            } else if (_pendingBlitzerType) {
              _handleBlitzerTypeVoiceChoice(text);
            } else if (_pendingFuelChoices != null) {
              _handleFuelVoiceChoice(text);
            } else {
              _processVoiceQuery(text);
            }
            break;
          case VoskWakeEvent.commandTimeout:
            debugPrint('[Vosk] Command timeout (pendingChoices=${_pendingFuelChoices != null})');
            // DON'T clear pending fuel choices — user might still respond
            setState(() => _wakeWordTriggered = false);
            break;
        }
      };

      // Auto-start Vosk listening — always on, no button press needed
      await VoskWakeWordService.instance.startListening();
      if (mounted) {
        setState(() => _wakeWordActive = true);
        debugPrint('[Vosk] Auto-started listening — say "Hi Moto"!');
      }
    }
  }

  /// Waze-style heading-up camera: GPS stream updates bearing + position.
  DateTime _lastUiUpdate = DateTime.now();

  Future<void> _getInitialGps() async {
    try {
      final pos = await Geolocator.getLastKnownPosition();
      if (pos != null && mounted && _currentGpsPos == null) {
        setState(() {
          _currentGpsPos = LatLng(pos.latitude, pos.longitude);
        });
        // GPS available immediately — load blitzers
        if (!_blitzerLoadedWithGps) {
          _blitzerLoadedWithGps = true;
          _loadNearbyBlitzers();
        }
      }
    } catch (_) {}
  }

  void _startHeadingTracking() {
    // Start gyroscope sensor fusion for Waze-level smooth heading
    final headingService = HeadingSensorService.instance;
    headingService.start();
    _fusedHeadingSub = headingService.headingStream.listen((heading) {
      _fusedHeading = heading;
    });

    // Start non-nav heading follow (compass rotation without active navigation)
    _startHeadingFollowTimer();

    _headingGpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation, // Max: GPS+WLAN+Cell+Sensors
        distanceFilter: 0, // Every GPS fix — max accuracy, ignore battery
      ),
    ).listen((pos) {
      if (!mounted) return;

      // ── Kalman filter for position + speed accuracy ──
      final smoothed = _navKalman.update(pos);
      var newPos = LatLng(smoothed.smoothedLat, smoothed.smoothedLng);
      final speedKmh = smoothed.smoothedSpeed; // Kalman-EMA smoothed
      final rawSpeedKmh = pos.speed * 3.6;

      // Skip bad GPS fixes (accuracy > 25m) for navigation
      if (pos.accuracy > 25) return;

      // ── Stillstands-Filter ──
      // Biker/Auto: GPS noise at standstill = 2-4 km/h → filter below 4 km/h.
      // Pedestrian: NO early return — always process position updates so icon moves.
      //   Speed display filtered separately below.
      final standstillThreshold = _routeMode == RouteMode.pedestrian ? 1.0 : 4.0;
      if (rawSpeedKmh < standstillThreshold && speedKmh < standstillThreshold && _currentGpsPos != null) {
        _currentGpsPos = newPos;
        _gpsSpeedKmh = 0;
        _lastGpsTimestamp = DateTime.now();
        _smoothedSpeed = 0;
        _displaySpeed = 0;
        _navCameraDirty = true;
        _navEngine.updateGps(newPos, 0, _currentHeading);
        if (!_userTouchingMap && mounted) setState(() {});
        return;
      }

      // Feed GPS heading + speed to sensor fusion service
      HeadingSensorService.instance.updateFromGps(
        gpsHeading: pos.heading,
        speedKmh: rawSpeedKmh,
      );

      // Use fused heading (gyro+GPS) or raw GPS heading
      // Pedestrian: accept heading at lower speed (walking ~5 km/h)
      final headingMinSpeed = _routeMode == RouteMode.pedestrian ? 2.0 : 5.0;
      final newHeading = rawSpeedKmh > headingMinSpeed
          ? (HeadingSensorService.instance.isGyroAvailable
              ? _fusedHeading
              : (pos.heading >= 0 ? pos.heading : _currentHeading))
          : _currentHeading;

      // Update state
      final wasGpsNull = _currentGpsPos == null;
      _currentGpsPos = newPos;
      _currentHeading = newHeading;
      _targetHeading = newHeading;

      if (wasGpsNull && !_blitzerLoadedWithGps) {
        _blitzerLoadedWithGps = true;
        _loadNearbyBlitzers();
      }
      _gpsSpeedKmh = rawSpeedKmh;
      _lastGpsTimestamp = DateTime.now();
      _lastSnapInput = null; // Invalidate snap cache

      if (_isNavigating) {
        _feedGpsMatchBuffer(newPos);
      }

      // Speed: use Kalman-filtered speed directly (alpha=0.7, fast follow).
      // Speed display: instant zero when stopping, Kalman-filtered when moving.
      // Raw speed is the fastest indicator of deceleration.
      _smoothedSpeed = speedKmh;
      final speedZeroThreshold = _routeMode == RouteMode.pedestrian ? 2.5 : 4.0;
      if (rawSpeedKmh < speedZeroThreshold) {
        _displaySpeed = 0; // Instant zero — no decay lag
      } else {
        _displaySpeed = speedKmh;
      }

      // Feed NavEngine FIRST, then read state
      _navEngine.updateGps(newPos, rawSpeedKmh, newHeading);

      // Turn distance + step driven by NavEngine
      if (_isNavigating) {
        _nextTurnStep = _navEngine.state.nextTurn;
        _nextTurnDistanceM = _navEngine.state.nextTurnDistM;
        _afterNextTurnStep = _navEngine.state.afterNextTurn;
      }

      // Mark camera dirty for 30fps loop
      _navCameraDirty = true;
      if (rawSpeedKmh > 5) _hasEverDriven = true;

      // Throttle UI rebuilds
      if (!_userTouchingMap) {
        final now = DateTime.now();
        final throttleMs = _isNavigating ? 50 : 250;
        if (now.difference(_lastUiUpdate).inMilliseconds > throttleMs) {
          _lastUiUpdate = now;
          setState(() {});
        }
      }
    });
  }

  /// Start periodic navigation tasks (off-route, speed limit) — runs every 1s.
  void _startNavPeriodicTimer() {
    _navPeriodicTimer?.cancel();
    _navPeriodicTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _currentGpsPos == null) return;
      if (_isNavigating) {
        _checkOffRoute(_currentGpsPos!);
        // TTS + turn tracking now handled by NavEngine (no double-announcements)
        // _announceNextStep(_currentGpsPos!);
        // _updateNextTurn(_currentGpsPos!);
      }
      _updateSpeedLimit(
        _currentGpsPos!.latitude, _currentGpsPos!.longitude, _gpsSpeedKmh);
      // Reload nearby community blitzers every 30s
      _loadNearbyBlitzers();
    });
  }

  /// Announce upcoming turns via TTS — multi-level, motorcycle-optimized.
  /// Designed for riders who can't look at the display.
  ///
  /// Announcement levels:
  /// 1.  Segment start: "Gut. Weiter auf Berliner Str. für 1,6 km, dann links auf Mülheimer Str."
  /// 1b. Periodic straight: "Weiter geradeaus für 800 Meter, dann links auf Berliner Str."
  /// 2.  600m pre-warning: "Achtung, in 500 Metern links abbiegen auf Berliner Str."
  /// 3.  200m pre-announcement: "Bitte gleich links auf Berliner Str."
  /// 3b. 100m warning: "In 100 Metern links abbiegen!"
  /// 4.  50m now: "Jetzt links abbiegen"
  /// 5.  Arrival: "Du hast dein Ziel erreicht"
  // TTS dedup: tracks (stepIndex:threshold) pairs already announced
  final Set<String> _announcedTtsPairs = {};

  /// Clean 3-threshold announcement system (like backup NavigationTtsService):
  /// - 500m: "In 500 Metern, [instruction] auf [road]"
  /// - 200m: "In 200 Metern, [instruction] auf [road]"
  /// - <40m: "Jetzt, [instruction]!"
  /// Each (step, threshold) pair is announced exactly once (dedup via Set).
  void _announceNextStep(LatLng pos) {
    if (_currentRoute == null || _currentRoute!.steps.isEmpty) return;
    // Don't interrupt queued speech (nav start, reroute, etc.)
    if (TtsAlertService.instance.isQueueActive) return;

    final steps = _currentRoute!.steps;

    for (int i = _lastAnnouncedStepIndex + 1; i < steps.length; i++) {
      final step = steps[i];
      if (step.maneuver.startsWith('depart')) continue;

      final distToStep = _distAlongRoute(pos, step.location);

      // Build instruction with road name (dedup: don't repeat if already in instruction)
      final hasRoadInInstruction = step.roadName != null && step.roadName!.isNotEmpty
          && step.instruction.toLowerCase().contains(step.roadName!.toLowerCase());
      final roadInfo = (step.roadName != null && step.roadName!.isNotEmpty && !hasRoadInInstruction)
          ? ' auf ${step.roadName}' : '';

      // ── Arrival ──
      if (step.maneuver == 'arrive' && distToStep < 50) {
        _lastAnnouncedStepIndex = i;
        TtsAlertService.instance.clearQueue();
        TtsAlertService.instance.speakQueued('Du hast dein Ziel erreicht. Viel Spaß noch!');
        return;
      }

      // ── Determine threshold ──
      String? threshold;
      String? distanceText;
      if (distToStep <= 40) {
        threshold = 'now';
        distanceText = 'Jetzt';
      } else if (distToStep <= 200) {
        threshold = '200m';
        distanceText = 'In 200 Metern';
      } else if (distToStep <= 500) {
        threshold = '500m';
        distanceText = 'In 500 Metern';
      }

      if (threshold == null) return; // Not close enough yet

      // Deduplication: each (step, threshold) announced exactly once
      final key = '$i:$threshold';
      if (_announcedTtsPairs.contains(key)) {
        if (threshold == 'now') {
          // Step done — advance index
          _lastAnnouncedStepIndex = i;
        }
        return;
      }
      _announcedTtsPairs.add(key);

      if (threshold == 'now') {
        _lastAnnouncedStepIndex = i;
        TtsAlertService.instance.speakText('Jetzt, ${step.instruction}$roadInfo!');
      } else {
        TtsAlertService.instance.speakText(
          '$distanceText, ${step.instruction}$roadInfo',
        );
      }
      return;
    }
  }

  /// Update next turn step + distance for the turn banner display.
  /// Uses distance along route polyline (not air-line) for accuracy.
  void _updateNextTurn(LatLng pos) {
    if (_currentRoute == null || _currentRoute!.steps.isEmpty) {
      _nextTurnStep = null;
      _afterNextTurnStep = null;
      return;
    }
    final steps = _currentRoute!.steps;
    bool foundFirst = false;
    for (int i = _lastAnnouncedStepIndex + 1; i < steps.length; i++) {
      final step = steps[i];
      if (step.maneuver.startsWith('depart')) continue;
      if (!foundFirst) {
        // First upcoming turn
        final dist = _distAlongRoute(pos, step.location);
        _nextTurnStep = step;
        _nextTurnDistanceM = dist;
        foundFirst = true;
      } else {
        // Second upcoming turn → "Danach:" preview
        if (!step.maneuver.startsWith('depart') && step.maneuver != 'arrive') {
          _afterNextTurnStep = step;
        }
        return;
      }
    }
    if (!foundFirst) _nextTurnStep = null;
    _afterNextTurnStep = null;
  }

  /// Calculate distance along the route polyline between current pos and target.
  /// Falls back to air-line distance if route is unavailable.
  double _distAlongRoute(LatLng from, LatLng to) {
    if (_currentRoute == null || _currentRoute!.polylinePoints.length < 2) {
      return _distLatLng(from, to);
    }
    final pts = _currentRoute!.polylinePoints;

    // Find nearest point on route to current position
    int nearestIdx = 0;
    double nearestDist = double.infinity;
    for (int i = 0; i < pts.length; i++) {
      final d = _distLatLng(from, pts[i]);
      if (d < nearestDist) {
        nearestDist = d;
        nearestIdx = i;
      }
    }

    // Find nearest point on route to target (step location)
    int targetIdx = nearestIdx;
    double targetDist = double.infinity;
    for (int i = nearestIdx; i < pts.length; i++) {
      final d = _distLatLng(to, pts[i]);
      if (d < targetDist) {
        targetDist = d;
        targetIdx = i;
      }
    }

    // Sum distances along route segments
    double total = _distLatLng(from, pts[nearestIdx]); // gap to route
    for (int i = nearestIdx; i < targetIdx && i + 1 < pts.length; i++) {
      total += _distLatLng(pts[i], pts[i + 1]);
    }
    return total;
  }

  /// Format distance for TTS: "200 Meter", "1,5 Kilometer"
  String _formatDistance(double meters) {
    if (meters < 1000) {
      final rounded = (meters / 50).round() * 50;
      // Never say "0 Meter" — minimum 50
      return '${rounded < 50 ? 50 : rounded} Meter';
    } else {
      final km = (meters / 100).round() / 10; // round to 0.1 km
      final kmStr = km.toStringAsFixed(1).replaceAll('.', ',');
      return '$kmStr Kilometer';
    }
  }

  /// Camera follow: simple, stable, no jitter.
  /// - Position: RAW GPS (not snapped — snap causes segment jumps)
  /// - Bearing: ONLY from route polyline (GPS heading is garbage at low speed)
  /// - Update: 1× per second, let Google Maps animate internally at 60fps
  /// - No manual offset — use GoogleMap padding instead
  void _startNavCameraLoop() {
    _cameraAnimTimer?.cancel();
    _isProgrammaticMove = true;

    _cameraAnimTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      if (_mapController == null || !mounted) return;
      if (!_isNavFollowing || _userTouchingMap) return;

      // ── POSITION: always raw GPS — no snap, no dead reckoning ──
      // Snap-to-route caused position jumps between parallel segments.
      // Raw GPS is noisy but Google animateCamera smooths it at 60fps.
      final pos = _currentGpsPos;
      if (pos == null) return;

      // ── BEARING: route-only during navigation ──
      // GPS heading at <30 km/h is ±90° noise → camera flips.
      // Route heading from polyline is stable and predictive.
      if (_isNavigating && _gpsSpeedKmh > 3) {
        final routeHdg = _routeHeadingAhead(pos);
        if (routeHdg != null) {
          double delta = (routeHdg - _committedBearing) % 360;
          if (delta > 180) delta -= 360;
          if (delta < -180) delta += 360;
          // Only commit if real turn (>20°) — prevents micro-corrections
          if (delta.abs() > 20) {
            _committedBearing = routeHdg;
          }
        }
      } else if (!_isNavigating && _gpsSpeedKmh > 8) {
        // Outside nav: use GPS heading, but only at higher speed
        _committedBearing = _targetHeading;
      }
      _smoothBearing = _committedBearing;
      _smoothCamPos = pos;

      _lastProgrammaticMoveTime = DateTime.now();
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(gmaps.CameraPosition(
          target: pos,
          zoom: _smoothZoom,
          bearing: _smoothBearing,
          tilt: 50,
        )),
      );
      _navCameraDirty = false;
    });
  }

  void _stopNavCameraLoop() {
    _cameraAnimTimer?.cancel();
    _cameraAnimTimer = null;
  }

  /// Linearly interpolate between two angles via shortest arc.
  double _lerpAngle(double a, double b, double t) {
    double diff = (b - a) % 360;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    return (a + diff * t) % 360;
  }

  /// Compute heading from route polyline at current snap position, looking ~60m ahead.
  /// This gives instant, predictive heading through curves — no GPS delay.
  double? _routeHeadingAhead(LatLng snappedPos) {
    if (_currentRoute == null || _currentRoute!.polylinePoints.length < 2) return null;
    final pts = _currentRoute!.polylinePoints;
    final segIdx = _lastSnapSegIdx.clamp(0, pts.length - 2);

    // Walk ~60m ahead on the polyline from current segment
    const lookAheadM = 60.0;
    double walked = 0;
    LatLng aheadPt = snappedPos;
    for (int i = segIdx; i < pts.length - 1 && walked < lookAheadM; i++) {
      final segLen = _distLatLng(pts[i], pts[i + 1]);
      if (walked + segLen >= lookAheadM) {
        // Interpolate within this segment to hit exactly lookAheadM
        final remaining = lookAheadM - walked;
        final frac = segLen > 0 ? remaining / segLen : 0.0;
        aheadPt = LatLng(
          pts[i].latitude + (pts[i + 1].latitude - pts[i].latitude) * frac,
          pts[i].longitude + (pts[i + 1].longitude - pts[i].longitude) * frac,
        );
        walked = lookAheadM;
        break;
      }
      walked += segLen;
      aheadPt = pts[i + 1];
    }

    if (walked < 10) return null; // Too close to end of route

    // Compute bearing from snapped position to look-ahead point
    final dLat = aheadPt.latitude - snappedPos.latitude;
    final dLng = aheadPt.longitude - snappedPos.longitude;
    if (dLat.abs() < 1e-9 && dLng.abs() < 1e-9) return null;

    final cosLat = math.cos(snappedPos.latitude * math.pi / 180);
    final bearing = math.atan2(dLng * cosLat, dLat) * 180 / math.pi;
    return (bearing + 360) % 360;
  }

  /// Start heading-follow timer for non-navigation mode.
  /// 10fps marker rotation — rotates user marker, map stays north-up.
  void _startHeadingFollowTimer() {
    double lastBearing = -999;
    _headingFollowTimer?.cancel();
    _headingFollowTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_isNavigating || _cameraAnimTimer != null) return;
      if (_currentGpsPos == null) return;

      // GPS heading when driving, compass until first drive, freeze after
      double heading;
      if (_gpsSpeedKmh > 5 && _targetHeading >= 0) {
        heading = _targetHeading;
        _hasEverDriven = true;
      } else if (!_hasEverDriven) {
        heading = _fusedHeading; // First use: compass for initial direction
      } else {
        heading = _currentHeading; // Driven before, now stopped: freeze
      }

      // Skip if heading barely changed (< 3°) — reduces marker rebuilds
      var diff = (heading - lastBearing).abs();
      if (diff > 180) diff = 360 - diff;
      if (diff < 3.0 && lastBearing != -999) return;
      lastBearing = heading;

      // Update heading for marker rotation (map stays north-up)
      _currentHeading = heading;

      // Center camera on user position (north-up, no rotation)
      if (_isNavFollowing && _mapController != null && !_userTouchingMap) {
        _isProgrammaticMove = true;
        _lastProgrammaticMoveTime = DateTime.now();
        _mapController!.moveCamera(
          CameraUpdate.newLatLng(_currentGpsPos!),
        );
        Future.delayed(const Duration(milliseconds: 200), () {
          _isProgrammaticMove = false;
        });
      }

      if (mounted && !_userTouchingMap) setState(() {});
    });
  }

  /// Query speed limit + check for speeding.
  void _updateSpeedLimit(double lat, double lon, double speedKmh) async {
    try {
      final result = await SpeedLimitService.instance.getSpeedLimit(lat, lon);
      if (!mounted) return;

      final wasSpeeding = _isSpeeding;
      final limit = result.effectiveLimitKmh;
      // Speeding = over limit + 5 km/h tolerance (and limit is not 0/unlimited)
      final nowSpeeding = limit > 0 && speedKmh > limit + 5;

      // Only trigger rebuild if speed limit or speeding state actually changed
      if (_speedLimit.effectiveLimitKmh != limit || _isSpeeding != nowSpeeding) {
        setState(() {
          _speedLimit = result;
          _isSpeeding = nowSpeeding;
        });
      } else {
        _speedLimit = result;
        _isSpeeding = nowSpeeding;
      }

      // Haptic + sound alert on speeding start (throttle to every 10s)
      if (nowSpeeding && !wasSpeeding) {
        final now = DateTime.now();
        if (_lastSpeedingAlert == null ||
            now.difference(_lastSpeedingAlert!) > const Duration(seconds: 10)) {
          _lastSpeedingAlert = now;
          HapticFeedback.heavyImpact();
          // TTS warning
          TtsAlertService.instance.speakText(
            'Achtung! Geschwindigkeitsbegrenzung $limit Kilometer pro Stunde!',
          );
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    // Cancel ALL timers FIRST — prevents setState after dispose
    _headingFollowTimer?.cancel();
    _navPeriodicTimer?.cancel();
    _searchDebounce?.cancel();
    _sosBlinkTimer?.cancel();
    _navUiShowTimer?.cancel();
    _mapIdleTimer?.cancel();
    _wakeWordRestartTimer?.cancel();
    _autoStartTimer?.cancel();
    _stopNavCameraLoop();
    _navEngine.dispose();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _headingGpsSub?.cancel();
    _fusedHeadingSub?.cancel();
    HeadingSensorService.instance.stop();
    _speech.stop();
    VoskWakeWordService.instance.stopListening();
    _blitzerRealtimeChannel?.unsubscribe();

    // Dispose controllers LAST (after all timers cancelled)
    _mapController?.dispose();
    _alertPulseController.dispose();
    _searchController.dispose();
    _overlaySearchCtrl.dispose();
    _panelScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required by AutomaticKeepAliveClientMixin
    final rideState = ref.watch(groupRideProvider(widget.groupId));
    final community = ref.watch(communityProvider);
    final accentColor = community?.accentColor ?? const Color(0xFF4CAF50);
    final group = rideState.group;

    // Handle blitzer removal from other users
    if (rideState.lastRemovedBlitzerId != null) {
      final removedId = rideState.lastRemovedBlitzerId!;
      _nearbyBlitzerReports.removeWhere((r) => r.id == removedId);
    }

    // Pulse alert animation
    if (rideState.currentAlert != null) {
      if (!_alertPulseController.isAnimating) {
        _alertPulseController.repeat(reverse: true);
      }
    } else {
      _alertPulseController.stop();
      _alertPulseController.reset();
    }

    // Loading state
    if (rideState.isConnecting && group == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: accentColor),
              const SizedBox(height: 16),
              const Text('Fahrt wird geladen...',
                  style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      );
    }

    // Error state
    if (rideState.error != null && group == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(rideState.error!,
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.pop(),
                child: const Text('Zurück'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false, // We handle keyboard insets manually in search overlay
      body: Stack(
        children: [
          // ── Layer 1: Google Map ──
          _buildMap(rideState, accentColor),

          // ── Layer 2: Video grid (optional) ──
          if (_showVideoGrid)
            _buildVideoGrid(),

          // ── Layer 3: Top bar (hidden during nav, fades on map interaction) ──
          if (!_navUiHidden)
            _buildTopBar(context, rideState, accentColor),

          // ── Layer 4: Turn instruction banner (fades on map interaction) ──
          if (_isNavigating && _nextTurnStep != null)
            _buildTurnBanner(),

          // ── Layer 5: Blitzer Alert Banner (ALWAYS visible — even during interaction) ──
          if (rideState.currentAlert != null)
            _buildBlitzerBanner(rideState),

          // ── Layer 6: Voice listening overlay ──
          if (_isListening)
            _buildListeningOverlay(),

          // ── Layer 7: Speed display (fades on map interaction) ──
          _buildSpeedDisplay(rideState),

          // ── Layer 8: Bottom controls (fades on map interaction) ──
          _buildBottomControls(rideState, accentColor),

          // ── Layer 9: Route info panel (fades on map interaction) ──
          if (_currentRoute != null)
            _buildRoutePanel(),

          // ── Layer 10: Search overlay (fullscreen from top) ──
          if (_showSearchOverlay)
            _buildSearchOverlay(),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  MAP
  // ═══════════════════════════════════════════════════

  Widget _buildMap(GroupRideState rideState, Color accentColor) {
    final markers = <Marker>{};
    final rideHue = _colorToHue(rideState.group?.rideColor ?? '#4CAF50');
    final groupColorHex = rideState.group?.rideColor;

    // ── Cache polylines (only rebuild when route/alternatives change) ──
    final polylines = _buildCachedPolylines(rideState);

    // Group member markers — profile picture circles with colored borders
    final myUserId = Supabase.instance.client.auth.currentUser?.id;
    LatLng? myPosition;
    for (final entry in rideState.rideMembers.entries) {
      final user = entry.value;

      // Track first/own position for route polyline
      myPosition ??= LatLng(user.lat, user.lng);

      // Skip own marker — replaced by my_vehicle marker with Bike/Car badge
      if (user.userId == myUserId && _navVehicleIcon != null) continue;

      final cacheKey = '${user.userId}_${user.isGroupLeader}';

      // Load profile marker icon async if not cached yet
      if (!_memberMarkerIcons.containsKey(cacheKey) && !_loadingIcons.contains(cacheKey)) {
        _loadingIcons.add(cacheKey);
        _loadMarkerIcon(user, groupColorHex, cacheKey);
      }

      final icon = _memberMarkerIcons[cacheKey]
          ?? BitmapDescriptor.defaultMarkerWithHue(
               user.isGroupLeader ? BitmapDescriptor.hueRed : rideHue,
             );

      // Always use real GPS position — don't snap other users to route
      final userPos = LatLng(user.lat, user.lng);

      markers.add(Marker(
        markerId: MarkerId('ride_${user.userId}'),
        position: userPos,
        infoWindow: InfoWindow(
          title: '${user.isGroupLeader ? '👑 ' : ''}${user.displayName} 🏍️',
          snippet: '${user.speed.round()} km/h',
        ),
        icon: icon,
        zIndex: user.isGroupLeader ? 15 : 10,
        onTap: () => context.push('/profile/${user.userId}'),
      ));
    }

    // ── Vehicle marker on map ──
    if (_currentGpsPos != null && _navVehicleIcon != null) {
      // During nav: use smooth camera position (same as camera target) for perfect sync.
      // The marker must sit exactly where the camera thinks the vehicle is,
      // otherwise it drifts off-center.
      final markerPos = _isNavigating
          ? (_smoothCamPos ?? _snapToRoute(_currentGpsPos!))
          : _currentGpsPos!;
      // During nav: arrow must always point UP on screen (forward direction).
      // flat:true rotation is relative to map-north → compensate for camera bearing.
      // rotation = _smoothBearing makes the arrow point in driving direction on the MAP,
      // and since camera bearing = _smoothBearing, it appears pointing UP on screen.
      final markerHeading = _isNavigating ? _smoothBearing : _currentHeading;
      // During nav: Waze-style arrow; outside nav: avatar icon
      final markerIcon = _isNavigating && _navDotIcon != null
          ? _navDotIcon!
          : _navVehicleIcon!;
      markers.add(Marker(
        markerId: const MarkerId('my_vehicle'),
        position: markerPos,
        icon: markerIcon,
        anchor: const Offset(0.5, 0.5),
        rotation: markerHeading,
        flat: true,
        zIndex: 100,
      ));
    }

    // Destination marker
    final group = rideState.group;
    if (group?.destinationLat != null && group?.destinationLng != null) {
      final destPos = LatLng(group!.destinationLat!, group.destinationLng!);
      markers.add(Marker(
        markerId: const MarkerId('destination'),
        position: destPos,
        infoWindow: InfoWindow(title: group.destinationName ?? 'Ziel'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
        zIndex: 20,
      ));
    }

    // Polylines already built by _buildCachedPolylines above

    // ── POI markers: nearest 5 per category within 5km of current GPS ──
    // As the user drives, markers dynamically appear/disappear around them.
    final gps = _currentGpsPos;
    const proximityRadiusSq = 5000.0 * 5000.0; // 5km² (squared meters)
    const maxVisiblePois = 5;

    if (!_routePois.isEmpty && _currentRoute != null) {
      // Fuel — nearest 5 within 5km
      _addNearestPois(markers, _routePois.fuel, 'fuel', gps,
          proximityRadiusSq, maxVisiblePois, BitmapDescriptor.hueOrange, 'Tankstelle');
      // Biker shops — nearest 5 within 5km
      _addNearestPois(markers, _routePois.bikerShops, 'shop', gps,
          proximityRadiusSq, maxVisiblePois, BitmapDescriptor.hueCyan, 'Bikershop');
      // Workshops — nearest 5 within 5km
      _addNearestPois(markers, _routePois.workshops, 'workshop', gps,
          proximityRadiusSq, maxVisiblePois, BitmapDescriptor.hueYellow, 'Werkstatt');
    }

    // ── Distance-based alpha for blitzer markers ──
    double _blitzerAlpha(LatLng pos) {
      if (gps == null) return 1.0;
      final distM = _distLatLng(gps, pos);
      if (distM <= 5000) return 1.0;       // < 5km: fully visible
      if (distM <= 10000) return 0.6;      // 5-10km: mostly visible
      if (distM <= 20000) return 0.4;      // 10-20km: semi-transparent
      return 0.25;                          // > 20km: faint but visible
    }

    // ── Blitzer markers: OSM route blitzers ──
    for (int i = 0; i < _routeBlitzerPositions.length; i++) {
      final pos = _routeBlitzerPositions[i];
      final alpha = _blitzerAlpha(pos);
      markers.add(Marker(
        markerId: MarkerId('blitzer_$i'),
        position: pos,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: 'Blitzer'),
        alpha: alpha,
        zIndex: alpha >= 1.0 ? 8 : 1,
      ));
    }

    // ── Community blitzer markers from Supabase (custom icons) ──
    for (final report in _nearbyBlitzerReports) {
      final pos = LatLng(report.latitude, report.longitude);
      // Skip if too close to an OSM blitzer (avoid duplicates)
      final isDuplicate = _routeBlitzerPositions.any((rp) =>
        _distLatLng(rp, pos) < 50);
      if (isDuplicate) continue;
      final alpha = _blitzerAlpha(pos);
      // Use cached custom icon if available, otherwise default
      final cacheKey = '${report.type}_a${(alpha * 10).round()}';
      final customIcon = _blitzerIconCache[cacheKey];
      markers.add(Marker(
        markerId: MarkerId('community_blitzer_${report.id}'),
        position: pos,
        icon: customIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        alpha: alpha,
        zIndex: alpha >= 1.0 ? 8 : 2,
        onTap: () => _showBlitzerDetail(report),
      ));
    }

    // Start on user's GPS position, fallback Germany center
    final startPos = _initialPosition ?? const LatLng(51.16, 10.45);
    final startZoom = _initialPosition != null ? 15.0 : 6.0;

    return Listener(
      onPointerDown: (_) => _userTouchingMap = true,
      onPointerUp: (_) {
        // Small delay so onCameraMoveStarted fires while flag is still true
        Future.delayed(const Duration(milliseconds: 300), () {
          _userTouchingMap = false;
        });
      },
      onPointerCancel: (_) {
        Future.delayed(const Duration(milliseconds: 300), () {
          _userTouchingMap = false;
        });
      },
      child: GoogleMap(
      initialCameraPosition: gmaps.CameraPosition(
        target: startPos,
        zoom: startZoom,
        tilt: 0,
        bearing: 0,
      ),
      markers: markers,
      polylines: polylines,
      myLocationEnabled: false, // Replaced by my_vehicle marker
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: true,
      mapToolbarEnabled: false,
      mapType: MapType.normal,
      // During navigation: top padding pushes logical center down → rider at bottom
      padding: _isNavigating
          ? EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.45)
          : EdgeInsets.zero,
      style: _darkMapStyle,
      onMapCreated: (controller) {
        _mapController = controller;
        _centerOnGroup(rideState);
      },
      // Detect user panning/zooming → pause auto-follow + hide UI
      onCameraMoveStarted: () {
        // Only react to user finger touches — not programmatic animateCamera
        if (_userTouchingMap) {
          if (_isNavFollowing) setState(() => _isNavFollowing = false);
          _mapIdleTimer?.cancel();
          if (!_mapInteracting) setState(() => _mapInteracting = true);
        }
      },
      onCameraMove: (pos) {
        _currentZoom = pos.zoom; // Track zoom so we preserve it
        _mapIdleTimer?.cancel();
      },
      // Camera stopped moving → show UI again (debounced)
      onCameraIdle: () {
        _mapIdleTimer?.cancel();
        _mapIdleTimer = Timer(const Duration(milliseconds: 400), () {
          if (mounted && _mapInteracting) setState(() => _mapInteracting = false);
        });
      },
      // Tap map during navigation → toggle UI visibility (don't disable follow!)
      onTap: (_) {
        if (_isNavigating) {
          if (_navUiHidden) {
            _showNavUiTemporarily();
          } else {
            setState(() => _navUiHidden = true);
          }
          return;
        }
      },
    ),
    ); // end Listener
  }

  /// Fixed navigation icon overlay — stays at a fixed screen position (like Waze/Google Maps).
  /// The map moves underneath, the icon never jitters.
  Widget _buildFixedNavIcon() {
    final modeColor = _routeMode == RouteMode.biker
        ? const Color(0xFF00BCD4)
        : _routeMode == RouteMode.pedestrian
            ? const Color(0xFF4CAF50)
            : const Color(0xFF2196F3);

    return Positioned(
      // Position near bottom edge to match 200m camera offset
      bottom: MediaQuery.of(context).size.height * 0.12,
      left: 0,
      right: 0,
      child: Center(
        child: IgnorePointer(
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: modeColor,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: modeColor.withValues(alpha: 0.4),
                  blurRadius: 10,
                  spreadRadius: 4,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build polylines with caching — only rebuild when route/alternatives change.
  Set<Polyline> _buildCachedPolylines(GroupRideState rideState) {
    // Return cache if route hasn't changed — but NOT during navigation
    // (polyline is trimmed dynamically as user moves along route)
    if (!_isNavigating &&
        _cachedPolylines != null &&
        _cachedPolylineRoute == _currentRoute &&
        _cachedPolylineAltCount == _alternativeRoutes.length) {
      return _cachedPolylines!;
    }

    final polylines = <Polyline>{};
    const routeCyan = Color(0xFF00BCD4);

    // Alternative routes (grey, behind primary)
    for (var i = 0; i < _alternativeRoutes.length; i++) {
      if (i == _selectedRouteIndex) continue;
      final altRoute = _alternativeRoutes[i];
      if (altRoute.polylinePoints.length >= 2) {
        polylines.add(Polyline(
          polylineId: PolylineId('alt_route_$i'),
          points: altRoute.polylinePoints,
          color: Colors.white.withValues(alpha: 0.25),
          width: 5,
          zIndex: 1,
        ));
      }
    }

    // Primary route (Waze-style: Cyan, dashed)
    // During navigation: trim polyline to only show route AHEAD of icon
    if (_currentRoute != null && _currentRoute!.polylinePoints.length >= 2) {
      List<LatLng> routePoints = _currentRoute!.polylinePoints;

      // Waze-style: route disappears behind the icon
      if (_isNavigating && _smoothCamPos != null) {
        final segIdx = _lastSnapSegIdx.clamp(0, routePoints.length - 2);
        // Start from current segment + snapped position
        routePoints = [_smoothCamPos!, ...routePoints.sublist(segIdx + 1)];
      }

      polylines.add(Polyline(
        polylineId: const PolylineId('route_shadow'),
        points: routePoints,
        color: const Color(0xFF004D57),
        width: 12,
        zIndex: 2,
        patterns: [PatternItem.dash(40), PatternItem.gap(15)],
      ));
      polylines.add(Polyline(
        polylineId: const PolylineId('route'),
        points: routePoints,
        color: routeCyan,
        width: 7,
        zIndex: 3,
        patterns: [PatternItem.dash(40), PatternItem.gap(15)],
      ));
    } else {
      final group = rideState.group;
      if (group?.destinationLat != null && group?.destinationLng != null) {
        final destPos = LatLng(group!.destinationLat!, group.destinationLng!);
        final routeStart = _currentGpsPos ?? _initialPosition;
        if (routeStart != null) {
          polylines.add(Polyline(
            polylineId: const PolylineId('route'),
            points: [routeStart, destPos],
            color: routeCyan.withValues(alpha: 0.5),
            width: 4,
            patterns: [PatternItem.dash(20), PatternItem.gap(10)],
          ));
        }
      }
    }

    _cachedPolylines = polylines;
    _cachedPolylineRoute = _currentRoute;
    _cachedPolylineAltCount = _alternativeRoutes.length;
    return polylines;
  }

  /// Async load a profile picture marker icon for a ride member.
  /// During navigation, defers setState to avoid expensive rebuilds — the next
  /// throttled GPS-tick setState will pick up the new icon.
  Future<void> _loadMarkerIcon(LiveUserPosition user, String? groupColorHex, String cacheKey) async {
    try {
      final BitmapDescriptor icon;
      if (user.isGroupLeader) {
        icon = await MarkerIconService.instance.getLeaderMarker(
          avatarUrl: user.avatarUrl,
          displayName: user.displayName,
        );
      } else {
        icon = await MarkerIconService.instance.getLiveUserMarker(
          avatarUrl: user.avatarUrl,
          displayName: user.displayName,
          groupColorHex: groupColorHex,
        );
      }
      if (mounted) {
        _memberMarkerIcons[cacheKey] = icon;
        _loadingIcons.remove(cacheKey);
        // During navigation, skip setState — next GPS-tick rebuild picks it up.
        // Otherwise trigger immediate rebuild for visible marker.
        if (!_isNavigating) {
          setState(() {});
        }
      }
    } catch (e) {
      debugPrint('[GroupRide] Marker icon error for ${user.displayName}: $e');
      _loadingIcons.remove(cacheKey);
    }
  }

  void _centerOnGroup(GroupRideState rideState) {
    if (_hasCenteredOnce && rideState.rideMembers.isEmpty) return;

    _isProgrammaticMove = true;

    // If no ride members yet, center on user GPS position
    if (rideState.rideMembers.isEmpty) {
      if (_initialPosition != null && !_hasCenteredOnce) {
        _hasCenteredOnce = true;
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(
          _initialPosition!, 14,
        )).then((_) => _isProgrammaticMove = false);
      } else {
        _isProgrammaticMove = false;
      }
      return;
    }

    _hasCenteredOnce = true;
    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (final user in rideState.rideMembers.values) {
      if (user.lat < minLat) minLat = user.lat;
      if (user.lat > maxLat) maxLat = user.lat;
      if (user.lng < minLng) minLng = user.lng;
      if (user.lng > maxLng) maxLng = user.lng;
    }

    final group = rideState.group;
    if (group?.destinationLat != null) {
      if (group!.destinationLat! < minLat) minLat = group.destinationLat!;
      if (group.destinationLat! > maxLat) maxLat = group.destinationLat!;
      if (group.destinationLng! < minLng) minLng = group.destinationLng!;
      if (group.destinationLng! > maxLng) maxLng = group.destinationLng!;
    }

    if (minLat == maxLat && minLng == maxLng) {
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(
        LatLng(minLat, minLng), 14,
      )).then((_) => _isProgrammaticMove = false);
    } else {
      _mapController?.animateCamera(CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        80,
      )).then((_) => _isProgrammaticMove = false);
    }
  }

  // ═══════════════════════════════════════════════════
  //  TOP BAR
  // ═══════════════════════════════════════════════════

  Widget _buildTopBar(BuildContext context, GroupRideState rideState, Color accentColor) {
    final group = rideState.group;

    return Positioned(
      top: 0, left: 0, right: 0,
      child: AnimatedOpacity(
        opacity: _mapInteracting ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(
          ignoring: _mapInteracting,
          child: SafeArea(
            bottom: false,
            child: Column(
          children: [
            // ── Waze-style search bar with group info ──
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xF01B1F2B),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Back button
                  IconButton(
                    onPressed: () => _showLeaveDialog(context),
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70, size: 22),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),

                  // Search trigger — opens Waze-style search sheet
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showSearchSheet(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                        child: Text(
                          'Wohin?',
                          style: GoogleFonts.inter(color: Colors.white30, fontSize: 15),
                        ),
                      ),
                    ),
                  ),

                  // Group info pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people_rounded, color: accentColor, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '${rideState.rideMembers.length}',
                          style: GoogleFonts.inter(color: accentColor, fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),

                  // Center on GPS / group
                  IconButton(
                    onPressed: () {
                      if (_currentGpsPos != null && _mapController != null) {
                        _mapController!.animateCamera(
                          CameraUpdate.newCameraPosition(
                            gmaps.CameraPosition(
                              target: _currentGpsPos!,
                              zoom: 15.0,
                              tilt: 0,
                              bearing: 0,
                            ),
                          ),
                        );
                      } else {
                        _centerOnGroup(rideState);
                      }
                    },
                    icon: Icon(
                      Icons.my_location_rounded,
                      color: _currentGpsPos != null ? Colors.blueAccent : Colors.white54,
                      size: 22,
                    ),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),

            // ── Destination card (wenn Ziel gesetzt) ──
            if (group?.destinationLat != null)
              _buildDestinationCard(rideState, accentColor),

            // ── Leader distance warning (wenn > 500m) ──
            if (rideState.distanceToLeader != null && rideState.distanceToLeader! > 500)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: rideState.distanceToLeader! > 1000
                      ? Colors.red.shade900.withValues(alpha: 0.9)
                      : Colors.orange.shade900.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Text('👑', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Text(
                      'Leader: ${rideState.distanceToLeader! >= 1000 ? '${(rideState.distanceToLeader! / 1000).toStringAsFixed(1)} km' : '${rideState.distanceToLeader!.round()} m'}',
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _centerOnGroup(rideState),
                      child: Text('Zeigen', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
        ),
      ),
    );
  }

  Widget _buildDestinationCard(GroupRideState rideState, Color accentColor) {
    final group = rideState.group!;
    final route = _currentRoute;

    String distText = '';
    String? durationText;
    if (route != null) {
      distText = route.distanceText;
      durationText = route.durationText;
    } else {
      final dist = rideState.distanceToDestination;
      if (dist != null) {
        distText = dist < 1000 ? '${dist.round()} m' : '${(dist / 1000).toStringAsFixed(1)} km';
      }
    }

    return GestureDetector(
      onTap: () => _showRoutePreviewSheet(),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xF0232839),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8)],
        ),
        child: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF00BCD4).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _isCalculatingRoute
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00BCD4)))
                  : const Icon(Icons.flag_rounded, color: Color(0xFF00BCD4), size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(group.destinationName ?? 'Ziel',
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  Row(children: [
                    if (distText.isNotEmpty)
                      Text(distText, style: GoogleFonts.inter(color: const Color(0xFF00BCD4), fontSize: 12, fontWeight: FontWeight.w700)),
                    if (durationText != null) ...[
                      Text(' · ', style: GoogleFonts.inter(color: Colors.white30, fontSize: 12)),
                      Text(durationText, style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                    Text('  ${_routeMode == RouteMode.biker ? '🏍' : _routeMode == RouteMode.pedestrian ? '🚶' : '🚗'}', style: const TextStyle(fontSize: 11)),
                  ]),
                ],
              ),
            ),
            const Icon(Icons.expand_more_rounded, color: Colors.white30, size: 22),
          ],
        ),
      ),
    );
  }

  /// Search for a destination and set it for the group ride.
  Future<void> _searchDestination(String query) async {
    Position? currentPos;
    try {
      currentPos = await Geolocator.getLastKnownPosition();
    } catch (_) {}

    final geocoding = GeocodingService();
    List<GeocodingResult> results;
    try {
      results = await geocoding.searchPlace(
        query,
        limit: 5,
        near: currentPos != null
            ? LatLng(currentPos.latitude, currentPos.longitude)
            : null,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Suche fehlgeschlagen: $e')),
        );
      }
      return;
    }

    if (!mounted) return;
    if (results.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kein Ergebnis gefunden')),
      );
      return;
    }

    // Show results in bottom sheet
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Ziel wählen',
                style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            ...results.map((r) {
              final name = r.name ?? r.displayName;
              final subtitle = r.city ?? r.state ?? '';
              return ListTile(
                leading: const Icon(Icons.place_rounded, color: Colors.blue),
                title: Text(name, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: subtitle.isNotEmpty
                    ? Text(subtitle, style: GoogleFonts.inter(color: Colors.white54, fontSize: 12))
                    : null,
                onTap: () {
                  Navigator.of(ctx).pop();
                  _setDestination(r);
                },
              );
            }),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  /// Set the chosen destination for the group ride.
  Future<void> _setDestination(GeocodingResult result) async {
    // Build display name: "Straße Hausnummer" (German format)
    // If Nominatim doesn't return houseNumber, try extracting from displayName
    String name;
    if (result.road != null && result.houseNumber != null) {
      name = '${result.road} ${result.houseNumber}';
    } else if (result.road != null) {
      // Try to find house number from displayName (format: "1-5, Ahrstraße, ...")
      final dn = result.displayName;
      final hnMatch = RegExp(r'(\d+[\w-]*),\s*' + RegExp.escape(result.road!)).firstMatch(dn);
      if (hnMatch != null) {
        name = '${result.road} ${hnMatch.group(1)}';
      } else {
        name = result.shortName;
      }
    } else {
      name = result.shortName;
    }
    final lat = result.location.latitude;
    final lng = result.location.longitude;

    // Send to group chat
    ref.read(groupRideProvider(widget.groupId).notifier).sendMessage(
      '🏁 Neues Ziel: $name',
    );

    // Update destination in DB (use repository directly)
    try {
      final repo = ref.read(groupRepositoryProvider);
      await repo.setDestination(widget.groupId, lat: lat, lng: lng, name: name);
    } catch (e) {
      debugPrint('[GroupRide] Set destination error: $e');
    }

    _searchController.clear();
    if (mounted) FocusScope.of(context).unfocus();

    // Save to search history
    final subtitle = result.city ?? result.state ?? '';
    _saveSearchHistory(name, subtitle, lat, lng);

    // Make name TTS-friendly: "1-5" → "1 bis 5"
    final ttsName = name.replaceAllMapped(
      RegExp(r'(\d+)\s*-\s*(\d+)'), (m) => '${m.group(1)} bis ${m.group(2)}');
    final ttsParts = <String>[ttsName];
    if (result.city != null && result.city!.isNotEmpty && !name.contains(result.city!)) {
      ttsParts.add(result.city!);
    }
    // Skip country for domestic destinations (always "Deutschland" → useless)
    // Only add country if it's NOT Germany
    if (result.country != null && result.country!.isNotEmpty &&
        !result.country!.toLowerCase().contains('deutsch') &&
        result.country!.toLowerCase() != 'germany') {
      ttsParts.add(result.country!);
    }
    final ttsText = 'Neues Ziel: ${ttsParts.join(', ')}';
    TtsAlertService.instance.speakText(ttsText);
    _lastDestinationName = name;

    // Calculate OSRM route
    _calculateRoute(LatLng(lat, lng));
  }

  // ═══════════════════════════════════════════════════
  //  WAZE-STYLE SEARCH SHEET
  // ═══════════════════════════════════════════════════

  void _showSearchSheet() {
    _overlaySearchCtrl.clear();
    setState(() {
      _showSearchOverlay = true;
      _searchResults = null;
      _isSearching = false;
    });
  }

  void _closeSearchOverlay() {
    _searchDebounce?.cancel();
    _overlaySearchCtrl.clear();
    FocusScope.of(context).unfocus();
    setState(() {
      _showSearchOverlay = false;
      _searchResults = null;
      _isSearching = false;
    });
  }

  void _onSearchChanged(String q) {
    _searchDebounce?.cancel();
    if (q.trim().length < 2) {
      setState(() { _searchResults = null; _isSearching = false; });
      return;
    }
    setState(() => _isSearching = true);
    _searchDebounce = Timer(const Duration(milliseconds: 500), () async {
      final results = await _geocodeQuery(q.trim());
      if (mounted) setState(() { _searchResults = results; _isSearching = false; });
    });
  }

  Widget _buildSearchOverlay() {
    final topPad = MediaQuery.of(context).padding.top;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Positioned.fill(
      child: GestureDetector(
        onTap: _closeSearchOverlay,
        child: Container(
          color: const Color(0xFF111520),
          child: GestureDetector(
            onTap: () {}, // absorb taps on content
            child: Padding(
              padding: EdgeInsets.only(top: topPad, bottom: keyboardHeight),
              child: Column(
                children: [
                  // ── Search bar row ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D3446),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: _closeSearchOverlay,
                            child: const Icon(Icons.arrow_back_rounded, color: Colors.white54, size: 22),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _overlaySearchCtrl,
                              autofocus: true,
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
                              decoration: InputDecoration(
                                hintText: 'Wohin?',
                                hintStyle: GoogleFonts.inter(color: Colors.white30, fontSize: 16),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              textInputAction: TextInputAction.search,
                              onChanged: _onSearchChanged,
                              onSubmitted: (q) {
                                if (q.trim().isEmpty) return;
                                _searchDebounce?.cancel();
                                setState(() => _isSearching = true);
                                _geocodeQuery(q.trim()).then((results) {
                                  if (mounted) setState(() { _searchResults = results; _isSearching = false; });
                                });
                              },
                            ),
                          ),
                          if (_isSearching)
                            const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00BCD4)))
                          else
                            GestureDetector(
                              onTap: () {
                                _closeSearchOverlay();
                                _startVoiceQuery();
                              },
                              child: const Icon(Icons.mic_rounded, color: Colors.white38, size: 24),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // ── Scrollable content (quick buttons + results/history) ──
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        // Quick buttons (inside scroll so they never overflow)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: Row(
                            children: [
                              _quickPlaceButton(context, Icons.home_rounded, 'Nach Hause', 'nav_home'),
                              const SizedBox(width: 10),
                              _quickPlaceButton(context, Icons.work_rounded, 'Zur Arbeit', 'nav_work'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Search results
                        if (_searchResults != null && _searchResults!.isNotEmpty)
                          ..._searchResults!.map((r) {
                            // Build display name: "Straße Hausnummer" (German format)
                            String name;
                            if (r.road != null && r.houseNumber != null) {
                              name = '${r.road} ${r.houseNumber}';
                            } else if (r.name != null && r.name!.isNotEmpty) {
                              // If name looks like "42 Ahrstraße" (number first), flip it
                              final match = RegExp(r'^(\d+\w?)\s+(.+)$').firstMatch(r.name!);
                              if (match != null && r.road != null) {
                                name = '${r.road} ${match.group(1)}';
                              } else {
                                name = r.name!;
                              }
                            } else {
                              name = r.road ?? r.displayName;
                            }
                            // Build rich subtitle: city, state — from displayName as fallback
                            final parts = <String>[];
                            if (r.city != null && r.city!.isNotEmpty) parts.add(r.city!);
                            if (r.state != null && r.state!.isNotEmpty && r.state != r.city) parts.add(r.state!);
                            // If no city/state, extract from displayName (comma-separated)
                            if (parts.isEmpty && r.displayName.contains(',')) {
                              final segments = r.displayName.split(',').map((s) => s.trim()).toList();
                              // Skip first segment (usually the name itself), take next 2
                              for (int i = 1; i < segments.length && parts.length < 2; i++) {
                                if (segments[i].isNotEmpty && segments[i] != name) {
                                  parts.add(segments[i]);
                                }
                              }
                            }
                            final sub = parts.join(', ');
                            return ListTile(
                              leading: Icon(r.typeIcon, color: const Color(0xFF00BCD4)),
                              title: Text(name, style: GoogleFonts.inter(
                                color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: sub.isNotEmpty
                                  ? Text(sub, style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                                      maxLines: 1, overflow: TextOverflow.ellipsis)
                                  : null,
                              onTap: () {
                                _closeSearchOverlay();
                                _setDestination(r);
                              },
                            );
                          })
                        else if (_searchResults != null && _searchResults!.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text('Keine Ergebnisse',
                              style: GoogleFonts.inter(color: Colors.white38, fontSize: 14)),
                          )
                        else ...[
                          // History
                          if (_searchHistory.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.only(left: 16, bottom: 4),
                              child: Text('Letzte Ziele',
                                style: GoogleFonts.inter(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                            ..._searchHistory.map((entry) => ListTile(
                              leading: const Icon(Icons.history_rounded, color: Colors.white30),
                              title: Text(entry['name'] ?? '',
                                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                              subtitle: entry['subtitle']?.isNotEmpty == true
                                  ? Text(entry['subtitle']!, style: GoogleFonts.inter(color: Colors.white54, fontSize: 12))
                                  : null,
                              onTap: () {
                                _closeSearchOverlay();
                                final lat = double.tryParse(entry['lat'] ?? '');
                                final lng = double.tryParse(entry['lng'] ?? '');
                                if (lat != null && lng != null) {
                                  _setDestinationDirect(entry['name'] ?? 'Ziel', lat, lng);
                                }
                              },
                            )),
                          ] else
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  const Icon(Icons.explore_rounded, color: Colors.white24, size: 40),
                                  const SizedBox(height: 8),
                                  Text('Gib ein Ziel ein oder nutze die Sprachsuche',
                                    style: GoogleFonts.inter(color: Colors.white30, fontSize: 13),
                                    textAlign: TextAlign.center),
                                ],
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _quickPlaceButton(BuildContext sheetCtx, IconData icon, String label, String prefKey) {
    return Expanded(
      child: GestureDetector(
        onTap: () async {
          final prefs = await SharedPreferences.getInstance();
          final saved = prefs.getString(prefKey);
          if (saved != null) {
            final parts = saved.split('|');
            if (parts.length >= 3) {
              _closeSearchOverlay();
              final lat = double.tryParse(parts[1]);
              final lng = double.tryParse(parts[2]);
              if (lat != null && lng != null) {
                _setDestinationDirect(parts[0], lat, lng);
              }
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$label noch nicht gespeichert (lang drücken zum Speichern)')),
            );
          }
        },
        onLongPress: () async {
          // Long press to save current position as home/work
          final pos = _currentGpsPos;
          if (pos == null) return;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(prefKey, '$label|${pos.latitude}|${pos.longitude}');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$label gespeichert! (aktuelle Position)')),
            );
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF2D3446),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white54, size: 18),
              const SizedBox(width: 6),
              Flexible(child: Text(label, style: GoogleFonts.inter(
                color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      ),
    );
  }

  Future<List<GeocodingResult>> _geocodeQuery(String query) async {
    Position? currentPos;
    try { currentPos = await Geolocator.getLastKnownPosition(); } catch (_) {}
    // Prefer _currentGpsPos (always available during ride) over Geolocator
    final nearPos = _currentGpsPos != null
        ? LatLng(_currentGpsPos!.latitude, _currentGpsPos!.longitude)
        : (currentPos != null ? LatLng(currentPos.latitude, currentPos.longitude) : null);
    try {
      return await GeocodingService().searchPlace(
        query, limit: 5,
        near: nearPos,
      );
    } catch (_) {
      return [];
    }
  }

  // ─────────────────────────────────────────────────
  //  VOICE ADDRESS CLEANING (Vosk garbled speech)
  // ─────────────────────────────────────────────────

  /// German number words → digits. Vosk transcribes "1" as "eins", "2" as "zwei" etc.
  static const _numberWords = {
    'eins': '1', 'zwei': '2', 'drei': '3', 'vier': '4', 'fünf': '5',
    'sechs': '6', 'sieben': '7', 'acht': '8', 'neun': '9', 'zehn': '10',
    'elf': '11', 'zwölf': '12', 'dreizehn': '13', 'vierzehn': '14',
    'fünfzehn': '15', 'sechzehn': '16', 'siebzehn': '17', 'achtzehn': '18',
    'neunzehn': '19', 'zwanzig': '20',
    // Common compounds
    'einundzwanzig': '21', 'zweiundzwanzig': '22', 'dreißig': '30',
    'vierzig': '40', 'fünfzig': '50', 'sechzig': '60', 'siebzig': '70',
    'achtzig': '80', 'neunzig': '90', 'hundert': '100',
  };

  /// Clean Vosk-garbled address text for geocoding.
  /// "a straße eins in solingen" → "astraße 1 in solingen"
  String _cleanVoskAddress(String address) {
    var result = address.trim();

    // 1. Number words → digits
    for (final entry in _numberWords.entries) {
      result = result.replaceAll(RegExp('\\b${entry.key}\\b', caseSensitive: false), entry.value);
    }

    // 2. Common Vosk misheard street suffixes
    result = result
        .replaceAll(RegExp(r'\bstra(?:ß|ss)e\b', caseSensitive: false), 'straße')
        .replaceAll(RegExp(r'\bstrasse\b', caseSensitive: false), 'straße')
        .replaceAll(RegExp(r'\bstr\b', caseSensitive: false), 'straße');

    // 3. Remove filler words/articles that Vosk adds (but keep "in" for city extraction)
    result = result
        .replaceAll(RegExp(r'\bdie\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bder\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bdas\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bzum\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bzur\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bnach\b', caseSensitive: false), '');

    // 4. Clean up multiple spaces
    result = result.replaceAll(RegExp(r'\s+'), ' ').trim();

    return result;
  }

  /// Common Vosk single-letter misheard → actual street prefix expansions.
  /// Vosk often hears only the first syllable or letter of a street name.
  static const _streetPrefixExpansions = <String, List<String>>{
    'a': ['ahr', 'alt', 'am', 'an', 'au'],
    'b': ['berg', 'bahn', 'bach', 'bir', 'burg'],
    'e': ['eich', 'erlen', 'essen'],
    'ha': ['haupt', 'hagen', 'hammer'],
    'ho': ['hoch', 'holz'],
    'k': ['karl', 'kaiser', 'kirch', 'köln'],
    'l': ['lang', 'linden'],
    'm': ['markt', 'main', 'mühlen'],
    'r': ['rhein', 'ring', 'rot'],
    's': ['schiller', 'schul'],
    'w': ['wald', 'wasser', 'wil'],
  };

  /// Join short word prefix to "straße" — "a straße" → "astraße", "ahr straße" → "ahrstraße"
  String _joinStreetPrefix(String address) {
    // Match: [short word(s)] + straße/str/strasse
    final match = RegExp(r'^(\S{1,4})\s+(straße|strasse|str)\b(.*)$', caseSensitive: false).firstMatch(address);
    if (match != null) {
      return '${match.group(1)}${match.group(2)}${match.group(3)}'.trim();
    }
    return address;
  }

  /// Try expanding a single-letter street prefix into common German street names.
  /// "a straße 1, solingen" → ["ahrstraße 1, solingen", "altstraße 1, solingen", ...]
  List<String> _expandStreetPrefix(String address) {
    final variants = <String>[];
    final match = RegExp(r'^(\S{1,2})\s*(straße|strasse)\b(.*)$', caseSensitive: false).firstMatch(address);
    if (match != null) {
      final prefix = match.group(1)!.toLowerCase();
      final suffix = match.group(2)!;
      final rest = match.group(3)!;
      final expansions = _streetPrefixExpansions[prefix];
      if (expansions != null) {
        for (final exp in expansions) {
          variants.add('$exp$suffix$rest'.trim());
        }
      }
    }
    return variants;
  }

  /// Extract city from "in [city]" and format as "street, city" for Nominatim.
  /// "astraße 1 in solingen" → "astraße 1, solingen"
  String? _structureAddress(String address) {
    final inMatch = RegExp(r'^(.+?)\s+in\s+(\S.+)$', caseSensitive: false).firstMatch(address);
    if (inMatch != null) {
      final street = inMatch.group(1)!.trim();
      final city = inMatch.group(2)!.trim();
      if (street.isNotEmpty && city.isNotEmpty) {
        return '$street, $city';
      }
    }
    return null;
  }

  /// Google Places text search fallback.
  Future<List<GeocodingResult>> _googlePlacesSearch(String query) async {
    try {
      final loc = _currentGpsPos!;
      final resp = await http.get(Uri.parse(
        'https://maps.googleapis.com/maps/api/place/textsearch/json'
        '?query=${Uri.encodeComponent(query)}'
        '&location=${loc.latitude},${loc.longitude}'
        '&radius=50000&language=de'
        '&key=${DestinationInfoService.googleApiKey}',
      )).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        debugPrint('[VoiceNav] Google status: ${json['status']}');
        final gResults = json['results'] as List? ?? [];
        if (gResults.isNotEmpty) {
          final first = gResults[0] as Map<String, dynamic>;
          final loc = (first['geometry'] as Map?)?['location'] as Map?;
          if (loc != null) {
            final gLat = (loc['lat'] as num).toDouble();
            final gLng = (loc['lng'] as num).toDouble();
            final gName = first['name'] as String? ?? query;
            debugPrint('[VoiceNav] Google found: $gName ($gLat, $gLng)');
            return [GeocodingResult(displayName: gName, location: LatLng(gLat, gLng))];
          }
        }
      }
    } catch (e) {
      debugPrint('[VoiceNav] Google error: $e');
    }
    return [];
  }

  /// Extract street part and city from garbled Vosk address.
  /// Takes the first word(s) containing "straße/str" as street, last word as city.
  /// "a straße allen sinnen solingen" → ("a straße", "solingen")
  /// "ahrstraße 1, solingen" → ("ahrstraße 1", "solingen")
  (String, String)? _extractStreetAndCity(String address) {
    final words = address.replaceAll(',', ' ').split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length < 2) return null;

    // City = last word (Vosk almost always gets the city right)
    final city = words.last;

    // Find street part: everything up to and including "straße" + optional number
    int streetEnd = -1;
    for (int i = 0; i < words.length; i++) {
      if (words[i].toLowerCase().contains('straße') || words[i].toLowerCase().contains('strasse') ||
          words[i].toLowerCase().contains('str') || words[i].toLowerCase().contains('weg') ||
          words[i].toLowerCase().contains('platz') || words[i].toLowerCase().contains('gasse') ||
          words[i].toLowerCase().contains('allee') || words[i].toLowerCase().contains('ring') ||
          words[i].toLowerCase().contains('damm')) {
        streetEnd = i;
        // Include number after street if it's a digit
        if (i + 1 < words.length && RegExp(r'^\d+[a-z]?$').hasMatch(words[i + 1])) {
          streetEnd = i + 1;
        }
        break;
      }
    }

    if (streetEnd >= 0) {
      final street = words.sublist(0, streetEnd + 1).join(' ');
      if (street.isNotEmpty && city.isNotEmpty && street.toLowerCase() != city.toLowerCase()) {
        return (street, city);
      }
    }

    // Fallback: first word(s) = street, last word = city
    if (words.length >= 3) {
      // Take first 1-2 words as street
      final street = words.length > 3 ? words.sublist(0, 2).join(' ') : words.first;
      if (street.toLowerCase() != city.toLowerCase()) {
        return (street, city);
      }
    }

    return null;
  }

  /// Set destination directly from lat/lng (from history or favorites).
  Future<void> _setDestinationDirect(String name, double lat, double lng) async {
    ref.read(groupRideProvider(widget.groupId).notifier).sendMessage('Neues Ziel: $name');
    try {
      final repo = ref.read(groupRepositoryProvider);
      await repo.setDestination(widget.groupId, lat: lat, lng: lng, name: name);
    } catch (e) {
      debugPrint('[GroupRide] Set destination error: $e');
    }
    // Try to get country name for TTS
    String ttsText = 'Neues Ziel: $name';
    try {
      final countryCode = await GeocodingService().reverseGeocodeCountryCode(lat, lng);
      if (countryCode != null) {
        final countryName = _countryCodeToName(countryCode);
        if (countryName != null) ttsText = 'Neues Ziel: $name, $countryName';
      }
    } catch (_) {}
    TtsAlertService.instance.speakText(ttsText);
    _lastDestinationName = name;
    _calculateRoute(LatLng(lat, lng));
  }

  /// Navigate to an address spoken by the user via voice command.
  /// Geocodes the address, calculates route directly using OSRM, and auto-starts navigation.
  Future<void> _navigateToAddress(String address) async {
    try {
      debugPrint('[VoiceNav] Starting navigation to: "$address"');

      // ── Clean up Vosk-garbled speech ──
      final cleaned = _cleanVoskAddress(address);
      debugPrint('[VoiceNav] Cleaned address: "$cleaned"');

      // 1. Geocode — try multiple strategies for voice-garbled text
      var results = await _geocodeQuery(cleaned);
      debugPrint('[VoiceNav] Strategy 1 (cleaned): ${results.length} results');

      // Strategy 2: Join short prefix to "straße" — "a straße" → "astraße"
      if (results.isEmpty) {
        final joinedAddr = _joinStreetPrefix(cleaned);
        if (joinedAddr != cleaned) {
          debugPrint('[VoiceNav] Strategy 2 (joined): "$joinedAddr"');
          results = await _geocodeQuery(joinedAddr);
        }
      }

      // Strategy 3: Extract city after "in" and format as "street, city"
      if (results.isEmpty) {
        final structured = _structureAddress(cleaned);
        if (structured != null && structured != cleaned) {
          debugPrint('[VoiceNav] Strategy 3 (structured): "$structured"');
          results = await _geocodeQuery(structured);
        }
      }

      // Strategy 4: Join prefix + structured
      if (results.isEmpty) {
        final joined = _joinStreetPrefix(cleaned);
        final structured = _structureAddress(joined);
        if (structured != null) {
          debugPrint('[VoiceNav] Strategy 4 (joined+structured): "$structured"');
          results = await _geocodeQuery(structured);
        }
      }

      // Strategy 5: Expand prefix + ONLY street + city (drop noise between)
      // "a straße allen sinnen solingen" → try "ahrstraße, solingen" etc.
      if (results.isEmpty) {
        final streetCity = _extractStreetAndCity(cleaned);
        if (streetCity != null) {
          final (street, city) = streetCity;
          // Try joining prefix to street first
          final joinedStreet = _joinStreetPrefix(street);
          // Try expansions with just street + city
          final expansions = _expandStreetPrefix('$joinedStreet, $city');
          for (final expanded in expansions) {
            debugPrint('[VoiceNav] Strategy 5a (expand+city): "$expanded"');
            results = await _geocodeQuery(expanded);
            if (results.isNotEmpty) break;
          }
          // Also try joined street + city without expansion
          if (results.isEmpty && joinedStreet != street) {
            final simple = '$joinedStreet, $city';
            debugPrint('[VoiceNav] Strategy 5b (joined+city): "$simple"');
            results = await _geocodeQuery(simple);
          }
        }
        // Fallback: try expansions on full cleaned text
        if (results.isEmpty) {
          final base = _joinStreetPrefix(cleaned);
          final expansions = _expandStreetPrefix(base);
          for (final expanded in expansions) {
            debugPrint('[VoiceNav] Strategy 5c (expand full): "$expanded"');
            results = await _geocodeQuery(expanded);
            if (results.isNotEmpty) break;
          }
        }
      }

      // Strategy 6: Original unmodified input
      if (results.isEmpty && cleaned != address) {
        debugPrint('[VoiceNav] Strategy 6 (original): "$address"');
        results = await _geocodeQuery(address);
      }

      // Strategy 7: Google Places text search as ultimate fallback
      if (results.isEmpty && _currentGpsPos != null) {
        // Try simplified street + city for better Google results
        final streetCity = _extractStreetAndCity(cleaned);
        final googleQuery = streetCity != null
            ? '${_joinStreetPrefix(streetCity.$1)}, ${streetCity.$2}'
            : (_structureAddress(cleaned) ?? cleaned);
        debugPrint('[VoiceNav] Strategy 7 (Google Places): "$googleQuery"');
        results = await _googlePlacesSearch(googleQuery);
      }

      if (results.isEmpty) {
        debugPrint('[VoiceNav] All geocoding failed for: "$address" / "$cleaned"');
        _speakWithVoskPause('Adresse $address nicht gefunden.');
        return;
      }
      final best = results.first;
      final destLat = best.location.latitude;
      final destLng = best.location.longitude;
      debugPrint('[VoiceNav] Geocoded to: ${best.displayName} ($destLat, $destLng)');
      _lastDestinationName = best.displayName;

      // 2. Get own GPS position as origin
      LatLng? origin = _currentGpsPos;
      if (origin == null) {
        try {
          final pos = await Geolocator.getLastKnownPosition();
          if (pos != null) origin = LatLng(pos.latitude, pos.longitude);
        } catch (_) {}
      }
      if (origin == null) {
        debugPrint('[VoiceNav] No GPS position available');
        _speakWithVoskPause('Kein GPS Signal.');
        return;
      }
      debugPrint('[VoiceNav] Origin: ${origin.latitude}, ${origin.longitude}');

      // 3. Set destination in group (background, don't wait)
      try {
        final repo = ref.read(groupRepositoryProvider);
        repo.setDestination(widget.groupId, lat: destLat, lng: destLng, name: best.displayName);
      } catch (e) {
        debugPrint('[VoiceNav] Set destination error: $e');
      }

      // 4. Calculate route — Google Routes first, OSRM fallback
      debugPrint('[VoiceNav] Calculating route...');
      final destination = LatLng(destLat, destLng);
      List<OsrmRoute> allRoutes = [];
      if (GoogleRoutesService.isAvailable) {
        try {
          allRoutes = await _googleRoutes.getAllRoutes(origin, destination, mode: _routeMode);
          debugPrint('[VoiceNav] Google Routes: ${allRoutes.length} routes');
        } catch (e) {
          debugPrint('[VoiceNav] Google Routes failed: $e — OSRM fallback');
        }
      }
      if (allRoutes.isEmpty) {
        allRoutes = await _osrmService.getAllRoutes(origin, destination, mode: _routeMode);
      }
      debugPrint('[VoiceNav] Got ${allRoutes.length} routes');

      if (allRoutes.isEmpty || !mounted) {
        _speakWithVoskPause('Konnte keine Route berechnen.');
        return;
      }

      // Pick route (biker: longest for more Landstraße)
      int primaryIdx = 0;
      if (_routeMode == RouteMode.biker && allRoutes.length > 1) {
        final sorted = List.from(allRoutes)..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
        primaryIdx = allRoutes.indexOf(sorted.last);
      }
      final route = allRoutes[primaryIdx];
      debugPrint('[VoiceNav] Route: ${route.distanceText}, ${route.durationText}');

      // 5. Set route state
      setState(() {
        _alternativeRoutes = allRoutes;
        _selectedRouteIndex = primaryIdx;
        _currentRoute = route;
        _isCalculatingRoute = false;
        _routePanelExpanded = false;
      });

      // 6. Load enrichment (background)
      _loadRouteEnrichment(route, destination);

      // 7. Immediately start navigation — no countdown, no overview
      debugPrint('[VoiceNav] Starting navigation NOW');
      _startNavigation();

    } catch (e) {
      debugPrint('[VoiceNav] Error: $e');
      _speakWithVoskPause('Fehler bei der Navigation.');
    }
  }

  String? _countryCodeToName(String code) {
    const map = {
      'DE': 'Deutschland', 'AT': 'Österreich', 'CH': 'Schweiz',
      'IT': 'Italien', 'FR': 'Frankreich', 'ES': 'Spanien',
      'PT': 'Portugal', 'NL': 'Niederlande', 'BE': 'Belgien',
      'LU': 'Luxemburg', 'PL': 'Polen', 'CZ': 'Tschechien',
      'DK': 'Dänemark', 'SE': 'Schweden', 'NO': 'Norwegen',
      'GB': 'Großbritannien', 'IE': 'Irland', 'HR': 'Kroatien',
      'GR': 'Griechenland', 'TR': 'Türkei', 'HU': 'Ungarn',
      'SK': 'Slowakei', 'SI': 'Slowenien', 'RO': 'Rumänien',
      'BG': 'Bulgarien', 'RS': 'Serbien', 'BA': 'Bosnien',
      'ME': 'Montenegro', 'AL': 'Albanien', 'MK': 'Nordmazedonien',
      'FI': 'Finnland', 'EE': 'Estland', 'LV': 'Lettland',
      'LT': 'Litauen', 'MA': 'Marokko', 'TN': 'Tunesien',
    };
    return map[code.toUpperCase()];
  }

  /// Country flag emoji from ISO code (e.g. "DE" → "🇩🇪")
  String _countryCodeToFlag(String code) {
    final upper = code.toUpperCase();
    if (upper.length != 2) return '';
    final first = 0x1F1E6 + upper.codeUnitAt(0) - 65;
    final second = 0x1F1E6 + upper.codeUnitAt(1) - 65;
    return String.fromCharCodes([first, second]);
  }

  /// Build a prominent country border divider for route sections.
  Widget _buildCountryBorderDivider(String countryCode) {
    final name = _countryCodeToName(countryCode) ?? countryCode;
    final flag = _countryCodeToFlag(countryCode);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1565C0).withValues(alpha: 0.4),
            const Color(0xFF0D47A1).withValues(alpha: 0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF42A5F5).withValues(alpha: 0.5), width: 1.5),
      ),
      child: Row(
        children: [
          Text(flag, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(countryCode,
                  style: GoogleFonts.inter(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                Text(name,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          Icon(Icons.flag_rounded, color: const Color(0xFF42A5F5).withValues(alpha: 0.6), size: 22),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  ROUTE PREVIEW SHEET (Waze-style "Jetzt losfahren")
  // ═══════════════════════════════════════════════════

  void _showRoutePreviewSheet() {
    if (!mounted || _currentRoute == null) return;
    setState(() => _routePanelExpanded = true);
  }

  /// Persistent route info panel — swipe down to collapse, swipe up to expand
  Widget _buildRoutePanel() {
    final route = _currentRoute!;

    // Road names from steps
    final roadNames = route.steps
        .where((s) => s.roadName != null && s.roadName!.isNotEmpty && s.maneuver != 'depart' && s.maneuver != 'arrive')
        .map((s) => s.roadName!)
        .toSet()
        .take(3)
        .join(', ');

    final collapsedHeight = _isNavigating ? 90.0 : 140.0;
    final screenH = MediaQuery.of(context).size.height;
    // Panel goes up to just below the search bar (~120px from top)
    final topPad = MediaQuery.of(context).padding.top;
    final expandedHeight = screenH - topPad - 80;
    final panelHeight = _routePanelExpanded ? expandedHeight : collapsedHeight;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: AnimatedOpacity(
        opacity: _mapInteracting ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
            height: panelHeight,
          decoration: const BoxDecoration(
            color: Color(0xFF1A1E2E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // ── Always visible: Drag handle + Duration/Distance ──
              GestureDetector(
                onTap: () {
                  if (!_routePanelExpanded) {
                    setState(() => _routePanelExpanded = true);
                  } else {
                    setState(() => _routePanelExpanded = false);
                  }
                },
                child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  children: [
                    Center(child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(2)),
                    )),
                    const SizedBox(height: 6),
                    // Row 1: Mode chips + settings gear
                    Row(
                      children: [
                        _buildModeChip(RouteMode.biker, Icons.two_wheeler_rounded, 'Biker'),
                        const SizedBox(width: 6),
                        _buildModeChip(RouteMode.auto, Icons.directions_car_rounded, 'Auto'),
                        const SizedBox(width: 6),
                        _buildModeChip(RouteMode.pedestrian, Icons.directions_walk_rounded, 'Fuß'),
                        const Spacer(),
                        GestureDetector(
                          onTap: _showNavQuickSettings,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.settings_rounded, color: Colors.white70, size: 18),
                          ),
                        ),
                      ],
                    ),
                    // Row 2: Time/distance (collapsed only)
                    if (!_routePanelExpanded)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Text(route.durationText,
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                            const SizedBox(width: 10),
                            Text(route.distanceText,
                              style: GoogleFonts.inter(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                  ],
                ),
              ), // end Padding
              ), // end GestureDetector (header)

              // ── Action Buttons: always visible (below header, above scrollable) ──
              if (!_isNavigating && !_routePanelExpanded)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            _autoStartTimer?.cancel();
                            _stopNavigation();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2D3446),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(child: Text('Abbrechen',
                              style: GoogleFonts.inter(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600))),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: GestureDetector(
                          onTap: () {
                            if (_autoStartCountdown > 0) {
                              _autoStartTimer?.cancel();
                              _autoStartTimer = null;
                              setState(() => _autoStartCountdown = 0);
                            } else {
                              // Launch Mapbox navigation (smooth native tracking)
                              final dest = _getNavDestination();
                              if (dest != null) {
                                context.push('/mapbox-nav', extra: {
                                  'destLat': dest.latitude,
                                  'destLng': dest.longitude,
                                  'destName': _lastDestinationName ?? 'Ziel',
                                });
                              }
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00BCD4),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(child: Text(
                              _autoStartCountdown > 0
                                  ? 'STOP ($_autoStartCountdown)'
                                  : 'LOS!',
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900))),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Expanded: scrollable content with collapse/scroll indicators ──
              if (_routePanelExpanded)
                Expanded(
                  child: Stack(
                    children: [
                  RepaintBoundary(
                    child: NotificationListener<OverscrollNotification>(
                    onNotification: (notification) {
                      if (notification.overscroll < -20 &&
                          notification.metrics.pixels <= 0) {
                        setState(() => _routePanelExpanded = false);
                        return true;
                      }
                      return false;
                    },
                    child: ListView(
                    controller: _panelScrollController,
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    physics: const ClampingScrollPhysics(),
                    cacheExtent: 1000,
                    children: [
                      // Road names
                      if (roadNames.isNotEmpty)
                        Text('Über $roadNames',
                          style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),

                      // ── Section A: Destination Info Card ──
                      if (_destinationInfo != null) _buildDestInfoCard(),

                      // ── Duration + Distance (unter Zielort) ──
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Flexible(child: Text(route.durationText,
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                            maxLines: 1, overflow: TextOverflow.ellipsis)),
                          const SizedBox(width: 10),
                          Text(route.distanceText,
                            style: GoogleFonts.inter(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.w600)),
                        ],
                      ),

                      // ── Section B: Route Stats (POIs + Blitzer) ──
                      const SizedBox(height: 10),
                      _buildRouteStats(),

                      // ── Section C: Alternative Routes ──
                      if (_alternativeRoutes.length > 1) ...[
                        const SizedBox(height: 10),
                        _buildAlternativeRoutes(),
                      ],

                      // ── Section E: Expandable Route Steps ──
                      const SizedBox(height: 10),
                      ..._buildRouteSteps(route),

                      // ── Section F: Action Buttons (only before navigation starts) ──
                      if (!_isNavigating) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                _autoStartTimer?.cancel();
                                setState(() => _routePanelExpanded = false);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2D3446),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Center(child: Text('Später',
                                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w700))),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: GestureDetector(
                              onTap: () {
                                if (_autoStartCountdown > 0) {
                                  // User taps during countdown → stop timer, don't auto-start
                                  _autoStartTimer?.cancel();
                                  _autoStartTimer = null;
                                  setState(() => _autoStartCountdown = 0);
                                } else {
                                  _startNavigation();
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: _autoStartCountdown > 0
                                      ? const Color(0xFF00BCD4)
                                      : const Color(0xFF00BCD4),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Center(child: Text(
                                  _autoStartCountdown > 0
                                      ? 'STOP ($_autoStartCountdown)'
                                      : 'LOS!',
                                  style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900))),
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Cancel route button (before navigation starts)
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: _stopNavigation,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade700.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.red.shade700.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.close_rounded, color: Colors.red.shade300, size: 18),
                              const SizedBox(width: 8),
                              Text('Navigation abbrechen',
                                style: GoogleFonts.inter(color: Colors.red.shade300, fontSize: 14, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                      ] else ...[
                      // ── Navigation active: show cancel button ──
                      const SizedBox(height: 14),
                      GestureDetector(
                        onTap: _stopNavigation,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.red.shade700,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Text('Navigation beenden',
                                style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                      ],
                      const SizedBox(height: 20),
                    ],
                  ),
                  ), // end NotificationListener
                  ), // end RepaintBoundary
                  // ── Collapse arrow at top (visual only, passes scroll events through) ──
                  Positioned(
                    top: 0, left: 0, right: 0,
                    child: IgnorePointer(
                      child: Container(
                        height: 24,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              const Color(0xFF1A1E2E),
                              const Color(0xFF1A1E2E).withValues(alpha: 0),
                            ],
                          ),
                        ),
                        child: const Center(
                          child: Icon(Icons.keyboard_arrow_down_rounded,
                            color: Colors.white38, size: 20),
                        ),
                      ),
                    ),
                  ),
                    ], // end Stack children
                  ), // end Stack
                ), // end Expanded
            ],
          ), // end Column
        ), // end AnimatedContainer
      ), // end AnimatedOpacity
    ); // end Positioned
  }

  Widget _routeChip(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: GoogleFonts.inter(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _routeModeButton(RouteMode mode, IconData icon, String label, Color color) {
    final isActive = _routeMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_routeMode == mode) return;
          setState(() => _routeMode = mode);
          _loadVehicleIcon(); // Reload with new mode badge
          final group = ref.read(groupRideProvider(widget.groupId)).group;
          if (group?.destinationLat != null && group?.destinationLng != null) {
            _calculateRoute(LatLng(group!.destinationLat!, group.destinationLng!));
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? color.withValues(alpha: 0.2) : const Color(0xFF2D3446),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? color : Colors.white12,
              width: isActive ? 2 : 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isActive ? color : Colors.white38, size: 20),
              const SizedBox(width: 6),
              Text(label, style: GoogleFonts.inter(
                color: isActive ? color : Colors.white38,
                fontSize: 14, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }

  /// Biker/Auto/Fußgänger mode toggle chip for collapsed panel.
  Widget _buildModeChip(RouteMode mode, IconData icon, String label) {
    final isActive = _routeMode == mode;
    return GestureDetector(
      onTap: () {
        if (_routeMode == mode || _isCalculatingRoute) return;
        final oldMode = _routeMode;
        setState(() => _routeMode = mode);

        // If switching to/from pedestrian, recalculate route (different OSRM profile)
        final needsRecalc = mode == RouteMode.pedestrian || oldMode == RouteMode.pedestrian;
        if (needsRecalc) {
          // Use current destination (group destination OR last polyline point)
          final dest = _getNavDestination();
          if (dest != null) {
            _calculateRoute(dest);
          }
        } else if (_alternativeRoutes.isNotEmpty) {
          // Re-select route: biker=longest, auto/pedestrian=shortest
          final sorted = List<OsrmRoute>.from(_alternativeRoutes)
            ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
          final pick = mode == RouteMode.biker ? sorted.last : sorted.first;
          final idx = _alternativeRoutes.indexOf(pick);
          setState(() {
            _selectedRouteIndex = idx;
            _currentRoute = pick;
          });
          _fitCameraToRoute(pick);
          // Reload enrichment with destination
          final rideState = ref.read(groupRideProvider(widget.groupId));
          final group = rideState.group;
          if (group?.destinationLat != null && group?.destinationLng != null) {
            _loadRouteEnrichment(pick, LatLng(group!.destinationLat!, group.destinationLng!));
          }
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? (mode == RouteMode.biker ? const Color(0xFF00BCD4) : mode == RouteMode.pedestrian ? const Color(0xFF4CAF50) : Colors.orange)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? (mode == RouteMode.biker ? const Color(0xFF00BCD4) : mode == RouteMode.pedestrian ? const Color(0xFF4CAF50) : Colors.orange)
                : Colors.white24,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: isActive ? Colors.white : Colors.white54),
            const SizedBox(width: 4),
            Text(label, style: GoogleFonts.inter(
              color: isActive ? Colors.white : Colors.white54,
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            )),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  ROUTE PANEL SECTIONS
  // ═══════════════════════════════════════════════════

  /// Section A: Destination info card (population, Wikipedia, country flag)
  Widget _buildDestInfoCard() {
    final info = _destinationInfo!;
    final rideState = ref.read(groupRideProvider(widget.groupId));
    final destName = _lastDestinationName ?? rideState.group?.destinationName ?? 'Ziel';

    return Row(
      children: [
        // Flag + Country code
        if (info.countryFlag != null) ...[
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (info.countryCode != null)
                Text(info.countryCode!,
                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.w700)),
              Text(info.countryFlag!, style: const TextStyle(fontSize: 22)),
            ],
          ),
          const SizedBox(width: 8),
        ],
        // Name + City + Population inline
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(destName,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              if (info.cityName != null || info.populationText != null)
                Text([
                  if (info.cityName != null && info.cityName != destName) info.cityName!,
                  if (info.populationText != null) '${info.populationText} Einwohner',
                ].join(' · '),
                  style: GoogleFonts.inter(color: Colors.white38, fontSize: 11)),
            ],
          ),
        ),
        // Blitzer count badge
        if (_routeBlitzerCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.camera_alt_rounded, color: Colors.redAccent, size: 14),
                const SizedBox(width: 4),
                Text('$_routeBlitzerCount',
                  style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
      ],
    );
  }

  /// Section B: Route stats chips (fuel, biker shops, workshops, blitzer)
  Widget _buildRouteStats() {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        _routeChip(
          _routeMode == RouteMode.biker ? 'Scenic Route' : _routeMode == RouteMode.pedestrian ? 'Fußweg' : 'Schnellste Route',
          _routeMode == RouteMode.biker ? const Color(0xFF00BCD4) : _routeMode == RouteMode.pedestrian ? const Color(0xFF4CAF50) : Colors.blueAccent),
        if (_isLoadingRouteInfo)
          _routeIconChip(Icons.hourglass_empty_rounded, 'Laden...', Colors.white24)
        else ...[
          if (_routePois.fuel.isNotEmpty)
            _routeIconChip(Icons.local_gas_station_rounded, '${_routePois.fuel.length}', Colors.orange),
          if (_routePois.bikerShops.isNotEmpty)
            _routeIconChip(Icons.two_wheeler_rounded, '${_routePois.bikerShops.length} Shops', const Color(0xFF00BCD4)),
          if (_routePois.workshops.isNotEmpty)
            _routeIconChip(Icons.build_rounded, '${_routePois.workshops.length}', Colors.amber),
          if (_routeBlitzerCount > 0)
            _routeIconChip(Icons.camera_alt_rounded, '$_routeBlitzerCount Blitzer', Colors.redAccent),
        ],
      ],
    );
  }

  /// Chip with icon + text
  Widget _routeIconChip(IconData icon, String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.inter(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  /// Section C: Alternative routes (tappable list)
  Widget _buildAlternativeRoutes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Routen', style: GoogleFonts.inter(
          color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        ...List.generate(_alternativeRoutes.length, (i) {
          final alt = _alternativeRoutes[i];
          final isSelected = i == _selectedRouteIndex;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedRouteIndex = i;
                _currentRoute = alt;
              });
              // Reload enrichment for new route
              final rideState = ref.read(groupRideProvider(widget.groupId));
              final group = rideState.group;
              if (group?.destinationLat != null) {
                _loadRouteEnrichment(alt, LatLng(group!.destinationLat!, group.destinationLng!));
              }
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF00BCD4).withValues(alpha: 0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? const Color(0xFF00BCD4) : Colors.white12,
                  width: isSelected ? 1.5 : 0.5),
              ),
              child: Row(
                children: [
                  Icon(isSelected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                    color: isSelected ? const Color(0xFF00BCD4) : Colors.white24, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('${alt.distanceText}, ${alt.durationText}',
                      style: GoogleFonts.inter(
                        color: isSelected ? Colors.white : Colors.white54,
                        fontSize: 13, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
                  ),
                  if (i == 0)
                    _routeChip('Schnellste', Colors.blueAccent),
                  if (_routeMode == RouteMode.biker && i == _selectedRouteIndex)
                    _routeChip('Scenic', const Color(0xFF00BCD4)),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  /// Section E: Expandable route steps with highway badges
  List<Widget> _buildRouteSteps(OsrmRoute route) {
    // Cache route step widgets — only rebuild on route, fuel, or expand change
    final fuelCount = _routePois.fuel.length;
    if (_cachedRouteStepWidgets != null &&
        _cachedRouteStepRoute == route &&
        _cachedFuelCount == fuelCount &&
        _cachedShowSteps == _showRouteSteps &&
        _cachedRouteMode == _routeMode) {
      return _cachedRouteStepWidgets!;
    }
    _cachedRouteStepRoute = route;
    _cachedFuelCount = fuelCount;
    _cachedShowSteps = _showRouteSteps;
    _cachedRouteMode = _routeMode;

    // Group consecutive steps with same road name, capture maneuver + cumulative distance
    final groupedSteps = <_RoadSection>[];
    String? currentRoad;
    String currentManeuver = 'continue';
    double currentDist = 0;
    double cumulativeDist = 0;

    for (final step in route.steps) {
      if (step.maneuver.startsWith('depart') || step.maneuver == 'arrive') continue;
      final road = (step.roadName ?? '').trim();
      if (road.isEmpty) continue;
      // Skip pure-number refs like "8", "45" — not useful as road names
      if (RegExp(r'^\d+$').hasMatch(road)) continue;
      if (road == currentRoad) {
        currentDist += step.distanceMeters;
        cumulativeDist += step.distanceMeters;
      } else {
        if (currentRoad != null) {
          groupedSteps.add(_RoadSection(
            name: currentRoad, distanceM: currentDist,
            maneuver: currentManeuver,
            cumulativeDistM: cumulativeDist - currentDist,
          ));
        }
        currentRoad = road;
        currentManeuver = step.maneuver;
        cumulativeDist += step.distanceMeters;
        currentDist = step.distanceMeters;
      }
    }
    if (currentRoad != null) {
      groupedSteps.add(_RoadSection(
        name: currentRoad, distanceM: currentDist,
        maneuver: currentManeuver,
        cumulativeDistM: cumulativeDist - currentDist,
      ));
    }

    // ── Assign fuel stations to sections by nearest step location ──
    final fuelBySection = <int, List<RoutePoi>>{};
    if (_routePois.fuel.isNotEmpty) {
      // Collect one location per grouped section from the original steps
      final sectionLocations = <LatLng>[];
      String? curRoad;
      for (final step in route.steps) {
        if (step.maneuver.startsWith('depart') || step.maneuver == 'arrive') continue;
        final road = (step.roadName ?? '').trim();
        if (road.isEmpty) continue;
        if (road != curRoad) {
          sectionLocations.add(step.location);
          curRoad = road;
        }
      }

      for (final fuel in _routePois.fuel) {
        final fuelPos = LatLng(fuel.lat, fuel.lon);
        // Find nearest section by geographic distance
        int bestIdx = 0;
        double bestDist = double.infinity;
        for (int s = 0; s < sectionLocations.length && s < groupedSteps.length; s++) {
          final d = _distLatLng(fuelPos, sectionLocations[s]);
          if (d < bestDist) {
            bestDist = d;
            bestIdx = s;
          }
        }
        (fuelBySection[bestIdx] ??= []).add(fuel);
      }
    }

    final result = <Widget>[
      // Header
      GestureDetector(
        onTap: () => setState(() => _showRouteSteps = !_showRouteSteps),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF252A3A),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(_showRouteSteps ? Icons.expand_less : Icons.expand_more,
                color: Colors.white54, size: 22),
              const SizedBox(width: 6),
              const Icon(Icons.route_rounded, color: Color(0xFF00BCD4), size: 20),
              const SizedBox(width: 8),
              Text('Abschnitte (${groupedSteps.length})',
                style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    ];

    // Expanded step list — grouped by country, each country collapsible
    if (_showRouteSteps) {
      result.add(const SizedBox(height: 8));

      // Build country → step ranges mapping
      // Each country segment starts at groupedStepIndex and runs until the next segment
      final countryRanges = <({String code, int from, int to})>[];
      if (_routeCountrySegments.isEmpty) {
        // No country data — treat all as one group with no header
        countryRanges.add((code: '', from: 0, to: groupedSteps.length));
      } else {
        for (int c = 0; c < _routeCountrySegments.length; c++) {
          final seg = _routeCountrySegments[c];
          final nextFrom = c + 1 < _routeCountrySegments.length
              ? _routeCountrySegments[c + 1].groupedStepIndex
              : groupedSteps.length;
          countryRanges.add((code: seg.countryCode, from: seg.groupedStepIndex, to: nextFrom));
        }
      }

      for (final range in countryRanges) {
        final stepsInCountry = range.to - range.from;
        // Calculate total distance in this country
        double countryDistM = 0;
        for (int i = range.from; i < range.to && i < groupedSteps.length; i++) {
          countryDistM += groupedSteps[i].distanceM;
        }
        final countryDistText = countryDistM >= 1000
            ? '${(countryDistM / 1000).toStringAsFixed(1)} km'
            : '${countryDistM.round()} m';

        final isExpanded = _expandedCountries.contains(range.code);

        // Country header (clickable to expand/collapse)
        if (range.code.isNotEmpty) {
          final name = _countryCodeToName(range.code) ?? range.code;
          final flag = _countryCodeToFlag(range.code);
          result.add(GestureDetector(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedCountries.remove(range.code);
                } else {
                  _expandedCountries.add(range.code);
                }
                _cachedRouteStepWidgets = null; // invalidate cache
              });
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 6, top: 4),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF1565C0).withValues(alpha: 0.4),
                    const Color(0xFF0D47A1).withValues(alpha: 0.2),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF42A5F5).withValues(alpha: 0.5), width: 1.5),
              ),
              child: Row(
                children: [
                  Text(flag, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                        Text('$stepsInCountry Abschnitte · $countryDistText',
                          style: GoogleFonts.inter(color: Colors.white54, fontSize: 11)),
                      ],
                    ),
                  ),
                  Icon(isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: Colors.white54, size: 22),
                ],
              ),
            ),
          ));
        } else {
          // No country data — always show steps without header
        }

        // Steps within this country (only if expanded, or no country data)
        if (isExpanded || range.code.isEmpty) {
          for (int idx = range.from; idx < range.to && idx < groupedSteps.length; idx++) {
            final section = groupedSteps[idx];
            final roadType = _classifyRoad(section.name);
            final distText = section.distanceM >= 1000
                ? '${(section.distanceM / 1000).toStringAsFixed(1)} km'
                : '${section.distanceM.round()} m';
            final maneuverIcon = _maneuverIcon(section.maneuver);
            final displayName = section.name.contains(' / ')
                ? section.name.split(' / ').last
                : section.name;

            result.add(Container(
              margin: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 22,
                    child: Text('${idx + 1}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: Colors.white30, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: maneuverIcon.bgColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(maneuverIcon.icon, color: maneuverIcon.iconColor, size: 24),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildFullRoadSign(roadType, displayName, distText),
                  ),
                ],
              ),
            ));

            // ── Fuel stations in this section (max 3) ──
            final fuels = fuelBySection[idx];
            if (fuels != null) {
              final displayFuels = fuels.length > 3 ? fuels.sublist(0, 3) : fuels;
              for (final f in displayFuels) {
                result.add(Container(
                  margin: const EdgeInsets.only(bottom: 4, left: 28),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.local_gas_station_rounded, color: Colors.orange, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          f.name.isNotEmpty ? f.name : 'Tankstelle',
                          style: GoogleFonts.inter(color: Colors.orange.shade200, fontSize: 12, fontWeight: FontWeight.w600),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ));
              }
            }
          }
        }
      }
    }

    _cachedRouteStepWidgets = result;
    return result;
  }

  /// Get maneuver icon + colors for Fahrschulbogen-style display.
  ({IconData icon, Color bgColor, Color iconColor}) _maneuverIcon(String maneuver) {
    return switch (maneuver) {
      'turn-left' || 'turn-sharp-left' => (
        icon: Icons.turn_left_rounded,
        bgColor: const Color(0xFF1565C0).withValues(alpha: 0.3),
        iconColor: const Color(0xFF42A5F5),
      ),
      'turn-right' || 'turn-sharp-right' => (
        icon: Icons.turn_right_rounded,
        bgColor: const Color(0xFF1565C0).withValues(alpha: 0.3),
        iconColor: const Color(0xFF42A5F5),
      ),
      'turn-slight-left' || 'fork-left' => (
        icon: Icons.turn_slight_left_rounded,
        bgColor: const Color(0xFF0097A7).withValues(alpha: 0.3),
        iconColor: const Color(0xFF26C6DA),
      ),
      'turn-slight-right' || 'fork-right' => (
        icon: Icons.turn_slight_right_rounded,
        bgColor: const Color(0xFF0097A7).withValues(alpha: 0.3),
        iconColor: const Color(0xFF26C6DA),
      ),
      'roundabout' || 'rotary' => (
        icon: Icons.roundabout_right_rounded,
        bgColor: const Color(0xFF6A1B9A).withValues(alpha: 0.3),
        iconColor: const Color(0xFFCE93D8),
      ),
      'merge-left' || 'merge-right' || 'merge' => (
        icon: Icons.merge_rounded,
        bgColor: const Color(0xFFE65100).withValues(alpha: 0.3),
        iconColor: const Color(0xFFFF9800),
      ),
      'ramp-left' || 'off-ramp-left' || 'on-ramp-left' => (
        icon: Icons.ramp_left_rounded,
        bgColor: const Color(0xFFE65100).withValues(alpha: 0.3),
        iconColor: const Color(0xFFFFAB40),
      ),
      'ramp-right' || 'off-ramp-right' || 'on-ramp-right' => (
        icon: Icons.ramp_right_rounded,
        bgColor: const Color(0xFFE65100).withValues(alpha: 0.3),
        iconColor: const Color(0xFFFFAB40),
      ),
      'uturn' || 'turn-uturn' => (
        icon: Icons.u_turn_left_rounded,
        bgColor: const Color(0xFFC62828).withValues(alpha: 0.3),
        iconColor: const Color(0xFFEF5350),
      ),
      'ferry' => (
        icon: Icons.directions_ferry_rounded,
        bgColor: const Color(0xFF00695C).withValues(alpha: 0.3),
        iconColor: const Color(0xFF4DB6AC),
      ),
      _ => ( // straight, continue, new-name
        icon: Icons.straight_rounded,
        bgColor: Colors.white.withValues(alpha: 0.08),
        iconColor: Colors.white38,
      ),
    };
  }

  /// Build a full "Wegweiser"-style road sign with name + distance built in.
  Widget _buildFullRoadSign(_RoadType roadType, String roadName, String distText) {
    if (roadType.badge != null && roadType.signType == _SignType.autobahn) {
      // German Autobahn Wegweiser: blue sign with road name + distance
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0050A4),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(color: const Color(0xFF0050A4).withValues(alpha: 0.5), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            // Badge (A1, A3...)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(roadType.badge!,
                style: GoogleFonts.inter(color: const Color(0xFF0050A4), fontSize: 13, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 8),
            // Road name
            Expanded(
              child: Text(roadName,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 6),
            // Distance
            Text(distText,
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    if (roadType.badge != null && roadType.signType == _SignType.bundesstrasse) {
      // Bundesstraße Wegweiser: yellow sign
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFCC00),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.black54, width: 2),
          boxShadow: [
            BoxShadow(color: const Color(0xFFFFCC00).withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(roadType.badge!,
                style: GoogleFonts.inter(color: const Color(0xFFFFCC00), fontSize: 13, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(roadName,
                style: GoogleFonts.inter(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w700),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 6),
            Text(distText,
              style: GoogleFonts.inter(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    if (roadType.badge != null && roadType.signType == _SignType.europastrasse) {
      // Europastraße Wegweiser: green sign
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF006B3F),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(color: const Color(0xFF006B3F).withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(roadType.badge!,
                style: GoogleFonts.inter(color: const Color(0xFF006B3F), fontSize: 13, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(roadName,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 6),
            Text(distText,
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    // Landstraße — weißes Schild, schwarze Schrift (wie deutsche Ortsschilder)
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.black26, width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(roadName,
              style: GoogleFonts.inter(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w700),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 6),
          Text(distText,
            style: GoogleFonts.inter(color: Colors.black45, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  /// Classify a road by name → type with colors & icons.
  _RoadType _classifyRoad(String roadName) {
    // Autobahn (A1, A3, A44)
    final autobahnMatch = RegExp(r'\bA\s?(\d+)\b').firstMatch(roadName);
    if (autobahnMatch != null) {
      return _RoadType(
        badge: 'A${autobahnMatch.group(1)}',
        signType: _SignType.autobahn,
        iconBg: const Color(0xFF0050A4),
        badgeTextColor: Colors.white,
        bgColor: const Color(0xFF0050A4).withValues(alpha: 0.1),
        icon: Icons.speed_rounded,
        iconColor: const Color(0xFF0050A4),
      );
    }

    // Bundesstraße (B42, B8)
    final bundesMatch = RegExp(r'\bB\s?(\d+)\b').firstMatch(roadName);
    if (bundesMatch != null) {
      return _RoadType(
        badge: 'B${bundesMatch.group(1)}',
        signType: _SignType.bundesstrasse,
        iconBg: const Color(0xFFFFCC00),
        badgeTextColor: Colors.black,
        bgColor: const Color(0xFFFFCC00).withValues(alpha: 0.08),
        icon: Icons.signpost_rounded,
        iconColor: const Color(0xFFFFCC00),
      );
    }

    // Europastraße (E40, E45)
    final euroMatch = RegExp(r'\bE\s?(\d+)\b').firstMatch(roadName);
    if (euroMatch != null) {
      return _RoadType(
        badge: 'E${euroMatch.group(1)}',
        signType: _SignType.europastrasse,
        iconBg: const Color(0xFF006B3F),
        badgeTextColor: Colors.white,
        bgColor: const Color(0xFF006B3F).withValues(alpha: 0.08),
        icon: Icons.public_rounded,
        iconColor: const Color(0xFF006B3F),
      );
    }

    // Ring / Kreisverkehr
    if (roadName.contains('Ring') || roadName.contains('ring')) {
      return _RoadType(
        iconBg: Colors.purple.withValues(alpha: 0.3),
        bgColor: Colors.purple.withValues(alpha: 0.05),
        icon: Icons.roundabout_right_rounded,
        iconColor: Colors.purpleAccent,
      );
    }

    // Straße / Weg — default city road
    return _RoadType(
      iconBg: Colors.white.withValues(alpha: 0.1),
      bgColor: Colors.white.withValues(alpha: 0.03),
      icon: Icons.place_rounded,
      iconColor: Colors.white38,
    );
  }

  /// Show quick navigation settings bottom sheet.
  void _showNavQuickSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final settingsAsync = ref.watch(blitzerSettingsProvider);
          return settingsAsync.when(
            loading: () => const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SizedBox(
              height: 200,
              child: Center(child: Text('Fehler: $e', style: const TextStyle(color: Colors.white))),
            ),
            data: (settings) => ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.6,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  // Drag handle
                  Center(child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  )),
                  const SizedBox(height: 16),
                  Text('Navigationseinstellungen',
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  // Volume slider
                  Row(
                    children: [
                      const Icon(Icons.volume_up_rounded, color: Colors.white70, size: 20),
                      const SizedBox(width: 12),
                      Text('Lautstärke', style: GoogleFonts.inter(color: Colors.white, fontSize: 14)),
                      const Spacer(),
                      SizedBox(
                        width: 140,
                        child: Slider(
                          value: settings.audioVolume,
                          onChanged: (v) => ref.read(blitzerSettingsProvider.notifier)
                              .updateSetting((s) => s.copyWith(audioVolume: v)),
                          activeColor: const Color(0xFF00BCD4),
                          inactiveColor: Colors.white24,
                        ),
                      ),
                    ],
                  ),
                  _quickSettingsToggle(
                    ref, Icons.navigation_rounded, 'Navigations-Töne',
                    settings.navSoundEnabled,
                    (v) => ref.read(blitzerSettingsProvider.notifier)
                        .updateSetting((s) => s.copyWith(navSoundEnabled: v)),
                  ),
                  _quickSettingsToggle(
                    ref, Icons.warning_amber_rounded, 'Warnmeldungs-Töne',
                    settings.warningSoundEnabled,
                    (v) => ref.read(blitzerSettingsProvider.notifier)
                        .updateSetting((s) => s.copyWith(warningSoundEnabled: v)),
                  ),
                  _quickSettingsToggle(
                    ref, Icons.speed_rounded, 'Geschwindigkeit zeigen',
                    settings.speedDisplay,
                    (v) => ref.read(blitzerSettingsProvider.notifier)
                        .updateSetting((s) => s.copyWith(speedDisplay: v)),
                  ),
                  _quickSettingsToggle(
                    ref, Icons.brightness_high_rounded, 'Bildschirm anlassen',
                    settings.keepScreenOn,
                    (v) => ref.read(blitzerSettingsProvider.notifier)
                        .updateSetting((s) => s.copyWith(keepScreenOn: v)),
                  ),
                  _quickSettingsToggle(
                    ref, Icons.threed_rotation_rounded, '3D Navigation',
                    settings.auto3dNavigation,
                    (v) => ref.read(blitzerSettingsProvider.notifier)
                        .updateSetting((s) => s.copyWith(auto3dNavigation: v)),
                  ),
                  const Divider(color: Colors.white24, height: 24),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      context.push('/map-settings');
                    },
                    child: Row(
                      children: [
                        const Icon(Icons.tune_rounded, color: Color(0xFF00BCD4), size: 20),
                        const SizedBox(width: 12),
                        Text('Alle Einstellungen',
                          style: GoogleFonts.inter(color: const Color(0xFF00BCD4), fontSize: 14, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF00BCD4), size: 16),
                      ],
                    ),
                  ),
                ],
              ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Quick-settings toggle row helper.
  Widget _quickSettingsToggle(
    WidgetRef ref,
    IconData icon,
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: GoogleFonts.inter(color: Colors.white, fontSize: 14)),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF00BCD4),
          ),
        ],
      ),
    );
  }

  /// Launch Mapbox navigation screen (smooth native tracking).
  void _launchMapboxNav() {
    final dest = _getNavDestination();
    if (dest == null) return;
    context.push('/mapbox-nav', extra: {
      'destLat': dest.latitude,
      'destLng': dest.longitude,
      'destName': _lastDestinationName ?? 'Ziel',
    });
  }

  /// Start navigation — called from "LOS!" button or auto-start timer.
  /// NOW REDIRECTS TO MAPBOX for smooth native tracking.
  void _startNavigation() {
    _launchMapboxNav();
    return;
    // ignore: dead_code
    debugPrint('[Nav] _startNavigation called! _isNavigating=$_isNavigating _currentRoute=${_currentRoute != null}');
    if (_isNavigating) {
      debugPrint('[Nav] BLOCKED — already navigating!');
      return;
    }
    _autoStartTimer?.cancel();
    _autoStartTimer = null;
    _autoStartCountdown = 0;
    // Stop non-nav heading follow (extrapolation timer takes over)
    _headingFollowTimer?.cancel();
    _headingFollowTimer = null;
    _isProgrammaticMove = true; // Protect from onCameraMoveStarted during setup
    WakelockPlus.enable(); // Display bleibt an während Navigation
    setState(() {
      _routePanelExpanded = false;
      _isNavFollowing = true;
      _isNavigating = true;
      _navUiHidden = true; // Auto-hide UI during navigation
    });
    // Start NavEngine (parallel — will take over TTS + turn tracking)
    if (_currentRoute != null) {
      final dest = _getNavDestination();
      _navEngine.setRoute(_currentRoute!, destination: dest, mode: _routeMode);
      _navEngine.onStateChangedSync = () { if (mounted) setState(() {}); };
      _navEngine.onArrived = () => _stopNavigation(arrived: true);
      _navEngine.start(currentPos: _currentGpsPos);
    }
    _startNavPeriodicTimer();
    // NOTE: Extrapolation timer started AFTER initial camera positioning (see below)
    // Route announcement — "Navigation gestartet" FIRST, then details after delay
    final destName = _lastDestinationName ?? 'Ziel';
    // Use city name (e.g. "Solingen") not country ("Deutschland")
    final cityName = _destinationInfo?.cityName;
    final route = _currentRoute;
    if (route != null) {
      final destFull = cityName != null && cityName.isNotEmpty
          ? '$destName in $cityName'
          : destName;
      // Sequential navigation TTS: each waits for the previous to finish
      TtsAlertService.instance.clearQueue();
      TtsAlertService.instance.speakQueued('Navigation gestartet.');
      TtsAlertService.instance.speakQueued(
        '$destFull. ${route.distanceText}, ${route.durationText}.',
      );
      // First turn instruction — directly in queue, no Future.delayed needed
      if (route.steps.length > 1 && _currentGpsPos != null) {
        for (int i = 0; i < route.steps.length; i++) {
          final s = route.steps[i];
          if (s.maneuver.startsWith('depart')) continue;
          final dist = _formatDistance(s.distanceMeters > 0
              ? _distLatLng(_currentGpsPos!, s.location)
              : route.steps[0].distanceMeters);
          // Don't add road name if already in instruction (avoid "auf X auf X")
          final hasRoad = s.roadName != null && s.roadName!.isNotEmpty
              && s.instruction.toLowerCase().contains(s.roadName!.toLowerCase());
          final road = (s.roadName != null && s.roadName!.isNotEmpty && !hasRoad)
              ? ' auf ${s.roadName}' : '';
          _announcedTtsPairs.add('$i:500m'); // Mark as pre-announced
          TtsAlertService.instance.speakQueued(
            'Weiter für $dist, dann ${s.instruction}$road',
          );
          break;
        }
      }
    }
    if (_currentGpsPos != null && _mapController != null) {
      // Use route direction for initial bearing — find a point far enough away
      double initBearing = _currentHeading;
      final route = _currentRoute;
      if (route != null && route.polylinePoints.length >= 2) {
        final p1 = _currentGpsPos!;
        // Find first route point at least 50m from current position
        LatLng? p2;
        for (final pt in route.polylinePoints) {
          if (_distLatLng(p1, pt) > 50) {
            p2 = pt;
            break;
          }
        }
        p2 ??= route.polylinePoints.last;
        initBearing = _bearingBetween(p1, p2);
        debugPrint('[Nav] Init bearing: ${initBearing.toStringAsFixed(1)}° from GPS to route point');
        _currentHeading = initBearing;
        _targetHeading = initBearing;
        _smoothBearing = initBearing;
        _committedBearing = initBearing;
      }
      _smoothCamPos = null; // Reset smooth position for immediate jump
      _lastCamTarget = null;
      _lastCamBearing = -1;
      // Start camera at current position, looking in travel direction
      _isProgrammaticMove = true;
      _lastProgrammaticMoveTime = DateTime.now();
      _smoothZoom = 17.0;
      _mapController!.moveCamera(
        CameraUpdate.newCameraPosition(
          gmaps.CameraPosition(
            target: _currentGpsPos!,
            zoom: 17.0,
            tilt: 45,
            bearing: _smoothBearing,
          ),
        ),
      );
      _startNavCameraLoop();
    } else {
      _startNavCameraLoop();
    }
  }

  /// Calculate bearing from point A to point B in degrees.
  double _bearingBetween(LatLng a, LatLng b) {
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  /// Auto-start navigation with visible countdown (5, 4, 3, 2, 1... LOS!)
  Timer? _autoStartTimer;
  int _autoStartCountdown = 0; // 0 = no countdown active

  void _startAutoStartTimer() {
    _autoStartTimer?.cancel();
    _autoStartCountdown = 5;
    if (mounted) setState(() {});

    _autoStartTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isNavigating || _currentRoute == null) {
        timer.cancel();
        _autoStartCountdown = 0;
        if (mounted) setState(() {});
        return;
      }
      _autoStartCountdown--;
      if (_autoStartCountdown <= 0) {
        timer.cancel();
        _autoStartCountdown = 0;
        debugPrint('[Nav] Countdown finished — auto-starting navigation');
        _startNavigation();
      } else {
        setState(() {});
      }
    });
  }

  /// Stop active navigation and reset all route state.
  void _stopNavigation({bool arrived = false}) {
    WakelockPlus.disable(); // Display darf wieder ausgehen
    // Cancel all timers
    _autoStartTimer?.cancel();
    _autoStartTimer = null;
    _stopNavCameraLoop();
    _isProgrammaticMove = false; // Allow user gestures again
    // Keep HeadingSensorService + fused heading running for non-nav heading follow
    _navKalman.reset(); // Reset Kalman filter for next navigation
    _navPeriodicTimer?.cancel();
    _navPeriodicTimer = null;
    _navEngine.stop();
    if (!arrived) {
      // Manual stop — announce it
      TtsAlertService.instance.speakText('Navigation beendet.');
    }
    // If arrived: NavEngine already said "Du hast dein Ziel erreicht. Viel Spaß noch!"
    _navUiShowTimer?.cancel();
    setState(() {
      _isNavigating = false;
      _navUiHidden = false; // Show UI again when navigation stops
      _isNavFollowing = true; // Keep heading follow active (non-nav rotation)
      _currentRoute = null;
      _alternativeRoutes = [];
      _selectedRouteIndex = 0;
      _routePois = RoutePois.empty();
      _routeBlitzerPositions = [];
      _routeBlitzerCount = 0;
      _destinationInfo = null;
      _routeCountrySegments = [];
      _lastAnnouncedStepIndex = -1;
      _announcedTtsPairs.clear();
      _nextTurnStep = null;
      _afterNextTurnStep = null;
      _nextTurnDistanceM = 0;
      _offRouteCount = 0;
      _offRouteAsked = false;
      _offRouteWarned = false;
      _awaitingRerouteChoice = false;
      _lastOnRoutePos = _currentGpsPos;
      _navStartPos = _currentGpsPos; // remember start for "Zurück zum Start"
      _routePanelExpanded = false;
      _isLoadingRouteInfo = false;
      _cachedRouteStepWidgets = null;
      _cachedPolylines = null;
      _lastSnapInput = null;
      _osrmMatchedPos = null;
      _gpsMatchBuffer.clear();
      _gpsMatchTimestamps.clear();
      _gpsMatchTickCounter = 0;
      _expandedCountries.clear();
    });
    // Resume non-nav heading follow timer (compass rotation)
    _startHeadingFollowTimer();
  }

  /// Calculate route from admin/leader position to destination via OSRM.
  /// If no admin position available, falls back to own GPS.
  Future<void> _calculateRoute(LatLng destination) async {
    if (_isCalculatingRoute) return;

    // Prefer admin/leader position as route origin
    LatLng? origin;
    final rideState = ref.read(groupRideProvider(widget.groupId));
    final group = rideState.group;
    if (group != null) {
      // Find the group leader/admin in ride members
      for (final member in rideState.rideMembers.values) {
        if (member.isGroupLeader || member.userId == group.creatorId) {
          origin = LatLng(member.lat, member.lng);
          debugPrint('[Nav] Using admin position as origin: ${member.displayName}');
          break;
        }
      }
    }

    // Fallback: own GPS position
    if (origin == null) {
      Position? currentPos;
      try {
        currentPos = await Geolocator.getLastKnownPosition();
        currentPos ??= await Geolocator.getCurrentPosition();
      } catch (e) {
        debugPrint('[Nav] GPS error: $e');
      }
      if (currentPos == null || !mounted) return;
      origin = LatLng(currentPos.latitude, currentPos.longitude);
    }
    debugPrint('[Nav] Calculating route: $origin -> $destination');

    setState(() => _isCalculatingRoute = true);
    try {
      // Fetch ALL route alternatives — Google Routes first, OSRM fallback
      List<OsrmRoute> allRoutes = [];
      if (GoogleRoutesService.isAvailable) {
        try {
          allRoutes = await _googleRoutes.getAllRoutes(origin, destination, mode: _routeMode);
          debugPrint('[Nav] Google Routes: ${allRoutes.length} routes');
        } catch (e) {
          debugPrint('[Nav] Google Routes failed: $e — OSRM fallback');
        }
      }
      if (allRoutes.isEmpty) {
        allRoutes = await _osrmService.getAllRoutes(origin, destination, mode: _routeMode);
      }

      if (!mounted) return;

      if (allRoutes.isNotEmpty) {
        // Pick primary based on mode:
        // Biker: longest route (more Landstraße, less Autobahn)
        // Auto: fastest/shortest route
        int primaryIdx = 0;
        if (_routeMode == RouteMode.biker && allRoutes.length > 1) {
          // Pick the LONGEST route — typically avoids Autobahn
          final sorted = List<OsrmRoute>.from(allRoutes)
            ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
          final scenic = sorted.last; // Longest = most Landstraße
          primaryIdx = allRoutes.indexOf(scenic);
          debugPrint('[Nav] Biker mode: picked route ${primaryIdx + 1}/${allRoutes.length} '
              '(${scenic.distanceText} scenic vs ${allRoutes[0].distanceText} fast)');
        } else if (_routeMode == RouteMode.biker && allRoutes.length == 1) {
          debugPrint('[Nav] Biker mode: only 1 route available (long distance, no alternatives)');
        }

        final route = allRoutes[primaryIdx];
        debugPrint('[Nav] ${allRoutes.length} routes found. Primary: ${route.distanceText}, ${route.durationText}');

        setState(() {
          _alternativeRoutes = allRoutes;
          _selectedRouteIndex = primaryIdx;
          _currentRoute = route;
          _isCalculatingRoute = false;
          _routePanelExpanded = false; // Collapsed by default — user taps to expand
        });

        // Fit camera to route bounds (overview), pause auto-follow
        _fitCameraToRoute(route);

        // ── Enrich route data (background, non-blocking) ──
        _loadRouteEnrichment(route, destination);

        TtsAlertService.instance.speakText(
          'Route berechnet. ${route.distanceText}, ${route.durationText}.',
        );

        // Auto-start navigation after 5s if user doesn't interact
        _startAutoStartTimer();
      } else {
        debugPrint('[Nav] No route found');
        setState(() => _isCalculatingRoute = false);
      }
    } catch (e) {
      debugPrint('[Nav] Route calculation error: $e');
      if (mounted) setState(() => _isCalculatingRoute = false);
    }
  }

  /// Off-route detection — after 3s off-route:
  /// TTS: "Hast du dich verfahren Racer? Sage Weiter zum Ziel, oder Zurück zum Start."
  /// Auto-reroute to destination after 10s if no voice answer.
  bool _offRouteAsked = false;
  bool _offRouteWarned = false;
  bool _awaitingRerouteChoice = false; // waiting for voice: "weiter" or "zurück"
  LatLng? _lastOnRoutePos;
  LatLng? _navStartPos; // where navigation was started

  void _checkOffRoute(LatLng pos) {
    if (_currentRoute == null || _isCalculatingRoute) {
      debugPrint('[Nav] Off-route SKIP: route=${_currentRoute != null}, calculating=$_isCalculatingRoute');
      return;
    }
    final dist = _minDistanceToRoute(pos);
    // Mode-aware: pedestrians on narrow sidewalks, bikers need more GPS tolerance
    final offThreshold = _routeMode == RouteMode.pedestrian ? 20.0 : 35.0;
    debugPrint('[Nav] Off-route: dist=${dist.toStringAsFixed(1)}m (threshold=${offThreshold}m), count=$_offRouteCount, asked=$_offRouteAsked');
    if (dist > offThreshold) {
      _offRouteCount++;

      // ── 3 consecutive off-route fixes → reroute + ask rider ──
      // 30m threshold: GPS accuracy is 5-15m, so 10m caused constant false alarms.
      // 3 fixes = ~3 seconds confirmation before triggering.
      if (_offRouteCount >= 3 && !_offRouteAsked) {
        _offRouteAsked = true;
        _offRouteCount = 0;
        debugPrint('[Nav] Off-route → auto-rerouting to destination');

        // Auto-reroute without asking — like Google Maps
        TtsAlertService.instance.clearQueue();
        TtsAlertService.instance.speakQueued('Route wird neu berechnet.');

        final dest = _getNavDestination();
        if (dest != null && _currentGpsPos != null) {
          _rerouteFromCurrentPosition(_currentGpsPos!, dest);
        }
      }
    } else if (dist < (offThreshold * 0.5)) {
      // Hysteresis: only reset when clearly back on-route (half the off-threshold)
      _lastOnRoutePos = pos;
      _offRouteCount = 0;
      _offRouteWarned = false;
      _offRouteAsked = false;
      if (_awaitingRerouteChoice) {
        _awaitingRerouteChoice = false;
        VoskWakeWordService.instance.directListenMode = false;
        TtsAlertService.instance.speakText('Wieder auf der Route.');
      }
    }
  }

  /// Handle voice answer for off-route choice: "weiter" or "zurück"
  void _handleRerouteChoice(String text) {
    if (!_awaitingRerouteChoice) return;
    final lower = text.toLowerCase().trim();
    debugPrint('[Nav] Reroute choice voice: "$lower"');

    if (lower.contains('weiter') || lower.contains('ziel') || lower.contains('eins') || lower.contains('1')) {
      // Option 1: Reroute to destination
      _awaitingRerouteChoice = false;
      VoskWakeWordService.instance.directListenMode = false;
      TtsAlertService.instance.speakText('Route zum Ziel wird neu berechnet.');
      final dest = _getNavDestination();
      if (dest != null && _currentGpsPos != null) {
        _rerouteFromCurrentPosition(_currentGpsPos!, dest);
      }
    } else if (lower.contains('zurück') || lower.contains('start') || lower.contains('zwei') || lower.contains('2')) {
      // Option 2: Route back to start point
      _awaitingRerouteChoice = false;
      VoskWakeWordService.instance.directListenMode = false;
      if (_navStartPos != null && _currentGpsPos != null) {
        TtsAlertService.instance.speakText('Route zurück zum Startpunkt wird berechnet.');
        _rerouteFromCurrentPosition(_currentGpsPos!, _navStartPos!);
      }
    } else if (lower.contains('beenden') || lower.contains('stopp') || lower.contains('drei') || lower.contains('3') || lower.contains('nein')) {
      // Option 3: End navigation
      _awaitingRerouteChoice = false;
      VoskWakeWordService.instance.directListenMode = false;
      TtsAlertService.instance.speakText('Navigation wird beendet.');
      _stopNavigation();
    }
  }

  /// Get navigation destination from group or route endpoint.
  LatLng? _getNavDestination() {
    final group = ref.read(groupRideProvider(widget.groupId)).group;
    if (group?.destinationLat != null && group?.destinationLng != null) {
      return LatLng(group!.destinationLat!, group!.destinationLng!);
    } else if (_currentRoute != null && _currentRoute!.polylinePoints.isNotEmpty) {
      return _currentRoute!.polylinePoints.last;
    }
    return null;
  }

  /// Ask user via TTS + Vosk voice recognition if they want to reroute.
  /// "Ja" → reroute, "Nein" → keep current route, no answer (6s) → auto-reroute.
  /// Uses Vosk (already listening) instead of speech_to_text to avoid mic conflict.
  bool _awaitingOffRouteAnswer = false;
  LatLng? _offRouteDestination;

  Future<void> _askOffRouteVoice(LatLng destination) async {
    _offRouteDestination = destination;
    _awaitingOffRouteAnswer = true;

    // Vosk stays in wake-word mode — user can say "Hi Moto" to interrupt
    TtsAlertService.instance.speakPriority(
      'Du hast die Route verlassen. Sage Ja für neue Route, oder Nein zum Beibehalten.',
    );

    debugPrint('[Nav] Off-route question asked');

    // Enable direct listen after TTS finishes (~5s) for Ja/Nein answer
    Future.delayed(const Duration(seconds: 5), () {
      if (_awaitingOffRouteAnswer && mounted) {
        VoskWakeWordService.instance.directListenMode = true;
        debugPrint('[Nav] Direct listen ON for Ja/Nein');
      }
    });

    // Auto-reroute after 12s total if no answer
    Future.delayed(const Duration(seconds: 12), () {
      if (_awaitingOffRouteAnswer && mounted && _currentGpsPos != null) {
        _awaitingOffRouteAnswer = false;
        _offRouteDestination = null;
        VoskWakeWordService.instance.directListenMode = false;
        debugPrint('[Nav] No answer — auto-rerouting');
        TtsAlertService.instance.speakText('Neue Route wird automatisch berechnet.');
        _rerouteFromCurrentPosition(_currentGpsPos!, destination);
      }
    });
  }

  /// Called from the main Vosk event handler when off-route answer is pending.
  void _handleOffRouteVoiceAnswer(String text) {
    if (!_awaitingOffRouteAnswer || _offRouteDestination == null) return;
    final lower = text.toLowerCase().trim();
    debugPrint('[Nav] Off-route voice answer: "$lower"');

    if (lower.contains('ja') || lower.contains('yeah') || lower.contains('ok') || lower.contains('neue') || lower.contains('bitte')) {
      _awaitingOffRouteAnswer = false;
      final dest = _offRouteDestination!;
      _offRouteDestination = null;
      VoskWakeWordService.instance.directListenMode = false;
      TtsAlertService.instance.speakText('Route wird neu berechnet.');
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _currentGpsPos != null) {
          _rerouteFromCurrentPosition(_currentGpsPos!, dest);
        }
      });
    } else if (lower.contains('nein') || lower.contains('no') || lower.contains('nicht')) {
      _awaitingOffRouteAnswer = false;
      _offRouteDestination = null;
      VoskWakeWordService.instance.directListenMode = false;
      TtsAlertService.instance.speakText('Okay, aktuelle Route beibehalten.');
      _offRouteAsked = false;
      _offRouteCount = 0;
    }
  }

  /// Handle voice commands during navigation (called from Vosk handler).
  /// Returns true if the command was handled.
  bool _handleNavVoiceCommand(String text) {
    if (!_isNavigating) return false;
    final lower = text.toLowerCase().trim();

    // "Zurück" — reroute back to last on-route position, then to destination
    if (lower.contains('zurück') || lower.contains('umdrehen') || lower.contains('umkehren')) {
      if (_lastOnRoutePos != null && _currentGpsPos != null) {
        TtsAlertService.instance.speakText('Wird zurück zur Route berechnet.');
        _rerouteFromCurrentPosition(_currentGpsPos!, _getNavDestination() ?? _lastOnRoutePos!);
      }
      return true;
    }

    // "Navigation beenden" / "Stopp" — end navigation
    if (lower.contains('navigation beenden') || lower.contains('navi beenden') ||
        lower.contains('stopp navigation') || lower.contains('navi stopp')) {
      TtsAlertService.instance.speakText('Navigation wird beendet.');
      _stopNavigation();
      return true;
    }

    return false;
  }

  /// Reroute from current GPS position — recalculates route line immediately.
  Future<void> _rerouteFromCurrentPosition(LatLng from, LatLng to) async {
    if (_isCalculatingRoute) return;
    setState(() => _isCalculatingRoute = true);

    try {
      // Google Routes first, OSRM fallback
      List<OsrmRoute> allRoutes = [];
      if (GoogleRoutesService.isAvailable) {
        try {
          allRoutes = await _googleRoutes.getAllRoutes(from, to, mode: _routeMode);
        } catch (e) {
          debugPrint('[Nav] Google reroute failed: $e — OSRM fallback');
        }
      }
      if (allRoutes.isEmpty) {
        allRoutes = await _osrmService.getAllRoutes(from, to, mode: _routeMode);
      }
      if (!mounted || allRoutes.isEmpty) {
        debugPrint('[Nav] Reroute FAILED: no routes returned. Will retry in 5s.');
        setState(() => _isCalculatingRoute = false);
        // Reset so reroute can retry after next 3 off-route fixes
        _offRouteAsked = false;
        _offRouteCount = 0;
        return;
      }

      // Pick route based on mode (same logic as _calculateRoute)
      int primaryIdx = 0;
      if (_routeMode == RouteMode.biker && allRoutes.length > 1) {
        final sorted = List<OsrmRoute>.from(allRoutes)
          ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
        primaryIdx = allRoutes.indexOf(sorted.last);
      }

      final route = allRoutes[primaryIdx];
      debugPrint('[Nav] Rerouted: ${route.distanceText}, ${route.durationText}');

      setState(() {
        _alternativeRoutes = allRoutes;
        _selectedRouteIndex = primaryIdx;
        _currentRoute = route;
        _isCalculatingRoute = false;
        // Force polyline cache rebuild so blue line updates on map
        _cachedPolylines = null;
        _cachedPolylineRoute = null;
        // Reset step tracking for new route
        _lastAnnouncedStepIndex = -1;
        _announcedTtsPairs.clear();
        // DON'T reset _offRouteAsked here — only reset when back on route
        // Otherwise it immediately re-triggers off-route on the new route
        _offRouteCount = 0;
      });

      // Update NavEngine with new route (so TTS + turn tracking works on new route)
      _navEngine.setRoute(route, destination: to, mode: _routeMode);
      _navEngine.start(currentPos: _currentGpsPos);
      // Reset off-route after short delay (give GPS time to snap to new route)
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          _offRouteAsked = false;
          _offRouteCount = 0;
        }
      });

      // Reload enrichment for new route
      _loadRouteEnrichment(route, to);

      // Reroute announcement with first turn instruction
      TtsAlertService.instance.clearQueue();
      TtsAlertService.instance.speakQueued(
        'Neue Route. ${route.distanceText}, ${route.durationText}.',
      );
      // Add first turn instruction to reroute announcement
      if (route.steps.length > 1 && _currentGpsPos != null) {
        for (final s in route.steps) {
          if (s.maneuver.startsWith('depart')) continue;
          final dist = _formatDistance(_distLatLng(_currentGpsPos!, s.location));
          final hasRoad = s.roadName != null && s.roadName!.isNotEmpty
              && s.instruction.toLowerCase().contains(s.roadName!.toLowerCase());
          final road = (s.roadName != null && s.roadName!.isNotEmpty && !hasRoad)
              ? ' auf ${s.roadName}' : '';
          TtsAlertService.instance.speakQueued(
            'Weiter für $dist, dann ${s.instruction}$road',
          );
          break;
        }
      }
    } catch (e) {
      debugPrint('[Nav] Reroute error: $e');
      if (mounted) setState(() => _isCalculatingRoute = false);
    }
  }

  /// Load enrichment data for the current route (background, non-blocking).
  /// Fetches: destination info, blitzer count on route, POIs along route.
  Future<void> _loadRouteEnrichment(OsrmRoute route, LatLng destination) async {
    if (_isLoadingRouteInfo) return;
    setState(() => _isLoadingRouteInfo = true);

    try {
      // Get destination name: prefer locally stored name, then group DB
      final rideState = ref.read(groupRideProvider(widget.groupId));
      final destName = _lastDestinationName ?? rideState.group?.destinationName;

      // Run fast queries in parallel (dest info, blitzer, countries)
      // Fuel is loaded separately in background — it's slow (batched Overpass)
      final results = await Future.wait([
        // 1. Destination info (population, Wikipedia, POIs at destination)
        _destInfoService.fetchAll(
          cityName: destName,
          location: destination,
          onUpdate: (updated) {
            if (mounted) setState(() => _destinationInfo = updated);
          },
        ),
        // 2. Blitzer positions on route
        _findBlitzerOnRoute(route),
        // 3. Country borders along route
        _detectCountryBorders(route),
      ]);

      if (!mounted) return;

      final destInfo = results[0] as DestinationInfo;
      final blitzerPositions = results[1] as List<LatLng>;
      final countrySegments = results[2] as List<_CountrySegment>;

      setState(() {
        _destinationInfo = destInfo;
        _routeBlitzerPositions = blitzerPositions;
        _routeBlitzerCount = blitzerPositions.length;
        _routeCountrySegments = countrySegments;
        _isLoadingRouteInfo = false;
        // Start collapsed — user taps to expand individual countries
        _expandedCountries.clear();
        _cachedRouteStepWidgets = null; // invalidate cache
      });

      // 4. Fuel stations — load in background, update UI after each batch
      _loadFuelInBackground(route);

      debugPrint('[Nav] Route enrichment done: blitzer=${blitzerPositions.length}, '
          'countries=${countrySegments.length} (fuel loading in background)');
    } catch (e) {
      debugPrint('[Nav] Route enrichment error: $e');
      if (mounted) setState(() => _isLoadingRouteInfo = false);
    }
  }

  /// Load fuel stations in background — updates UI after each batch.
  Future<void> _loadFuelInBackground(OsrmRoute route) async {
    try {
      final routePois = await _destInfoService.getAlongRoutePoiCounts(route.polylinePoints);
      if (!mounted) return;
      setState(() {
        _routePois = routePois;
      });
      debugPrint('[Nav] Fuel loaded: ${routePois.fuel.length} Tankstellen');
    } catch (e) {
      debugPrint('[Nav] Fuel loading error: $e');
    }
  }

  /// Find speed cameras along a route polyline via Overpass API.
  /// Returns list of positions (for map markers) — count = list.length.
  Future<List<LatLng>> _findBlitzerOnRoute(OsrmRoute route) async {
    try {
      // Sample polyline every ~30km for Overpass query
      final samples = <LatLng>[];
      double accumulated = 0;
      samples.add(route.polylinePoints.first);
      for (int i = 1; i < route.polylinePoints.length; i++) {
        final prev = route.polylinePoints[i - 1];
        final curr = route.polylinePoints[i];
        final dx = (curr.latitude - prev.latitude);
        final dy = (curr.longitude - prev.longitude);
        accumulated += math.sqrt(dx * dx + dy * dy) * 111; // ~km
        if (accumulated >= 30) {
          samples.add(curr);
          accumulated = 0;
        }
      }
      if (samples.length > 15) {
        final step = samples.length / 15;
        final limited = List.generate(15, (i) => samples[(i * step).floor()]);
        samples
          ..clear()
          ..addAll(limited);
      }

      // Build Overpass query — use 'out body' to get positions
      final buffer = StringBuffer('[out:json][timeout:30];(');
      for (final pt in samples) {
        buffer.write('node["highway"="speed_camera"](around:1000,${pt.latitude},${pt.longitude});');
        buffer.write('node["enforcement"="maxspeed"](around:1000,${pt.latitude},${pt.longitude});');
      }
      buffer.write(');out body;');

      final response = await http.post(
        Uri.parse('https://overpass-api.de/api/interpreter'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'data=${Uri.encodeComponent(buffer.toString())}',
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final elements = data['elements'] as List<dynamic>? ?? [];
      final positions = <LatLng>[];
      final seen = <String>{}; // deduplicate by id
      for (final el in elements) {
        if (el is Map<String, dynamic> && el['lat'] != null && el['lon'] != null) {
          final id = '${el['id']}';
          if (seen.add(id)) {
            positions.add(LatLng(
              (el['lat'] as num).toDouble(),
              (el['lon'] as num).toDouble(),
            ));
          }
        }
      }
      return positions;
    } catch (e) {
      debugPrint('[Nav] Blitzer search error: $e');
      return [];
    }
  }

  /// Detect country borders along a route by sampling step locations.
  /// Returns list of country segments keyed by grouped-step index.
  Future<List<_CountrySegment>> _detectCountryBorders(OsrmRoute route) async {
    try {
      final steps = route.steps.where((s) =>
        s.maneuver != 'depart' && s.maneuver != 'arrive' &&
        (s.roadName ?? '').trim().isNotEmpty
      ).toList();
      if (steps.isEmpty) return [];

      // Group steps into road sections (same logic as _buildRouteSteps)
      // and pick one sample location per section
      final sectionLocations = <LatLng>[];
      String? currentRoad;
      for (final step in steps) {
        final road = (step.roadName ?? '').trim();
        if (road != currentRoad) {
          sectionLocations.add(step.location);
          currentRoad = road;
        }
      }

      // Sample every ~5 sections (or fewer for short routes), always include first + last
      final sampleIndices = <int>{0, sectionLocations.length - 1};
      final step = (sectionLocations.length / 8).ceil().clamp(1, 10);
      for (int i = 0; i < sectionLocations.length; i += step) {
        sampleIndices.add(i);
      }
      final sortedIndices = sampleIndices.toList()..sort();

      final geocoder = GeocodingService();
      // Geocode each sample point (with 1.1s delay to respect Nominatim rate limit)
      final indexToCountry = <int, String>{};
      for (int j = 0; j < sortedIndices.length; j++) {
        final i = sortedIndices[j];
        if (j > 0) await Future.delayed(const Duration(milliseconds: 1100));
        final code = await geocoder.reverseGeocodeCountryCode(
          sectionLocations[i].latitude, sectionLocations[i].longitude);
        if (code != null) indexToCountry[i] = code;
      }

      // Interpolate: fill gaps by nearest known country
      final allCountries = List<String?>.filled(sectionLocations.length, null);
      for (final e in indexToCountry.entries) {
        allCountries[e.key] = e.value;
      }
      // Forward fill
      String? last;
      for (int i = 0; i < allCountries.length; i++) {
        if (allCountries[i] != null) last = allCountries[i];
        else allCountries[i] = last;
      }

      // Build segments: only where country changes
      final segments = <_CountrySegment>[];
      String? prevCode;
      for (int i = 0; i < allCountries.length; i++) {
        if (allCountries[i] != null && allCountries[i] != prevCode) {
          segments.add(_CountrySegment(groupedStepIndex: i, countryCode: allCountries[i]!));
          prevCode = allCountries[i];
        }
      }

      debugPrint('[Nav] Country borders detected: ${segments.map((s) => '${s.countryCode}@step${s.groupedStepIndex}').join(' → ')}');
      return segments;
    } catch (e) {
      debugPrint('[Nav] Country border detection error: $e');
      return [];
    }
  }

  void _fitCameraToRoute(OsrmRoute route) {
    if (route.polylinePoints.length < 2) return;
    setState(() => _isNavFollowing = false);
    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (final p in route.polylinePoints) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    _isProgrammaticMove = true;
    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      ),
      80,
    )).then((_) => _isProgrammaticMove = false);
  }

  // ═══════════════════════════════════════════════════
  //  BLITZER ALERT BANNER
  // ═══════════════════════════════════════════════════

  Widget _buildBlitzerBanner(GroupRideState rideState) {
    final alert = rideState.currentAlert!;
    final isImmediate = alert.stage == AlertStage.immediate;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 80,
      left: 16, right: 16,
      child: AnimatedBuilder(
        animation: _alertPulseController,
        builder: (context, child) {
          final opacity = isImmediate
              ? 0.85 + (_alertPulseController.value * 0.15)
              : 0.9;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isImmediate
                  ? Color.lerp(Colors.red.shade900, Colors.red.shade700, _alertPulseController.value)
                  : Colors.orange.shade900.withValues(alpha: opacity),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isImmediate ? Colors.red : Colors.orange,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isImmediate ? Colors.red : Colors.orange).withValues(alpha: 0.4),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  isImmediate ? Icons.warning_amber_rounded : Icons.radar_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        alert.warningText,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (alert.report.speedLimit != null)
                        Text(
                          'Limit: ${alert.report.speedLimit} km/h',
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    alert.distanceText,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // (_buildDestinationBar removed — integrated into _buildDestinationCard in top bar)

  // ═══════════════════════════════════════════════════
  //  FIXED NAV ARROW (Waze-style — arrow stays fixed, map moves underneath)
  // ═══════════════════════════════════════════════════

  Widget _buildFixedNavArrow() {
    return Positioned(
      // Position at ~75% from top (bottom quarter of screen)
      bottom: MediaQuery.of(context).size.height * 0.22,
      left: 0,
      right: 0,
      child: Center(
        child: IgnorePointer(
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF00BCD4),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00BCD4).withValues(alpha: 0.4),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.navigation_rounded, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  TURN INSTRUCTION BANNER (Navi-Schild)
  // ═══════════════════════════════════════════════════

  Widget _buildTurnBanner() {
    final step = _nextTurnStep!;
    final dist = _nextTurnDistanceM;
    final maneuver = _maneuverIcon(step.maneuver);

    // Distance text
    final distText = dist < 1000
        ? '${(dist / 10).round() * 10} m'
        : '${(dist / 100).round() / 10} km';

    // Road name (if available)
    final roadName = step.roadName;

    // Urgency color — closer = more intense
    final urgencyColor = dist < 100
        ? Colors.orange
        : dist < 300
            ? const Color(0xFF00BCD4)
            : const Color(0xFF263250);

    return Positioned(
      top: 0, left: 0, right: 0,
      child: AnimatedOpacity(
        opacity: _mapInteracting ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: SafeArea(
          bottom: false,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: urgencyColor.withValues(alpha: dist < 100 ? 0.95 : 0.92),
              borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  // Maneuver icon (large)
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(maneuver.icon, color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 14),
                  // Distance + instruction
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          distText,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          step.instruction,
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (roadName != null && roadName.isNotEmpty)
                          Text(
                            roadName,
                            style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              // ── "Danach:" next step preview ──
              if (_afterNextTurnStep != null && _afterNextTurnStep!.maneuver != 'arrive') ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    Icon(
                      _maneuverIcon(_afterNextTurnStep!.maneuver).icon,
                      color: Colors.white.withValues(alpha: 0.7),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text('Danach: ', style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.8),
                    )),
                    Expanded(child: Text(
                      _afterNextTurnStep!.instruction,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.65),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )),
                  ]),
                ),
              ],
            ],
          ),
        ),
      ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  SPEED DISPLAY
  // ═══════════════════════════════════════════════════

  Widget _buildSpeedDisplay(GroupRideState rideState) {
    // Ultra-smooth speed: EMA + buffer + lerp (smoother than Waze)
    final speed = _displaySpeed.round();
    final limit = _speedLimit.effectiveLimitKmh;
    final hasLimit = _speedLimit.hasLimit || _speedLimit.roadType != null;
    final isUnlimited = _speedLimit.isUnlimited;
    // Speeding: red when over limit+5 (tolerance), or over 130 if no limit known
    final isSpeeding = _isSpeeding || (!hasLimit && speed > 130);

    return Positioned(
      left: 16,
      bottom: _currentRoute != null ? 100 : 16,
      child: AnimatedOpacity(
        opacity: _mapInteracting ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Speed limit sign (European style: white circle, red border) ──
            if (hasLimit && _currentRoute != null)
            _buildSpeedLimitSign(limit, isUnlimited, isSpeeding),
          if (hasLimit && _currentRoute != null)
            const SizedBox(height: 6),
          // Waze-style speed bubble (now turns red when speeding)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: isSpeeding
                  ? const Color(0xF0C62828)
                  : const Color(0xF01B1F2B),
              shape: BoxShape.circle,
              border: Border.all(
                color: isSpeeding ? Colors.redAccent : Colors.white24,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSpeeding
                      ? Colors.red.withValues(alpha: 0.5)
                      : Colors.black.withValues(alpha: 0.5),
                  blurRadius: isSpeeding ? 20 : 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$speed',
                  style: GoogleFonts.inter(
                    color: isSpeeding ? const Color(0xFFFF5252) : Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                Text(
                  'km/h',
                  style: GoogleFonts.inter(
                    color: isSpeeding ? Colors.red.shade200 : Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Toggle: Route overview ↔ Driving view / Center on GPS
          GestureDetector(
              onTap: () {
                if (_currentRoute != null && _isNavFollowing) {
                  // Currently in driving view → switch to route overview
                  _fitCameraToRoute(_currentRoute!); // sets _isNavFollowing = false
                } else if (_currentRoute != null) {
                  // Currently in route overview → switch back to driving view
                  // Same as _startNavigation: north-up, fixed offset, no tilt
                  // Timer handles heading rotation once user starts moving
                  _isNavFollowing = true;
                  _currentZoom = 17.0;
                  if (_currentGpsPos != null && _mapController != null) {
                    // Re-center: snap to current bearing, restart camera loop
                    _isProgrammaticMove = true;
                    _lastProgrammaticMoveTime = DateTime.now();
                    _smoothZoom = 17.0;
                    _navCameraDirty = true;
                    _mapController!.moveCamera(
                      CameraUpdate.newCameraPosition(gmaps.CameraPosition(
                        target: _currentGpsPos!,
                        zoom: 17.0,
                        bearing: _smoothBearing,
                        tilt: 45,
                      )),
                    );
                  }
                  setState(() {});
                } else if (_currentGpsPos != null && _mapController != null) {
                  // No route → re-center with heading follow
                  setState(() => _isNavFollowing = true);
                  _startHeadingFollowTimer();
                } else {
                  final rs = ref.read(groupRideProvider(widget.groupId));
                  _centerOnGroup(rs);
                }
              },
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: _isNavFollowing
                      ? Colors.blueAccent.withValues(alpha: 0.3)
                      : const Color(0xF01B1F2B),
                  shape: BoxShape.circle,
                  border: _isNavFollowing
                      ? Border.all(color: Colors.blueAccent, width: 2)
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Icon(
                  _isNavFollowing ? Icons.navigation_rounded : Icons.map_rounded,
                  color: _isNavFollowing ? Colors.blueAccent : Colors.white70,
                  size: 20,
                ),
              ),
            ),
          const SizedBox(height: 8),
          // Zoom in button
          _zoomButton(Icons.add_rounded, 1),
          const SizedBox(height: 4),
          // Zoom out button
          _zoomButton(Icons.remove_rounded, -1),
        ],
      ),
      ),
    );
  }

  Widget _zoomButton(IconData icon, double zoomDelta) {
    return GestureDetector(
      onTap: () {
        _currentZoom = (_currentZoom + zoomDelta).clamp(5.0, 20.0);
        // Apply zoom immediately via animateCamera
        _mapController?.animateCamera(CameraUpdate.zoomTo(_currentZoom));
      },
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: const Color(0xF01B1F2B),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 6),
          ],
        ),
        child: Icon(icon, color: Colors.white70, size: 20),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  SPEED LIMIT SIGN (European style)
  // ═══════════════════════════════════════════════════

  Widget _buildSpeedLimitSign(int limitKmh, bool isUnlimited, bool isSpeeding) {
    // European speed limit sign: white circle with thick red border
    // Unlimited (Autobahn): white circle with diagonal grey stripes
    return AnimatedScale(
      scale: isSpeeding ? 1.15 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        width: 64, height: 64,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: isUnlimited ? Colors.grey.shade400 : const Color(0xFFCC0000),
            width: isUnlimited ? 3 : 5,
          ),
          boxShadow: [
            BoxShadow(
              color: isSpeeding
                  ? Colors.red.withValues(alpha: 0.6)
                  : Colors.black.withValues(alpha: 0.4),
              blurRadius: isSpeeding ? 16 : 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: isUnlimited
            // Diagonal stripes for "Ende aller Beschränkungen"
            ? ClipOval(
                child: CustomPaint(
                  size: const Size(54, 54),
                  painter: _UnlimitedSignPainter(),
                ),
              )
            : Center(
                child: Text(
                  '$limitKmh',
                  style: GoogleFonts.inter(
                    color: Colors.black,
                    fontSize: limitKmh >= 100 ? 20 : 24,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  VIDEO GRID (LiveKit)
  // ═══════════════════════════════════════════════════

  Widget _buildVideoGrid() {
    final liveKit = LiveKitService.instance;
    final remoteTracks = liveKit.remoteVideoTracks;
    final localTrack = liveKit.localVideoTrack;

    if (remoteTracks.isEmpty && localTrack == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: 12,
      top: MediaQuery.of(context).padding.top + 100,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Local preview
          if (localTrack != null)
            _buildVideoTile(localTrack, 'Du'),

          // Remote participants
          for (final entry in remoteTracks.take(3))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _buildVideoTile(
                entry.value,
                liveKit.remoteParticipants[entry.key]?.name ?? '?',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoTile(VideoTrack track, String label) {
    return Container(
      width: 90, height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          VideoTrackRenderer(
            track,
            fit: VideoViewFit.cover,
          ),
          Positioned(
            bottom: 4, left: 4, right: 4,
            child: Text(
              label,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600,
                shadows: [const Shadow(blurRadius: 4, color: Colors.black)],
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  VOICE LISTENING OVERLAY
  // ═══════════════════════════════════════════════════

  Widget _buildListeningOverlay() {
    return Positioned(
      left: 16, right: 16,
      bottom: 240,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xF01B1F2B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.withValues(alpha: 0.5), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withValues(alpha: 0.2),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green,
                    boxShadow: [
                      BoxShadow(color: Colors.green.withValues(alpha: 0.6), blurRadius: 8),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Höre zu...',
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            if (_listenText.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '"$_listenText"',
                style: GoogleFonts.inter(color: Colors.greenAccent, fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              '"Tankstelle" · "Kamera an" · "Blitzer melden"',
              style: GoogleFonts.inter(color: Colors.white30, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  BOTTOM CONTROLS
  // ═══════════════════════════════════════════════════

  Widget _buildBottomControls(GroupRideState rideState, Color accentColor) {
    return Positioned(
      right: 16, bottom: _currentRoute != null ? 100 : 24,
      child: AnimatedOpacity(
        opacity: _mapInteracting ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(
          ignoring: _mapInteracting,
          child: SafeArea(
            top: false,
            child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Info button — shows voice command list ──
            if (_currentGpsPos != null)
            GestureDetector(
              onTap: _showVoiceCommandList,
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF2D3446),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.info_outline_rounded, color: Colors.white54, size: 18),
              ),
            ),

            if (_currentGpsPos != null)
            const SizedBox(height: 8),

            // ── "Hi Moto" voice button — only when GPS is active ──
            if (_currentGpsPos != null)
            GestureDetector(
              onTap: () => _toggleWakeWord(),
              onLongPress: () => _startVoiceQuery(),
              child: Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: _wakeWordTriggered
                      ? Colors.green
                      : _sosActive
                          ? Colors.red.shade700
                          : _wakeWordActive
                              ? const Color(0xFF1B5E20)
                              : const Color(0xFF2D3446),
                  shape: BoxShape.circle,
                  border: _wakeWordActive
                      ? Border.all(color: Colors.green, width: 2)
                      : _sosActive
                          ? Border.all(color: Colors.red, width: 2)
                          : null,
                  boxShadow: [
                    BoxShadow(
                      color: _sosActive
                          ? Colors.red.withValues(alpha: 0.5)
                          : _wakeWordActive
                              ? Colors.green.withValues(alpha: 0.4)
                              : Colors.black.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: _wakeWordTriggered
                    ? const Icon(Icons.hearing_rounded, color: Colors.white, size: 24)
                    : _sosActive
                        ? AnimatedOpacity(
                            opacity: _sosBlinkVisible ? 1.0 : 0.3,
                            duration: const Duration(milliseconds: 200),
                            child: const Icon(Icons.sos_rounded, color: Colors.white, size: 24),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Hi', style: GoogleFonts.inter(
                                color: _wakeWordActive ? Colors.greenAccent : Colors.white70,
                                fontSize: 10, fontWeight: FontWeight.w600)),
                              Text('Moto', style: GoogleFonts.inter(
                                color: _wakeWordActive ? Colors.greenAccent : Colors.white,
                                fontSize: 12, fontWeight: FontWeight.w800)),
                            ],
                          ),
              ),
            ),
          ],
        ),
      ),
        ),
      ),
    );
  }

  Widget _wazeActionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: isActive
                  ? color.withValues(alpha: 0.2)
                  : const Color(0xFF2D3446),
              shape: BoxShape.circle,
              border: isActive ? Border.all(color: color, width: 2) : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: isActive ? color : Colors.white, size: 22),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white60,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  VOICE COMMAND LIST (Info sheet)
  // ═══════════════════════════════════════════════════

  void _showVoiceCommandList() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        expand: false,
        builder: (ctx, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2)),
              )),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.mic_rounded, color: Colors.greenAccent, size: 22),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Hi Moto — Dein Biker-KI-Kumpel',
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis)),
                ],
              ),
              const SizedBox(height: 6),
              Text('Sage "Hi Moto" und dann einen Befehl oder stell eine Frage!\nFunktioniert auch während der Navigation per Sprache.',
                style: GoogleFonts.inter(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 16),

              // ── POI Suche ──
              _sectionHeader('POI Suche — Top 3 mit Bewertungen'),
              _commandRow(Icons.local_gas_station_rounded, Colors.amber, '"Tankstelle"', 'Nächste 3 Tankstellen mit Google-Bewertung'),
              _commandRow(Icons.restaurant_rounded, Colors.deepOrange, '"Restaurant"', 'Restaurants, Imbiss, Döner, Pizza in der Nähe'),
              _commandRow(Icons.build_rounded, Colors.blueAccent, '"Werkstatt"', 'Motorrad-Werkstatt finden'),
              _commandRow(Icons.shopping_cart_rounded, Colors.teal, '"Shop"', 'Supermarkt, Kiosk, Laden'),
              const SizedBox(height: 8),

              // ── Aktionen ──
              _sectionHeader('Aktionen'),
              _commandRow(Icons.radar_rounded, Colors.orange.shade300, '"Blitzer"', 'Nächste 3 Blitzer mit Entfernung ansagen'),
              _commandRow(Icons.warning_amber_rounded, Colors.orange, '"Blitzer melden"', 'Neuen Blitzer an Gruppe melden'),
              _commandRow(Icons.videocam_rounded, Colors.blue, '"Kamera an/aus"', 'Dashcam / Live-Kamera umschalten'),
              _commandRow(Icons.mic_off_rounded, Colors.purple, '"Mikrofon stumm"', 'Mikrofon muten/unmuten'),
              _commandRow(Icons.sos_rounded, Colors.red, '"SOS" / "Hilfe"', 'Notruf an die Gruppe senden'),
              _commandRow(Icons.navigation_rounded, Colors.cyan, '"Navigation stoppen"', 'Aktive Route abbrechen'),
              _commandRow(Icons.logout_rounded, Colors.red.shade300, '"Fahrt beenden"', 'Gruppe verlassen'),
              const SizedBox(height: 8),

              // ── KI Assistent ──
              _sectionHeader('Moto KI — Frag einfach drauf los!'),
              _commandRow(Icons.cloud_rounded, Colors.lightBlue, '"Wie wird das Wetter?"', 'Wetter an deinem Standort'),
              _commandRow(Icons.speed_rounded, Colors.greenAccent, '"Wie schnell bin ich?"', 'Aktuelle Speed + Standort'),
              _commandRow(Icons.map_rounded, Colors.lime, '"Wie weit noch?"', 'Restdistanz wenn Navigation aktiv'),
              _commandRow(Icons.tips_and_updates_rounded, Colors.yellow, '"Gibt es schöne Strecken?"', 'Routentipps für Biker'),
              _commandRow(Icons.smart_toy_rounded, Colors.pinkAccent, 'Alles andere...', 'Moto antwortet auf jede Frage!'),
              const SizedBox(height: 16),

              // ── Tipps ──
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tipps',
                      style: GoogleFonts.inter(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text('• Langes Drücken auf "Hi Moto" = sofort sprechen\n'
                         '• Sage 1, 2 oder 3 — oder warte, Moto fährt automatisch zur 1\n'
                         '• Perfekt mit Handschuhen — alles per Sprache steuerbar\n'
                         '• Blitzer-Warnungen kommen automatisch bei 800m und 200m',
                      style: GoogleFonts.inter(color: Colors.white38, fontSize: 11, height: 1.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 4),
      child: Text(title,
        style: GoogleFonts.inter(color: Colors.greenAccent.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
    );
  }

  Widget _commandRow(IconData icon, Color color, String command, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: command,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  TextSpan(
                    text: '  —  $description',
                    style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  NAV UI AUTO-HIDE (tap to show for 5s)
  // ═══════════════════════════════════════════════════

  void _showNavUiTemporarily() {
    if (!_isNavigating) return;
    setState(() => _navUiHidden = false);
    _navUiShowTimer?.cancel();
    _navUiShowTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _isNavigating) {
        setState(() => _navUiHidden = true);
      }
    });
  }

  // ═══════════════════════════════════════════════════
  //  SOS (Long-Press 3s)
  // ═══════════════════════════════════════════════════

  Widget _buildSosButton() {
    if (_sosActive) {
      // SOS aktiv → pulsierender roter Button, Tap zum Deaktivieren
      return GestureDetector(
        onTap: _showDeactivateSosDialog,
        child: AnimatedOpacity(
          opacity: _sosBlinkVisible ? 1.0 : 0.4,
          duration: const Duration(milliseconds: 300),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: Colors.red.shade700,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.red.withValues(alpha: 0.5), blurRadius: 12, spreadRadius: 2),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.sos, color: Colors.white, size: 24),
                ),
              ),
              const SizedBox(height: 4),
              Text('SOS', style: GoogleFonts.inter(
                color: Colors.red, fontSize: 10, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      );
    }

    // SOS inaktiv → Long-Press zum Aktivieren
    return _SosLongPressButton(
      onSosActivated: _activateSos,
    );
  }

  void _activateSos() {
    if (!mounted) return;
    HapticFeedback.heavyImpact();

    // SOS-Alarmton abspielen
    AlertAudioService.instance.playSosAlarm();

    setState(() {
      _sosActive = true;
      _sosBlinkVisible = true;
    });

    // Blink-Timer starten (500ms toggle)
    _sosBlinkTimer?.cancel();
    _sosBlinkTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) {
        _sosBlinkTimer?.cancel();
        return;
      }
      setState(() => _sosBlinkVisible = !_sosBlinkVisible);
    });

    // SOS über Presence broadcasten
    try {
      ref.read(liveLocationServiceProvider).setSosActive(true);
    } catch (e) {
      debugPrint('[GroupRide] SOS broadcast error: $e');
    }

    // SOS-Nachricht im Gruppenchat senden
    final notifier = ref.read(groupRideProvider(widget.groupId).notifier);
    notifier.sendMessage('🆘 SOS! Ich brauche Hilfe!');

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.sos, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('SOS gesendet! Deine Gruppe sieht deinen Standort.',
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
      debugPrint('[GroupRide] SOS deactivate error: $e');
    }

    // Entwarnung im Chat
    final notifier = ref.read(groupRideProvider(widget.groupId).notifier);
    notifier.sendMessage('✅ SOS aufgehoben — alles OK!');
  }

  void _showDeactivateSosDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2230),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.sos, color: Colors.red.shade400, size: 28),
            const SizedBox(width: 12),
            const Text('SOS deaktivieren?', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'Dein SOS-Signal wird beendet und deine Gruppe wird benachrichtigt.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deactivateSos();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Entwarnung', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  ACTIONS
  // ═══════════════════════════════════════════════════

  Future<void> _toggleCamera() async {
    final notifier = ref.read(groupRideProvider(widget.groupId).notifier);
    final rideState = ref.read(groupRideProvider(widget.groupId));

    if (!rideState.isCameraActive) {
      // Connect to LiveKit for video (mic stays muted)
      if (!rideState.isVoiceActive) {
        await notifier.joinVoice(); // establishes LiveKit connection
      }
      await notifier.toggleCamera();
      setState(() => _showVideoGrid = true);
    } else {
      await notifier.toggleCamera();
      // Always hide grid when user turns off camera (no remote participants in solo ride)
      final liveKit = LiveKitService.instance;
      final hasRemote = liveKit.remoteVideoTracks.isNotEmpty;
      setState(() => _showVideoGrid = hasRemote); // keep grid only if others are streaming
    }
  }

  void _openNavigation(dynamic group) {
    final lat = group.destinationLat;
    final lng = group.destinationLng;
    if (lat == null || lng == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Navigation öffnen', style: GoogleFonts.inter(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _navOption(ctx, 'Google Maps', Icons.map_rounded, Colors.green,
                'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving'),
            const SizedBox(height: 8),
            _navOption(ctx, 'Waze (inkl. Blitzer)', Icons.radar_rounded, Colors.blue,
                'https://waze.com/ul?ll=$lat,$lng&navigate=yes'),
            const SizedBox(height: 8),
            _navOption(ctx, 'Standard Navigation', Icons.navigation_rounded, Colors.orange,
                'geo:$lat,$lng?q=$lat,$lng'),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _navOption(BuildContext ctx, String title, IconData icon, Color color, String url) {
    return ListTile(
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.open_in_new_rounded, color: Colors.white38, size: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: Colors.white.withValues(alpha: 0.05),
      onTap: () {
        Navigator.of(ctx).pop();
        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      },
    );
  }

  void _reportBlitzer() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Blitzer melden', style: GoogleFonts.inter(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'Warnung wird an alle Gruppenmitglieder gesendet',
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 16),
            _blitzerReportOption(ctx, 'Mobiler Blitzer', Icons.speed_rounded, Colors.orange, 'mobile'),
            const SizedBox(height: 6),
            _blitzerReportOption(ctx, 'Fester Blitzer', Icons.camera_alt_rounded, Colors.red, 'fixed'),
            const SizedBox(height: 6),
            _blitzerReportOption(ctx, 'Polizeikontrolle', Icons.local_police_rounded, Colors.blue, 'police'),
            const SizedBox(height: 6),
            _blitzerReportOption(ctx, 'Baustelle / Gefahr', Icons.construction_rounded, Colors.amber, 'construction'),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _blitzerReportOption(BuildContext ctx, String title, IconData icon, Color color, String type) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: Colors.white.withValues(alpha: 0.05),
      onTap: () {
        Navigator.of(ctx).pop();
        _sendBlitzerWarning(type, title);
      },
    );
  }

  void _sendBlitzerWarning(String type, String label) {
    // 1. Send warning to group chat
    ref.read(groupRideProvider(widget.groupId).notifier)
        .sendMessage('🚨 $label voraus! Vorsicht!');
    HapticFeedback.heavyImpact();

    // 2. Save to database so it appears on the map
    if (_currentGpsPos != null) {
      _saveBlitzerToDatabase(type, label);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label an Gruppe gemeldet'),
        backgroundColor: Colors.orange.shade800,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _saveBlitzerToDatabase(String type, String label) async {
    try {
      final repo = BlitzerRepository();
      await repo.createReport(
        latitude: _currentGpsPos!.latitude,
        longitude: _currentGpsPos!.longitude,
        type: type,
        description: 'Gemeldet aus Gruppenfahrt',
      );
      debugPrint('[GroupRide] Blitzer saved to DB: $type at ${_currentGpsPos}');
      // Force reload to show new marker immediately
      _lastBlitzerLoad = null;
      _loadNearbyBlitzers();
    } catch (e) {
      debugPrint('[GroupRide] Blitzer DB save failed: $e');
    }
  }

  /// Subscribe to Supabase Realtime for instant blitzer marker updates on map.
  void _startBlitzerRealtime() {
    try {
      final repo = BlitzerRepository();
      _blitzerRealtimeChannel = repo.subscribeToBlitzerReports(
        onNewReport: (report) {
          if (!mounted) return;
          final myUserId = Supabase.instance.client.auth.currentUser?.id;
          if (report.userId == myUserId) return;
          if (!report.isActive || report.isExpired) return;
          if (_nearbyBlitzerReports.any((r) => r.id == report.id)) return;

          // Check proximity
          if (_currentGpsPos != null) {
            final dist = Geolocator.distanceBetween(
              _currentGpsPos!.latitude, _currentGpsPos!.longitude,
              report.latitude, report.longitude,
            );
            if (dist > 50000) return;
          }

          debugPrint('[GroupRide RT] Neuer Blitzer auf Karte: ${report.typeLabel} (id=${report.id})');
          setState(() => _nearbyBlitzerReports.add(report));
          _buildCommunityBlitzerMarkers();
        },
        onUpdate: (report) {
          if (!mounted) return;
          final idx = _nearbyBlitzerReports.indexWhere((r) => r.id == report.id);
          if (idx == -1) return;
          if (!report.isActive) {
            setState(() => _nearbyBlitzerReports.removeAt(idx));
          } else {
            setState(() => _nearbyBlitzerReports[idx] = report);
          }
          _buildCommunityBlitzerMarkers();
        },
      );
      debugPrint('[GroupRide RT] Blitzer Realtime subscription active');
    } catch (e) {
      debugPrint('[GroupRide RT] Blitzer Realtime subscription failed: $e');
    }
  }

  /// Load nearby blitzers: community (Supabase) + OSM speed cameras (Overpass).
  bool _blitzerLoadedWithGps = false; // track if we ever loaded with GPS
  Future<void> _loadNearbyBlitzers() async {
    final gps = _currentGpsPos;
    if (gps == null) {
      debugPrint('[GroupRide] _loadNearbyBlitzers: GPS null, skipping');
      return;
    }
    final now = DateTime.now();
    if (_lastBlitzerLoad != null && now.difference(_lastBlitzerLoad!).inSeconds < 8) return;
    _lastBlitzerLoad = now;
    try {
      final repo = BlitzerRepository();
      final communityReports = await repo.getNearbyReports(
        latitude: gps.latitude,
        longitude: gps.longitude,
        radiusKm: 50, // 50km radius — show all blitzers in wide area
      );

      // Fetch OSM stationäre Blitzer (cached, refreshed daily)
      List<BlitzerReport> osmReports = [];
      try {
        final allCameras = await OsmBlitzerService.instance.getAllGermany();
        // Nur Blitzer im 5km Radius anzeigen
        final osmCameras = allCameras.where((c) =>
            OsmBlitzerService.distanceApprox(c.latitude, c.longitude, gps.latitude, gps.longitude) <= 5000).toList();
        osmReports = osmCameras.map((c) => BlitzerReport.fromOsm(c)).toList();
        debugPrint('[GroupRide] Screen blitzer: ${communityReports.length} community + ${osmReports.length} OSM');
      } catch (e) {
        debugPrint('[GroupRide] OSM blitzer load error: $e');
      }

      // Merge: community + OSM (deduplicate by proximity)
      final merged = [...communityReports];
      for (final osm in osmReports) {
        final hasCommunityNearby = communityReports.any((c) =>
            c.type == 'fixed' &&
            Geolocator.distanceBetween(
                c.latitude, c.longitude, osm.latitude, osm.longitude) < 50);
        if (!hasCommunityNearby) {
          merged.add(osm);
        }
      }

      if (mounted) {
        setState(() => _nearbyBlitzerReports = merged);
        if (merged.isNotEmpty) {
          debugPrint('[GroupRide] Loaded ${merged.length} nearby blitzers '
              '(${communityReports.length} community + ${osmReports.length} OSM)');
          _buildCommunityBlitzerMarkers();
        }
      }
    } catch (e) {
      debugPrint('[GroupRide] Load nearby blitzers failed: $e');
    }
  }

  // ── Custom blitzer marker icons (same style as community map) ──
  final Map<String, BitmapDescriptor> _blitzerIconCache = {};

  Future<BitmapDescriptor> _getBlitzerMarkerIcon(String type, {double opacity = 1.0}) async {
    final opacityKey = (opacity * 10).round();
    final cacheKey = '${type}_a$opacityKey';
    if (_blitzerIconCache.containsKey(cacheKey)) return _blitzerIconCache[cacheKey]!;

    final (iconData, color) = switch (type) {
      'fixed' => (Icons.photo_camera_rounded, Colors.red),
      'mobile' => (Icons.directions_car_rounded, Colors.orange),
      'construction' => (Icons.construction_rounded, Colors.amber),
      'police' => (Icons.local_police_rounded, Colors.blue),
      _ => (Icons.photo_camera_rounded, Colors.red),
    };

    const double size = 96;
    const double iconSize = 48;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));
    final alpha = opacity.clamp(0.0, 1.0);

    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2,
        Paint()..color = color.withValues(alpha: alpha));
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2 - 3,
        Paint()..color = Colors.white.withValues(alpha: alpha)..style = PaintingStyle.stroke..strokeWidth = 4);

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

    final descriptor = BitmapDescriptor.bytes(bytes, width: 40, height: 40);
    _blitzerIconCache[cacheKey] = descriptor;
    return descriptor;
  }

  /// Build community blitzer markers with custom icons (async).
  Future<void> _buildCommunityBlitzerMarkers() async {
    // Pre-build icons for all nearby reports so markers render with custom icons
    for (final report in _nearbyBlitzerReports) {
      await _getBlitzerMarkerIcon(report.type);
    }
    if (mounted) setState(() {}); // Trigger rebuild with cached icons
  }

  void _showBlitzerDetail(BlitzerReport report) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isOwnReport = currentUserId != null && report.userId == currentUserId;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with type icon + title + delete button
            Row(children: [
              _blitzerTypeIcon(report.type, 28),
              const SizedBox(width: 12),
              Expanded(child: Text(report.typeLabel,
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white))),
              IconButton(
                onPressed: () async {
                  final dialogTitle = isOwnReport ? 'Meldung löschen?' : 'Meldung entfernen?';
                  final dialogText = isOwnReport
                      ? 'Deine Meldung "${report.typeLabel}" wird für alle entfernt.'
                      : '"${report.typeLabel}" wird von deiner Karte entfernt.';
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (dlgCtx) => AlertDialog(
                      backgroundColor: const Color(0xFF1E1E1E),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: Text(dialogTitle, style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
                      content: Text(dialogText, style: GoogleFonts.inter(color: Colors.white70)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(dlgCtx, false),
                            child: Text('Abbrechen', style: GoogleFonts.inter(color: Colors.white54))),
                        TextButton(onPressed: () => Navigator.pop(dlgCtx, true),
                            child: Text('Entfernen', style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.w600))),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    // Remove from local state immediately
                    _nearbyBlitzerReports.removeWhere((r) => r.id == report.id);
                    if (mounted) {
                      Navigator.pop(context);
                      setState(() {});
                    }
                    // Persist deletion
                    try {
                      await BlitzerRepository().deleteReport(report.id);
                    } catch (e) {
                      debugPrint('[GroupRide] Blitzer delete failed: $e');
                    }
                    // Send group message so other users remove it too
                    ref.read(groupRideProvider(widget.groupId).notifier)
                        .sendMessage('🗑️ BLITZER_REMOVED:${report.id}');
                    // Force reload
                    _lastBlitzerLoad = null;
                    _loadNearbyBlitzers();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('${report.typeLabel} entfernt'),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 2),
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
              Text(report.description!, style: GoogleFonts.inter(fontSize: 14, color: Colors.white70)),
            ],
            const SizedBox(height: 16),
            // Confirm/dismiss counts
            Row(children: [
              const Icon(Icons.thumb_up_outlined, size: 16, color: Colors.white54),
              const SizedBox(width: 4),
              Text('${report.confirmations}', style: GoogleFonts.inter(fontSize: 13, color: Colors.white54)),
              const SizedBox(width: 16),
              const Icon(Icons.thumb_down_outlined, size: 16, color: Colors.white54),
              const SizedBox(width: 4),
              Text('${report.dismissals}', style: GoogleFonts.inter(fontSize: 13, color: Colors.white54)),
              const Spacer(),
              if (report.createdAt != null)
                Text(_blitzerTimeAgo(report.createdAt!), style: GoogleFonts.inter(fontSize: 12, color: Colors.white54)),
            ]),
            const SizedBox(height: 16),
            // Action buttons: Bestätigen + Ist weg
            Row(children: [
              Expanded(child: ElevatedButton.icon(
                onPressed: () async {
                  await BlitzerRepository().confirmReport(report.id);
                  if (mounted) Navigator.pop(context);
                  _lastBlitzerLoad = null;
                  _loadNearbyBlitzers();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('${report.typeLabel} bestätigt!'),
                      backgroundColor: const Color(0xFF00BCD4),
                      duration: const Duration(seconds: 2),
                    ));
                  }
                },
                icon: const Icon(Icons.thumb_up_rounded, size: 18),
                label: Text('Bestätigen', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BCD4), foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
              )),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton.icon(
                onPressed: () async {
                  await BlitzerRepository().dismissReport(report.id);
                  if (mounted) Navigator.pop(context);
                  _lastBlitzerLoad = null;
                  _loadNearbyBlitzers();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('${report.typeLabel} als "weg" gemeldet'),
                      backgroundColor: Colors.orange,
                      duration: const Duration(seconds: 2),
                    ));
                  }
                },
                icon: const Icon(Icons.close_rounded, size: 18),
                label: Text('Ist weg', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
              )),
            ]),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _blitzerTypeIcon(String type, double size) {
    final (iconData, color) = switch (type) {
      'fixed' => (Icons.photo_camera_rounded, Colors.red),
      'mobile' => (Icons.directions_car_rounded, Colors.orange),
      'construction' => (Icons.construction_rounded, Colors.amber),
      'police' => (Icons.local_police_rounded, Colors.blue),
      _ => (Icons.warning_rounded, Colors.red),
    };
    return Container(
      width: size + 8, height: size + 8,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
      child: Icon(iconData, color: color, size: size * 0.75),
    );
  }

  String _blitzerTimeAgo(DateTime created) {
    final diff = DateTime.now().difference(created);
    if (diff.inMinutes < 1) return 'Gerade eben';
    if (diff.inMinutes < 60) return 'vor ${diff.inMinutes} Min.';
    if (diff.inHours < 24) return 'vor ${diff.inHours} Std.';
    return 'vor ${diff.inDays} Tagen';
  }

  void _showLeaveDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text('Fahrt verlassen?', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text(
          'Du verlässt die Live-Karte und Blitzerwarnungen.',
          style: GoogleFonts.inter(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Abbrechen', style: GoogleFonts.inter(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(ctx).pop();
              _leaveRide();
            },
            child: Text('Verlassen', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _leaveRide() async {
    await ref.read(groupRideProvider(widget.groupId).notifier).leaveVoice();
    if (mounted) {
      context.pop();
    }
  }

  // ═══════════════════════════════════════════════════
  //  VOICE QUERY (POI search via speech)
  // ═══════════════════════════════════════════════════

  // ═══════════════════════════════════════════════════
  //  WAKE WORD "Hi Moto" — hands-free voice activation
  // ═══════════════════════════════════════════════════

  void _toggleWakeWord() {
    if (_wakeWordActive) {
      _stopWakeWord();
    } else {
      _startWakeWord();
    }
  }

  Future<void> _startWakeWord() async {
    if (_voskInitialized) {
      // Use Vosk (offline, always-on)
      await TtsAlertService.instance.stop();
      setState(() {
        _wakeWordActive = true;
        _wakeWordTriggered = false;
        _isListening = false;
        _listenText = '';
      });
      await VoskWakeWordService.instance.startListening();
      debugPrint('[WakeWord] Vosk wake word started');
    } else if (_speechAvailable) {
      // Fallback to speech_to_text
      await TtsAlertService.instance.stop();
      await _speech.stop();
      setState(() {
        _wakeWordActive = true;
        _wakeWordTriggered = false;
        _isListening = false;
        _listenText = '';
      });
      _startWakeWordListening();
    } else {
      _showManualPoiSearch();
    }
  }

  void _stopWakeWord() {
    _wakeWordRestartTimer?.cancel();
    if (_voskInitialized) {
      VoskWakeWordService.instance.stopListening();
    } else {
      _speech.stop();
    }
    setState(() {
      _wakeWordActive = false;
      _wakeWordTriggered = false;
      _isListening = false;
      _listenText = '';
    });
  }

  void _startWakeWordListening() async {
    if (!_wakeWordActive || !mounted) return;
    await _speech.stop();
    await Future.delayed(const Duration(milliseconds: 300));
    if (!_wakeWordActive || !mounted) return;

    debugPrint('[WakeWord] Starting wake word listener...');
    try {
      await _speech.listen(
        onResult: (result) {
          if (!mounted || !_wakeWordActive) return;
          final words = result.recognizedWords.toLowerCase().trim();
          debugPrint('[WakeWord] Heard: "$words" final=${result.finalResult}');

          if (!_wakeWordTriggered) {
            if (words.contains('hi moto') || words.contains('hey moto') ||
                words.contains('hi motto') || words.contains('hey motto') ||
                words.contains('hallo moto') || words.contains('hi motor') ||
                words.contains('high moto') || words.contains('hy moto')) {
              debugPrint('[WakeWord] TRIGGERED!');
              HapticFeedback.heavyImpact();
              TtsAlertService.instance.speakText('Ja Racer?');
              setState(() {
                _wakeWordTriggered = true;
                _listenText = '';
              });
              _speech.stop();
              Future.delayed(const Duration(milliseconds: 800), () {
                if (!mounted || !_wakeWordActive) return;
                _startCommandListening();
              });
            }
          }
        },
        onSoundLevelChange: (_) {}, // Keep alive
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 4),
        localeId: 'de_DE',
        listenMode: stt.ListenMode.dictation,
      );
    } catch (e) {
      debugPrint('[WakeWord] Listen error: $e');
    }

    // Use speech status to auto-restart when listener stops
    _speech.statusListener = (status) {
      debugPrint('[WakeWord] Status: $status');
      if (status == 'done' || status == 'notListening') {
        if (_wakeWordActive && !_wakeWordTriggered && mounted) {
          // Auto-restart after brief pause
          _wakeWordRestartTimer?.cancel();
          _wakeWordRestartTimer = Timer(const Duration(milliseconds: 500), () {
            if (_wakeWordActive && !_wakeWordTriggered && mounted) {
              debugPrint('[WakeWord] Auto-restarting listener...');
              _startWakeWordListening();
            }
          });
        }
      }
    };
  }

  void _startCommandListening() async {
    if (!_wakeWordActive || !mounted) return;

    setState(() => _isListening = true);

    try {
      await _speech.listen(
        onResult: (result) {
          if (!mounted || !_wakeWordActive) return;
          setState(() => _listenText = result.recognizedWords);

          if (result.finalResult && result.recognizedWords.isNotEmpty) {
            debugPrint('[WakeWord] Command: "${result.recognizedWords}"');
            _speech.stop();
            setState(() {
              _isListening = false;
              _wakeWordTriggered = false;
            });
            _processVoiceQuery(result.recognizedWords);
            // Go back to wake word listening
            Future.delayed(const Duration(seconds: 2), () {
              if (_wakeWordActive && mounted) _startWakeWordListening();
            });
          }
        },
        listenFor: const Duration(seconds: 8),
        pauseFor: const Duration(seconds: 3),
        localeId: 'de_DE',
        listenMode: stt.ListenMode.dictation,
      );
    } catch (e) {
      debugPrint('[WakeWord] Command listen error: $e');
      setState(() {
        _isListening = false;
        _wakeWordTriggered = false;
      });
      if (_wakeWordActive && mounted) {
        Future.delayed(const Duration(seconds: 1), () => _startWakeWordListening());
      }
    }

    // Timeout: if no command after 8s, go back to wake word mode
    Future.delayed(const Duration(seconds: 9), () {
      if (_wakeWordTriggered && mounted) {
        _speech.stop();
        setState(() {
          _isListening = false;
          _wakeWordTriggered = false;
        });
        if (_wakeWordActive) _startWakeWordListening();
      }
    });
  }

  void _startVoiceQuery() async {
    if (!_speechAvailable) {
      debugPrint('[Speech] Speech not available, showing manual search');
      _showManualPoiSearch();
      return;
    }

    HapticFeedback.mediumImpact();

    // ═══ CRITICAL: Stop ALL audio before starting mic ═══
    // TTS and any audio holds Android audio focus → mic gets no audio.
    await TtsAlertService.instance.stop();
    await _speech.stop(); // Stop any previous session

    setState(() {
      _isListening = true;
      _listenText = '';
    });

    // Small delay for audio focus release
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted || !_isListening) return;

    debugPrint('[Speech] Starting listen...');
    try {
      await _speech.listen(
        onResult: (result) {
          debugPrint('[Speech] "${result.recognizedWords}" final=${result.finalResult}');
          if (mounted && _isListening) {
            setState(() { _listenText = result.recognizedWords; });
          }
        },
        listenFor: const Duration(seconds: 8),
        pauseFor: const Duration(seconds: 3),
        localeId: 'de_DE',
        listenMode: stt.ListenMode.dictation,
      );
    } catch (e) {
      debugPrint('[Speech] Listen error: $e');
      if (mounted) setState(() => _isListening = false);
      return;
    }

    // Timer: process result after 6s
    Future.delayed(const Duration(seconds: 6), () {
      if (!mounted) return;
      final captured = _listenText;
      debugPrint('[Speech] Timer done — Text: "$captured"');
      _speech.stop();
      if (_isListening) {
        setState(() => _isListening = false);
        if (captured.isNotEmpty) {
          debugPrint('[Speech] Processing: "$captured"');
          _processVoiceQuery(captured);
        } else {
          debugPrint('[Speech] No text recognized');
        }
      }
    });
  }

  /// Speak text via TTS — Vosk keeps listening for wake word so user can
  /// interrupt with "Hi Moto" at any time. Only command-phase gets paused
  /// (handled in wakeWordDetected callback above).
  void _speakWithVoskPause(String text, {bool priority = false}) {
    if (priority) {
      TtsAlertService.instance.speakPriority(text);
    } else {
      TtsAlertService.instance.speakText(text);
    }
  }

  Future<void> _processVoiceQuery(String text) async {
    final command = VoiceCommandService.parse(text);

    // ── Global garbage filter: if Vosk produces noise, ask "Wie bitte?" ──
    // Skip for intents that matched a clear keyword (those are already validated)
    if (command.intent == VoiceIntent.unknown) {
      debugPrint('[Voice] Unknown/noise: "$text" → asking back');
      _speakWithVoskPause('Wie bitte, Racer?');
      return;
    }

    switch (command.intent) {
      case VoiceIntent.searchPoi:
        final label = command.poiLabel ?? text;
        final query = command.query ?? text;
        // All POI types: find 3 nearest via Overpass+Google, announce via TTS, voice choice
        if (label.toLowerCase().contains('tankstelle') || query.toLowerCase().contains('tankstelle')) {
          _searchNearestPoiWithVoiceChoice(
            label: 'Tankstelle',
            labelPlural: 'Tankstellen',
            overpassTag: '["amenity"="fuel"]',
            googleType: 'gas_station',
          );
        } else if (label.toLowerCase().contains('werkstatt') || query.toLowerCase().contains('werkstatt')) {
          _searchNearestPoiWithVoiceChoice(
            label: 'Werkstatt',
            labelPlural: 'Werkstätten',
            overpassTag: '["shop"="motorcycle"]',
            overpassTag2: '["shop"="car_repair"]',
            googleType: 'car_repair',
          );
        } else if (label.toLowerCase().contains('shop') || query.toLowerCase().contains('supermarkt')) {
          _searchNearestPoiWithVoiceChoice(
            label: 'Supermarkt',
            labelPlural: 'Supermärkte',
            overpassTag: '["shop"="supermarket"]',
            googleType: 'supermarket',
          );
        } else if (label.toLowerCase().contains('restaurant') || query.toLowerCase().contains('restaurant') ||
                   query.toLowerCase().contains('essen') || query.toLowerCase().contains('hunger') ||
                   query.toLowerCase().contains('café') || query.toLowerCase().contains('cafe') ||
                   query.toLowerCase().contains('kaffee')) {
          _searchNearestPoiWithVoiceChoice(
            label: 'Restaurant',
            labelPlural: 'Restaurants',
            overpassTag: '["amenity"="restaurant"]',
            overpassTag2: '["amenity"="fast_food"]',
            googleType: 'restaurant',
            radiusMeters: 15000,
          );
        } else {
          _searchAndShowPoi(query, label);
        }
        break;

      case VoiceIntent.toggleCamera:
        final notifier = ref.read(groupRideProvider(widget.groupId).notifier);
        if (!ref.read(groupRideProvider(widget.groupId)).isVoiceActive) {
          // Need voice channel first
          notifier.joinVoice().then((_) => notifier.toggleCamera());
        } else {
          notifier.toggleCamera();
        }
        _speakWithVoskPause('Kamera wird umgeschaltet.');
        break;

      case VoiceIntent.toggleMic:
        final rideNotifier = ref.read(groupRideProvider(widget.groupId).notifier);
        rideNotifier.toggleMic();
        final isMuted = ref.read(groupRideProvider(widget.groupId)).isMicMuted;
        _speakWithVoskPause(
          isMuted ? 'Mikrofon eingeschaltet.' : 'Mikrofon stumm geschaltet.',
        );
        break;

      case VoiceIntent.reportBlitzer:
        // Type already detected from voice command — no need to ask
        final bType = command.blitzerType ?? 'mobile';
        final bLabel = switch (bType) {
          'fixed' => 'Fester Blitzer',
          'police' => 'Polizeikontrolle',
          'construction' => 'Baustelle / Gefahr',
          _ => 'Mobiler Blitzer',
        };
        _sendBlitzerWarning(bType, bLabel);
        final safeLabel = switch (bType) {
          'fixed' => 'Feste Radarfalle',
          'police' => 'Polizeikontrolle',
          'construction' => 'Baustelle',
          _ => 'Mobile Kontrolle',
        };
        _speakWithVoskPause('$safeLabel gemeldet.');
        break;

      case VoiceIntent.showBlitzer:
        _announceNearestBlitzers();
        break;

      case VoiceIntent.endRide:
        _showLeaveDialog(context);
        break;

      case VoiceIntent.activateSos:
        if (_sosActive) {
          _speakWithVoskPause('SOS ist bereits aktiv.');
        } else {
          _activateSos();
          _speakWithVoskPause('SOS aktiviert! Alle werden benachrichtigt.');
        }
        break;

      case VoiceIntent.stopNavigation:
        if (_isNavigating || _currentRoute != null) {
          _stopNavigation();
          _speakWithVoskPause('Navigation beendet.');
        } else {
          _speakWithVoskPause('Keine Navigation aktiv.');
        }
        break;

      case VoiceIntent.navigateTo:
        final destination = command.query ?? '';
        if (destination.length >= 3) {
          debugPrint('[Voice] Navigate to: "$destination"');
          _speakWithVoskPause('Moment, Racer.');
          _navigateToAddress(destination);
        } else {
          _speakWithVoskPause('Wohin soll ich dich navigieren, Racer?');
        }
        break;

      case VoiceIntent.searchEvents:
        _searchRacerEvents();
        break;

      case VoiceIntent.aiQuery:
        debugPrint('[Voice] AI query: "$text"');
        final aiText = command.query ?? text;
        // Filter out garbage/noise — too short or just filler words
        if (aiText.trim().length < 4 || RegExp(r'^(ja|nein|ok|hm+|äh+|response|the|a|und|oder)\s*$', caseSensitive: false).hasMatch(aiText.trim())) {
          _speakWithVoskPause('Wie bitte, Racer?');
          break;
        }
        // Vosk stays active for wake word — user can say "Hi Moto" to interrupt

        try {
          // ── FAST PATH: Try instant answer from local database first ──
          final fastAnswer = await FastAnswerService.instance.tryAnswer(
            query: command.query ?? text,
            lat: _currentGpsPos?.latitude ?? 0,
            lon: _currentGpsPos?.longitude ?? 0,
            speedKmh: _displaySpeed,
            heading: _currentHeading,
            isNavigating: _isNavigating,
            routeDestination: _destinationInfo?.cityName ?? _lastDestinationName,
            distanceRemainingKm: _currentRoute?.distanceKm,
            etaMinutes: _currentRoute != null
                ? _currentRoute!.durationSeconds / 60.0
                : null,
            currentRoadName: _destinationInfo?.cityName,
            speedLimit: null,
          );

          if (fastAnswer != null) {
            debugPrint('[Voice] FAST ANSWER: $fastAnswer');
            await TtsAlertService.instance.speakPriority(fastAnswer);
          } else {
            // ── SLOW PATH: Send to Ollama LLM ──
            TtsAlertService.instance.speakText('Moment...');
            final aiResponse = await BikerAiService.instance.query(
              text: command.query ?? text,
              lat: _currentGpsPos?.latitude ?? 0,
              lon: _currentGpsPos?.longitude ?? 0,
              speed: _displaySpeed,
              heading: _currentHeading,
              isNavigating: _isNavigating,
              routeDestination: _destinationInfo?.cityName,
              currentRoadName: _destinationInfo?.cityName,
            );

            if (aiResponse != null) {
              await TtsAlertService.instance.speakPriority(aiResponse.response);
              if (aiResponse.action != null) {
                _handleAiAction(aiResponse.action!);
              }
            } else {
              await TtsAlertService.instance.speakText(
                'Entschuldigung, versuche es nochmal.',
              );
            }
          }
        } catch (e) {
          debugPrint('[Voice] AI error: $e');
          await TtsAlertService.instance.speakText(
            'Entschuldigung, ich konnte das nicht beantworten.',
          );
        }
        break;

      case VoiceIntent.unknown:
        // Handled by global filter above — should not reach here
        break;
      // New intents — not available in group ride
      case VoiceIntent.reportPolice:
      case VoiceIntent.reportHazard:
      case VoiceIntent.reportTraffic:
      case VoiceIntent.announceRoute:
      case VoiceIntent.switchTab:
      case VoiceIntent.thankMoto:
      case VoiceIntent.askWeather:
      case VoiceIntent.askSpeed:
      case VoiceIntent.askLocation:
      case VoiceIntent.confirmYes:
      case VoiceIntent.confirmNo:
        break;
    }
  }

  /// Handle structured actions from the Moto KI assistant.
  void _handleAiAction(AiAction action) {
    debugPrint('[Voice] AI action: ${action.type} ${action.params}');
    switch (action.type) {
      case 'searchPoi':
        final query = action.params['query'] as String? ?? '';
        final label = action.params['poiLabel'] as String? ?? query;
        if (query.isNotEmpty) {
          _searchAndShowPoi(query, label);
        }
        break;
      case 'reportBlitzer':
        _sendBlitzerWarning('mobile', 'Blitzer');
        break;
      case 'navigate':
        // Future: handle navigation to an address
        final address = action.params['address'] as String?;
        if (address != null) {
          debugPrint('[Voice] AI wants to navigate to: $address');
          // TODO: Implement address search + navigation
        }
        break;
      default:
        // 'none' or unknown — response already spoken, no action
        break;
    }
  }

  /// Search fuel stations via Overpass (proximity) + Google Places fallback.
  /// Shows results in the standard POI results sheet.
  Future<void> _searchFuelOverpass() async {
    Position? currentPos;
    try {
      currentPos = await Geolocator.getLastKnownPosition();
      currentPos ??= await Geolocator.getCurrentPosition();
    } catch (e) {
      debugPrint('[FuelSearch] Position error: $e');
    }
    if (currentPos == null || !mounted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kein GPS Signal')),
        );
      }
      return;
    }

    final lat = currentPos.latitude;
    final lon = currentPos.longitude;
    final List<({String name, String? city, double lat, double lon, double distance})> stations = [];

    // 1. Overpass API — 5km radius
    try {
      final query = '[out:json][timeout:10];node["amenity"="fuel"](around:5000,$lat,$lon);out body;';
      final resp = await http.post(
        Uri.parse('https://overpass-api.de/api/interpreter'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'data=${Uri.encodeComponent(query)}',
      ).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final elements = data['elements'] as List? ?? [];
        for (final el in elements) {
          if (el is! Map<String, dynamic>) continue;
          final sLat = (el['lat'] as num?)?.toDouble();
          final sLon = (el['lon'] as num?)?.toDouble();
          if (sLat == null || sLon == null) continue;
          final tags = el['tags'] as Map<String, dynamic>? ?? {};
          final brand = tags['brand'] as String? ?? '';
          final name = tags['name'] as String? ?? brand;
          if (name.isEmpty) continue;
          final city = tags['addr:city'] as String?;
          final dist = Geolocator.distanceBetween(lat, lon, sLat, sLon);
          stations.add((name: name, city: city, lat: sLat, lon: sLon, distance: dist));
        }
        debugPrint('[FuelSearch] Overpass found ${stations.length} stations');
      }
    } catch (e) {
      debugPrint('[FuelSearch] Overpass error: $e');
    }

    // 2. Google Places fallback if Overpass found <3
    if (stations.length < 3) {
      try {
        final resp = await http.get(
          Uri.parse('https://maps.googleapis.com/maps/api/place/nearbysearch/json'
              '?location=$lat,$lon&radius=5000&type=gas_station&key=${DestinationInfoService.googleApiKey}'),
        ).timeout(const Duration(seconds: 8));
        if (resp.statusCode == 200) {
          final json = jsonDecode(resp.body) as Map<String, dynamic>;
          final results = json['results'] as List? ?? [];
          for (final r in results) {
            if (r is! Map<String, dynamic>) continue;
            final loc = (r['geometry'] as Map?)?['location'] as Map?;
            if (loc == null) continue;
            final sLat = (loc['lat'] as num?)?.toDouble();
            final sLon = (loc['lng'] as num?)?.toDouble();
            if (sLat == null || sLon == null) continue;
            final gName = r['name'] as String? ?? '';
            if (gName.isEmpty) continue;
            // Dedup: skip if within 200m of existing station
            final isDupe = stations.any((s) =>
                Geolocator.distanceBetween(s.lat, s.lon, sLat, sLon) < 200);
            if (isDupe) continue;
            final dist = Geolocator.distanceBetween(lat, lon, sLat, sLon);
            final vicinity = r['vicinity'] as String?;
            stations.add((name: gName, city: vicinity, lat: sLat, lon: sLon, distance: dist));
          }
          debugPrint('[FuelSearch] +Google Places, total: ${stations.length}');
        }
      } catch (e) {
        debugPrint('[FuelSearch] Google Places error: $e');
      }
    }

    if (!mounted || stations.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Keine Tankstellen gefunden')),
        );
      }
      return;
    }

    stations.sort((a, b) => a.distance.compareTo(b.distance));

    // Convert to GeocodingResult-compatible format for _showPoiResultsSheet
    final withDist = stations.map((s) => (
      result: GeocodingResult(
        name: s.name,
        displayName: s.name,
        location: LatLng(s.lat, s.lon),
        city: s.city,
      ),
      distance: s.distance,
    )).toList();

    _showPoiResultsSheet('Tankstelle', withDist, currentPos);
  }

  /// Generic: Find 3 nearest POIs via Overpass + Google Places, announce via TTS,
  /// let user choose by voice ("eins", "zwei", "drei") and navigate there.
  ///
  /// Works for Tankstelle, Werkstatt, Supermarkt etc.
  Future<void> _searchNearestPoiWithVoiceChoice({
    required String label,
    required String labelPlural,
    required String overpassTag,
    String? overpassTag2,
    required String googleType,
    int radiusMeters = 10000,
  }) async {
    debugPrint('[VoicePoi] Searching nearby $label...');
    // No "Suche..." announcement — keep it silent until results are ready

    // Use our tracked GPS position (always available during ride)
    // Fall back to platform position if not available
    double lat, lon;
    if (_currentGpsPos != null) {
      lat = _currentGpsPos!.latitude;
      lon = _currentGpsPos!.longitude;
    } else {
      Position? currentPos;
      try {
        currentPos = await Geolocator.getLastKnownPosition();
        currentPos ??= await Geolocator.getCurrentPosition();
      } catch (e) {
        debugPrint('[VoicePoi] Position error: $e');
        TtsAlertService.instance.speakText('Kein GPS Signal.');
        return;
      }
      if (currentPos == null) {
        TtsAlertService.instance.speakText('Kein GPS Signal.');
        return;
      }
      lat = currentPos.latitude;
      lon = currentPos.longitude;
    }
    debugPrint('[VoicePoi] Searching $label near $lat,$lon radius=${radiusMeters}m');
    List<({String name, double lat, double lon, double distance, double? rating, int? ratingCount})> results = [];

    // Run Overpass + Google Places in parallel
    final overpassFuture = () async {
      final items = <({String name, double lat, double lon, double distance, double? rating, int? ratingCount})>[];
      try {
        // Build query with optional second tag
        final tagQuery = overpassTag2 != null
            ? 'node$overpassTag(around:$radiusMeters,$lat,$lon);way$overpassTag(around:$radiusMeters,$lat,$lon);node$overpassTag2(around:$radiusMeters,$lat,$lon);way$overpassTag2(around:$radiusMeters,$lat,$lon);'
            : 'node$overpassTag(around:$radiusMeters,$lat,$lon);way$overpassTag(around:$radiusMeters,$lat,$lon);';
        final query = '[out:json][timeout:25];($tagQuery);out center body;';
        final resp = await http.post(
          Uri.parse('https://overpass-api.de/api/interpreter'),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: 'data=${Uri.encodeComponent(query)}',
        ).timeout(const Duration(seconds: 25));

        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          final elements = data['elements'] as List? ?? [];
          debugPrint('[VoicePoi] Overpass: ${elements.length} elements');
          for (final el in elements) {
            if (el is! Map<String, dynamic>) continue;
            // node has lat/lon directly; way has center.lat/center.lon
            double? sLat = (el['lat'] as num?)?.toDouble();
            double? sLon = (el['lon'] as num?)?.toDouble();
            if (sLat == null || sLon == null) {
              final center = el['center'] as Map<String, dynamic>?;
              if (center != null) {
                sLat = (center['lat'] as num?)?.toDouble();
                sLon = (center['lon'] as num?)?.toDouble();
              }
            }
            if (sLat == null || sLon == null) continue;
            final tags = el['tags'] as Map<String, dynamic>? ?? {};
            final name = tags['name'] as String?
                ?? tags['brand'] as String?
                ?? tags['operator'] as String?
                ?? '';
            if (name.isEmpty) continue;
            final dist = Geolocator.distanceBetween(lat, lon, sLat, sLon);
            items.add((name: name, lat: sLat, lon: sLon, distance: dist, rating: null, ratingCount: null));
          }
        }
      } catch (e) {
        debugPrint('[VoicePoi] Overpass error: $e');
      }
      return items;
    }();

    final googleFuture = () async {
      final items = <({String name, double lat, double lon, double distance, double? rating, int? ratingCount})>[];
      try {
        final resp = await http.get(
          Uri.parse('https://maps.googleapis.com/maps/api/place/nearbysearch/json'
              '?location=$lat,$lon&radius=$radiusMeters&type=$googleType&key=${DestinationInfoService.googleApiKey}'),
        ).timeout(const Duration(seconds: 10));
        if (resp.statusCode == 200) {
          final json = jsonDecode(resp.body) as Map<String, dynamic>;
          final gResults = json['results'] as List? ?? [];
          for (final r in gResults) {
            if (r is! Map<String, dynamic>) continue;
            final loc = (r['geometry'] as Map?)?['location'] as Map?;
            if (loc == null) continue;
            final sLat = (loc['lat'] as num?)?.toDouble();
            final sLon = (loc['lng'] as num?)?.toDouble();
            if (sLat == null || sLon == null) continue;
            final gName = r['name'] as String? ?? '';
            if (gName.isEmpty) continue;
            final gRating = (r['rating'] as num?)?.toDouble();
            final gRatingCount = (r['user_ratings_total'] as num?)?.toInt();
            final dist = Geolocator.distanceBetween(lat, lon, sLat, sLon);
            debugPrint('[VoicePoi] Google: $gName dist=${dist.round()}m rating=$gRating count=$gRatingCount');
            items.add((name: gName, lat: sLat, lon: sLon, distance: dist, rating: gRating, ratingCount: gRatingCount));
          }
        }
      } catch (e) {
        debugPrint('[VoicePoi] Google error: $e');
      }
      return items;
    }();

    // Wait for both
    final both = await Future.wait([overpassFuture, googleFuture]);
    results.addAll(both[0]);
    for (final g in both[1]) {
      // Check if this Google result overlaps with an Overpass result
      final dupeIdx = results.indexWhere((s) =>
          Geolocator.distanceBetween(s.lat, s.lon, g.lat, g.lon) < 200);
      if (dupeIdx >= 0 && g.rating != null) {
        // Replace Overpass entry with Google entry (has rating data)
        results[dupeIdx] = g;
      } else if (dupeIdx < 0) {
        results.add(g);
      }
    }
    debugPrint('[VoicePoi] Total: ${both[0].length} OSM + ${both[1].length} Google → ${results.length} merged');

    if (!mounted || results.isEmpty) {
      TtsAlertService.instance.speakText('Keine $labelPlural in der Nähe gefunden.');
      return;
    }

    // Sort by distance, take top 3
    results.sort((a, b) => a.distance.compareTo(b.distance));
    final top3 = results.take(3).toList();
    for (int i = 0; i < top3.length; i++) {
      debugPrint('[VoicePoi] Top${i+1}: ${top3[i].name} ${top3[i].distance.round()}m rating=${top3[i].rating} count=${top3[i].ratingCount}');
    }

    // Natural speech: queued so each sentence waits for the previous
    // Vosk stays in wake-word mode — user can say "Hi Moto" to interrupt
    String _distShort(double m) => m < 1000 ? '${(m / 100).round() * 100} Meter' : '${(m / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';

    TtsAlertService.instance.clearQueue();

    // "Okay, ich hab [3] [Tankstellen] gefunden!"
    TtsAlertService.instance.speakQueued(
      top3.length == 1 ? 'Ich hab eine $label für dich!' : 'Okay, ich hab ${top3.length} $labelPlural gefunden!',
    );

    // Each POI as separate queued TTS
    for (int i = 0; i < top3.length; i++) {
      final r = top3[i];
      final ratingStr = r.rating != null
          ? '. ${r.rating!.toStringAsFixed(1).replaceAll('.', ',')} Sterne'
          : '';
      final line = '${i + 1}. ${r.name}. ${_distShort(r.distance)}$ratingStr.';
      TtsAlertService.instance.speakQueued(line);
    }

    // "Sage eins, zwei oder drei..."
    TtsAlertService.instance.speakQueued(
      top3.length > 1
          ? 'Sage eins, zwei oder drei. Oder ich navigier dich zur Eins.'
          : 'Sage ja, wenn du hinfahren willst.',
    );

    debugPrint('[VoicePoi] Queued TTS: ${top3.length} items');

    // Show bottom sheet with choices
    if (mounted) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.grey[900],
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('$label wählen',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                for (int i = 0; i < top3.length; i++)
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue,
                      child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(top3[i].name, style: const TextStyle(color: Colors.white)),
                    subtitle: Row(
                      children: [
                        Text(
                          top3[i].distance < 1000
                              ? '${top3[i].distance.round()} m'
                              : '${(top3[i].distance / 1000).toStringAsFixed(1)} km',
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                        if (top3[i].rating != null) ...[
                          const SizedBox(width: 12),
                          Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 2),
                          Text(
                            '${top3[i].rating!.toStringAsFixed(1)}',
                            style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                          ),
                          if (top3[i].ratingCount != null)
                            Text(
                              ' (${top3[i].ratingCount})',
                              style: TextStyle(color: Colors.grey[500], fontSize: 12),
                            ),
                        ],
                      ],
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      final picked = top3[i];
                      TtsAlertService.instance.speakText('Navigiere zu ${picked.name}.');
                      _lastDestinationName = picked.name;
                      _calculateRoute(LatLng(picked.lat, picked.lon));
                    },
                  ),
              ],
            ),
          ),
        ),
      );
    }

    // Set pending choices — voice handler will route next command here
    _pendingFuelChoices = top3;
    _pendingPoiLabel = label;

    // Enable Vosk after estimated TTS finishes
    final poiTtsEstimate = 3 + top3.length * 5 + 4;
    Future.delayed(Duration(seconds: poiTtsEstimate), () {
      _waitForTtsThenEnableVosk();
    });

    // Auto-navigate to #1 after estimated TTS + 15s wait
    Future.delayed(Duration(seconds: poiTtsEstimate + 15), () {
      if (_pendingFuelChoices != null && mounted) {
        final autoChoice = _pendingFuelChoices!.first;
        _pendingFuelChoices = null;
        _pendingPoiLabel = null;
        VoskWakeWordService.instance.directListenMode = false;
        // Close bottom sheet if still open
        Navigator.of(context).maybePop();
        TtsAlertService.instance.speakText('Navigiere automatisch zu ${autoChoice.name}.');
        _lastDestinationName = autoChoice.name;
        _calculateRoute(LatLng(autoChoice.lat, autoChoice.lon));
        debugPrint('[VoicePoi] Auto-navigate to #1: ${autoChoice.name}');
      }
    });
  }

  /// Announce the 3 nearest blitzers via TTS (voice POI query).
  void _announceNearestBlitzers() {
    // Vosk stays in wake-word mode — user can say "Hi Moto" to interrupt

    if (_currentGpsPos == null) {
      TtsAlertService.instance.speakText('Kein GPS Signal.');
      return;
    }

    if (_nearbyBlitzerReports.isEmpty) {
      TtsAlertService.instance.clearQueue();
      TtsAlertService.instance.speakQueued('Keine Sorge Racer, ich bin immer für dich da.');
      TtsAlertService.instance.speakQueued('Aktuell keine Warnungen in der Nähe.');
      TtsAlertService.instance.speakQueued('Ich melde dir automatisch alles auf der Strecke!');
      return;
    }

    // Calculate distance and sort
    final lat = _currentGpsPos!.latitude;
    final lon = _currentGpsPos!.longitude;
    final withDist = _nearbyBlitzerReports.map((b) {
      final d = Geolocator.distanceBetween(lat, lon, b.latitude, b.longitude);
      return (report: b, distance: d);
    }).toList()..sort((a, b) => a.distance.compareTo(b.distance));

    // Take top 3
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

    // Natural speech: queued so each sentence waits for the previous
    TtsAlertService.instance.clearQueue();
    TtsAlertService.instance.speakQueued('Keine Sorge Racer, ich pass auf dich auf!');

    for (int i = 0; i < top3.length; i++) {
      final b = top3[i];
      final line = '${typeLabel(b.report.type)} in ${distShort(b.distance)}.';
      TtsAlertService.instance.speakQueued(line);
    }
    TtsAlertService.instance.speakQueued('Ich melde dir alles automatisch. Ride on!');
    debugPrint('[VoiceBlitzer] Queued TTS: ${top3.length} warnings');
  }

  /// Search for nearby Racer Events and offer 3 via voice choice.
  void _searchRacerEvents() {
    // Vosk stays in wake-word mode — user can say "Hi Moto" to interrupt

    if (_currentGpsPos == null) {
      TtsAlertService.instance.speakText('Kein GPS Signal, Racer.');
      return;
    }

    final lat = _currentGpsPos!.latitude;
    final lng = _currentGpsPos!.longitude;

    // Search is instant (hardcoded spots, no network)
    RacerEventsService.instance.searchEvents(lat: lat, lng: lng).then((events) {
      if (!mounted) return;

      if (events.isEmpty) {
        TtsAlertService.instance.clearQueue();
        TtsAlertService.instance.speakQueued('Hi Racer!');
        TtsAlertService.instance.speakQueued('Leider keine Events in der Nähe.');
        return;
      }

      debugPrint('[RacerEvents] Found ${events.length} events');

      // Convert to same format as fuel choices for voice selection reuse
      final top3 = events.map((e) => (
        name: e.name,
        lat: e.lat,
        lon: e.lng,
        distance: e.distanceKm * 1000, // meters for display
        rating: null as double?,
        ratingCount: null as int?,
      )).toList();

      // Build individual TTS lines for natural speech
      final eventLines = <String>[];
      for (int i = 0; i < top3.length; i++) {
        final e = events[i];
        final distText = e.distanceKm >= 10
            ? '${e.distanceKm.round()} Kilometer'
            : '${e.distanceKm.toStringAsFixed(1)} Kilometer';
        eventLines.add('${i + 1}. ${e.name}. $distText entfernt.');
      }

      // Show bottom sheet with choices
      _showEventChoiceSheet(events);

      // Set pending choices for voice selection (reuses fuel choice handler)
      _pendingFuelChoices = top3;
      _pendingPoiLabel = 'Racer Event';

      // Natural speech flow: queued so each sentence waits for the previous
      TtsAlertService.instance.clearQueue();
      TtsAlertService.instance.speakQueued('Hi mein Racer!');
      TtsAlertService.instance.speakQueued(
        top3.length == 1 ? 'Ich hab da was für dich.' : 'Ich hab ${top3.length} Events für dich.',
      );
      for (final line in eventLines) {
        TtsAlertService.instance.speakQueued(line);
      }
      TtsAlertService.instance.speakQueued(
        top3.length > 1
            ? 'Sage eins, zwei oder drei. Oder ich navigier dich einfach zur Eins.'
            : 'Sage ja, wenn du hinfahren willst.',
      );

      // Enable Vosk after a short delay (queue handles timing)
      Future.delayed(Duration(seconds: (3 + eventLines.length * 5 + 4)), () {
        if (mounted) _waitForTtsThenEnableVosk();
      });

      // Auto-select #1 after estimated TTS time + 15s wait
      final estimatedTtsTime = 3 + eventLines.length * 5 + 4;
      Future.delayed(Duration(seconds: estimatedTtsTime + 15), () {
        if (_pendingFuelChoices != null && mounted) {
          final autoChoice = _pendingFuelChoices!.first;
          _pendingFuelChoices = null;
          _pendingPoiLabel = null;
          VoskWakeWordService.instance.directListenMode = false;
          Navigator.of(context).popUntil((route) => route is! PopupRoute);
          TtsAlertService.instance.speakText('${autoChoice.name}.');
          _lastDestinationName = autoChoice.name;
          _calculateRoute(LatLng(autoChoice.lat, autoChoice.lon));
          debugPrint('[RacerEvents] Auto-navigate to #1: ${autoChoice.name}');
        }
      });
    }).catchError((e) {
      debugPrint('[RacerEvents] Error: $e');
      TtsAlertService.instance.speakText('Fehler bei der Event-Suche.');
    });
  }

  /// Show bottom sheet with Racer Event choices (1/2/3).
  void _showEventChoiceSheet(List<RacerEvent> events) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF00BCD4).withValues(alpha: 0.3)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🏁 Racer Events in deiner Nähe',
              style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...events.asMap().entries.map((entry) {
              final i = entry.key;
              final e = entry.value;
              final distText = e.distanceKm >= 10
                  ? '${e.distanceKm.round()} km'
                  : '${e.distanceKm.toStringAsFixed(1)} km';
              return GestureDetector(
                onTap: () {
                  _pendingFuelChoices = null;
                  _pendingPoiLabel = null;
                  VoskWakeWordService.instance.directListenMode = false;
                  Navigator.pop(ctx);
                  TtsAlertService.instance.speakText('${e.name}.');
                  _lastDestinationName = e.name;
                  _calculateRoute(LatLng(e.lat, e.lng));
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16213E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF00BCD4).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32, height: 32,
                        decoration: const BoxDecoration(
                          color: Color(0xFF00BCD4),
                          shape: BoxShape.circle,
                        ),
                        child: Center(child: Text('${i + 1}',
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.name,
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                            if (e.description != null)
                              Text(e.description!,
                                style: GoogleFonts.inter(color: Colors.white60, fontSize: 12),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      Text(distText,
                        style: GoogleFonts.inter(color: const Color(0xFF00BCD4), fontSize: 14, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
            Text('Sage "Eins", "Zwei" oder "Drei" — oder tippe drauf',
              style: GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  /// Start blitzer report flow — ask user for type (mobil/fest) via voice.
  void _startBlitzerTypeSelection() {
    _pendingBlitzerType = true;
    VoskWakeWordService.instance.setPaused(true);
    // IMPORTANT: Don't say "mobil" or "fest" in TTS — Vosk would hear it as the answer!
    TtsAlertService.instance.speakPriority(
      'Warnung melden! Welche Art?',
    );
    // Poll until TTS finishes, then enable voice input
    int polls = 0;
    Timer.periodic(const Duration(milliseconds: 300), (timer) {
      polls++;
      if (!mounted || !_pendingBlitzerType) {
        timer.cancel();
        return;
      }
      if (!TtsAlertService.instance.isSpeaking || polls > 20) {
        timer.cancel();
        // Extra buffer for echo
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (_pendingBlitzerType && mounted) {
            VoskWakeWordService.instance.setPaused(false);
            VoskWakeWordService.instance.directListenMode = true;
            debugPrint('[VoiceBlitzer] Listening for type selection...');
          }
        });
      }
    });

    // Auto-timeout: if no answer in 10s, default to mobile
    Future.delayed(const Duration(seconds: 12), () {
      if (_pendingBlitzerType && mounted) {
        _pendingBlitzerType = false;
        VoskWakeWordService.instance.directListenMode = false;
        _sendBlitzerWarning('mobile', 'Mobiler Blitzer');
        _speakWithVoskPause(
          'Mobile Kontrolle wurde in die Motorinu Datenbank eingetragen.',
        );
      }
    });
  }

  /// Handle voice answer for blitzer type selection.
  void _handleBlitzerTypeVoiceChoice(String text) {
    final lower = text.toLowerCase().trim();
    _pendingBlitzerType = false;
    VoskWakeWordService.instance.directListenMode = false; // Back to wake word mode

    String type;
    String label;

    if (lower.contains('fest') || lower.contains('stationär') || lower.contains('fix')) {
      type = 'fixed';
      label = 'Fester Blitzer';
    } else if (lower.contains('polizei') || lower.contains('kontrolle')) {
      type = 'police';
      label = 'Polizeikontrolle';
    } else {
      // Default: mobile (most common)
      type = 'mobile';
      label = 'Mobiler Blitzer';
    }

    _sendBlitzerWarning(type, label);
    // Use safe TTS label (avoid "Blitzer" word that Vosk could pick up)
    final safeLabel = switch (type) {
      'fixed' => 'Feste Radarfalle',
      'mobile' => 'Mobile Kontrolle',
      'police' => 'Polizeikontrolle',
      _ => 'Warnung',
    };
    _speakWithVoskPause('$safeLabel wurde in die Motorinu Datenbank eingetragen. Ride safe!');
  }

  /// Waits for TTS to finish speaking, then enables Vosk directListenMode.
  /// Polls every 300ms to check if TTS is done. Max 15s safety timeout.
  void _waitForTtsThenEnableVosk() {
    int attempts = 0;
    const maxAttempts = 50; // 50 × 300ms = 15s max
    Timer.periodic(const Duration(milliseconds: 300), (timer) {
      attempts++;
      if (!mounted || _pendingFuelChoices == null) {
        timer.cancel();
        return;
      }
      final stillSpeaking = TtsAlertService.instance.isSpeaking;
      if (!stillSpeaking || attempts >= maxAttempts) {
        timer.cancel();
        // Extra 500ms buffer after TTS ends to avoid echo pickup
        Future.delayed(const Duration(milliseconds: 500), () {
          if (_pendingFuelChoices != null && mounted) {
            VoskWakeWordService.instance.setPaused(false);
            VoskWakeWordService.instance.directListenMode = true;
            debugPrint('[VoicePoi] TTS done → Vosk RESUMED + directListen ON (after ${attempts * 300}ms wait)');
          }
        });
      }
    });
  }

  /// Pending POI label for voice choice feedback
  String? _pendingPoiLabel;

  /// Handle voice POI choice ("eins", "zwei", "drei" or name).
  void _handleFuelVoiceChoice(String text) {
    final top3 = _pendingFuelChoices;
    final poiLabel = _pendingPoiLabel ?? 'Ort';
    _pendingFuelChoices = null;
    _pendingPoiLabel = null;
    VoskWakeWordService.instance.directListenMode = false;

    if (top3 == null || top3.isEmpty) return;

    final lower = text.toLowerCase().trim();
    debugPrint('[VoiceChoice] Raw text: "$text" → lower: "$lower"');

    // Split into words for exact matching
    final words = lower.split(RegExp(r'\s+'));

    // ── Abbrechen / Cancel ──
    if (words.any((w) => w == 'abbrechen' || w == 'abbruch' || w == 'stopp' ||
        w == 'stop' || w == 'nein' || w == 'nee' || w == 'cancel' ||
        w == 'egal' || w == 'nichts' || w == 'lassen')) {
      debugPrint('[VoiceChoice] → CANCELLED by user');
      TtsAlertService.instance.clearQueue();
      Navigator.of(context).popUntil((route) => route is! PopupRoute);
      TtsAlertService.instance.speakText('Alles klar, Racer.');
      return;
    }

    int? choice;

    // Check DREI first (highest number), then ZWEI, then EINS
    // This prevents "zwei" from matching "eins" if Vosk adds noise
    if (words.any((w) => w == 'drei' || w == 'dritte' || w == 'drittes' || w == '3')) {
      choice = 2;
    } else if (words.any((w) => w == 'zwei' || w == 'zweite' || w == 'zweites' || w == '2')) {
      choice = 1;
    } else if (words.any((w) => w == 'eins' || w == 'erste' || w == 'erstes' || w == 'ein' || w == '1')) {
      choice = 0;
    } else {
      // Try to match by station name
      for (int i = 0; i < top3.length; i++) {
        final sName = top3[i].name.toLowerCase();
        if (sName.isNotEmpty && lower.contains(sName)) {
          choice = i;
          break;
        }
      }
    }

    debugPrint('[VoiceChoice] Parsed choice: $choice (from words: $words)');

    if (choice != null && choice < top3.length && mounted) {
      final picked = top3[choice];
      debugPrint('[VoiceChoice] → Navigating to #${choice + 1}: ${picked.name}');
      TtsAlertService.instance.speakText('${picked.name}.');
      Navigator.of(context).popUntil((route) => route is! PopupRoute);
      _lastDestinationName = picked.name;
      _calculateRoute(LatLng(picked.lat, picked.lon));
    } else if (mounted) {
      debugPrint('[VoiceChoice] → No match, user should tap');
    }
  }

  Future<void> _searchAndShowPoi(String query, String label) async {
    // Get current position
    Position? currentPos;
    try {
      currentPos = await Geolocator.getLastKnownPosition();
      currentPos ??= await Geolocator.getCurrentPosition();
    } catch (e) {
      debugPrint('[VoiceQuery] Position error: $e');
    }

    final geocoding = GeocodingService();
    List<GeocodingResult> results;
    try {
      results = await geocoding.searchPlace(
        query,
        limit: 8,
        near: currentPos != null
            ? LatLng(currentPos.latitude, currentPos.longitude)
            : null,
      );
    } catch (e) {
      debugPrint('[VoiceQuery] Search error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Suche fehlgeschlagen: $e')),
        );
      }
      return;
    }

    if (!mounted) return;

    if (results.isEmpty) {
      TtsAlertService.instance.speakText('Keine Ergebnisse für $label gefunden.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Keine $label in der Nähe gefunden')),
      );
      return;
    }

    // Calculate distances and sort
    final withDist = results.map((r) {
      double dist = 0;
      if (currentPos != null) {
        dist = Geolocator.distanceBetween(
          currentPos.latitude, currentPos.longitude,
          r.location.latitude, r.location.longitude,
        );
      }
      return (result: r, distance: dist);
    }).toList()
      ..sort((a, b) => a.distance.compareTo(b.distance));

    // Announce the closest result
    final closest = withDist.first;
    final distKm = closest.distance / 1000;
    TtsAlertService.instance.speakPoiResult(
      label,
      closest.result.displayName ?? closest.result.name ?? label,
      closest.distance,
    );

    // Show results sheet
    _showPoiResultsSheet(label, withDist, currentPos);
  }

  void _showPoiResultsSheet(
    String label,
    List<({GeocodingResult result, double distance})> results,
    Position? currentPos,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.55,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: Colors.white70, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '$label in der Nähe',
                    style: GoogleFonts.inter(
                      color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${results.length} Ergebnisse',
                    style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: results.length,
                itemBuilder: (_, i) {
                  final item = results[i];
                  final r = item.result;
                  final dist = item.distance;
                  final distText = dist < 1000
                      ? '${dist.round()}m'
                      : '${(dist / 1000).toStringAsFixed(1)}km';
                  final name = r.displayName ?? r.name ?? label;

                  return ListTile(
                    leading: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.place_rounded, color: Colors.blue, size: 22),
                    ),
                    title: Text(
                      name,
                      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${r.city ?? ''} — $distText',
                      style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                    ),
                    trailing: SizedBox(
                      width: 72,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Share with group
                          SizedBox(
                            width: 34, height: 34,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.group_rounded, color: Colors.green, size: 18),
                              tooltip: 'An Gruppe senden',
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                ref.read(groupRideProvider(widget.groupId).notifier)
                                    .sharePoiWithGroup(
                                  poiType: label,
                                  name: name,
                                  lat: r.location.latitude,
                                  lng: r.location.longitude,
                                  distanceKm: dist / 1000,
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('$label an Gruppe gesendet'),
                                    backgroundColor: Colors.green.shade800,
                                  ),
                                );
                              },
                            ),
                          ),
                          // Navigate to POI
                          SizedBox(
                            width: 34, height: 34,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.navigation_rounded, color: Colors.blue, size: 18),
                              tooltip: 'Navigieren',
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                _launchNavToPoi(r.location.latitude, r.location.longitude, name);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    onTap: () {
                      // Share + Navigate
                      Navigator.of(ctx).pop();
                      ref.read(groupRideProvider(widget.groupId).notifier)
                          .sharePoiWithGroup(
                        poiType: label,
                        name: name,
                        lat: r.location.latitude,
                        lng: r.location.longitude,
                        distanceKm: dist / 1000,
                      );
                      _launchNavToPoi(r.location.latitude, r.location.longitude, name);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _launchNavToPoi(double lat, double lng, String name) {
    // Use in-app navigation instead of Google Maps
    _lastDestinationName = name;
    _calculateRoute(LatLng(lat, lng));
  }

  void _showManualPoiSearch() {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Suche in der Nähe', style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: ctrl,
                      autofocus: true,
                      style: GoogleFonts.inter(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'z.B. Tankstelle, Restaurant...',
                        hintStyle: GoogleFonts.inter(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.06),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      final q = ctrl.text.trim();
                      if (q.isNotEmpty) {
                        Navigator.of(ctx).pop();
                        if (q.toLowerCase().contains('tankstelle') || q.toLowerCase().contains('tanken')) {
                          _searchFuelOverpass();
                        } else {
                          _searchAndShowPoi(q, q);
                        }
                      }
                    },
                    child: const Text('Suchen'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Quick buttons
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _quickSearchChip(ctx, '⛽ Tankstelle', 'Tankstelle', 'Tankstelle'),
                  _quickSearchChip(ctx, '🍴 Restaurant', 'Restaurant', 'Restaurant'),
                  _quickSearchChip(ctx, '🅿️ Parkplatz', 'Parkplatz', 'Parkplatz'),
                  _quickSearchChip(ctx, '🏨 Hotel', 'Hotel', 'Hotel'),
                  _quickSearchChip(ctx, '🍺 Biergarten', 'Biergarten', 'Bikertreffen'),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickSearchChip(BuildContext ctx, String label, String query, String poiLabel) {
    return ActionChip(
      label: Text(label, style: GoogleFonts.inter(color: Colors.white, fontSize: 12)),
      backgroundColor: Colors.white.withValues(alpha: 0.08),
      side: BorderSide.none,
      onPressed: () {
        Navigator.of(ctx).pop();
        // Tankstelle → Overpass proximity search
        if (poiLabel.toLowerCase().contains('tankstelle') || query.toLowerCase().contains('tankstelle')) {
          _searchFuelOverpass();
        } else {
          _searchAndShowPoi(query, poiLabel);
        }
      },
    );
  }

  // ═══════════════════════════════════════════════════
  //  HELPERS
  // ═══════════════════════════════════════════════════

  double _colorToHue(String hexColor) {
    try {
      final hex = hexColor.replaceAll('#', '');
      final color = Color(int.parse('FF$hex', radix: 16));
      final hsl = HSLColor.fromColor(color);
      return hsl.hue;
    } catch (_) {
      return BitmapDescriptor.hueGreen;
    }
  }

  /// Offset a position [meters] ahead in [headingDeg] direction.
  /// Used to shift camera target forward so user appears in bottom third.
  LatLng _offsetPositionAhead(LatLng pos, double headingDeg, double meters) {
    final headingRad = headingDeg * math.pi / 180;
    final latOffset = meters / 111320.0;
    final lngOffset = meters / (111320.0 * math.cos(pos.latitude * math.pi / 180));
    return LatLng(
      pos.latitude + latOffset * math.cos(headingRad),
      pos.longitude + lngOffset * math.sin(headingRad),
    );
  }

  /// Snap a GPS position to the nearest point on the route polyline.
  /// Prefers OSRM HMM map-matched position when available (much more accurate).
  /// Falls back to local polyline projection if OSRM hasn't responded yet.
  /// Returns the original position if no route or too far (> 50m).
  /// Caches result + distance so callers on the same GPS tick don't recalculate.
  LatLng _snapToRoute(LatLng gps) {
    // Return cached result if same input (multiple callers per GPS tick)
    if (_lastSnapInput != null &&
        _lastSnapInput!.latitude == gps.latitude &&
        _lastSnapInput!.longitude == gps.longitude) {
      return _lastSnapResult ?? gps;
    }

    if (_currentRoute == null || _currentRoute!.polylinePoints.length < 2) {
      _lastSnapInput = gps;
      _lastSnapResult = gps;
      _lastSnapDist = double.infinity;
      return gps;
    }

    // ── Prefer OSRM map-matched position (HMM, considers road topology) ──
    if (_osrmMatchedPos != null) {
      // Verify the OSRM result is still fresh (within ~30m of current GPS)
      final osrmDist = _distLatLng(_osrmMatchedPos!, gps);
      if (osrmDist < 30) {
        _lastSnapInput = gps;
        _lastSnapDist = osrmDist;
        _lastSnapResult = _osrmMatchedPos;
        return _lastSnapResult!;
      }
      // OSRM result too stale — fall through to local snap
    }

    // ── Fallback: local polyline projection ──
    double bestDistSq = double.infinity;
    LatLng bestPoint = gps;
    int bestIdx = 0;

    final pts = _currentRoute!.polylinePoints;

    // Phase 1: Coarse search — check every 10th point (squared distance, no sqrt)
    for (int i = 0; i < pts.length - 1; i += 10) {
      final distSq = _distLatLngSq(gps, pts[i]);
      if (distSq < bestDistSq) {
        bestDistSq = distSq;
        bestIdx = i;
      }
    }

    // Phase 2: Fine search — check ±15 segments around best coarse match
    bestDistSq = double.infinity;
    final start = (bestIdx - 15).clamp(0, pts.length - 2);
    final end = (bestIdx + 15).clamp(0, pts.length - 1);
    int bestSegIdx = bestIdx;
    for (int i = start; i < end; i++) {
      final snapped = _projectPointOnSegment(gps, pts[i], pts[i + 1]);
      final distSq = _distLatLngSq(gps, snapped);
      if (distSq < bestDistSq) {
        bestDistSq = distSq;
        bestPoint = snapped;
        bestSegIdx = i;
      }
    }

    // Convert best squared distance to meters for threshold check
    final bestDist = math.sqrt(bestDistSq);

    // Save segment index for route-based heading
    if (bestDist < 50) _lastSnapSegIdx = bestSegIdx;

    // Cache for this GPS tick
    _lastSnapInput = gps;
    _lastSnapDist = bestDist;
    _lastSnapResult = bestDist < 50 ? bestPoint : gps;
    return _lastSnapResult!;
  }

  /// Project point P onto line segment AB, return closest point on segment.
  LatLng _projectPointOnSegment(LatLng p, LatLng a, LatLng b) {
    final dx = b.latitude - a.latitude;
    final dy = b.longitude - a.longitude;
    if (dx == 0 && dy == 0) return a; // Segment is a point

    // t = dot(AP, AB) / dot(AB, AB), clamped to [0, 1]
    var t = ((p.latitude - a.latitude) * dx + (p.longitude - a.longitude) * dy)
        / (dx * dx + dy * dy);
    t = t.clamp(0.0, 1.0);

    return LatLng(a.latitude + t * dx, a.longitude + t * dy);
  }

  // ── OSRM Map Matching ────────────────────────────────────────────────────

  /// Buffer a new GPS point and periodically call OSRM /match for HMM road snap.
  /// The matched position is stored in [_osrmMatchedPos] and used by [_snapToRoute].
  void _feedGpsMatchBuffer(LatLng gps) {
    // Add to ring buffer
    _gpsMatchBuffer.add(gps);
    _gpsMatchTimestamps.add(DateTime.now().millisecondsSinceEpoch ~/ 1000);
    if (_gpsMatchBuffer.length > _gpsMatchBufferSize) {
      _gpsMatchBuffer.removeAt(0);
      _gpsMatchTimestamps.removeAt(0);
    }

    // Only call OSRM every N ticks and when buffer has enough points
    _gpsMatchTickCounter++;
    if (_gpsMatchTickCounter < _gpsMatchInterval) return;
    _gpsMatchTickCounter = 0;

    if (_gpsMatchBuffer.length < 3) return; // Need at least 3 points for good matching
    if (_osrmMatchInFlight) return; // Previous request still pending

    _osrmMatchInFlight = true;
    final points = List<LatLng>.from(_gpsMatchBuffer);
    final timestamps = List<int>.from(_gpsMatchTimestamps);

    _osrmService.matchPosition(points, timestamps: timestamps).then((matched) {
      _osrmMatchInFlight = false;
      if (matched != null && mounted) {
        // Verify the matched position is reasonable (within 50m of raw GPS)
        final dist = _distLatLng(matched, _gpsMatchBuffer.last);
        if (dist < 50) {
          _osrmMatchedPos = matched;
          debugPrint('[OSRM Match] ✓ snapped ${dist.toStringAsFixed(1)}m from raw GPS');
        } else {
          debugPrint('[OSRM Match] ✗ rejected: ${dist.toStringAsFixed(0)}m too far');
        }
      }
    }).catchError((_) {
      _osrmMatchInFlight = false;
    });
  }

  /// Minimum distance in meters from a point to the route polyline.
  /// Uses cached snap result if available for the same GPS point.
  double _minDistanceToRoute(LatLng gps) {
    // If _snapToRoute was already called for this GPS point, reuse its distance
    if (_lastSnapInput != null &&
        _lastSnapInput!.latitude == gps.latitude &&
        _lastSnapInput!.longitude == gps.longitude) {
      return _lastSnapDist;
    }
    // Otherwise, call snap to compute and cache
    _snapToRoute(gps);
    return _lastSnapDist;
  }

  /// Add up to [max] nearest POIs within [radiusSq] meters² to markers set.
  /// If no GPS available yet, shows all POIs.
  void _addNearestPois(
    Set<Marker> markers,
    List<RoutePoi> pois,
    String prefix,
    LatLng? gps,
    double radiusSq,
    int max,
    double hue,
    String fallbackName,
  ) {
    if (pois.isEmpty) return;

    if (gps == null) {
      // No GPS — show all
      for (int i = 0; i < pois.length; i++) {
        final p = pois[i];
        markers.add(Marker(
          markerId: MarkerId('${prefix}_$i'),
          position: LatLng(p.lat, p.lon),
          icon: BitmapDescriptor.defaultMarkerWithHue(hue),
          infoWindow: InfoWindow(title: p.name.isNotEmpty ? p.name : fallbackName),
          zIndex: 5,
        ));
      }
      return;
    }

    // Sort by distance to GPS, take nearest [max] within radius
    final indexed = List.generate(pois.length, (i) => i)
      ..sort((a, b) {
        final da = _distLatLngSq(gps, LatLng(pois[a].lat, pois[a].lon));
        final db = _distLatLngSq(gps, LatLng(pois[b].lat, pois[b].lon));
        return da.compareTo(db);
      });

    int added = 0;
    for (final i in indexed) {
      if (added >= max) break;
      final p = pois[i];
      final pPos = LatLng(p.lat, p.lon);
      if (_distLatLngSq(gps, pPos) > radiusSq) break; // sorted — rest is farther
      markers.add(Marker(
        markerId: MarkerId('${prefix}_$i'),
        position: pPos,
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        infoWindow: InfoWindow(title: p.name.isNotEmpty ? p.name : fallbackName),
        zIndex: 5,
      ));
      added++;
    }
  }

  /// Squared distance (meters²) — use for comparisons to avoid sqrt.
  double _distLatLngSq(LatLng a, LatLng b) {
    final dLat = (b.latitude - a.latitude) * 111320;
    final dLng = (b.longitude - a.longitude) * 111320 *
        math.cos(a.latitude * math.pi / 180);
    return dLat * dLat + dLng * dLng;
  }

  /// Approximate distance in meters between two LatLng points.
  double _distLatLng(LatLng a, LatLng b) {
    return math.sqrt(_distLatLngSq(a, b));
  }

}

/// Helper class for grouped route sections.
class _RoadSection {
  final String name;
  final double distanceM;
  final String maneuver; // first maneuver entering this road
  final double cumulativeDistM; // distance from route start to this section
  const _RoadSection({required this.name, required this.distanceM, this.maneuver = 'continue', this.cumulativeDistM = 0});
}

/// Country segment along route (detected via reverse geocoding).
/// groupedStepIndex = index in the grouped _RoadSection list where this country starts.
class _CountrySegment {
  final int groupedStepIndex; // index in grouped steps list
  final String countryCode;   // ISO 3166-1 alpha-2
  const _CountrySegment({required this.groupedStepIndex, required this.countryCode});
}

/// Sign type for road classification.
enum _SignType { autobahn, bundesstrasse, europastrasse, other }

/// Visual classification of a road type.
class _RoadType {
  final String? badge;         // e.g. "A1", "B42"
  final _SignType signType;    // Type of road sign to render
  final Color iconBg;
  final Color? badgeTextColor;
  final Color bgColor;
  final IconData icon;
  final Color iconColor;

  const _RoadType({
    this.badge,
    this.signType = _SignType.other,
    required this.iconBg,
    this.badgeTextColor,
    required this.bgColor,
    required this.icon,
    required this.iconColor,
  });
}

/// Painter for the "Ende aller Streckenverbote" sign (diagonal grey stripes).
class _UnlimitedSignPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF666666)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    // 5 diagonal lines from bottom-left to top-right
    for (int i = -2; i <= 2; i++) {
      final offset = i * 8.0;
      canvas.drawLine(
        Offset(offset, size.height),
        Offset(size.width + offset, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════
//  SOS Long-Press Button (3 Sekunden halten)
// ═══════════════════════════════════════════════════

class _SosLongPressButton extends StatefulWidget {
  final VoidCallback onSosActivated;

  const _SosLongPressButton({required this.onSosActivated});

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
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: _pressing
                      ? Colors.red.shade700.withValues(alpha: 0.15)
                      : const Color(0xFF2D3446),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _pressing
                          ? Colors.red.withValues(alpha: 0.4)
                          : Colors.black.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Progress-Ring während Long-Press
                    if (_pressing)
                      SizedBox(
                        width: 40,
                        height: 40,
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
              ),
              const SizedBox(height: 4),
              Text(
                'SOS',
                style: GoogleFonts.inter(
                  color: Colors.white60,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
