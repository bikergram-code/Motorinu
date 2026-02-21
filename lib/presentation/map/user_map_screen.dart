import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/community.dart';
import '../../providers/core/providers.dart';
import '../../providers/auth/auth_notifier.dart';
import '../../providers/auth/auth_state.dart';
import '../../providers/map/live_location_provider.dart';
import '../../providers/blitzer/navigation_provider.dart';
import '../../services/live_location_service.dart';
import '../../theme/app_theme.dart';

class UserMapScreen extends ConsumerStatefulWidget {
  const UserMapScreen({super.key});

  @override
  ConsumerState<UserMapScreen> createState() => _UserMapScreenState();
}

class _UserMapScreenState extends ConsumerState<UserMapScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  bool _isLoading = true;
  Set<Marker> _offlineMarkers = {};
  List<Map<String, dynamic>> _users = [];
  String? _error;

  // Live GPS
  StreamSubscription<Map<String, LiveUserPosition>>? _liveSub;
  Map<String, LiveUserPosition> _liveUsers = {};

  // Map type
  MapType _mapType = MapType.normal;

  @override
  void initState() {
    super.initState();
    _initLocation();
    _listenToLiveUsers();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _liveSub?.cancel();
    super.dispose();
  }

  void _listenToLiveUsers() {
    final service = ref.read(liveLocationServiceProvider);
    _liveSub = service.nearbyUsersStream.listen((users) {
      if (!mounted) return;
      setState(() {
        _liveUsers = users;
      });
    });
  }

  Future<void> _initLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLoading = false;
          _error = 'GPS deaktiviert';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLoading = false;
            _error = 'GPS-Berechtigung verweigert';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoading = false;
          _error = 'GPS dauerhaft deaktiviert';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );

      setState(() {
        _currentPosition = position;
      });

      await _loadUsers();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Standort nicht verfuegbar';
      });
    }
  }

  Future<void> _loadUsers() async {
    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;

      final data = await Supabase.instance.client
          .from('profiles')
          .select('id, username, display_name, avatar_url, postal_code')
          .not('postal_code', 'is', null);

      final users = <Map<String, dynamic>>[];
      final markers = <Marker>{};

      for (final profile in data) {
        final postalCode = profile['postal_code'] as String?;
        if (postalCode == null || postalCode.isEmpty) continue;

        final coords = _plzToCoords(postalCode);
        if (coords == null) continue;

        final displayName =
            profile['display_name'] ?? profile['username'] ?? 'User';
        final isMe = profile['id'] == currentUserId;

        users.add(
            {...profile, 'lat': coords.latitude, 'lng': coords.longitude});

        markers.add(
          Marker(
            markerId: MarkerId('plz_${profile['id']}'),
            position: coords,
            infoWindow: InfoWindow(
              title: isMe ? '$displayName (Du)' : displayName as String,
              snippet: 'PLZ: $postalCode',
            ),
            icon: isMe
                ? BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueAzure)
                : BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueOrange),
            alpha: 0.5, // Dimmed for offline/PLZ markers
          ),
        );
      }

      setState(() {
        _users = users;
        _offlineMarkers = markers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Fehler beim Laden: $e';
      });
    }
  }

  void _toggleMapType() {
    setState(() {
      _mapType = _mapType == MapType.hybrid ? MapType.normal : MapType.hybrid;
    });
    _applyMapStyle();
  }

  void _applyMapStyle() {
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_mapType == MapType.normal && isDark) {
      _mapController?.setMapStyle(_darkMapStyle);
    } else {
      _mapController?.setMapStyle(null);
    }
  }

  /// Toggle live GPS broadcasting on/off.
  Future<void> _toggleLive() async {
    final service = ref.read(liveLocationServiceProvider);
    final authState = ref.read(authNotifierProvider);

    if (service.isLive) {
      await service.goOffline();
      ref.read(isLiveProvider.notifier).set(false);
    } else {
      if (authState is! Authenticated) return;

      final user = authState.user;
      final plzRegion = user.postalCode;

      final community = ref.read(communityProvider);

      await service.goLive(
        userId: user.id,
        displayName: user.displayName ?? user.bikername ?? user.username,
        avatarUrl: user.avatarUrl,
        plzRegion: plzRegion,
        xpTotal: user.xpTotal ?? 0,
        bikeName: user.bikername,
        community: community?.name ?? 'bikergram',
      );
      ref.read(isLiveProvider.notifier).set(true);
    }
    setState(() {});
  }

  /// Build combined markers: offline PLZ markers + live GPS markers.
  Set<Marker> _buildAllMarkers() {
    final all = <Marker>{..._offlineMarkers};

    // Add live user markers (bright green, on top)
    for (final entry in _liveUsers.entries) {
      final user = entry.value;
      all.add(
        Marker(
          markerId: MarkerId('live_${user.userId}'),
          position: LatLng(user.lat, user.lng),
          infoWindow: InfoWindow(
            title: '${user.displayName} (Live)',
            snippet: '${user.speed.toStringAsFixed(0)} km/h',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen),
          zIndex: 10,
        ),
      );
    }

    return all;
  }

  LatLng? _plzToCoords(String plz) {
    if (plz.isEmpty) return null;
    final code = int.tryParse(plz.replaceAll(RegExp(r'[^0-9]'), ''));
    if (code == null) return null;

    final region = code ~/ 10000;
    switch (region) {
      case 0:
        return LatLng(51.05 + (code % 10000) * 0.00005,
            13.74 + (code % 1000) * 0.0003);
      case 1:
        return LatLng(52.52 + (code % 10000) * 0.00004,
            13.40 + (code % 1000) * 0.0002);
      case 2:
        return LatLng(53.55 + (code % 10000) * 0.00003,
            9.99 + (code % 1000) * 0.0003);
      case 3:
        return LatLng(52.37 + (code % 10000) * 0.00004,
            9.74 + (code % 1000) * 0.0002);
      case 4:
        return LatLng(51.48 + (code % 10000) * 0.00003,
            7.45 + (code % 1000) * 0.0002);
      case 5:
        return LatLng(50.94 + (code % 10000) * 0.00003,
            6.96 + (code % 1000) * 0.0003);
      case 6:
        return LatLng(50.11 + (code % 10000) * 0.00004,
            8.68 + (code % 1000) * 0.0002);
      case 7:
        return LatLng(48.78 + (code % 10000) * 0.00004,
            9.18 + (code % 1000) * 0.0002);
      case 8:
        return LatLng(48.14 + (code % 10000) * 0.00004,
            11.58 + (code % 1000) * 0.0002);
      case 9:
        return LatLng(49.45 + (code % 10000) * 0.00004,
            11.08 + (code % 1000) * 0.0002);
      default:
        return const LatLng(51.16, 10.45);
    }
  }

  @override
  Widget build(BuildContext context) {
    final community = ref.watch(communityProvider);
    final brightness = Theme.of(context).brightness;
    final accentColor = community?.accentColor ?? AppTheme.accentDark;
    final isLive = ref.watch(isLiveProvider);
    final liveCount = _liveUsers.length;

    // Re-register Speed-Dial items every build (ensures they persist after tab switches)
    final location = GoRouterState.of(context).matchedLocation;
    if (location == '/map') {
      Future.microtask(() {
        if (!mounted) return;
        ref.read(speedDialItemsProvider.notifier).register([
          SpeedDialItem(
            icon: Icons.my_location_rounded,
            label: 'Standort',
            color: Colors.blue,
            onTap: () {
              if (!mounted) return;
              if (_currentPosition != null) {
                _mapController?.animateCamera(CameraUpdate.newLatLngZoom(
                  LatLng(_currentPosition!.latitude, _currentPosition!.longitude), 13.0));
              }
            },
          ),
          SpeedDialItem(
            icon: Icons.gps_fixed_rounded,
            label: 'Live',
            color: Colors.green,
            onTap: () { if (!mounted) return; _toggleLive(); },
          ),
        ]);
      });
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Map
          if (_error != null)
            _buildErrorState(accentColor)
          else if (_isLoading)
            const Center(
                child: CircularProgressIndicator(strokeWidth: 2))
          else
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _currentPosition != null
                    ? LatLng(_currentPosition!.latitude,
                        _currentPosition!.longitude)
                    : const LatLng(51.16, 10.45),
                zoom: 6,
              ),
              markers: _buildAllMarkers(),
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              mapType: _mapType,
              onMapCreated: (controller) {
                _mapController = controller;
                // Apply dark style immediately after map is ready
                _applyMapStyle();
              },
            ),

          // Badges below global top bar
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 52, 12, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Live count badge
                    if (liveCount > 0) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.green)),
                          const SizedBox(width: 5),
                          Text('$liveCount live', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green)),
                        ]),
                      ),
                      const SizedBox(width: 8),
                    ],
                    // Rider count badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.people_rounded, color: accentColor, size: 16),
                        const SizedBox(width: 6),
                        Text('${_users.length} Rider', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: accentColor)),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // FAB stack: Live toggle + My location
          Positioned(
            right: 16,
            bottom: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Live toggle button
                FloatingActionButton(
                  heroTag: 'live_toggle',
                  onPressed: _toggleLive,
                  backgroundColor: isLive
                      ? Colors.green
                      : const Color(0xFF1A1A1A),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isLive
                            ? Icons.gps_fixed_rounded
                            : Icons.gps_not_fixed_rounded,
                        color: isLive ? Colors.white : accentColor,
                        size: 24,
                      ),
                      Text(
                        isLive ? 'LIVE' : 'Live',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: isLive ? Colors.white : accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // My location button
                FloatingActionButton.small(
                  heroTag: 'my_location',
                  onPressed: () {
                    if (_currentPosition != null &&
                        _mapController != null) {
                      _mapController!.animateCamera(
                        CameraUpdate.newLatLngZoom(
                          LatLng(_currentPosition!.latitude,
                              _currentPosition!.longitude),
                          12,
                        ),
                      );
                    }
                  },
                  backgroundColor: const Color(0xFF1A1A1A),
                  child: Icon(Icons.my_location_rounded,
                      color: accentColor, size: 22),
                ),
                const SizedBox(height: 8),

                // Map type toggle button
                FloatingActionButton.small(
                  heroTag: 'map_type_toggle',
                  onPressed: _toggleMapType,
                  backgroundColor: const Color(0xFF1A1A1A),
                  child: Icon(
                    _mapType == MapType.hybrid
                        ? Icons.map_rounded
                        : Icons.satellite_alt_rounded,
                    color: accentColor,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Color accentColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off_rounded,
              size: 48, color: Colors.white.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text(
            _error ?? 'Fehler',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              setState(() {
                _isLoading = true;
                _error = null;
              });
              _initLocation();
            },
            child: Text('Erneut versuchen',
                style: GoogleFonts.inter(
                    color: accentColor, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // Dark map style JSON
  static const String _darkMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#212121"}]},
  {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#212121"}]},
  {"featureType":"administrative","elementType":"geometry","stylers":[{"color":"#757575"}]},
  {"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
  {"featureType":"road","elementType":"geometry.fill","stylers":[{"color":"#2c2c2c"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#8a8a8a"}]},
  {"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#373737"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#3c3c3c"}]},
  {"featureType":"transit","elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#000000"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#3d3d3d"}]}
]
''';
}
