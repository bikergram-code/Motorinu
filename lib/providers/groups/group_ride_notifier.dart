import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/group.dart';
import '../../domain/models/direct_message.dart';
import '../../data/repositories/group_repository.dart';
import '../../data/repositories/blitzer_repository.dart';
import '../../services/live_location_service.dart';
import '../../services/livekit_service.dart';
import '../../services/blitzer_alert_service.dart';
import '../../services/alert_audio_service.dart';
import '../../services/tts_alert_service.dart';
import '../../services/osm_blitzer_service.dart';
import '../../providers/map/live_location_provider.dart';
import '../../providers/map/map_settings_provider.dart';
import '../../providers/core/providers.dart';

// ═══════════════════════════════════════════════════
//  GROUP RIDE STATE
// ═══════════════════════════════════════════════════

class GroupRideState {
  const GroupRideState({
    this.group,
    this.isConnecting = false,
    this.isVoiceActive = false,
    this.isCameraActive = false,
    this.isMicMuted = false,
    this.participantCount = 0,
    this.currentAlert,
    this.activeAlerts = const [],
    this.chatMessages = const [],
    this.rideMembers = const {},
    this.currentSpeed = 0,
    this.distanceToDestination,
    this.distanceToLeader,
    this.leaderDisplayName,
    this.isListening = false,
    this.listenText,
    this.error,
    this.lastRemovedBlitzerId,
  });

  final BikerGroup? group;
  final bool isConnecting;
  final bool isVoiceActive;
  final bool isCameraActive;
  final bool isMicMuted;
  final int participantCount;
  final BlitzerAlert? currentAlert;
  final List<BlitzerAlert> activeAlerts;
  final List<DirectMessage> chatMessages;
  /// Live positions of group members.
  final Map<String, LiveUserPosition> rideMembers;
  final double currentSpeed;
  final double? distanceToDestination;
  /// Distance to the group leader in meters (null if no leader or I am leader).
  final double? distanceToLeader;
  /// Leader display name (for UI).
  final String? leaderDisplayName;
  /// Voice search state.
  final bool isListening;
  final String? listenText;
  final String? error;
  /// Set when another user removes a blitzer — screen should remove from local list
  final int? lastRemovedBlitzerId;

  GroupRideState copyWith({
    BikerGroup? group,
    bool? isConnecting,
    bool? isVoiceActive,
    bool? isCameraActive,
    bool? isMicMuted,
    int? participantCount,
    BlitzerAlert? currentAlert,
    bool clearAlert = false,
    List<BlitzerAlert>? activeAlerts,
    List<DirectMessage>? chatMessages,
    Map<String, LiveUserPosition>? rideMembers,
    double? currentSpeed,
    double? distanceToDestination,
    bool clearDistance = false,
    double? distanceToLeader,
    bool clearLeaderDistance = false,
    String? leaderDisplayName,
    bool? isListening,
    String? listenText,
    bool clearListenText = false,
    String? error,
    bool clearError = false,
    int? lastRemovedBlitzerId,
  }) {
    return GroupRideState(
      group: group ?? this.group,
      isConnecting: isConnecting ?? this.isConnecting,
      isVoiceActive: isVoiceActive ?? this.isVoiceActive,
      isCameraActive: isCameraActive ?? this.isCameraActive,
      isMicMuted: isMicMuted ?? this.isMicMuted,
      participantCount: participantCount ?? this.participantCount,
      currentAlert: clearAlert ? null : (currentAlert ?? this.currentAlert),
      activeAlerts: activeAlerts ?? this.activeAlerts,
      chatMessages: chatMessages ?? this.chatMessages,
      rideMembers: rideMembers ?? this.rideMembers,
      currentSpeed: currentSpeed ?? this.currentSpeed,
      distanceToDestination: clearDistance ? null : (distanceToDestination ?? this.distanceToDestination),
      distanceToLeader: clearLeaderDistance ? null : (distanceToLeader ?? this.distanceToLeader),
      leaderDisplayName: leaderDisplayName ?? this.leaderDisplayName,
      isListening: isListening ?? this.isListening,
      listenText: clearListenText ? null : (listenText ?? this.listenText),
      error: clearError ? null : (error ?? this.error),
      lastRemovedBlitzerId: lastRemovedBlitzerId ?? this.lastRemovedBlitzerId,
    );
  }
}

