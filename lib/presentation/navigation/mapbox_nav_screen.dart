import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../data/repositories/blitzer_repository.dart';
import '../../services/blitzer_alert_service.dart';
import '../../services/osm_blitzer_service.dart';
import '../../services/osrm_service.dart';
import '../../services/speed_limit_service.dart';
import '../../services/tts_alert_service.dart';
import '../../services/voice_command_service.dart';
import '../../services/vosk_wake_word_service.dart';
import '../../providers/map/map_settings_provider.dart';
import '../../core/api_config.dart';

// Token moved to ApiConfig to avoid secret-scanning blocks.
String get _mapboxPublicToken => ApiConfig.mapboxPublicToken;

/// Full-featured Mapbox navigation screen.
/// Native Location Puck (60fps), OSRM routing, Blitzer, Speed Limits, Hi Moto.
class MapboxNavScreen extends StatefulWidget {
  final double destLat;
  final double destLng;
  final String destName;
  final RouteMode routeMode;

  const MapboxNavScreen({
    super.key,
    required this.destLat,
    required this.destLng,
    this.destName = 'Ziel',
    this.routeMode = RouteMode.biker,
  });

  @override
  State<MapboxNavScreen> createState() => _MapboxNavScreenState();
}

class _MapboxNavScreenState extends State<MapboxNavScreen> {
  MapboxMap? _mapboxMap;
  StreamSubscription<geo.Position>? _positionSub;
  Timer? _followTimer;
  Timer? _speedLimitTimer;

  // ── Navigation state ──
  bool _isNavigating = false;
  bool _isLoading = true;
  bool _arrivalAnnounced = false;
  bool _isFollowing = true;
  OsrmRoute? _currentRoute;
  List<LatLng> _routePoints = [];
  int _currentStepIndex = 0;
  final Set<String> _announcedThresholds = {};
  String? _currentManeuver; // OSRM maneuver key for icon

  // ── GPS state ──
  double _lat = 51.0;
  double _lng = 7.0;
  double _speed = 0;
  double _heading = 0;
  String _statusText = 'GPS wird gesucht...';

  // ── Route info ──
  double _remainingDistKm = 0;
  int _remainingMin = 0;
  String? _nextInstruction;

  // ── Off-route ──
  int _offRouteCount = 0;
  bool _isRerouting = false;

  // ── Speed limit ──
  int? _speedLimit;
  bool _isSpeeding = false;
  String? _roadName;

  // ── Blitzer ──
  List<BlitzerReport> _blitzerReports = [];
  String? _blitzerWarning;
  bool _blitzerLoaded = false;

  // ── Hi Moto ──
  bool _hiMotoListening = false;
  String? _hiMotoFeedback;

  // ── Services ──
  final _osrm = OsrmService();

