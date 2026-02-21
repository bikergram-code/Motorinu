import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_bottom_bar.dart';
import '../../widgets/custom_icon_widget.dart';
import './widgets/control_panel_widget.dart';
import './widgets/ride_complete_dialog_widget.dart';
import './widgets/ride_stats_overlay_widget.dart';

class GpsRideTracker extends StatefulWidget {
  const GpsRideTracker({super.key});

  @override
  State<GpsRideTracker> createState() => _GpsRideTrackerState();
}

class _GpsRideTrackerState extends State<GpsRideTracker> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  final List<LatLng> _routePoints = [];
  final Set<Polyline> _polylines = {};
  final Set<Marker> _markers = {};

  // Ride tracking state
  bool _isTracking = false;
  bool _isPaused = false;
  DateTime? _rideStartTime;
  DateTime? _ridePauseTime;
  Duration _totalPauseDuration = Duration.zero;

  // Ride statistics
  double _totalDistance = 0.0;
  double _currentSpeed = 0.0;
  double _averageSpeed = 0.0;

  // Location subscription
  StreamSubscription<Position>? _positionStreamSubscription;

  // Privacy masking (mock home location - Cologne, Germany)
  final LatLng _homeLocation = const LatLng(50.9375, 6.9603);
  final double _privacyRadius = 200.0; // meters

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationServiceDialog();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showPermissionDeniedDialog();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showPermissionDeniedDialog();
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
      });

      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 16.0,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error initializing location: $e');
    }
  }

  void _startTracking() {
    if (_currentPosition == null) {
      _showLocationErrorDialog();
      return;
    }

    HapticFeedback.mediumImpact();

    setState(() {
      _isTracking = true;
      _isPaused = false;
      _rideStartTime = DateTime.now();
      _totalDistance = 0.0;
      _routePoints.clear();
      _polylines.clear();
      _markers.clear();
      _totalPauseDuration = Duration.zero;
    });

    _positionStreamSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen((Position position) {
          if (!_isPaused) {
            _updateRideData(position);
          }
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

  void _stopTracking() {
    HapticFeedback.heavyImpact();

    _positionStreamSubscription?.cancel();

    final rideData = {
      'distance': _totalDistance,
      'duration': _getRideDuration(),
      'averageSpeed': _averageSpeed,
      'routePoints': _routePoints,
      'startTime': _rideStartTime,
      'endTime': DateTime.now(),
    };

    setState(() {
      _isTracking = false;
      _isPaused = false;
    });

    _showRideCompleteDialog(rideData);
  }

  void _updateRideData(Position position) {
    setState(() {
      if (_routePoints.isNotEmpty) {
        final lastPoint = _routePoints.last;
        final distance = Geolocator.distanceBetween(
          lastPoint.latitude,
          lastPoint.longitude,
          position.latitude,
          position.longitude,
        );
        _totalDistance += distance;
      }

      _currentPosition = position;
      _currentSpeed = position.speed * 3.6; // Convert m/s to km/h

      final newPoint = LatLng(position.latitude, position.longitude);
      _routePoints.add(newPoint);

      _polylines.clear();
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: _routePoints,
          color: Theme.of(context).colorScheme.secondary,
          width: 5,
        ),
      );

      final duration = _getRideDuration();
      if (duration.inSeconds > 0) {
        _averageSpeed = (_totalDistance / 1000) / (duration.inSeconds / 3600);
      }

      _mapController?.animateCamera(CameraUpdate.newLatLng(newPoint));
    });
  }

  Duration _getRideDuration() {
    if (_rideStartTime == null) return Duration.zero;
    final now = _isPaused && _ridePauseTime != null
        ? _ridePauseTime!
        : DateTime.now();
    return now.difference(_rideStartTime!) - _totalPauseDuration;
  }

  bool _isNearHome(LatLng point) {
    final distance = Geolocator.distanceBetween(
      _homeLocation.latitude,
      _homeLocation.longitude,
      point.latitude,
      point.longitude,
    );
    return distance <= _privacyRadius;
  }

  void _centerOnCurrentLocation() {
    if (_currentPosition != null) {
      HapticFeedback.selectionClick();
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
            ),
            zoom: 16.0,
          ),
        ),
      );
    }
  }

  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Standortdienste deaktiviert'),
        content: const Text(
          'Bitte aktivieren Sie die Standortdienste, um Fahrten aufzuzeichnen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Standortberechtigung erforderlich'),
        content: const Text(
          'BikerGram benötigt Zugriff auf Ihren Standort, um Fahrten aufzuzeichnen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openAppSettings();
            },
            child: const Text('Einstellungen'),
          ),
        ],
      ),
    );
  }

  void _showLocationErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Standort nicht verfügbar'),
        content: const Text(
          'Ihr aktueller Standort konnte nicht ermittelt werden. Bitte versuchen Sie es erneut.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showRideCompleteDialog(Map<String, dynamic> rideData) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => RideCompleteDialogWidget(
        rideData: rideData,
        onShare: () {
          Navigator.pop(context);
          Navigator.pushNamed(context, '/main-social-feed');
        },
        onSave: () {
          Navigator.pop(context);
        },
        onDiscard: () {
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: CustomAppBar(
        variant: AppBarVariant.standard,
        title: 'GPS Ride Tracker',
        centerTitle: true,
        actions: [
          IconButton(
            icon: CustomIconWidget(
              iconName: 'settings',
              color: theme.colorScheme.onSurface,
              size: 24,
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
            },
            tooltip: 'Einstellungen',
          ),
        ],
      ),
      body: Stack(
        children: [
          _currentPosition == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        color: theme.colorScheme.secondary,
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        'Standort wird ermittelt...',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              : GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                    ),
                    zoom: 16.0,
                  ),
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  polylines: _polylines,
                  markers: _markers,
                  mapType: MapType.normal,
                ),
          if (_currentPosition != null) ...[
            RideStatsOverlayWidget(
              distance: _totalDistance,
              duration: _getRideDuration(),
              averageSpeed: _averageSpeed,
              currentSpeed: _currentSpeed,
              isTracking: _isTracking,
              isPaused: _isPaused,
            ),
            Positioned(
              right: 4.w,
              bottom: _isTracking ? 28.h : 20.h,
              child: FloatingActionButton(
                onPressed: _centerOnCurrentLocation,
                backgroundColor: theme.colorScheme.surface,
                child: CustomIconWidget(
                  iconName: 'my_location',
                  color: theme.colorScheme.secondary,
                  size: 24,
                ),
              ),
            ),
            ControlPanelWidget(
              isTracking: _isTracking,
              isPaused: _isPaused,
              onStart: _startTracking,
              onPause: _pauseTracking,
              onResume: _resumeTracking,
              onStop: _stopTracking,
            ),
          ],
        ],
      ),
      bottomNavigationBar: CustomBottomBar(
        currentIndex: 2,
        onTap: (index) {
          if (index != 2) {
            BottomBarNavigation.navigateToIndex(context, index);
          }
        },
      ),
    );
  }
}