// ═══════════════════════════════════════════════════
//  GROUP RIDE NOTIFIER (family by groupId)
// ═══════════════════════════════════════════════════

final groupRideProvider = NotifierProvider.family<GroupRideNotifier,
    GroupRideState, int>(GroupRideNotifier.new);

class GroupRideNotifier extends Notifier<GroupRideState> {
  GroupRideNotifier(this._groupId);

  final int _groupId;
  late GroupRepository _repo;
  final LiveKitService _liveKit = LiveKitService.instance;
  final BlitzerAlertService _blitzerService = BlitzerAlertService();

  StreamSubscription<Map<String, LiveUserPosition>>? _liveSub;
  StreamSubscription<Position>? _gpsSub;
  RealtimeChannel? _chatChannel;
  RealtimeChannel? _blitzerRealtimeChannel;
  Timer? _blitzerCheckTimer;
  Timer? _blitzerReloadTimer;
  Timer? _distanceCheckTimer;
  Timer? _alertDismissTimer;
  List<BlitzerReport> _blitzerReports = [];
  BlitzerSettings? _blitzerSettings;

  /// Tracks consecutive distance warnings to escalate severity.
  int _distanceWarningCount = 0;
  /// Last time a distance warning was spoken (prevents spam).
  DateTime? _lastDistanceWarning;

  @override
  GroupRideState build() {
    _repo = ref.watch(groupRepositoryProvider);

    ref.onDispose(() {
      _liveSub?.cancel();
      _gpsSub?.cancel();
      _chatChannel?.unsubscribe();
      _blitzerRealtimeChannel?.unsubscribe();
      _blitzerCheckTimer?.cancel();
      _blitzerReloadTimer?.cancel();
      _distanceCheckTimer?.cancel();
      _alertDismissTimer?.cancel();
    });

    Future.microtask(() => _initialize());
    return const GroupRideState(isConnecting: true);
  }

  Future<void> _initialize() async {
    try {
      // Initialize audio + TTS services
      AlertAudioService.instance.init();
      TtsAlertService.instance.init();

      // Load group details
      final group = await _repo.getGroupById(_groupId);
      state = state.copyWith(group: group, isConnecting: true);

      // Set active group with leader flag for GPS presence broadcast
      final isLeader = group?.isAdmin ?? false;
      final rideColor = group?.rideColor ?? '#4CAF50';
      globalLiveLocationService.setActiveGroup(_groupId, rideColor, isLeader: isLeader);

      // Start listening to live GPS of group members
      _listenToGroupMembers();

      // Start GPS position tracking FIRST so we have position for blitzer load
      _startGpsTracking();

      // Get initial position immediately for blitzer loading
      try {
        final pos = await Geolocator.getLastKnownPosition();
        if (pos != null) _lastKnownPosition ??= pos;
      } catch (_) {}

      // Load blitzer reports for nearby area + Realtime + polling fallback
      _loadBlitzerReports();
      _startBlitzerRealtime();
      _blitzerReloadTimer?.cancel();
      _blitzerReloadTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        _loadBlitzerReports();
      });

      // Subscribe to group chat messages
      if (group?.conversationId != null) {
        _subscribeToChatMessages(group!.conversationId!);
        _loadRecentMessages(group.conversationId!);
      }

      // Start distance-to-leader monitoring (every 10 seconds)
      _startDistanceMonitoring();

