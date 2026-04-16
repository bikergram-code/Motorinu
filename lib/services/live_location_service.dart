import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A user's live GPS position on the map.
class LiveUserPosition {
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final double lat;
  final double lng;
  final double speed; // km/h
  final int xpTotal;
  final String? postalCode;
  final String? bikeName;
  final int followerCount;
  final int totalLikes;
  final DateTime lastUpdate;
  /// Community key (e.g. 'bikergram', 'cars') — used to filter cross-community.
  final String community;
  /// SOS-Status — wenn true, zeigt blinkenden roten Marker auf der Karte.
  final bool sos;
  /// Active group ride ID (null = not in a group ride).
  final int? activeGroupId;
  /// Group marker color hex (e.g. '#4CAF50').
  final String? groupColor;
  /// True if this user is the leader (admin) of their active group ride.
  final bool isGroupLeader;

  const LiveUserPosition({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.lat,
    required this.lng,
    this.speed = 0,
    this.xpTotal = 0,
    this.postalCode,
    this.bikeName,
    this.followerCount = 0,
    this.totalLikes = 0,
    required this.lastUpdate,
    this.community = 'bikergram',
    this.sos = false,
    this.activeGroupId,
    this.groupColor,
    this.isGroupLeader = false,
  });
}

/// Service that broadcasts and receives live GPS positions
/// via Supabase Realtime Presence channels.
///
/// Uses a single global channel so all live users can see each other.
/// Includes periodic heartbeat, automatic reconnect, and stale user cleanup.
class LiveLocationService {
  SupabaseClient get _supabase => Supabase.instance.client;

  bool _isLive = false;
  bool get isLive => _isLive;

  bool _isListening = false;
  bool get isListening => _isListening;

  String? _userId;
  String? _displayName;
  String? _avatarUrl;
  int _xpTotal = 0;
  String? _postalCode;
  String? _bikeName;
  int _followerCount = 0;
  int _totalLikes = 0;
  String _community = 'bikergram';
  bool _sosActive = false;
  int? _activeGroupId;
  int? get activeGroupId => _activeGroupId;
  String? _groupColor;
  bool _isGroupLeader = false;

  StreamSubscription<Position>? _positionSub;
  RealtimeChannel? _channel;
  Timer? _cleanupTimer;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;

  /// Grace-period timers per user: when a presenceLeave fires, we wait
  /// 30 seconds before actually removing the user. If they rejoin within
  /// that window the timer is cancelled and they stay online — just like
  /// Instagram/WhatsApp handle brief disconnects.
  final Map<String, Timer> _leaveTimers = {};

  /// Last known position for heartbeat re-track.
  Position? _lastPosition;

  /// Track consecutive heartbeat failures for reconnect.
  int _heartbeatFailures = 0;
  static const _maxHeartbeatFailures = 3;

  /// Prevent rapid reconnects.
  bool _reconnecting = false;

  /// Track when we last received a presence sync — if too long ago,
  /// the WebSocket may have silently died and we need to reconnect.
  DateTime _lastSyncReceived = DateTime.now();

  /// All nearby live users (excluding self).
  final Map<String, LiveUserPosition> _nearbyUsers = {};

  /// Stream controller for UI updates.
  final _controller =
      StreamController<Map<String, LiveUserPosition>>.broadcast();

  /// Fires the userId whenever a user intentionally goes offline
  /// (sent going_offline=true payload). Listeners can use this to
  /// bypass grace-period debounces and remove the user immediately.
  final _goingOfflineController = StreamController<String>.broadcast();

  /// Listen to nearby users map changes.
  Stream<Map<String, LiveUserPosition>> get nearbyUsersStream =>
      _controller.stream;

  /// Fires with the userId of a user who intentionally logged out.
  Stream<String> get userGoingOfflineStream => _goingOfflineController.stream;

  /// Current snapshot of nearby users.
  Map<String, LiveUserPosition> get nearbyUsers =>
      Map.unmodifiable(_nearbyUsers);

  /// Listen-only mode: subscribe to the channel to see other users,
  /// but do NOT broadcast own position. Call this when GPS toggle is OFF
  /// but we still want to show online users on the map.
  Future<void> startListening({required String userId}) async {
    if (_isListening || _isLive) return; // Already connected
    _userId = userId;
    _isListening = true;
    debugPrint('[LiveGPS] Starting listen-only mode (no broadcast)');
    await _connectListenOnly();
  }

