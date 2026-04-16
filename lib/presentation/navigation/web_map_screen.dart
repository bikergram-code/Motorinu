import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api_config.dart';
import '../../core/community.dart';
import '../../data/repositories/events_repository.dart';
import '../../domain/models/event.dart';
import '../../providers/auth/auth_notifier.dart';
import '../../providers/auth/auth_state.dart';
import '../../providers/core/providers.dart';
import '../../providers/map/live_location_provider.dart';
import '../../services/live_location_service.dart';
import '../../services/poi_search_service.dart';

/// Lightweight web map — shows live users + events on OpenStreetMap.
class WebMapScreen extends ConsumerStatefulWidget {
  const WebMapScreen({super.key});

  @override
  ConsumerState<WebMapScreen> createState() => _WebMapScreenState();
}

class _WebMapScreenState extends ConsumerState<WebMapScreen> {
  final MapController _mapController = MapController();
  bool _isGpsLive = false; // true = broadcasting real GPS via goLive()
  List<BikerEvent> _events = [];
  bool _showEvents = false;
  bool _showUsers = true;
  bool _showPois = false;
  LatLng? _myPosition; // actual GPS position (only when GPS ON)
  LatLng? _plzPosition; // PLZ-based home position
  bool _gpsLoading = false;
  bool _poisLoading = false;
  double _currentZoom = 6.0; // Track zoom for adaptive markers
  String? _highlightedUserId; // Pulsierender Ring um visierten User

  /// ALL community users at their PLZ/home positions.
  List<_PlzUser> _allPlzUsers = [];

  /// POI results from Overpass API (loaded on-demand).
  List<PoiResult> _pois = [];
  LatLng? _lastPoiSearchCenter; // Prevent redundant searches

  static const _defaultCenter = LatLng(51.1657, 10.4515);
  static const _defaultZoom = 6.0;

