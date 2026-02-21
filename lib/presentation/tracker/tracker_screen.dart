import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/community.dart';
import '../../data/repositories/ride_repository.dart';
import '../../providers/core/providers.dart';
import '../../providers/ride/ride_notifier.dart';
import '../../theme/app_theme.dart';

class TrackerScreen extends ConsumerStatefulWidget {
  const TrackerScreen({super.key});

  @override
  ConsumerState<TrackerScreen> createState() => _TrackerScreenState();
}

class _TrackerScreenState extends ConsumerState<TrackerScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  final List<LatLng> _routePoints = [];
  final Set<Polyline> _polylines = {};

  bool _isTracking = false;
  bool _isPaused = false;
  bool _locationReady = false;
  bool _isSaving = false;
  String? _locationError;
  DateTime? _rideStartTime;
  DateTime? _ridePauseTime;
  Duration _totalPauseDuration = Duration.zero;

  double _totalDistance = 0.0; // meters
  double _currentSpeed = 0.0; // km/h
  double _maxSpeed = 0.0; // km/h
  double _averageSpeed = 0.0; // km/h

  StreamSubscription<Position>? _positionStream;
  Timer? _uiTimer;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _uiTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) _showDialog('Standortdienste deaktiviert', 'Bitte aktiviere GPS.');
        return;
      }

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) {
          if (mounted) _showDialog('Berechtigung verweigert', 'GPS-Zugriff wird benötigt.');
          return;
        }
      }
      if (perm == LocationPermission.deniedForever) {
        if (mounted) {
          _showDialog('Berechtigung dauerhaft verweigert',
              'Bitte erlaube GPS in den Einstellungen.',
              onSettings: () => Geolocator.openAppSettings());
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;
      setState(() {
        _currentPosition = pos;
        _locationReady = true;
      });

      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(pos.latitude, pos.longitude),
            zoom: 16.0,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Location init error: $e');
      if (mounted) {
        setState(() => _locationError = e.toString());
      }
    }
  }

  void _startTracking() {
    if (_currentPosition == null) {
      _showDialog('Standort fehlt', 'GPS wird noch ermittelt...');
      return;
    }

    HapticFeedback.mediumImpact();

    setState(() {
      _isTracking = true;
      _isPaused = false;
      _rideStartTime = DateTime.now();
      _totalDistance = 0;
      _currentSpeed = 0;
      _maxSpeed = 0;
      _averageSpeed = 0;
      _routePoints.clear();
      _polylines.clear();
      _totalPauseDuration = Duration.zero;
    });

    // Start UI timer for duration updates
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _isTracking && !_isPaused) setState(() {});
    });

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((pos) {
      if (!_isPaused) _updateRide(pos);
    });
  }

  void _pauseTracking() {
    HapticFeedback.lightImpact();
    setState(() {
      _isPaused = true;
      _ridePauseTime = DateTime.now();
    });
  }

  void _resumeTracking() {
    HapticFeedback.lightImpact();
    if (_ridePauseTime != null) {
      _totalPauseDuration += DateTime.now().difference(_ridePauseTime!);
    }
    setState(() {
      _isPaused = false;
      _ridePauseTime = null;
    });
  }

  Future<void> _stopTracking() async {
    HapticFeedback.heavyImpact();

    _positionStream?.cancel();
    _uiTimer?.cancel();

    final duration = _getRideDuration();
    final distanceKm = _totalDistance / 1000;

    setState(() {
      _isTracking = false;
      _isPaused = false;
    });

    // Only save rides longer than 100m
    if (distanceKm < 0.1) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fahrt zu kurz zum Speichern.')),
        );
      }
      return;
    }

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(rideRepositoryProvider);
      final ride = await repo.saveRide(
        startedAt: _rideStartTime!,
        endedAt: DateTime.now(),
        distanceKm: distanceKm,
        durationSeconds: duration.inSeconds,
        avgSpeedKmh: _averageSpeed,
        maxSpeedKmh: _maxSpeed,
      );

      ref.read(rideHistoryNotifierProvider.notifier).addRide(ride);

      if (!mounted) return;
      _showRideCompleteDialog(ride);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _updateRide(Position pos) {
    setState(() {
      if (_routePoints.isNotEmpty) {
        final last = _routePoints.last;
        final dist = Geolocator.distanceBetween(
          last.latitude, last.longitude,
          pos.latitude, pos.longitude,
        );
        _totalDistance += dist;
      }

      _currentPosition = pos;
      _currentSpeed = pos.speed * 3.6; // m/s → km/h
      if (_currentSpeed > _maxSpeed) _maxSpeed = _currentSpeed;

      final newPoint = LatLng(pos.latitude, pos.longitude);
      _routePoints.add(newPoint);

      _polylines
        ..clear()
        ..add(Polyline(
          polylineId: const PolylineId('route'),
          points: _routePoints,
          color: ref.read(communityProvider)?.accentColor ?? AppTheme.accentDark,
          width: 5,
        ));

      final duration = _getRideDuration();
      if (duration.inSeconds > 0) {
        _averageSpeed = (_totalDistance / 1000) / (duration.inSeconds / 3600);
      }

      _mapController?.animateCamera(CameraUpdate.newLatLng(newPoint));
    });
  }

  Duration _getRideDuration() {
    if (_rideStartTime == null) return Duration.zero;
    final end = _isPaused && _ridePauseTime != null
        ? _ridePauseTime!
        : DateTime.now();
    return end.difference(_rideStartTime!) - _totalPauseDuration;
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _showDialog(String title, String message, {VoidCallback? onSettings}) {
    final community = ref.read(communityProvider);
    final brightness = Theme.of(context).brightness;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: community?.cardFor(brightness) ?? (brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white),
        title: Text(title, style: TextStyle(color: brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A))),
        content: Text(message, style: TextStyle(color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF6C757D))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
          if (onSettings != null)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                onSettings();
              },
              child: const Text('Einstellungen'),
            ),
        ],
      ),
    );
  }

  void _showRideCompleteDialog(RideRecord ride) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final community = ref.read(communityProvider);
        final brightness = Theme.of(context).brightness;
        final accentColor = community?.accentColor ?? AppTheme.accentDark;

        return AlertDialog(
          backgroundColor: community?.cardFor(brightness) ?? (brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: accentColor, size: 28),
              const SizedBox(width: 10),
              Text('Fahrt gespeichert!',
                  style: GoogleFonts.inter(
                      fontSize: 18, fontWeight: FontWeight.w700, color: brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _rideStatRow('Distanz', '${ride.distanceKm.toStringAsFixed(1)} km'),
              _rideStatRow('Dauer', ride.formattedDuration),
              _rideStatRow('\u00d8 Tempo', '${ride.avgSpeedKmh.toStringAsFixed(1)} km/h'),
              _rideStatRow('Max Tempo', '${ride.maxSpeedKmh.toStringAsFixed(1)} km/h'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bolt_rounded, color: accentColor, size: 20),
                    const SizedBox(width: 6),
                    Text('+${ride.xpEarned} XP',
                        style: GoogleFonts.inter(
                            fontSize: 16, fontWeight: FontWeight.w700, color: accentColor)),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Schließen',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: accentColor)),
            ),
          ],
        );
      },
    );
  }

  Widget _rideStatRow(String label, String value) {
    final brightness = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(
              fontSize: 14, color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF6C757D))),
          Text(value, style: GoogleFonts.inter(
              fontSize: 14, fontWeight: FontWeight.w600, color: brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final community = ref.watch(communityProvider);
    final brightness = Theme.of(context).brightness;
    final accentColor = community?.accentColor ?? AppTheme.accentDark;
    final duration = _getRideDuration();

    return Scaffold(
      backgroundColor: community?.scaffoldFor(brightness) ?? (brightness == Brightness.dark ? Colors.black : const Color(0xFFF5F5F5)),
      body: Stack(
        children: [
          // Map
          if (_locationReady && _currentPosition != null)
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(
                    _currentPosition!.latitude, _currentPosition!.longitude),
                zoom: 16.0,
              ),
              onMapCreated: (c) => _mapController = c,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              polylines: _polylines,
              mapType: MapType.normal,
            )
          else
            Container(
              color: community?.navBarFor(brightness) ?? (brightness == Brightness.dark ? const Color(0xFF0D0D0D) : const Color(0xFFF5F5F5)),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_locationError != null) ...[
                      Icon(Icons.location_off_rounded,
                          size: 48, color: Colors.white.withValues(alpha: 0.2)),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'Standort konnte nicht ermittelt werden',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.5)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'Stelle sicher, dass GPS aktiviert ist und die App Standort-Berechtigung hat.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.3)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() => _locationError = null);
                          _initLocation();
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: Text('Erneut versuchen',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ] else ...[
                      CircularProgressIndicator(color: accentColor),
                      const SizedBox(height: 16),
                      Text('Standort wird ermittelt...',
                          style: GoogleFonts.inter(
                              fontSize: 15,
                              color: Colors.white.withValues(alpha: 0.4))),
                    ],
                  ],
                ),
              ),
            ),

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  // Back button
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('Ride Tracker',
                        style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                  const Spacer(),
                  // Ride history button
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed: () => context.push('/ride-history'),
                      icon: const Icon(Icons.history_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Center on location FAB
          if (_locationReady)
            Positioned(
              right: 16,
              bottom: _isTracking ? 310 : 250,
              child: FloatingActionButton.small(
                heroTag: 'center_location',
                onPressed: () {
                  if (_currentPosition != null) {
                    _mapController?.animateCamera(
                      CameraUpdate.newLatLng(LatLng(
                          _currentPosition!.latitude,
                          _currentPosition!.longitude)),
                    );
                  }
                },
                backgroundColor: Colors.black.withValues(alpha: 0.7),
                child: Icon(Icons.my_location_rounded,
                    color: accentColor, size: 20),
              ),
            ),

          // Bottom panel
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: community?.cardFor(brightness) ?? (brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.06)),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Stats
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _TrackerStat(
                            value: (_totalDistance / 1000).toStringAsFixed(1),
                            unit: 'km',
                            label: 'Distanz',
                          ),
                          _TrackerStat(
                            value: _formatDuration(duration),
                            unit: '',
                            label: 'Zeit',
                          ),
                          _TrackerStat(
                            value: _averageSpeed.toStringAsFixed(1),
                            unit: 'km/h',
                            label: '\u00d8 Tempo',
                          ),
                        ],
                      ),

                      if (_isTracking) ...[
                        const SizedBox(height: 12),
                        // Current speed
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.speed_rounded,
                                  color: accentColor, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                '${_currentSpeed.toStringAsFixed(0)} km/h',
                                style: GoogleFonts.inter(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: accentColor),
                              ),
                            ],
                          ),
                        ),
                      ],

                      if (!_isTracking) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: accentColor.withValues(alpha: 0.15)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.bolt_rounded,
                                  color: accentColor, size: 18),
                              const SizedBox(width: 6),
                              Text('1 XP pro Kilometer',
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: accentColor)),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Control buttons
                      if (!_isTracking)
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _locationReady ? _startTracking : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.play_arrow_rounded, size: 28),
                                const SizedBox(width: 8),
                                Text('Fahrt starten',
                                    style: GoogleFonts.inter(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        )
                      else
                        Row(
                          children: [
                            // Pause/Resume
                            Expanded(
                              child: SizedBox(
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: _isPaused
                                      ? _resumeTracking
                                      : _pauseTracking,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2A2A2A),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(16)),
                                    elevation: 0,
                                  ),
                                  child: Icon(
                                    _isPaused
                                        ? Icons.play_arrow_rounded
                                        : Icons.pause_rounded,
                                    size: 28,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Stop
                            Expanded(
                              flex: 2,
                              child: SizedBox(
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: _isSaving ? null : _stopTracking,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.errorDark,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(16)),
                                    elevation: 0,
                                  ),
                                  child: _isSaving
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white))
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.stop_rounded,
                                                size: 28),
                                            const SizedBox(width: 8),
                                            Text('Beenden',
                                                style: GoogleFonts.inter(
                                                    fontSize: 16,
                                                    fontWeight:
                                                        FontWeight.w700)),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                          ],
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
}

class _TrackerStat extends StatelessWidget {
  const _TrackerStat({
    required this.value,
    required this.unit,
    required this.label,
  });

  final String value;
  final String unit;
  final String label;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Column(
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A)),
              ),
              if (unit.isNotEmpty)
                TextSpan(
                  text: ' $unit',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.4) : const Color(0xFF6C757D)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 12,
                color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.4) : const Color(0xFF6C757D))),
      ],
    );
  }
}