  /// Stop listen-only mode. Does NOT affect goLive/goOffline.
  Future<void> stopListening() async {
    if (!_isListening || _isLive) return; // Don't disconnect if broadcasting
    _isListening = false;
    if (_channel != null) {
      try {
        await _supabase.removeChannel(_channel!);
      } catch (_) {}
      _channel = null;
    }
    debugPrint('[LiveGPS] Listen-only stopped');
  }

  /// Connect channel in listen-only mode (subscribe but don't track).
  Future<void> _connectListenOnly() async {
    if (_channel != null) {
      try {
        await _supabase.removeChannel(_channel!);
      } catch (_) {}
      _channel = null;
    }

    final channel = _supabase.channel('live_gps:all');

    channel.onPresenceSync((_) {
      _handlePresenceSync(channel);
    }).onPresenceJoin((payload) {
      for (final presence in payload.newPresences) {
        final uid = presence.payload['user_id'] as String?;
        if (uid != null && _leaveTimers.containsKey(uid)) {
          _leaveTimers[uid]!.cancel();
          _leaveTimers.remove(uid);
        }
      }
      _handlePresenceSync(channel);
    }).onPresenceLeave((payload) {
      bool anyImmediate = false;
      for (final presence in payload.leftPresences) {
        final data = presence.payload;
        final uid = data['user_id'] as String?;
        if (uid == null || uid == _userId) continue;
        final goingOffline = data['going_offline'] == true;
        if (goingOffline) {
          _leaveTimers[uid]?.cancel();
          _leaveTimers.remove(uid);
          _nearbyUsers.remove(uid);
          anyImmediate = true;
          _goingOfflineController.add(uid);
          continue;
        }
        if (_leaveTimers[uid]?.isActive == true) continue;
        _leaveTimers[uid] = Timer(const Duration(seconds: 1), () {
          _leaveTimers.remove(uid);
          if (_nearbyUsers.containsKey(uid)) {
            _nearbyUsers.remove(uid);
            _controller.add(Map.from(_nearbyUsers));
          }
        });
      }
      if (anyImmediate) _controller.add(Map.from(_nearbyUsers));
    });

    channel.subscribe((status, [error]) async {
      debugPrint('[LiveGPS] Listen-only channel status: $status');
      if (status == RealtimeSubscribeStatus.subscribed) {
        _consecutiveEmptySyncs = 0;
      }
    });

    _channel = channel;
  }