  @override
  void initState() {
    super.initState();
    // ★ Respect global service state (MainShell may have started goLive)
    _isGpsLive = globalLiveLocationService.isLive;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startListening();
      _loadEvents();
      if (_isGpsLive) {
        _getMyPosition(); // Already live → fly to GPS position
      } else {
        _initPlzPosition(); // Not live → fly to PLZ
      }
      _loadAllUsersPlz();
    });
  }

  void _startListening() {
    if (globalLiveLocationService.isLive) return;
    final authState = ref.read(authNotifierProvider);
    if (authState is Authenticated) {
      globalLiveLocationService.startListening(userId: authState.user.id);
    }
  }

  /// Fly to user's PLZ position on init (like native map does).
  void _initPlzPosition() {
    final authState = ref.read(authNotifierProvider);
    if (authState is! Authenticated) return;
    final plz = authState.user.postalCode;
    if (plz == null || plz.isEmpty) return;

    final coords = _plzToCoords(plz);
    if (coords != null) {
      _plzPosition = coords;
      debugPrint('[WebMap] PLZ position: $plz → ${coords.latitude}, ${coords.longitude}');
      _mapController.move(coords, 8.0);
      if (mounted) setState(() {});
    }
  }

  /// Load ALL community users' PLZ positions from Supabase profiles.
  /// These are the "home" markers — where users live (GPS OFF).
  Future<void> _loadAllUsersPlz() async {
    final authState = ref.read(authNotifierProvider);
    if (authState is! Authenticated) return;
    final myId = authState.user.id;
    final community = ref.read(communityProvider)?.name ?? 'bikergram';

    try {
      final supabase = Supabase.instance.client;
      // Load all profiles with a PLZ (community filter via column if exists, else all)
      final profilesRes = await supabase
          .from('profiles')
          .select('id, username, avatar_url, postal_code')
          .neq('id', myId) // Exclude self (own puck shown separately)
          .not('postal_code', 'is', null)
          .limit(500);
      final profiles = profilesRes as List;

      final users = <_PlzUser>[];
      for (final p in profiles) {
        final plz = p['postal_code'] as String?;
        if (plz == null || plz.isEmpty) continue;
        final coords = _plzToCoords(plz);
        if (coords == null) continue;
        users.add(_PlzUser(
          userId: p['id'] as String,
          username: p['username'] as String? ?? '?',
          avatarUrl: p['avatar_url'] as String?,
          position: coords,
        ));
      }
      if (mounted) setState(() => _allPlzUsers = users);
      debugPrint('[WebMap] Loaded ${users.length} community users PLZ markers');
    } catch (e) {
      debugPrint('[WebMap] loadAllUsersPlz error: $e');
    }
  }

  Future<void> _loadEvents() async {
    try {
      final community = ref.read(communityProvider)?.name ?? 'bikergram';
      // Load upcoming events for map markers
      final upcoming = await EventsRepository().getUpcomingEvents(
        community: community,
        limit: 100,
      );
      if (mounted) setState(() => _events = upcoming);
      debugPrint('[WebMap] Loaded ${upcoming.length} upcoming events'
          ' (${upcoming.where((e) => e.latitude != null).length} with coords)');
    } catch (e) {
      debugPrint('[WebMap] loadEvents error: $e');
    }
  }

  /// Load POIs around the current map center via Overpass API.
  /// Uses radius based on zoom level — close zoom = small radius.
  Future<void> _loadPois() async {
    final center = _mapController.camera.center;
    // Skip if we searched near the same spot already (< 2 km)
    if (_lastPoiSearchCenter != null) {
      final dist = const Distance().as(LengthUnit.Meter, center, _lastPoiSearchCenter!);
      if (dist < 2000 && _pois.isNotEmpty) return;
    }

    setState(() => _poisLoading = true);
    _lastPoiSearchCenter = center;

    try {
      // Search most useful POI categories around map center
      final cats = [PoiCategory.fuel, PoiCategory.restaurant, PoiCategory.cafe];
      final allResults = <PoiResult>[];

      for (final cat in cats) {
        final results = await PoiSearchService.instance.search(
          lat: center.latitude,
          lon: center.longitude,
          category: cat,
          limit: 15,
        );
        allResults.addAll(results);
      }

      if (mounted) {
        setState(() {
          _pois = allResults;
          _poisLoading = false;
        });
      }
      debugPrint('[WebMap] Loaded ${allResults.length} POIs around ${center.latitude.toStringAsFixed(3)}, ${center.longitude.toStringAsFixed(3)}');
    } catch (e) {
      debugPrint('[WebMap] loadPois error: $e');
      if (mounted) setState(() => _poisLoading = false);
    }
  }

  Future<void> _getMyPosition() async {
    try {
      setState(() => _gpsLoading = true);
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          if (mounted) setState(() => _gpsLoading = false);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _gpsLoading = false);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (mounted) {
        setState(() {
          _myPosition = LatLng(pos.latitude, pos.longitude);
          _gpsLoading = false;
        });
        _mapController.move(_myPosition!, 14.0);
      }
    } catch (e) {
      debugPrint('[WebMap] GPS error: $e');
      if (mounted) setState(() => _gpsLoading = false);
    }
  }

  @override
  void dispose() {
    // ★ Don't call goOffline() — MainShell manages global GPS lifecycle.
    // GPS state survives page navigation.
    super.dispose();
  }

  /// GPS Toggle — only affects OWN position broadcasting:
  /// OFF → I appear at my PLZ (home), see everyone
  /// ON  → I broadcast real GPS, fly to my actual position
  /// BOTH modes always show: PLZ-users (home) + live-users (real GPS)
  Future<void> _toggleGps() async {
    final authState = ref.read(authNotifierProvider);
    if (authState is! Authenticated) return;
    final user = authState.user;

    if (_isGpsLive) {
      // Turn OFF → stop broadcasting, go back to PLZ
      await globalLiveLocationService.goOffline();
      globalLiveLocationService.startListening(userId: user.id);
      setState(() {
        _isGpsLive = false;
        _myPosition = null;
      });
      // Fly back to PLZ position (home)
      if (_plzPosition != null) {
        _mapController.move(_plzPosition!, 8.0);
      }
    } else {
      // Turn ON → broadcast real GPS position
      final community = ref.read(communityProvider)?.name ?? 'bikergram';
      await globalLiveLocationService.goLive(
        userId: user.id,
        displayName: user.displayName ?? user.username ?? '',
        avatarUrl: user.avatarUrl,
        plzRegion: user.postalCode,
        xpTotal: user.xpTotal,
        followerCount: user.followerCount,
        community: community,
      );
      setState(() => _isGpsLive = true);
      // Fly to actual GPS position
      _getMyPosition();
    }
  }

  void _centerOnMe() {
    if (_isGpsLive && _myPosition != null) {
      _mapController.move(_myPosition!, 14.0);
    } else if (_plzPosition != null) {
      _mapController.move(_plzPosition!, 11.0);
    } else {
      _getMyPosition();
    }
  }

  /// Offline PLZ → LatLng mapper for German postal codes.
  static LatLng? _plzToCoords(String plz) {
    if (plz.isEmpty) return null;
    final trimmed = plz.trim();
    final code = int.tryParse(trimmed.replaceAll(RegExp(r'[^0-9]'), ''));
    if (code == null) return null;
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
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final community = ref.watch(communityProvider);
    final accentColor = community?.accentColor ?? Colors.amber;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Current user info for puck
    final authState = ref.watch(authNotifierProvider);
    String? myAvatarUrl;
    String myDisplayName = '';
    String? myUserId;
    if (authState is Authenticated) {
      myAvatarUrl = authState.user.avatarUrl;
      myDisplayName = authState.user.displayName ?? authState.user.username ?? '';
      myUserId = authState.user.id;
    }

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: Stack(
        children: [
          // ── Map ── (Listener handles scroll-zoom manually for web)
          Listener(
            onPointerSignal: (event) {
              if (event is PointerScrollEvent) {
                final currentZoom = _mapController.camera.zoom;
                final newZoom = (currentZoom - event.scrollDelta.dy * 0.001)
                    .clamp(1.0, 22.0);
                _mapController.move(
                    _mapController.camera.center, newZoom);
              }
            },
            child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _defaultCenter,
              initialZoom: _defaultZoom,
              minZoom: 1,
              maxZoom: 22,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.scrollWheelZoom,
              ),
              onPositionChanged: (pos, _) {
                final z = pos.zoom;
                if (z != null && (z - _currentZoom).abs() > 0.5) {
                  setState(() => _currentZoom = z);
                }
              },
            ),
            children: [
              // Mapbox tiles — same navigation style as the native app
              TileLayer(
                urlTemplate: ApiConfig.mapboxPublicToken.isNotEmpty
                    ? (isDark
                        ? 'https://api.mapbox.com/styles/v1/mapbox/navigation-night-v1/tiles/256/{z}/{x}/{y}@2x?access_token=${ApiConfig.mapboxPublicToken}'
                        : 'https://api.mapbox.com/styles/v1/mapbox/navigation-day-v1/tiles/256/{z}/{x}/{y}@2x?access_token=${ApiConfig.mapboxPublicToken}')
                    : (isDark
                        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png'
                        : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png'),
                subdomains: ApiConfig.mapboxPublicToken.isEmpty
                    ? const ['a', 'b', 'c', 'd']
                    : const [],
                userAgentPackageName: 'com.bikergram.app',
                maxZoom: 22,
              ),

              // Event markers
              if (_showEvents)
                MarkerLayer(
                  markers: _events
                      .where((e) => e.latitude != null && e.longitude != null)
                      .map((e) => Marker(
                            point: LatLng(e.latitude!, e.longitude!),
                            width: 140,
                            height: 44,
                            child: GestureDetector(
                              onTap: () => context.push('/events/${e.id}'),
                              child: _EventPin(event: e),
                            ),
                          ))
                      .toList(),
                ),

              // ── Zoom-adaptive user markers ──
              // Zoom 1-8: Cluster badges (region counts)
              // Zoom 8-13: Small dots for PLZ + big markers for live
              // Zoom 13+: Full avatar markers for all
              if (_showUsers) ...[
                if (_currentZoom < 8)
                  _buildClusterMarkers(accentColor)
                else ...[
                  _buildPlzUserMarkers(accentColor),
                  _buildLiveUserMarkers(accentColor),
                ],
              ],

              // ── POI markers ──
              if (_showPois && _pois.isNotEmpty)
                MarkerLayer(
                  markers: _pois.map((poi) => Marker(
                    point: LatLng(poi.lat, poi.lon),
                    width: 120,
                    height: 36,
                    child: _PoiPin(poi: poi),
                  )).toList(),
                ),

              // Own position puck (GPS ON → actual position, GPS OFF → PLZ)
              if (_isGpsLive && _myPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _myPosition!,
                      width: 52,
                      height: 66,
                      child: GestureDetector(
                        onTap: () {
                          if (myUserId != null) context.push('/profile/$myUserId');
                        },
                        child: _MyPositionPuck(
                          displayName: myDisplayName,
                          avatarUrl: myAvatarUrl,
                          accentColor: accentColor,
                        ),
                      ),
                    ),
                  ],
                )
              else if (_plzPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _plzPosition!,
                      width: 52,
                      height: 66,
                      child: GestureDetector(
                        onTap: () {
                          if (myUserId != null) context.push('/profile/$myUserId');
                        },
                        child: _MyPositionPuck(
                          displayName: myDisplayName,
                          avatarUrl: myAvatarUrl,
                          accentColor: accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          ), // end Listener

          // ── Permanent User-Panel rechts ──
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: _buildUserPanel(isDark, accentColor),
          ),

          // ── Controls: left side ──
          Positioned(
            left: 16,
            bottom: 80,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Toggle: Users on map
                _ToggleBtn(
                  icon: Icons.people_rounded,
                  active: _showUsers,
                  accentColor: accentColor,
                  isDark: isDark,
                  onTap: () => setState(() => _showUsers = !_showUsers),
                  tooltip: 'User anzeigen',
                ),
                const SizedBox(height: 6),

                // Toggle: Events on map — rot wenn aktiv
                _ToggleBtn(
                  icon: Icons.event_rounded,
                  active: _showEvents,
                  accentColor: Colors.red,
                  isDark: isDark,
                  onTap: () => setState(() => _showEvents = !_showEvents),
                  tooltip: _showEvents ? 'Treffen ausblenden' : 'Treffen anzeigen',
                ),
                const SizedBox(height: 6),

                // Toggle: POIs on map — orange wenn aktiv
                _ToggleBtn(
                  icon: Icons.local_gas_station_rounded,
                  active: _showPois,
                  accentColor: Colors.orange,
                  isDark: isDark,
                  onTap: () {
                    setState(() => _showPois = !_showPois);
                    if (_showPois && _pois.isEmpty) _loadPois();
                  },
                  tooltip: _showPois ? 'POIs ausblenden' : 'POIs anzeigen',
                ),
                const SizedBox(height: 6),

                // GPS Toggle: OFF = unsichtbar, ON = live sichtbar
                _ToggleBtn(
                  icon: _isGpsLive ? Icons.gps_fixed_rounded : Icons.gps_off_rounded,
                  active: _isGpsLive,
                  accentColor: accentColor,
                  isDark: isDark,
                  onTap: _toggleGps,
                  tooltip: _isGpsLive ? 'GPS AN (sichtbar)' : 'GPS AUS (unsichtbar)',
                ),
                const SizedBox(height: 6),

                // Center on me
                _ToggleBtn(
                  icon: Icons.my_location_rounded,
                  active: _myPosition != null || _plzPosition != null,
                  accentColor: accentColor,
                  isDark: isDark,
                  onTap: _centerOnMe,
                  tooltip: 'Mein Standort',
                ),
              ],
            ),
          ),

          // ── Zoom controls: left top ──
          Positioned(
            left: 16,
            top: 60,
            child: Column(
              children: [
                _mapBtn(Icons.add, () => _mapController.move(
                  _mapController.camera.center,
                  _mapController.camera.zoom + 1,
                ), isDark),
                const SizedBox(height: 4),
                _mapBtn(Icons.remove, () => _mapController.move(
                  _mapController.camera.center,
                  _mapController.camera.zoom - 1,
                ), isDark),
              ],
            ),
          ),

          // ── GPS loading indicator ──
          if (_gpsLoading)
            Positioned(
              left: 16,
              top: 120,
              child: _chip(isDark, child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('GPS wird geladen...',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                ],
              )),
            ),

          // ── Hint: bottom left ──
          Positioned(
            left: 16,
            bottom: 20,
            child: _chip(isDark, child: Text(
              'Navigation & Routing nur in der App',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            )),
          ),
        ],
      ),
    );
  }

  // ─── Zoom < 8: Cluster bubbles per PLZ region ─────────────────────────────

  Widget _buildClusterMarkers(Color accentColor) {
    final liveUsers = ref.watch(liveUsersProvider);

    // Group PLZ users by first 1-2 digits (region)
    final regionCounts = <int, List<_PlzUser>>{};
    for (final u in _allPlzUsers) {
      final plzCode = int.tryParse(u.userId.hashCode.abs().toString().padLeft(5, '0').substring(0, 1)) ?? 0;
      // Actually group by lat/lng grid cell (more accurate)
      final gridKey = ((u.position.latitude * 2).round() * 1000 + (u.position.longitude * 2).round());
      regionCounts.putIfAbsent(gridKey, () => []).add(u);
    }

    // Build cluster bubbles
    final clusterMarkers = <Marker>[];
    for (final entry in regionCounts.entries) {
      final users = entry.value;
      // Centroid of the cluster
      final avgLat = users.fold<double>(0, (s, u) => s + u.position.latitude) / users.length;
      final avgLng = users.fold<double>(0, (s, u) => s + u.position.longitude) / users.length;
      clusterMarkers.add(Marker(
        point: LatLng(avgLat, avgLng),
        width: 50,
        height: 50,
        child: GestureDetector(
          onTap: () => _mapController.move(LatLng(avgLat, avgLng), 10),
          child: _ClusterBubble(count: users.length, color: accentColor),
        ),
      ));
    }

    // Live users always shown as full markers even at low zoom
    for (final e in liveUsers.entries) {
      clusterMarkers.add(Marker(
        point: LatLng(e.value.lat, e.value.lng),
        width: 48,
        height: 60,
        child: GestureDetector(
          onTap: () => context.push('/profile/${e.key}'),
          child: _UserPin(
            displayName: e.value.displayName,
            avatarUrl: e.value.avatarUrl,
            accentColor: Colors.green,
            isLive: true,
          ),
        ),
      ));
    }

    return MarkerLayer(markers: clusterMarkers);
  }

  // ─── Zoom 8-13: Small dots for PLZ, big markers for live ─────────────────

  Widget _buildLiveUserMarkers(Color accentColor) {
    final users = ref.watch(liveUsersProvider);
    return MarkerLayer(
      markers: users.entries
          .map((e) => Marker(
                point: LatLng(e.value.lat, e.value.lng),
                width: _highlightedUserId == e.key ? 70 : 48,
                height: _highlightedUserId == e.key ? 82 : 60,
                child: GestureDetector(
                  onTap: () => context.push('/profile/${e.key}'),
                  child: _UserPin(
                    displayName: e.value.displayName,
                    avatarUrl: e.value.avatarUrl,
                    accentColor: Colors.green,
                    isLive: true,
                    highlighted: _highlightedUserId == e.key,
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildPlzUserMarkers(Color accentColor) {
    final liveUserIds = ref.watch(liveUsersProvider).keys.toSet();

    return MarkerLayer(
      markers: _allPlzUsers
          .where((u) => !liveUserIds.contains(u.userId))
          .map((u) => Marker(
                point: u.position,
                width: _highlightedUserId == u.userId ? 70 : 48,
                height: _highlightedUserId == u.userId ? 82 : 60,
                child: GestureDetector(
                  onTap: () => context.push('/profile/${u.userId}'),
                  child: _UserPin(
                    displayName: u.username,
                    avatarUrl: u.avatarUrl,
                    accentColor: accentColor,
                    isLive: false,
                    highlighted: _highlightedUserId == u.userId,
                  ),
                ),
              ))
          .toList(),
    );
  }

  /// Permanent user panel — always visible on the right side.
  Widget _buildUserPanel(bool isDark, Color accentColor) {
    final liveUsers = ref.watch(liveUsersProvider);
    final offlinePlz = _allPlzUsers
        .where((u) => !liveUsers.containsKey(u.userId))
        .toList();

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xF5101010) : const Color(0xF5FAFAFA),
        border: Border(
          left: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black12,
          ),
        ),
      ),
      child: Column(
          children: [
            // Top safe area spacing (avoids topbar overlap)
            SizedBox(height: MediaQuery.of(context).padding.top + 56),

            // ── Header with stats ──
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? Colors.white10 : Colors.black12,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.public_rounded, size: 20, color: accentColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Community',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Stats row
                  Row(
                    children: [
                      _statChip(
                        '${liveUsers.length}',
                        'Live',
                        Colors.green,
                        isDark,
                      ),
                      const SizedBox(width: 8),
                      _statChip(
                        '${offlinePlz.length}',
                        'Zu Hause',
                        accentColor,
                        isDark,
                      ),
                      const SizedBox(width: 8),
                      _statChip(
                        '${_events.length}',
                        'Treffen',
                        Colors.blue,
                        isDark,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── User list ──
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  // ── User sections (nur wenn Toggle aktiv) ──
                  if (_showUsers) ...[
                    // Live Users (GPS ON)
                    if (liveUsers.isNotEmpty) ...[
                      _sectionHeader('LIVE UNTERWEGS', Colors.green, isDark),
                      ...liveUsers.entries.map((e) => _userTile(
                        userId: e.key,
                        displayName: e.value.displayName,
                        avatarUrl: e.value.avatarUrl,
                        subtitle: e.value.speed > 5
                            ? '${e.value.speed.toStringAsFixed(0)} km/h'
                            : (e.value.postalCode ?? 'Online'),
                        accentColor: Colors.green,
                        isDark: isDark,
                        onLocate: () {
                          setState(() => _highlightedUserId = e.key);
                          _mapController.move(LatLng(e.value.lat, e.value.lng), 14);
                          Future.delayed(const Duration(seconds: 4), () {
                            if (mounted && _highlightedUserId == e.key) {
                              setState(() => _highlightedUserId = null);
                            }
                          });
                        },
                      )),
                    ],

                    // PLZ users (zu Hause)
                    if (offlinePlz.isNotEmpty) ...[
                      _sectionHeader(
                        'ZU HAUSE (${offlinePlz.length})',
                        accentColor,
                        isDark,
                      ),
                      ...offlinePlz.map((u) => _userTile(
                        userId: u.userId,
                        displayName: u.username,
                        avatarUrl: u.avatarUrl,
                        subtitle: 'PLZ Standort',
                        accentColor: isDark ? Colors.white38 : Colors.black38,
                        isDark: isDark,
                        isOffline: true,
                        onLocate: () {
                          setState(() => _highlightedUserId = u.userId);
                          _mapController.move(u.position, 12);
                          Future.delayed(const Duration(seconds: 4), () {
                            if (mounted && _highlightedUserId == u.userId) {
                              setState(() => _highlightedUserId = null);
                            }
                          });
                        },
                      )),
                    ],

                    if (liveUsers.isEmpty && _allPlzUsers.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Icon(Icons.people_outline, size: 40,
                                color: isDark ? Colors.white24 : Colors.black26),
                            const SizedBox(height: 8),
                            Text(
                              'Noch keine User.\nAktiviere GPS um sichtbar zu sein!',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],

                  // ── TREFFEN section (nur wenn Toggle aktiv) ──
                  if (_showEvents && _events.isNotEmpty) ...[
                    _sectionHeader(
                      'TREFFEN (${_events.length})',
                      Colors.red,
                      isDark,
                    ),
                    ..._events.map((e) => _eventTile(
                      event: e,
                      isDark: isDark,
                    )),
                  ],

                  if (_showEvents && _events.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                      child: Text(
                        'Keine Treffen geplant',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: isDark ? Colors.white30 : Colors.black26,
                        ),
                      ),
                    ),

                  // ── POIs section (nur wenn Toggle aktiv) ──
                  if (_showPois) ...[
                    _sectionHeader(
                      'POIS${_pois.isNotEmpty ? ' (${_pois.length})' : ''}',
                      Colors.orange,
                      isDark,
                    ),
                    if (_poisLoading)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Center(
                          child: SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.orange,
                            ),
                          ),
                        ),
                      ),
                    if (!_poisLoading && _pois.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                        child: Text(
                          'Zoom rein und POIs laden',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: isDark ? Colors.white30 : Colors.black26,
                          ),
                        ),
                      ),
                    ..._pois.map((poi) => _poiTile(poi: poi, isDark: isDark)),
                    // Reload button
                    if (_pois.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        child: GestureDetector(
                          onTap: () {
                            _lastPoiSearchCenter = null;
                            _loadPois();
                          },
                          child: Row(
                            children: [
                              Icon(Icons.refresh_rounded, size: 14,
                                  color: isDark ? Colors.white30 : Colors.black26),
                              const SizedBox(width: 4),
                              Text('POIs hier neu laden',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: isDark ? Colors.white30 : Colors.black26,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
    );
  }

  Widget _statChip(String count, String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text('$count $label', style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white70 : Colors.black54,
          )),
        ],
      ),
    );
  }

  Widget _sectionHeader(String label, Color color, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child: Row(
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: isDark ? Colors.white38 : Colors.black38,
          )),
        ],
      ),
    );
  }

  Widget _userTile({
    required String userId,
    required String displayName,
    String? avatarUrl,
    required String subtitle,
    required Color accentColor,
    required bool isDark,
    bool isOffline = false,
    VoidCallback? onLocate,
  }) {
    return InkWell(
      onTap: () => context.push('/profile/$userId'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isOffline ? Colors.grey : accentColor,
                  width: 2,
                ),
              ),
              child: ClipOval(
                child: avatarUrl != null && avatarUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: avatarUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => _avatarFallback(displayName),
                        errorWidget: (_, __, ___) => _avatarFallback(displayName),
                      )
                    : _avatarFallback(displayName),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
            // Locate on map button
            if (onLocate != null)
              GestureDetector(
                onTap: onLocate,
                child: Icon(Icons.my_location_rounded, size: 16,
                    color: isDark ? Colors.white30 : Colors.black26),
              ),
            const SizedBox(width: 4),
            // Online indicator
            if (!isOffline)
              Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _eventTile({
    required BikerEvent event,
    required bool isDark,
  }) {
    final hasCoords = event.latitude != null && event.longitude != null;
    final dateStr = '${event.startsAt.day.toString().padLeft(2, '0')}.${event.startsAt.month.toString().padLeft(2, '0')}.${event.startsAt.year}';
    return InkWell(
      onTap: () => context.push('/events/${event.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: Row(
          children: [
            // Event icon
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.withValues(alpha: 0.15),
                border: Border.all(color: Colors.blue, width: 2),
              ),
              child: Center(
                child: Text(
                  EventCategory.icon(event.category),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '$dateStr${event.location != null ? ' · ${event.location}' : ''}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.black45,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Locate on map button (only if has coordinates)
            if (hasCoords)
              GestureDetector(
                onTap: () {
                  _mapController.move(
                    LatLng(event.latitude!, event.longitude!), 14,
                  );
                },
                child: Icon(Icons.my_location_rounded, size: 16,
                    color: isDark ? Colors.white30 : Colors.black26),
              ),
          ],
        ),
      ),
    );
  }

  Widget _poiTile({required PoiResult poi, required bool isDark}) {
    final icon = switch (poi.type) {
      'fuel' => Icons.local_gas_station_rounded,
      'restaurant' => Icons.restaurant_rounded,
      'cafe' => Icons.coffee_rounded,
      'workshop' => Icons.build_rounded,
      'biker_shop' => Icons.two_wheeler,
      'auto_shop' => Icons.directions_car_rounded,
      'hospital' => Icons.local_hospital_rounded,
      'bank' => Icons.account_balance_rounded,
      _ => Icons.place_rounded,
    };
    final color = switch (poi.type) {
      'fuel' => Colors.orange,
      'restaurant' => Colors.green,
      'cafe' => const Color(0xFF795548),
      'workshop' => Colors.purple,
      'biker_shop' => Colors.red,
      'auto_shop' => Colors.blue,
      'hospital' => Colors.pink,
      'bank' => Colors.blueGrey,
      _ => Colors.grey,
    };
    return InkWell(
      onTap: () => _mapController.move(LatLng(poi.lat, poi.lon), 16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: Row(
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.15),
                border: Border.all(color: color, width: 2),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    poi.name,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${poi.distanceText}${poi.address != null ? ' · ${poi.address}' : ''}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.black45,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.my_location_rounded, size: 14,
                color: isDark ? Colors.white30 : Colors.black26),
          ],
        ),
      ),
    );
  }

  Widget _avatarFallback(String name) {
    return Container(
      color: Colors.grey.shade700,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
    );
  }

  Widget _chip(bool isDark, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
      ),
      child: child,
    );
  }

  Widget _mapBtn(IconData icon, VoidCallback onTap, bool isDark) {
    return Material(
      color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      borderRadius: BorderRadius.circular(8),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 40, height: 40,
          child: Icon(icon, size: 20,
              color: isDark ? Colors.white70 : Colors.black54),
        ),
      ),
    );
  }
}