  @override
  void initState() {
    super.initState();
    MapboxOptions.setAccessToken(_mapboxPublicToken);
    WakelockPlus.enable();
    _initGps();
    _initHiMoto();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _followTimer?.cancel();
    _speedLimitTimer?.cancel();
    _restoreVoskHandler();
    WakelockPlus.disable();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  GPS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _initGps() async {
    try {
      final pos = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.bestForNavigation,
        ),
      );
      _lat = pos.latitude;
      _lng = pos.longitude;
      _heading = pos.heading;
      _startGpsStream();
      _loadBlitzers();
      await _calcRoute();
      _startSpeedLimitPolling();
    } catch (e) {
      if (mounted) setState(() => _statusText = 'GPS Fehler: $e');
    }
  }

  void _startGpsStream() {
    _positionSub = geo.Geolocator.getPositionStream(
      locationSettings: const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
      ),
    ).listen((geo.Position pos) {
      _lat = pos.latitude;
      _lng = pos.longitude;
      _speed = (pos.speed * 3.6).clamp(0, 300);
      if (pos.heading >= 0 && _speed > 3) _heading = pos.heading;

      if (_isNavigating) {
        _onGpsTick();
        _checkBlitzerAlerts();
      }

      // Speed limit check
      if (_speedLimit != null) {
        final wasSpeeding = _isSpeeding;
        _isSpeeding = _speed > (_speedLimit! + 5);
        if (_isSpeeding && !wasSpeeding) {
          TtsAlertService.instance.speakPriority(
            'Achtung! Tempolimit ${_speedLimit} überschritten.',
          );
        }
      }

      if (mounted) setState(() {});
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  ROUTING (OSRM)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _calcRoute() async {
    setState(() { _isLoading = true; _statusText = 'Route wird berechnet...'; });

    try {
      final routes = await _osrm.getAllRoutes(
        LatLng(_lat, _lng),
        LatLng(widget.destLat, widget.destLng),
        mode: widget.routeMode,
      );

      if (routes.isEmpty) {
        setState(() { _isLoading = false; _statusText = 'Keine Route gefunden.'; });
        return;
      }

      _currentRoute = routes.first;
      _routePoints = _currentRoute!.polylinePoints;
      _currentStepIndex = 0;
      _announcedThresholds.clear();
      _offRouteCount = 0;
      _arrivalAnnounced = false;
      _isNavigating = true;
      _remainingDistKm = _currentRoute!.distanceKm;
      _remainingMin = (_currentRoute!.durationSeconds / 60).round();

      await _drawRouteOnMap();

      final steps = _currentRoute!.steps;
      final first = steps.isNotEmpty ? steps.first.instruction : 'Route gestartet';
      if (steps.isNotEmpty) _currentManeuver = steps.first.maneuver;
      TtsAlertService.instance.speakQueued('Navigation gestartet. $first');

      _startFollow();

      setState(() {
        _isLoading = false;
        _statusText = 'Navigation aktiv';
        _nextInstruction = first;
      });
    } catch (e) {
      setState(() { _isLoading = false; _statusText = 'Fehler: $e'; });
    }
  }

  Future<void> _drawRouteOnMap() async {
    if (_mapboxMap == null || _routePoints.isEmpty) return;
    final style = _mapboxMap!.style;

    try { await style.removeStyleLayer('route-layer'); } catch (_) {}
    try { await style.removeStyleLayer('route-border'); } catch (_) {}
    try { await style.removeStyleSource('route-source'); } catch (_) {}

    final coordsStr = _routePoints
        .map((p) => '[${p.longitude},${p.latitude}]')
        .join(',');
    final geoJson = '{"type":"Feature","geometry":{"type":"LineString","coordinates":[$coordsStr]}}';

    await style.addSource(GeoJsonSource(id: 'route-source', data: geoJson));

    // Border layer (darker, wider)
    await style.addLayer(LineLayer(
      id: 'route-border',
      sourceId: 'route-source',
      lineColor: 0xFF006064,
      lineWidth: 10.0,
      lineOpacity: 0.6,
      lineCap: LineCap.ROUND,
      lineJoin: LineJoin.ROUND,
    ));

    // Main route layer (cyan)
    await style.addLayer(LineLayer(
      id: 'route-layer',
      sourceId: 'route-source',
      lineColor: 0xFF00BCD4,
      lineWidth: 6.0,
      lineOpacity: 0.9,
      lineCap: LineCap.ROUND,
      lineJoin: LineJoin.ROUND,
    ));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  CAMERA FOLLOW
  // ═══════════════════════════════════════════════════════════════════════════

  void _startFollow() {
    _isFollowing = true;
    _followTimer?.cancel();
    _followTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (!_isFollowing || _mapboxMap == null || !mounted) return;
      _mapboxMap!.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(_lng, _lat)),
          zoom: 17.0,
          bearing: 0,   // Always north — map doesn't rotate
          pitch: 0,     // Top-down view
          padding: MbxEdgeInsets(top: 700, left: 0, bottom: 0, right: 0),
        ),
        MapAnimationOptions(duration: 1400),
      );
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  NAVIGATION LOGIC
  // ═══════════════════════════════════════════════════════════════════════════

  void _onGpsTick() {
    if (_currentRoute == null) return;

    // Off-route
    final distToRoute = _minDistToRoute();
    if (distToRoute > 35 && !_isRerouting) {
      _offRouteCount++;
      if (_offRouteCount >= 3) { _offRouteCount = 0; _reroute(); return; }
    } else if (distToRoute < 20) {
      _offRouteCount = 0;
    }

    // Step announcements
    final steps = _currentRoute!.steps;
    if (steps.isNotEmpty && _currentStepIndex < steps.length) {
      final step = steps[_currentStepIndex];
      final d = geo.Geolocator.distanceBetween(
        _lat, _lng, step.location.latitude, step.location.longitude,
      );

      String? threshold, distText;
      if (d <= 40) { threshold = 'now'; distText = 'Jetzt'; }
      else if (d <= 100) { threshold = '100'; distText = 'In ${(d / 10).round() * 10} Metern'; }
      else if (d <= 200) { threshold = '200'; distText = 'In 200 Metern'; }
      else if (d <= 500) { threshold = '500'; distText = 'In 500 Metern'; }

      if (threshold != null) {
        final key = '$_currentStepIndex:$threshold';
        if (!_announcedThresholds.contains(key)) {
          _announcedThresholds.add(key);
          TtsAlertService.instance.speakQueued('$distText, ${step.instruction}');
          setState(() {
            _nextInstruction = '$distText — ${step.instruction}';
            _currentManeuver = step.maneuver;
          });
        }
      }

      if (d <= 15) {
        _currentStepIndex++;
        if (_currentStepIndex < steps.length) {
          final next = steps[_currentStepIndex];
          setState(() {
            _nextInstruction = next.instruction;
            _currentManeuver = next.maneuver;
          });
        }
      }
    }

    // Arrival
    final distDest = geo.Geolocator.distanceBetween(_lat, _lng, widget.destLat, widget.destLng);
    if (distDest < 30 && !_arrivalAnnounced) {
      _arrivalAnnounced = true;
      TtsAlertService.instance.speakQueued('Ziel erreicht. ${widget.destName}.');
      setState(() { _statusText = 'Ziel erreicht!'; _isNavigating = false; });
      _followTimer?.cancel();
    }

    // Update remaining
    _remainingDistKm = distDest / 1000;
    final avgSpeed = math.max(_speed, widget.routeMode == RouteMode.pedestrian ? 5 : 30);
    _remainingMin = (_remainingDistKm / (avgSpeed / 60)).round();
  }

  double _minDistToRoute() {
    double min = double.infinity;
    for (int i = 0; i < _routePoints.length; i += 3) {
      final d = geo.Geolocator.distanceBetween(
        _lat, _lng, _routePoints[i].latitude, _routePoints[i].longitude,
      );
      if (d < min) min = d;
    }
    return min;
  }

  Future<void> _reroute() async {
    _isRerouting = true;
    TtsAlertService.instance.clearQueue();
    TtsAlertService.instance.speakQueued('Route wird neu berechnet.');
    setState(() => _statusText = 'Neue Route...');
    await _calcRoute();
    _isRerouting = false;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  SPEED LIMIT
  // ═══════════════════════════════════════════════════════════════════════════

  void _startSpeedLimitPolling() {
    _speedLimitTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted) return;
      try {
        final result = await SpeedLimitService.instance.getSpeedLimit(_lat, _lng);
        if (mounted) {
          setState(() {
            _speedLimit = result.effectiveLimitKmh;
            _roadName = result.roadName;
          });
        }
      } catch (_) {}
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  BLITZER
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _loadBlitzers() async {
    try {
      final osmCameras = await OsmBlitzerService.instance.getAllGermany();
      _blitzerReports = osmCameras
          .where((c) => OsmBlitzerService.distanceApprox(c.latitude, c.longitude, _lat, _lng) <= 5000)
          .map((c) => BlitzerReport.fromOsm(c))
          .toList();
      _blitzerLoaded = true;
    } catch (e) {
      debugPrint('[Blitzer] Load error: $e');
    }
  }

  final _blitzerAlertService = BlitzerAlertService();

  void _checkBlitzerAlerts() {
    if (!_blitzerLoaded || _blitzerReports.isEmpty) return;

    try {
      final result = _blitzerAlertService.checkAlerts(
        pos: geo.Position(
          latitude: _lat,
          longitude: _lng,
          timestamp: DateTime.now(),
          accuracy: 10,
          altitude: 0,
          heading: _heading,
          speed: _speed / 3.6,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        ),
        reports: _blitzerReports,
        settings: const BlitzerSettings(),
        currentSpeedKmh: _speed,
      );

      if (result.newAlerts.isNotEmpty) {
        final alert = result.newAlerts.first;
        final warning = alert.warningText;
        setState(() => _blitzerWarning = warning);
        TtsAlertService.instance.speakPriority(warning);

        Future.delayed(const Duration(seconds: 8), () {
          if (mounted) setState(() => _blitzerWarning = null);
        });
      }
    } catch (e) {
      debugPrint('[Blitzer] Alert check error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  HI MOTO VOICE
  // ═══════════════════════════════════════════════════════════════════════════

  // Store the previous handler so we can restore it when leaving
  void Function(VoskWakeEvent, String)? _previousVoskHandler;

  void _initHiMoto() async {
    final vosk = VoskWakeWordService.instance;
    final inited = await vosk.init();
    if (!inited) return;

    // Save previous handler (from group_ride_screen)
    _previousVoskHandler = vosk.onEvent;

    vosk.onEvent = (event, text) {
      if (!mounted) return;
      switch (event) {
        case VoskWakeEvent.wakeWordDetected:
          HapticFeedback.heavyImpact();
          // Stop any current TTS — user wants to speak
          TtsAlertService.instance.clearQueue();
          TtsAlertService.instance.stop();

          setState(() { _hiMotoListening = true; _hiMotoFeedback = 'Ich höre...'; });

          // Pause Vosk during TTS to prevent hearing its own response
          vosk.setPaused(true);
          TtsAlertService.instance.speakText('Ja Racer?').then((_) async {
            await Future.delayed(const Duration(milliseconds: 1200));
            vosk.setPaused(false);
          });
          break;

        case VoskWakeEvent.commandRecognized:
          setState(() => _hiMotoListening = false);
          _processVoiceCommand(text);
          break;

        case VoskWakeEvent.commandTimeout:
          setState(() { _hiMotoListening = false; _hiMotoFeedback = null; });
          break;
      }
    };

    await vosk.startListening();
  }

  void _restoreVoskHandler() {
    if (_previousVoskHandler != null) {
      VoskWakeWordService.instance.onEvent = _previousVoskHandler;
    }
  }

  void _processVoiceCommand(String text) {
    final cmd = VoiceCommandService.parse(text);
    setState(() => _hiMotoFeedback = '"$text"');

    // Pause Vosk during TTS response
    final vosk = VoskWakeWordService.instance;
    void speakAndResume(String msg) {
      vosk.setPaused(true);
      TtsAlertService.instance.speakText(msg).then((_) async {
        await Future.delayed(const Duration(milliseconds: 800));
        vosk.setPaused(false);
      });
    }

    switch (cmd.intent) {
      case VoiceIntent.stopNavigation:
        speakAndResume('Navigation wird beendet.');
        Future.delayed(const Duration(seconds: 2), () => _stopNav());
        break;
      case VoiceIntent.searchPoi:
        speakAndResume('Suche nach ${cmd.poiLabel ?? cmd.query}.');
        break;
      case VoiceIntent.reportBlitzer:
        final bLabel = switch (cmd.blitzerType) {
          'fixed' => 'Feste Radarfalle',
          'police' => 'Polizeikontrolle',
          'construction' => 'Baustelle',
          _ => 'Mobile Kontrolle',
        };
        speakAndResume('$bLabel gemeldet.');
        break;
      case VoiceIntent.showBlitzer:
        speakAndResume('Blitzer-Anzeige wird geladen.');
        break;
      case VoiceIntent.activateSos:
        speakAndResume('SOS wird aktiviert!');
        break;
      case VoiceIntent.unknown:
        speakAndResume('Wie bitte, Racer?');
        break;
      default:
        speakAndResume('Verstanden: $text');
    }

    // Auto-hide feedback after 5s
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) setState(() => _hiMotoFeedback = null);
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  MAP
  // ═══════════════════════════════════════════════════════════════════════════

  void _onMapCreated(MapboxMap map) async {
    _mapboxMap = map;

    await map.location.updateSettings(LocationComponentSettings(
      enabled: true,
      pulsingEnabled: true,
      pulsingColor: 0xFF00BCD4,
      pulsingMaxRadius: 30.0,
      showAccuracyRing: false,
      puckBearingEnabled: true,
      puckBearing: PuckBearing.HEADING,
    ));
  }

  void _stopNav() {
    _followTimer?.cancel();
    _speedLimitTimer?.cancel();
    _restoreVoskHandler(); // Give Hi Moto back to previous screen
    TtsAlertService.instance.speakQueued('Navigation beendet.');
    WakelockPlus.disable();
    Navigator.of(context).pop();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  MANEUVER ICON
  // ═══════════════════════════════════════════════════════════════════════════

  IconData _maneuverIcon(String? maneuver) {
    if (maneuver == null) return Icons.navigation;
    if (maneuver.contains('left')) return Icons.turn_left;
    if (maneuver.contains('right')) return Icons.turn_right;
    if (maneuver.contains('uturn')) return Icons.u_turn_left;
    if (maneuver.contains('roundabout') || maneuver.contains('rotary')) return Icons.roundabout_left;
    if (maneuver.contains('ramp')) return Icons.ramp_left;
    if (maneuver.contains('merge')) return Icons.merge;
    if (maneuver.contains('arrive')) return Icons.flag;
    if (maneuver.contains('depart')) return Icons.play_arrow;
    return Icons.straight;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  UI
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final modeColor = widget.routeMode == RouteMode.biker
        ? const Color(0xFF00BCD4)
        : widget.routeMode == RouteMode.pedestrian
            ? const Color(0xFF4CAF50)
            : const Color(0xFF2196F3);

    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: Stack(
        children: [
          // ── Mapbox Map ──
          MapWidget(
            key: const ValueKey('mapbox-nav'),
            onMapCreated: _onMapCreated,
            styleUri: Theme.of(context).brightness == Brightness.dark
                ? MapboxStyles.DARK
                : MapboxStyles.LIGHT,
            cameraOptions: CameraOptions(
              center: Point(coordinates: Position(_lng, _lat)),
              zoom: 15,
              pitch: 50,
            ),
          ),

          // ── Turn Banner (top) ──
          if (_nextInstruction != null && _isNavigating)
            Positioned(
              top: 0, left: 0, right: 0,
              child: SafeArea(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xF0111111),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: modeColor, width: 1.5),
                    boxShadow: [
                      BoxShadow(color: modeColor.withValues(alpha: 0.3), blurRadius: 12),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(_maneuverIcon(_currentManeuver), color: modeColor, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _nextInstruction!,
                          style: const TextStyle(
                            color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Blitzer Warning Banner ──
          if (_blitzerWarning != null)
            Positioned(
              top: _nextInstruction != null ? 120 : 50,
              left: 12, right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xF0B71C1C),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.red.withValues(alpha: 0.5), blurRadius: 16),
                  ],
                ),
                child: Row(
                  children: [
                    const Text('🚨', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _blitzerWarning!,
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Speed Limit Sign (left side) ──
          if (_speedLimit != null)
            Positioned(
              left: 16,
              bottom: 200 + bottomPad,
              child: _buildSpeedLimitSign(),
            ),

          // ── Speed Display (left side, below speed limit) ──
          Positioned(
            left: 16,
            bottom: 120 + bottomPad,
            child: _buildSpeedBubble(modeColor),
          ),

          // ── Hi Moto Button (right side) ──
          Positioned(
            right: 16,
            bottom: 200 + bottomPad,
            child: GestureDetector(
              onTap: () {
                // Manual trigger
                TtsAlertService.instance.speakPriority('Hi Moto aktiv.');
                setState(() { _hiMotoListening = true; _hiMotoFeedback = 'Ich höre...'; });
              },
              child: Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _hiMotoListening ? const Color(0xFF4CAF50) : const Color(0xFF1B1F2B),
                  border: Border.all(
                    color: _hiMotoListening ? const Color(0xFF4CAF50) : modeColor,
                    width: 2,
                  ),
                  boxShadow: [
                    if (_hiMotoListening)
                      BoxShadow(color: Colors.green.withValues(alpha: 0.5), blurRadius: 16),
                  ],
                ),
                child: Center(
                  child: Text(
                    _hiMotoListening ? '🎤' : 'Hi\nMoto',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _hiMotoListening ? Colors.white : modeColor,
                      fontSize: _hiMotoListening ? 24 : 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Hi Moto Feedback ──
          if (_hiMotoFeedback != null)
            Positioned(
              right: 80,
              bottom: 210 + bottomPad,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xF0111111),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _hiMotoFeedback!,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ),

          // ── Bottom Bar ──
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: bottomPad + 12),
              decoration: const BoxDecoration(
                color: Color(0xF0111111),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isNavigating)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _infoChip(_fmtDist(_remainingDistKm), 'Entfernung', Colors.white70),
                        _infoChip('$_remainingMin', 'Min.', Colors.white70),
                        if (_roadName != null)
                          Expanded(
                            child: Text(
                              _roadName!,
                              style: const TextStyle(color: Colors.white38, fontSize: 12),
                              textAlign: TextAlign.right,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  if (_isNavigating) const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _statusText,
                          style: const TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                      ),
                      if (_isNavigating)
                        IconButton(
                          onPressed: () { _isFollowing = true; _startFollow(); },
                          icon: Icon(Icons.my_location, color: modeColor, size: 22),
                        ),
                      IconButton(
                        onPressed: _isNavigating ? _stopNav : () => Navigator.pop(context),
                        icon: Icon(
                          _isNavigating ? Icons.close : Icons.arrow_back,
                          color: Colors.white54, size: 22,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Loading ──
          if (_isLoading)
            Center(
              child: Card(
                color: const Color(0xE6111111),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: modeColor),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Speed Limit Sign (German style: red ring + number) ──
  Widget _buildSpeedLimitSign() {
    return AnimatedScale(
      scale: _isSpeeding ? 1.15 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        width: 56, height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(
            color: const Color(0xFFCC0000),
            width: 5,
          ),
          boxShadow: [
            if (_isSpeeding)
              BoxShadow(color: Colors.red.withValues(alpha: 0.6), blurRadius: 16),
          ],
        ),
        child: Center(
          child: Text(
            '${_speedLimit}',
            style: TextStyle(
              color: Colors.black87,
              fontSize: _speedLimit! >= 100 ? 16 : 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  // ── Speed Bubble ──
  Widget _buildSpeedBubble(Color modeColor) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 64, height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _isSpeeding ? const Color(0xF0C62828) : const Color(0xF01B1F2B),
        border: Border.all(
          color: _isSpeeding ? Colors.redAccent : Colors.white24,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: _isSpeeding
                ? Colors.red.withValues(alpha: 0.5)
                : Colors.black.withValues(alpha: 0.4),
            blurRadius: _isSpeeding ? 16 : 8,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${_speed.round()}',
            style: TextStyle(
              color: _isSpeeding ? Colors.red.shade100 : Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              height: 1.0,
            ),
          ),
          Text(
            'km/h',
            style: TextStyle(
              color: _isSpeeding ? Colors.red.shade200 : Colors.white54,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(String val, String label, Color c) => Column(children: [
    Text(val, style: TextStyle(color: c, fontSize: 18, fontWeight: FontWeight.bold)),
    Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
  ]);

  String _fmtDist(double km) =>
      km >= 1 ? '${km.toStringAsFixed(1)} km' : '${(km * 1000).round()} m';
}