  /// Start broadcasting live position.
  Future<void> goLive({
    required String userId,
    required String displayName,
    String? avatarUrl,
    String? plzRegion,
    int xpTotal = 0,
    String? bikeName,
    int followerCount = 0,
    int totalLikes = 0,
    String community = 'bikergram',
  }) async {
    if (_isLive) return;

    // Stop listen-only if active — goLive replaces it with full connection
    if (_isListening) {
      _isListening = false;
      // Channel will be replaced by _connectChannel below
    }

    _userId = userId;
    _displayName = displayName;
    _avatarUrl = avatarUrl;
    _xpTotal = xpTotal;
    _postalCode = plzRegion;
    _bikeName = bikeName;
    _followerCount = followerCount;
    _totalLikes = totalLikes;
    _community = community;
    _isLive = true;
    _heartbeatFailures = 0;
    _lastSyncReceived = DateTime.now();

    debugPrint('[LiveGPS] Going live on channel: live_gps:all (user: $displayName)');

    await _connectChannel();

    // Start GPS stream — update on movement (50m filter)
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50,
      ),
    ).listen((position) {
      _lastPosition = position;
      _broadcastPosition(position);
    });

    // Heartbeat: re-track every 15 seconds to keep presence alive
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _sendHeartbeat();
    });

    // Cleanup timer — remove stale users every 120s
    // (Grace-period timers handle most departures; this is a last-resort cleanup.)
    _cleanupTimer = Timer.periodic(const Duration(seconds: 120), (_) {
      _cleanupStaleUsers();
    });
  }

  /// Connect (or reconnect) the Supabase Realtime channel.
  Future<void> _connectChannel() async {
    // Clean up old channel if exists
    if (_channel != null) {
      try {
        await _channel!.untrack();
        await _supabase.removeChannel(_channel!);
      } catch (_) {}
      _channel = null;
    }

    final channel = _supabase.channel('live_gps:all');

    channel.onPresenceSync((_) {
      _handlePresenceSync(channel);
    }).onPresenceJoin((payload) {
      // Cancel any pending leave-timer for users that just (re)joined
      for (final presence in payload.newPresences) {
        final uid = presence.payload['user_id'] as String?;
        if (uid != null && _leaveTimers.containsKey(uid)) {
          _leaveTimers[uid]!.cancel();
          _leaveTimers.remove(uid);
          debugPrint('[LiveGPS] User $uid rejoined — grace period cancelled');
        }
      }
      debugPrint('[LiveGPS] User joined: ${payload.newPresences.length}');
      _handlePresenceSync(channel);
    }).onPresenceLeave((payload) {
      bool anyImmediate = false;
      for (final presence in payload.leftPresences) {
        final data = presence.payload;
        final uid = data['user_id'] as String?;
        if (uid == null || uid == _userId) continue;

        // If the user sent a "going_offline" goodbye payload, remove immediately.
        final goingOffline = data['going_offline'] == true;
        if (goingOffline) {
          _leaveTimers[uid]?.cancel();
          _leaveTimers.remove(uid);
          _nearbyUsers.remove(uid);
          anyImmediate = true;
          debugPrint('[LiveGPS] User $uid sent goodbye — removing immediately');
          // Signal intentional logout so badge clears without debounce
          _goingOfflineController.add(uid);
          continue;
        }

        // Otherwise start a 30s grace period (handles brief network flickers).
        if (_leaveTimers[uid]?.isActive == true) continue; // already waiting
        debugPrint('[LiveGPS] User $uid left — starting 30s grace period');
        _leaveTimers[uid] = Timer(const Duration(seconds: 30), () {
          _leaveTimers.remove(uid);
          if (_nearbyUsers.containsKey(uid)) {
            _nearbyUsers.remove(uid);
            _controller.add(Map.from(_nearbyUsers));
            debugPrint('[LiveGPS] Grace period expired — removed $uid, nearby: ${_nearbyUsers.length}');
          }
        });
      }
      if (anyImmediate) {
        _controller.add(Map.from(_nearbyUsers));
      }
      // For non-goodbye leaves, do NOT emit immediately — grace period handles it.
    });

    channel.subscribe((status, [error]) async {
      debugPrint('[LiveGPS] Channel status: $status${error != null ? ' error: $error' : ''}');

      if (status == RealtimeSubscribeStatus.subscribed) {
        debugPrint('[LiveGPS] Subscribed to live_gps:all');
        _heartbeatFailures = 0;
        _consecutiveEmptySyncs = 0;
        _lastReconnectTime = DateTime.now();
        // Track our initial presence
        final pos = await _getCurrentPosition();
        if (pos != null) {
          _lastPosition = pos;
          await channel.track(_buildPayload(pos));
          debugPrint('[LiveGPS] Initial track sent: ${pos.latitude}, ${pos.longitude}');
        } else {
          await channel.track(_buildPayload(null));
          debugPrint('[LiveGPS] Initial track sent without GPS position');
        }
      } else if (status == RealtimeSubscribeStatus.closed ||
                 status == RealtimeSubscribeStatus.channelError) {
        // Channel died — schedule reconnect
        debugPrint('[LiveGPS] Channel lost ($status), scheduling reconnect...');
        _scheduleReconnect();
      }
    });

    _channel = channel;
  }

  /// Schedule a reconnect attempt with backoff.
  void _scheduleReconnect() {
    if (!_isLive || _reconnecting) return;
    _reconnecting = true;

    // Cancel existing reconnect timer
    _reconnectTimer?.cancel();

    // Wait 3 seconds then reconnect
    _reconnectTimer = Timer(const Duration(seconds: 3), () async {
      _reconnecting = false;
      if (!_isLive) return;

      debugPrint('[LiveGPS] Attempting reconnect...');
      try {
        await _connectChannel();
        debugPrint('[LiveGPS] Reconnected successfully');
      } catch (e) {
        debugPrint('[LiveGPS] Reconnect failed: $e');
        // Try again
        _scheduleReconnect();
      }
    });
  }

  /// Set active group ride. Call when joining/leaving a group ride.
  /// [isLeader] marks this user as the group leader (admin).
  void setActiveGroup(int? groupId, String? color, {bool isLeader = false}) {
    _activeGroupId = groupId;
    _groupColor = color;
    _isGroupLeader = isLeader;
    if (_isLive && _channel != null) {
      _channel!.track(_buildPayload(_lastPosition));
    }
  }

  /// Build the presence payload.
  Map<String, dynamic> _buildPayload(Position? pos) {
    return {
      'user_id': _userId,
      'display_name': _displayName,
      'avatar_url': _avatarUrl,
      'lat': pos?.latitude ?? 0,
      'lng': pos?.longitude ?? 0,
      'speed': pos != null ? (pos.speed * 3.6).clamp(0, 300) : 0,
      'xp_total': _xpTotal,
      'postal_code': _postalCode,
      'bike_name': _bikeName,
      'follower_count': _followerCount,
      'total_likes': _totalLikes,
      'community': _community,
      'sos': _sosActive,
      if (_activeGroupId != null) 'active_group_id': _activeGroupId,
      if (_groupColor != null) 'group_color': _groupColor,
      'is_group_leader': _isGroupLeader,
    };
  }

  /// Setze SOS-Status und broadcasten sofort an alle.
  /// Sendet 3x mit kurzer Verzögerung um sicherzustellen, dass alle Empfänger es bekommen.
  void setSosActive(bool active) {
    _sosActive = active;
    debugPrint('[LiveGPS] SOS ${active ? "ACTIVATED" : "deactivated"}');
    if (_isLive && _channel != null) {
      final payload = _buildPayload(_lastPosition);
      try {
        _channel!.track(payload);
      } catch (e) {
        debugPrint('[LiveGPS] SOS broadcast error: $e');
      }
      // Retry nach 1s und 3s — Presence-Sync kann erste Events verpassen
      Future.delayed(const Duration(seconds: 1), () {
        if (_isLive && _channel != null && _sosActive == active) {
          try { _channel!.track(_buildPayload(_lastPosition)); } catch (_) {}
        }
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (_isLive && _channel != null && _sosActive == active) {
          try { _channel!.track(_buildPayload(_lastPosition)); } catch (_) {}
        }
      });
    }
  }

  /// Pause GPS stream but keep channel + heartbeat alive.
  /// Call when app goes to background — user stays "online" on the map.
  void pauseGps() {
    _positionSub?.cancel();
    _positionSub = null;
    debugPrint('[LiveGPS] GPS paused (heartbeat continues)');
  }

  /// Resume GPS stream after a pause. No-op if not live.
  void resumeGps() {
    if (!_isLive) return;
    if (_positionSub != null) return; // Already running
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50,
      ),
    ).listen((position) {
      _lastPosition = position;
      _broadcastPosition(position);
    });
    debugPrint('[LiveGPS] GPS resumed');
  }

  /// Stop broadcasting and disconnect from all channels.
  Future<void> goOffline() async {
    if (!_isLive) return;

    // Log the call stack so we know WHO called goOffline
    debugPrint('[LiveGPS] ⚠️ goOffline() called! Stack trace:');
    debugPrint(StackTrace.current.toString().split('\n').take(8).join('\n'));
    _isLive = false;
    _consecutiveEmptySyncs = 0;

    _positionSub?.cancel();
    _positionSub = null;

    _cleanupTimer?.cancel();
    _cleanupTimer = null;

    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    // Cancel all pending leave-grace timers
    for (final t in _leaveTimers.values) {
      t.cancel();
    }
    _leaveTimers.clear();

    if (_channel != null) {
      try {
        // Send a "goodbye" payload before untracking so other clients
        // know this is an intentional logout — no grace period needed.
        await _channel!.track({
          'user_id': _userId,
          'going_offline': true,
        });
        // ★ Länger warten damit das Goodbye-Signal bei anderen ankommt
        await Future.delayed(const Duration(milliseconds: 800));
        await _channel!.untrack();
        await _supabase.removeChannel(_channel!);
      } catch (_) {}
      _channel = null;
    }

    // Delete live_locations DB entry so other users don't see stale data
    if (_userId != null) {
      try {
        await _supabase.from('live_locations').delete().eq('user_id', _userId!);
        debugPrint('[LiveGPS] Deleted live_locations entry for $_userId');
      } catch (e) {
        debugPrint('[LiveGPS] Failed to delete live_locations: $e');
      }
    }

    _nearbyUsers.clear();
    debugPrint('[LiveGPS] Clearing nearbyUsers and emitting empty map');
    _controller.add({});
  }

  /// Periodic heartbeat — re-track to keep presence alive.
  Future<void> _sendHeartbeat() async {
    if (!_isLive || _channel == null) return;

    // Stale-channel detection: if no sync received for 60s,
    // the WebSocket may have silently died — force reconnect.
    if (DateTime.now().difference(_lastSyncReceived).inSeconds > 60) {
      debugPrint('[LiveGPS] No sync received for 60s — forcing reconnect');
      _heartbeatFailures = 0;
      _scheduleReconnect();
      return;
    }

    try {
      await _channel!.track(_buildPayload(_lastPosition));
      _heartbeatFailures = 0; // Reset on success
    } catch (e) {
      _heartbeatFailures++;
      debugPrint('[LiveGPS] Heartbeat error (#$_heartbeatFailures): $e');

      // After N consecutive failures, reconnect
      if (_heartbeatFailures >= _maxHeartbeatFailures) {
        debugPrint('[LiveGPS] Too many heartbeat failures, reconnecting...');
        _heartbeatFailures = 0;
        _scheduleReconnect();
      }
    }
  }

  /// Broadcast current position to channel.
  void _broadcastPosition(Position pos) {
    if (!_isLive || _channel == null) return;

    try {
      _channel!.track(_buildPayload(pos));
    } catch (e) {
      debugPrint('[LiveGPS] Track error: $e');
    }
  }

  /// Ignore empty syncs within this many seconds of a reconnect
  /// (Supabase often sends an empty sync right after channel re-subscribe).
  DateTime? _lastReconnectTime;

  /// Count consecutive empty syncs — only clear after several in a row.
  int _consecutiveEmptySyncs = 0;

  /// Handle presence sync — update nearby users map.
  ///
  /// Conservative strategy: we MERGE incoming users into the existing map
  /// (updating positions for known users, adding new ones). We only REMOVE
  /// users when they are explicitly absent from multiple consecutive syncs
  /// (or via [onPresenceLeave]). This prevents the "flicker to 0" problem
  /// caused by Supabase occasionally sending incomplete/empty sync payloads.
  void _handlePresenceSync(RealtimeChannel channel) {
    _lastSyncReceived = DateTime.now();
    try {
      final presences = channel.presenceState();
      final updatedUsers = <String, LiveUserPosition>{};
      bool hadGoingOffline = false;

      for (final state in presences) {
        for (final presence in state.presences) {
          final data = presence.payload;

          final uid = data['user_id'] as String?;
          if (uid == null || uid == _userId) continue;

          // If user sent a goodbye payload, remove them immediately.
          // Don't add to updatedUsers — they are gone.
          if (data['going_offline'] == true) {
            _leaveTimers[uid]?.cancel();
            _leaveTimers.remove(uid);
            _nearbyUsers.remove(uid);
            hadGoingOffline = true;
            debugPrint('[LiveGPS] Sync: user $uid going_offline — removed immediately');
            // Signal intentional logout so badge clears without debounce
            _goingOfflineController.add(uid);
            continue;
          }

          // Cancel any pending leave-timer — user is still present
          if (_leaveTimers.containsKey(uid)) {
            _leaveTimers[uid]!.cancel();
            _leaveTimers.remove(uid);
          }

          updatedUsers[uid] = LiveUserPosition(
            userId: uid,
            displayName: data['display_name'] as String? ?? 'Rider',
            avatarUrl: data['avatar_url'] as String?,
            lat: (data['lat'] as num?)?.toDouble() ?? 0,
            lng: (data['lng'] as num?)?.toDouble() ?? 0,
            speed: (data['speed'] as num?)?.toDouble() ?? 0,
            xpTotal: (data['xp_total'] as num?)?.toInt() ?? 0,
            postalCode: data['postal_code'] as String?,
            bikeName: data['bike_name'] as String?,
            followerCount: (data['follower_count'] as num?)?.toInt() ?? 0,
            totalLikes: (data['total_likes'] as num?)?.toInt() ?? 0,
            lastUpdate: DateTime.now(),
            community: data['community'] as String? ?? 'bikergram',
            sos: data['sos'] == true,
            activeGroupId: (data['active_group_id'] as num?)?.toInt(),
            groupColor: data['group_color'] as String?,
            isGroupLeader: data['is_group_leader'] == true,
          );
        }
      }

      // ─── Guard against empty/partial syncs ─────────────────────────────
      // Supabase Presence can fire empty syncs during brief network hiccups,
      // channel re-subscribe, or internal state reconciliation.
      // We protect against this by requiring multiple consecutive empty syncs
      // before actually clearing the user list.

      // If we just removed a "going_offline" user, emit immediately and return.
      if (hadGoingOffline && updatedUsers.isEmpty) {
        _consecutiveEmptySyncs = 0;
        _controller.add(Map.from(_nearbyUsers));
        debugPrint('[LiveGPS] Sync: emitting after going_offline removal, nearby: ${_nearbyUsers.length}');
        return;
      }

      if (updatedUsers.isEmpty && _nearbyUsers.isNotEmpty) {
        _consecutiveEmptySyncs++;
        // Grace period after reconnect (10s)
        if (_lastReconnectTime != null &&
            DateTime.now().difference(_lastReconnectTime!).inSeconds < 10) {
          debugPrint('[LiveGPS] Ignoring empty sync after reconnect (grace period)');
          return;
        }
        // Need 3+ consecutive empty syncs before clearing (~3 heartbeats = 45s)
        if (_consecutiveEmptySyncs < 3) {
          debugPrint('[LiveGPS] Ignoring empty sync #$_consecutiveEmptySyncs (keeping ${_nearbyUsers.length} users)');
          return;
        }
        debugPrint('[LiveGPS] $_consecutiveEmptySyncs consecutive empty syncs — clearing users');
      } else if (updatedUsers.isNotEmpty) {
        _consecutiveEmptySyncs = 0;
      }

      // ─── Merge strategy ────────────────────────────────────────────────
      // If we got users from sync, update the map.
      // Users that were in _nearbyUsers but not in updatedUsers stay alive
      // until they are explicitly removed by onPresenceLeave or stale cleanup.
      if (updatedUsers.isNotEmpty) {
        // Update/add all users from the sync
        _nearbyUsers.addAll(updatedUsers);

        // Remove users that are no longer in the sync BUT have been gone
        // for more than one sync cycle (their lastUpdate didn't get refreshed).
        // This is handled by the stale cleanup timer instead.

        debugPrint('[LiveGPS] Sync: ${_nearbyUsers.length} nearby users'
            '${_nearbyUsers.isNotEmpty ? ' (${_nearbyUsers.values.map((u) => u.displayName).join(', ')})' : ''}');
        _controller.add(Map.from(_nearbyUsers));
      } else if (_consecutiveEmptySyncs >= 3) {
        // Confirmed empty — clear
        _nearbyUsers.clear();
        debugPrint('[LiveGPS] Sync: 0 nearby users (confirmed empty)');
        _controller.add(Map.from(_nearbyUsers));
      }
    } catch (e) {
      debugPrint('[LiveGPS] Presence sync error: $e');
    }
  }

  /// Remove users who haven't sent an update in 3 minutes.
  /// (Grace-period timers handle normal departures; this is a safety net.)
  void _cleanupStaleUsers() {
    final now = DateTime.now();
    final staleIds = <String>[];

    for (final entry in _nearbyUsers.entries) {
      // Only remove if no active leave-timer (i.e. not already in grace period)
      if (now.difference(entry.value.lastUpdate).inSeconds > 180 &&
          !_leaveTimers.containsKey(entry.key)) {
        staleIds.add(entry.key);
      }
    }

    if (staleIds.isNotEmpty) {
      for (final id in staleIds) {
        _nearbyUsers.remove(id);
      }
      _controller.add(Map.from(_nearbyUsers));
      debugPrint('[LiveGPS] Cleaned up ${staleIds.length} stale users');
    }
  }

  Future<Position?> _getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// Dispose all resources.
  /// NOTE: This is a global singleton — dispose should only be called on app shutdown.
  void dispose() {
    debugPrint('[LiveGPS] ⚠️ dispose() called on singleton! Stack:');
    debugPrint(StackTrace.current.toString().split('\n').take(6).join('\n'));
    goOffline();
    _controller.close();
    _goingOfflineController.close();
  }
}