// ─── Toggle Button (extracted widget for clarity) ───────────────────────────

class _ToggleBtn extends StatelessWidget {
  const _ToggleBtn({
    required this.icon,
    required this.active,
    required this.accentColor,
    required this.isDark,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final bool active;
  final Color accentColor;
  final bool isDark;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: active
                ? accentColor
                : (isDark ? const Color(0xFF2A2A2A) : Colors.white),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            size: 22,
            color: active
                ? Colors.white
                : (isDark ? Colors.white70 : Colors.black54),
          ),
        ),
      ),
    );
  }
}

// ─── My Position Puck (Avatar + Name) ───────────────────────────────────────

class _MyPositionPuck extends StatelessWidget {
  const _MyPositionPuck({
    required this.displayName,
    this.avatarUrl,
    required this.accentColor,
  });

  final String displayName;
  final String? avatarUrl;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Avatar circle with glow
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: accentColor, width: 3),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.4),
                blurRadius: 12,
                spreadRadius: 2,
              ),
              const BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: ClipOval(
            child: avatarUrl != null && avatarUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: avatarUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: accentColor,
                      child: Center(
                        child: Text(
                          displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                  )
                : Container(
                    color: accentColor,
                    child: Center(
                      child: Text(
                        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 2),
        // Name tag
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.circular(4),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1)),
            ],
          ),
          child: Text(
            displayName.isNotEmpty ? displayName : 'Du',
            style: const TextStyle(
              color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ─── Event Pin ───────────────────────────────────────────────────────────────

class _EventPin extends StatelessWidget {
  const _EventPin({required this.event});
  final BikerEvent event;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E88E5),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(EventCategory.icon(event.category), style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              event.title,
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── PLZ User model ─────────────────────────────────────────────────────────

class _PlzUser {
  final String userId;
  final String username;
  final String? avatarUrl;
  final LatLng position;
  const _PlzUser({
    required this.userId,
    required this.username,
    this.avatarUrl,
    required this.position,
  });
}

// ─── Cluster Bubble (zoom < 8) ──────────────────────────────────────────────

class _ClusterBubble extends StatelessWidget {
  const _ClusterBubble({required this.count, required this.color});
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final size = (30 + (count.clamp(0, 50) * 0.4)).clamp(30.0, 50.0);
    return Center(
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.7),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8, spreadRadius: 2)],
        ),
        child: Center(
          child: Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Small Dot (zoom 8-13) ──────────────────────────────────────────────────

class _SmallDot extends StatelessWidget {
  const _SmallDot({required this.color, required this.name});
  final Color color;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: name,
      child: Container(
        width: 14, height: 14,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.7),
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
        ),
      ),
    );
  }
}