      state = state.copyWith(isConnecting: false);
    } catch (e) {
      debugPrint('[GroupRide] Init error: $e');
      state = state.copyWith(isConnecting: false, error: e.toString());
    }
  }

  // ── Voice / Camera ─────────────────────────────────────────

  /// Join the voice channel (LiveKit group call).
  Future<void> joinVoice() async {
    try {
      state = state.copyWith(isConnecting: true);
      await _liveKit.connectToGroupCall(_groupId, withVideo: false);

      _liveKit.onParticipantChanged = () {
        state = state.copyWith(
          participantCount: _liveKit.remoteParticipantCount + 1,
        );
      };
      _liveKit.onDisconnected = () {
        state = state.copyWith(isVoiceActive: false, isCameraActive: false, participantCount: 0);
      };

      // Walkie-talkie mode: start with mic muted (push-to-talk)
      await _liveKit.room?.localParticipant?.setMicrophoneEnabled(false);

      state = state.copyWith(
        isVoiceActive: true,
        isMicMuted: true,
        isConnecting: false,
        participantCount: _liveKit.remoteParticipantCount + 1,
      );
    } catch (e) {
      debugPrint('[GroupRide] Voice error: $e');
      state = state.copyWith(isConnecting: false, error: 'Sprachkanal Fehler: $e');
    }
  }

  /// Leave the voice channel.
  Future<void> leaveVoice() async {
    await _liveKit.disconnect();
    state = state.copyWith(isVoiceActive: false, isCameraActive: false, participantCount: 0);
  }

  /// Toggle microphone.
  Future<void> toggleMic() async {
    if (!state.isVoiceActive) return;
    await _liveKit.toggleMic();
    state = state.copyWith(isMicMuted: !_liveKit.isMicEnabled);
  }

  /// Toggle camera.
  Future<void> toggleCamera() async {
    if (!state.isVoiceActive) return;
    if (!state.isCameraActive) {
      try {
        await _liveKit.room?.localParticipant?.setCameraEnabled(true);
        state = state.copyWith(isCameraActive: true);
      } catch (e) {
        debugPrint('[GroupRide] Camera error: $e');
      }
    } else {
      try {
        await _liveKit.room?.localParticipant?.setCameraEnabled(false);
      } catch (e) {
        debugPrint('[GroupRide] Camera off error: $e');
      }
      state = state.copyWith(isCameraActive: false);
    }
  }

  /// Switch front/back camera.
  Future<void> switchCamera() async {
    await _liveKit.switchCamera();
  }

  // ── Live GPS members ───────────────────────────────────────

  void _listenToGroupMembers() {
    _liveSub = globalLiveLocationService.nearbyUsersStream.listen((allUsers) {
      // Filter to only users in this group ride
      final groupMembers = Map<String, LiveUserPosition>.fromEntries(
        allUsers.entries.where((e) => e.value.activeGroupId == _groupId),
      );
      state = state.copyWith(rideMembers: groupMembers);

      // Calculate distance to leader
      _updateDistanceToLeader(groupMembers);

      // Update distance to destination
      _updateDistanceToDestination();
    });
  }

  /// Find the leader in group members and calculate distance to them.
  void _updateDistanceToLeader(Map<String, LiveUserPosition> members) {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == null) return;

    // Find the leader
    final leader = members.values
        .cast<LiveUserPosition?>()
        .firstWhere((u) => u!.isGroupLeader, orElse: () => null);

    if (leader == null) {
      if (state.distanceToLeader != null) {
        state = state.copyWith(clearLeaderDistance: true);
      }
      return;
    }

    state = state.copyWith(leaderDisplayName: leader.displayName);

    // If I am the leader, no distance to self
    if (leader.userId == myId) {
      if (state.distanceToLeader != null) {
        state = state.copyWith(clearLeaderDistance: true);
      }
      return;
    }

    // Find my position
    final me = members[myId];
    if (me == null) return;

    final dist = Geolocator.distanceBetween(
      me.lat, me.lng, leader.lat, leader.lng,
    );
    state = state.copyWith(distanceToLeader: dist, leaderDisplayName: leader.displayName);
  }

  // ── Chat ───────────────────────────────────────────────────

  void _subscribeToChatMessages(int conversationId) {
    _chatChannel?.unsubscribe();
    final supabase = Supabase.instance.client;

    _chatChannel = supabase
        .channel('ride_chat:$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'direct_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            final row = payload.newRecord;
            final msg = _parseMessage(row);

            // Handle blitzer report messages → force immediate reload
            // Multiple retries: DB insert may take a moment to commit
            if (msg.body.contains('🚨') && msg.body.contains('Blitzer')) {
              debugPrint('[GroupRide] Blitzer chat message detected → reload at 1s, 3s, 6s');
              Future.delayed(const Duration(seconds: 1), () => _loadBlitzerReports());
              Future.delayed(const Duration(seconds: 3), () => _loadBlitzerReports());
              Future.delayed(const Duration(seconds: 6), () => _loadBlitzerReports());
            }

            // Handle blitzer removal messages from other users
            if (msg.body.startsWith('🗑️ BLITZER_REMOVED:')) {
              final idStr = msg.body.replaceFirst('🗑️ BLITZER_REMOVED:', '').trim();
              final removedId = int.tryParse(idStr);
              if (removedId != null) {
                _blitzerReports.removeWhere((r) => r.id == removedId);
                _blitzerService.clearCooldown(removedId);
                // Clear current alert if it's for this blitzer + notify screen
                final shouldClearAlert = state.currentAlert?.report.id == removedId;
                state = state.copyWith(
                  clearAlert: shouldClearAlert,
                  lastRemovedBlitzerId: removedId,
                );
                debugPrint('[GroupRide] Blitzer $removedId removed via group message');
              }
              return; // Don't show in chat
            }

            final exists = state.chatMessages.any((m) => m.id == msg.id);
            if (!exists) {
              // Keep only last 50 messages in ride view
              final updated = [...state.chatMessages, msg];
              if (updated.length > 50) {
                state = state.copyWith(chatMessages: updated.sublist(updated.length - 50));
              } else {
                state = state.copyWith(chatMessages: updated);
              }
            }
          },
        )
        .subscribe();
  }

  Future<void> _loadRecentMessages(int conversationId) async {
    try {
      final data = await Supabase.instance.client
          .from('direct_messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false)
          .limit(30);

      final messages = (data as List)
          .map((row) => _parseMessage(row as Map<String, dynamic>))
          .toList()
          .reversed
          .toList();

      state = state.copyWith(chatMessages: messages);
    } catch (e) {
      debugPrint('[GroupRide] Load messages error: $e');
    }
  }

  /// Send a text message in the group chat.
  Future<void> sendMessage(String body) async {
    if (body.trim().isEmpty) return;
    final group = state.group;
    if (group?.conversationId == null) return;

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      await Supabase.instance.client.from('direct_messages').insert({
        'conversation_id': group!.conversationId,
        'user_id': userId,
        'body': body.trim(),
        'message_type': 'text',
      });
    } catch (e) {
      debugPrint('[GroupRide] Send message error: $e');
    }
  }

  /// Send a blitzer warning as a system message in the group chat.
  Future<void> _shareBlitzerAlert(BlitzerAlert alert) async {
    final group = state.group;
    if (group?.conversationId == null) return;

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      // Send warning text as chat message with blitzer emoji prefix
      await Supabase.instance.client.from('direct_messages').insert({
        'conversation_id': group!.conversationId,
        'user_id': userId,
        'body': '🚨 ${alert.warningText}',
        'message_type': 'text',
      });
    } catch (e) {
      debugPrint('[GroupRide] Share blitzer error: $e');
    }
  }

  // ── Blitzer alerts ─────────────────────────────────────────

  Position? _lastKnownPosition;

  /// Set current alert and auto-dismiss after a delay.
  void _setAlertWithAutoDismiss(BlitzerAlert alert) {
    state = state.copyWith(currentAlert: alert);
    _alertDismissTimer?.cancel();
    // Immediate alerts stay longer (8s), others dismiss after 6s
    final duration = alert.stage == AlertStage.immediate
        ? const Duration(seconds: 8)
        : const Duration(seconds: 6);
    _alertDismissTimer = Timer(duration, () {
      state = state.copyWith(clearAlert: true);
    });
  }

  /// Subscribe to Supabase Realtime for instant blitzer report notifications.
  void _startBlitzerRealtime() {
    try {
      final blitzerRepo = ref.read(blitzerRepositoryProvider);
      _blitzerRealtimeChannel = blitzerRepo.subscribeToBlitzerReports(
        onNewReport: (report) {
          final myUserId = Supabase.instance.client.auth.currentUser?.id;
          if (report.userId == myUserId) return; // Skip own reports
          if (!report.isActive || report.isExpired) return;
          if (_blitzerReports.any((r) => r.id == report.id)) return; // Already known

          // Check proximity — only alert if within 50km
          if (_lastKnownPosition != null) {
            final dist = Geolocator.distanceBetween(
              _lastKnownPosition!.latitude, _lastKnownPosition!.longitude,
              report.latitude, report.longitude,
            );
            if (dist > 50000) return;
          }

          debugPrint('[GroupRide RT] Neuer Blitzer: ${report.typeLabel} (id=${report.id})');
          _blitzerReports.add(report);
          _blitzerService.clearCooldown(report.id);

          // Immediately check alert for this new blitzer
          if (_lastKnownPosition != null && _blitzerSettings != null) {
            final speedKmh = (_lastKnownPosition!.speed * 3.6).clamp(0.0, 300.0);
            final result = _blitzerService.checkAlerts(
              pos: _lastKnownPosition!,
              reports: [report], // Check only the new report
              settings: _blitzerSettings!,
              currentSpeedKmh: speedKmh,
            );
            if (result.newAlerts.isNotEmpty) {
              final topAlert = result.newAlerts.first;
              debugPrint('[GroupRide RT] 🚨 INSTANT ALERT: ${topAlert.report.typeLabel} '
                  '${topAlert.distanceMeters.round()}m');
              _setAlertWithAutoDismiss(topAlert);
              _shareBlitzerAlert(topAlert);
              AlertAudioService.instance.playAlert(
                stage: topAlert.stage,
                audioEnabled: _blitzerSettings!.audioAlertsEnabled,
                volume: _blitzerSettings!.audioVolume,
                soundType: _blitzerSettings!.alertSoundType,
                hapticEnabled: _blitzerSettings!.hapticAlertsEnabled,
                hapticIntensity: _blitzerSettings!.hapticIntensity,
              );
              TtsAlertService.instance.speakBlitzerWarning(
                blitzerId: topAlert.report.id,
                stage: topAlert.stage,
                distanceMeters: topAlert.distanceMeters,
                speedLimit: topAlert.report.speedLimit,
                blitzerType: topAlert.report.type,
              );
            }
          }
        },
        onUpdate: (report) {
          final idx = _blitzerReports.indexWhere((r) => r.id == report.id);
          if (idx == -1) return;
          if (!report.isActive) {
            // Deactivated → remove
            _blitzerReports.removeAt(idx);
            _blitzerService.clearCooldown(report.id);
            if (state.currentAlert?.report.id == report.id) {
              state = state.copyWith(clearAlert: true);
            }
            debugPrint('[GroupRide RT] Blitzer ${report.id} deactivated → removed');
          } else {
            _blitzerReports[idx] = report;
          }
        },
      );
      debugPrint('[GroupRide RT] Realtime subscription active');
    } catch (e) {
      debugPrint('[GroupRide RT] Realtime subscription failed: $e');
    }
  }

  Future<void> _loadBlitzerReports() async {
    try {
      final blitzerRepo = ref.read(blitzerRepositoryProvider);
      final settingsAsync = ref.read(blitzerSettingsProvider);
      _blitzerSettings = settingsAsync.value ?? const BlitzerSettings();
      final oldIds = _blitzerReports.map((r) => r.id).toSet();
      debugPrint('[GroupRide] _loadBlitzerReports: pos=${_lastKnownPosition != null ? '${_lastKnownPosition!.latitude.toStringAsFixed(4)},${_lastKnownPosition!.longitude.toStringAsFixed(4)}' : 'null'}');
      final communityReports = await blitzerRepo.getAllActiveReports();
      debugPrint('[GroupRide] community: ${communityReports.length}');

      // Merge OSM speed cameras (cached, refreshed daily)
      List<BlitzerReport> osmReports = [];
      if (_lastKnownPosition != null) {
        try {
          final allCameras = await OsmBlitzerService.instance.getAllGermany();
          // Nur Blitzer im 5km Radius für Alerts
          final lat = _lastKnownPosition!.latitude;
          final lon = _lastKnownPosition!.longitude;
          final osmCameras = allCameras.where((c) =>
              OsmBlitzerService.distanceApprox(c.latitude, c.longitude, lat, lon) <= 5000).toList();
          osmReports = osmCameras.map((c) => BlitzerReport.fromOsm(c)).toList();
          debugPrint('[GroupRide] OSM: ${allCameras.length} total DE, ${osmCameras.length} within 5km');
        } catch (e) {
          debugPrint('[GroupRide] OSM load error: $e');
        }
      } else {
        debugPrint('[GroupRide] Skipping OSM: no GPS position');
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

      _blitzerReports = merged;
      final newIds = _blitzerReports.map((r) => r.id).toSet();

      // Find truly NEW blitzers (just appeared in DB) and clear their cooldowns
      final freshIds = newIds.difference(oldIds);
      if (freshIds.isNotEmpty) {
        debugPrint('[GroupRide] New blitzers detected: $freshIds — clearing cooldowns');
        for (final id in freshIds) {
          _blitzerService.clearCooldown(id);
        }
      }

      debugPrint('[GroupRide] Loaded ${_blitzerReports.length} blitzer reports '
          '(${communityReports.length} community + ${osmReports.length} OSM, ${freshIds.length} new)');

      // Re-check alerts with last known position after reload
      // (important: GPS might not fire during standstill)
      if (_lastKnownPosition != null && _blitzerReports.isNotEmpty && _blitzerSettings != null) {
        final speedKmh = (_lastKnownPosition!.speed * 3.6).clamp(0.0, 300.0);
        debugPrint('[GroupRide] Re-checking alerts: pos=${_lastKnownPosition!.latitude.toStringAsFixed(4)},'
            '${_lastKnownPosition!.longitude.toStringAsFixed(4)} speed=${speedKmh.round()} '
            'reports=${_blitzerReports.length}');
        final result = _blitzerService.checkAlerts(
          pos: _lastKnownPosition!,
          reports: _blitzerReports,
          settings: _blitzerSettings!,
          currentSpeedKmh: speedKmh,
        );
        debugPrint('[GroupRide] Alert result: ${result.newAlerts.length} new, '
            '${result.activeAlerts.length} active');
        if (result.newAlerts.isNotEmpty) {
          final topAlert = result.newAlerts.first;
          debugPrint('[GroupRide] 🚨 NEW ALERT: ${topAlert.report.typeLabel} '
              '${topAlert.distanceMeters.round()}m ${topAlert.stage.name}');
          _setAlertWithAutoDismiss(topAlert);
          if (topAlert.stage != AlertStage.early) {
            _shareBlitzerAlert(topAlert);
          }
          AlertAudioService.instance.playAlert(
            stage: topAlert.stage,
            audioEnabled: _blitzerSettings!.audioAlertsEnabled,
            volume: _blitzerSettings!.audioVolume,
            soundType: _blitzerSettings!.alertSoundType,
            hapticEnabled: _blitzerSettings!.hapticAlertsEnabled,
            hapticIntensity: _blitzerSettings!.hapticIntensity,
          );
          TtsAlertService.instance.speakBlitzerWarning(
            blitzerId: topAlert.report.id,
            stage: topAlert.stage,
            distanceMeters: topAlert.distanceMeters,
            speedLimit: topAlert.report.speedLimit,
            blitzerType: topAlert.report.type,
          );
        }
      } else {
        debugPrint('[GroupRide] Skip alert check: pos=${_lastKnownPosition != null} '
            'reports=${_blitzerReports.length} settings=${_blitzerSettings != null}');
      }
    } catch (e) {
      debugPrint('[GroupRide] Blitzer load error: $e');
    }
  }

  void _startGpsTracking() {
    // Get initial position immediately (for blitzer alerts at standstill)
    Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high)
        .then((pos) => _lastKnownPosition ??= pos)
        .catchError((_) {});

    _gpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Lower filter for blitzer alerts at slow speed
      ),
    ).listen((position) {
      final isFirstFix = _lastKnownPosition == null;
      _lastKnownPosition = position;
      // On first GPS fix, reload blitzers so OSM cameras can be fetched
      if (isFirstFix) {
        _loadBlitzerReports();
      }
      final speedKmh = (position.speed * 3.6).clamp(0.0, 300.0);
      state = state.copyWith(currentSpeed: speedKmh);

      // Check blitzer alerts
      if (_blitzerReports.isNotEmpty && _blitzerSettings != null) {
        final result = _blitzerService.checkAlerts(
          pos: position,
          reports: _blitzerReports,
          settings: _blitzerSettings!,
          currentSpeedKmh: speedKmh,
        );

        if (result.newAlerts.isNotEmpty) {
          final topAlert = result.newAlerts.first;
          _setAlertWithAutoDismiss(topAlert);

          // Auto-share blitzer warning in group chat (only approach + immediate)
          if (topAlert.stage != AlertStage.early) {
            _shareBlitzerAlert(topAlert);
          }

          // ── Audio shutter sound ──
          final settings = _blitzerSettings!;
          AlertAudioService.instance.playAlert(
            stage: topAlert.stage,
            audioEnabled: settings.audioAlertsEnabled,
            volume: settings.audioVolume,
            soundType: settings.alertSoundType,
            hapticEnabled: settings.hapticAlertsEnabled,
            hapticIntensity: settings.hapticIntensity,
          );

          // ── TTS voice warning ──
          TtsAlertService.instance.speakBlitzerWarning(
            blitzerId: topAlert.report.id,
            stage: topAlert.stage,
            distanceMeters: topAlert.distanceMeters,
            speedLimit: topAlert.report.speedLimit,
            blitzerType: topAlert.report.type,
          );
        }

        // Also speak when active alerts escalate to a new stage
        for (final alert in result.activeAlerts) {
          TtsAlertService.instance.speakBlitzerWarning(
            blitzerId: alert.report.id,
            stage: alert.stage,
            distanceMeters: alert.distanceMeters,
            speedLimit: alert.report.speedLimit,
            blitzerType: alert.report.type,
          );
        }

        state = state.copyWith(activeAlerts: result.activeAlerts);
      }

      _updateDistanceToDestination(position: position);
    });
  }

  void _updateDistanceToDestination({Position? position}) {
    final group = state.group;
    if (group?.destinationLat == null || group?.destinationLng == null) {
      if (state.distanceToDestination != null) {
        state = state.copyWith(clearDistance: true);
      }
      return;
    }

    // Use provided position or last known
    final pos = position ?? globalLiveLocationService.nearbyUsers.values
        .cast<LiveUserPosition?>()
        .firstWhere(
          (u) => u?.userId == Supabase.instance.client.auth.currentUser?.id,
          orElse: () => null,
        );
    if (pos == null) return;

    final lat = pos is Position ? pos.latitude : (pos as LiveUserPosition).lat;
    final lng = pos is Position ? pos.longitude : (pos as LiveUserPosition).lng;

    final dist = Geolocator.distanceBetween(
      lat, lng,
      group!.destinationLat!, group.destinationLng!,
    );

    state = state.copyWith(distanceToDestination: dist);
  }

  // ── POI sharing ──────────────────────────────────────────────

  /// Share a POI (gas station, meetup, etc.) with all group members.
  Future<void> sharePoiWithGroup({
    required String poiType,
    required String name,
    required double lat,
    required double lng,
    required double distanceKm,
  }) async {
    final distText = distanceKm < 1
        ? '${(distanceKm * 1000).round()}m'
        : '${distanceKm.toStringAsFixed(1)}km';
    final msg = '📍 $poiType: $name — $distText entfernt';
    await sendMessage(msg);

    // Also announce via TTS
    TtsAlertService.instance.speakText(
      '$poiType $name in $distText gefunden.',
    );
  }

  // ── Distance monitoring ──────────────────────────────────────

  /// Start periodic distance-to-leader check with TTS warnings.
  void _startDistanceMonitoring() {
    _distanceCheckTimer?.cancel();
    _distanceCheckTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkLeaderDistance();
    });
  }

  /// Check distance to leader and issue TTS warnings if needed.
  void _checkLeaderDistance() {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == null) return;

    final members = state.rideMembers;
    if (members.isEmpty) return;

    final me = members[myId];
    final leader = members.values
        .cast<LiveUserPosition?>()
        .firstWhere((u) => u!.isGroupLeader, orElse: () => null);

    // === MEMBER PERSPECTIVE: warn ME about distance to leader ===
    if (leader != null && leader.userId != myId && me != null) {
      final dist = Geolocator.distanceBetween(
        me.lat, me.lng, leader.lat, leader.lng,
      );

      if (dist > 1000) {
        final now = DateTime.now();
        final canWarn = _lastDistanceWarning == null ||
            now.difference(_lastDistanceWarning!) > const Duration(seconds: 30);

        if (canWarn) {
          _distanceWarningCount++;
          _lastDistanceWarning = now;

          final distText = dist >= 1000
              ? '${(dist / 1000).toStringAsFixed(1)} Kilometer'
              : '${dist.round()} Meter';

          if (_distanceWarningCount == 1) {
            TtsAlertService.instance.speakText(
              'Achtung, du verlierst die Gruppe. $distText zum Leader.',
            );
          } else {
            TtsAlertService.instance.speakText(
              'Warnung! $distText vom Leader entfernt. Bitte aufholen!',
            );
          }
        }
      } else {
        // Back in range — reset warnings
        if (_distanceWarningCount > 0) {
          _distanceWarningCount = 0;
          _lastDistanceWarning = null;
          debugPrint('[GroupRide] Distance to leader OK — warnings reset');
        }
      }
      return;
    }

    // === LEADER PERSPECTIVE: warn about distant members ===
    if (me != null && me.isGroupLeader) {
      for (final member in members.values) {
        if (member.userId == myId) continue;
        final dist = Geolocator.distanceBetween(
          me.lat, me.lng, member.lat, member.lng,
        );
        if (dist > 1000) {
          final now = DateTime.now();
          final canWarn = _lastDistanceWarning == null ||
              now.difference(_lastDistanceWarning!) > const Duration(seconds: 30);
          if (canWarn) {
            _lastDistanceWarning = now;
            final distText = dist >= 1000
                ? '${(dist / 1000).toStringAsFixed(1)} Kilometer'
                : '${dist.round()} Meter';
            TtsAlertService.instance.speakText(
              '${member.displayName} ist $distText entfernt.',
            );
            break; // Only announce one member at a time
          }
        }
      }
    }
  }

  // ── Cleanup ────────────────────────────────────────────────

  Future<void> dispose() async {
    _liveSub?.cancel();
    _gpsSub?.cancel();
    _chatChannel?.unsubscribe();
    _blitzerRealtimeChannel?.unsubscribe();
    _blitzerCheckTimer?.cancel();
    _blitzerReloadTimer?.cancel();
    _distanceCheckTimer?.cancel();
    _alertDismissTimer?.cancel();
    if (state.isVoiceActive) {
      await _liveKit.disconnect();
    }
    _blitzerService.reset();
    TtsAlertService.instance.clearSpokenAlerts();
    // Clear group affiliation when leaving ride screen
    globalLiveLocationService.setActiveGroup(null, null);
  }

  // ── Helpers ────────────────────────────────────────────────

  DirectMessage _parseMessage(Map<String, dynamic> row) {
    return DirectMessage(
      id: row['id'] is int ? row['id'] as int : int.parse(row['id'].toString()),
      conversationId: row['conversation_id'] is int
          ? row['conversation_id'] as int
          : int.parse(row['conversation_id'].toString()),
      senderId: row['user_id']?.toString() ?? '',
      body: row['body'] as String? ?? '',
      imageUrl: row['image_url'] as String?,
      audioUrl: row['audio_url'] as String?,
      messageType: row['message_type'] as String? ?? 'text',
      isRead: row['is_read'] as bool? ?? false,
      createdAt: row['created_at'] != null
          ? DateTime.tryParse(row['created_at'] as String)
          : null,
    );
  }
}