// ─── POI Pin (map marker) ───────────────────────────────────────────────────

class _PoiPin extends StatelessWidget {
  const _PoiPin({required this.poi});
  final PoiResult poi;

  @override
  Widget build(BuildContext context) {
    final icon = switch (poi.type) {
      'fuel' => Icons.local_gas_station_rounded,
      'restaurant' => Icons.restaurant_rounded,
      'cafe' => Icons.coffee_rounded,
      _ => Icons.place_rounded,
    };
    final color = switch (poi.type) {
      'fuel' => Colors.orange,
      'restaurant' => Colors.green,
      'cafe' => const Color(0xFF795548),
      _ => Colors.grey,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              poi.name,
              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── User Pin (zoom 13+) ────────────────────────────────────────────────────

class _UserPin extends StatefulWidget {
  const _UserPin({
    required this.displayName,
    this.avatarUrl,
    required this.accentColor,
    this.isLive = false,
    this.highlighted = false,
  });

  final String displayName;
  final String? avatarUrl;
  final Color accentColor;
  final bool isLive;
  final bool highlighted;

  @override
  State<_UserPin> createState() => _UserPinState();
}

class _UserPinState extends State<_UserPin> with SingleTickerProviderStateMixin {
  AnimationController? _pulseController;

  @override
  void initState() {
    super.initState();
    if (widget.highlighted) _startPulse();
  }

  @override
  void didUpdateWidget(_UserPin old) {
    super.didUpdateWidget(old);
    if (widget.highlighted && !old.highlighted) {
      _startPulse();
    } else if (!widget.highlighted && old.highlighted) {
      _pulseController?.stop();
      _pulseController?.dispose();
      _pulseController = null;
    }
  }

  void _startPulse() {
    _pulseController?.dispose();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.isLive ? Colors.green : widget.accentColor;
    final avatarWidget = Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.accentColor,
        border: Border.all(color: borderColor, width: widget.isLive ? 3 : 2),
        boxShadow: [
          if (widget.isLive)
            BoxShadow(color: Colors.green.withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 1)
          else
            const BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: ClipOval(
        child: widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty
            ? CachedNetworkImage(imageUrl: widget.avatarUrl!, fit: BoxFit.cover)
            : Center(
                child: Text(
                  widget.displayName.isNotEmpty ? widget.displayName[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pulsierender Ring wenn highlighted
        if (widget.highlighted && _pulseController != null)
          AnimatedBuilder(
            animation: _pulseController!,
            builder: (_, __) {
              final scale = 1.0 + _pulseController!.value * 0.35;
              final opacity = 0.7 - _pulseController!.value * 0.5;
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Outer pulse ring
                  Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.amber.withValues(alpha: opacity),
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                  avatarWidget,
                ],
              );
            },
          )
        else
          avatarWidget,
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: widget.highlighted
                ? Colors.amber.shade800
                : (widget.isLive ? Colors.green.shade800 : Colors.black87),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isLive) ...[
                Container(
                  width: 5, height: 5,
                  decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
                ),
                const SizedBox(width: 3),
              ],
              Flexible(
                child: Text(
                  widget.displayName,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
