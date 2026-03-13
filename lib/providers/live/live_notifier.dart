import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/live_stream.dart';
import '../../data/repositories/live_repository.dart';
import '../../services/livekit_service.dart';
import '../core/providers.dart';

// ═══════════════════════════════════════════════════
//  LIVE DISCOVERY STATE
// ═══════════════════════════════════════════════════

class LiveDiscoveryState {
  const LiveDiscoveryState({
    this.streams = const [],
    this.isLoading = false,
    this.error,
  });

  final List<LiveStream> streams;
  final bool isLoading;
  final String? error;

  LiveDiscoveryState copyWith({
    List<LiveStream>? streams,
    bool? isLoading,
    String? error,
  }) {
    return LiveDiscoveryState(
      streams: streams ?? this.streams,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class LiveDiscoveryNotifier extends Notifier<LiveDiscoveryState> {
  late LiveRepository _repo;
  String? _community;
  RealtimeChannel? _realtimeChannel;

  @override
  LiveDiscoveryState build() {
    _repo = ref.watch(liveRepositoryProvider);
    _community = ref.watch(communityProvider)?.name ?? 'bikergram';

    ref.onDispose(() {
      _realtimeChannel?.unsubscribe();
    });

    return const LiveDiscoveryState();
  }

  Future<void> loadStreams() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final streams = await _repo.getActiveStreams(community: _community);
      state = LiveDiscoveryState(streams: streams);
      _subscribeToChanges();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Subscribe to live_sessions changes so the list auto-updates
  /// when a stream goes live or ends.
  void _subscribeToChanges() {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = Supabase.instance.client
        .channel('live_discovery')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'live_sessions',
          callback: (payload) {
            debugPrint('[LiveDiscovery] Realtime change: ${payload.eventType}');
            // Re-fetch the full list on any change
            _silentRefresh();
          },
        )
        .subscribe();
  }

  /// Refresh without showing loading spinner.
  Future<void> _silentRefresh() async {
    try {
      final streams = await _repo.getActiveStreams(community: _community);
      state = state.copyWith(streams: streams, isLoading: false);
    } catch (_) {}
  }

  Future<void> refresh() => loadStreams();
}

final liveDiscoveryProvider =
    NotifierProvider<LiveDiscoveryNotifier, LiveDiscoveryState>(
        LiveDiscoveryNotifier.new);

// ═══════════════════════════════════════════════════
//  LIVE VIEWER STATE (watching a specific stream)
// ═══════════════════════════════════════════════════

class LiveViewerState {
  const LiveViewerState({
    this.session,
    this.messages = const [],
    this.isLoading = false,
    this.isEnded = false,
    this.error,
    this.remoteVideoTrack,
    this.isReconnecting = false,
    this.isVideoConnected = false,
  });

  final LiveStream? session;
  final List<LiveChatMessage> messages;
  final bool isLoading;
  final bool isEnded;
  final String? error;

  /// Remote video track from the host (LiveKit).
  final lk.VideoTrack? remoteVideoTrack;
  final bool isReconnecting;
  final bool isVideoConnected;

  LiveViewerState copyWith({
    LiveStream? session,
    List<LiveChatMessage>? messages,
    bool? isLoading,
    bool? isEnded,
    String? error,
    lk.VideoTrack? remoteVideoTrack,
    bool? isReconnecting,
    bool? isVideoConnected,
    bool clearRemoteTrack = false,
  }) {
    return LiveViewerState(
      session: session ?? this.session,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isEnded: isEnded ?? this.isEnded,
      error: error,
      remoteVideoTrack:
          clearRemoteTrack ? null : (remoteVideoTrack ?? this.remoteVideoTrack),
      isReconnecting: isReconnecting ?? this.isReconnecting,
      isVideoConnected: isVideoConnected ?? this.isVideoConnected,
    );
  }
}

class LiveViewerNotifier extends Notifier<LiveViewerState> {
  late LiveRepository _repo;
  RealtimeChannel? _chatChannel;
  RealtimeChannel? _sessionChannel;

  @override
  LiveViewerState build() {
    _repo = ref.watch(liveRepositoryProvider);

    ref.onDispose(() {
      _chatChannel?.unsubscribe();
      _sessionChannel?.unsubscribe();
    });

    return const LiveViewerState();
  }

  /// Join a live stream and start listening for chat + status changes.
  Future<void> joinStream(String sessionId) async {
    state = state.copyWith(isLoading: true);

    try {
      // Fetch session + initial chat
      final session = await _repo.getStreamById(sessionId);
      if (session == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Stream nicht gefunden',
        );
        return;
      }

      if (session.status == 'ended') {
        state = state.copyWith(
          session: session,
          isLoading: false,
          isEnded: true,
        );
        return;
      }

      final messages = await _repo.getChatMessages(sessionId: sessionId);

      state = LiveViewerState(
        session: session,
        messages: messages,
      );

      // Register viewer
      await _repo.joinSession(sessionId);

      // Subscribe to real-time chat messages
      _subscribeToChatMessages(sessionId);

      // Subscribe to session status changes
      _subscribeToSessionStatus(sessionId);

      // ── Connect to LiveKit room as viewer ──
      _connectToLiveKit(sessionId);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> _connectToLiveKit(String sessionId) async {
    try {
      final liveKit = LiveKitService.instance;

      // Setup callbacks before connecting
      liveKit.onRemoteTrackChanged = () {
        state = state.copyWith(
          remoteVideoTrack: liveKit.remoteVideoTrack,
          isVideoConnected: liveKit.remoteVideoTrack != null,
        );
      };
      liveKit.onConnectionStateChanged = (connState) {
        state = state.copyWith(
          isReconnecting: connState == lk.ConnectionState.reconnecting,
        );
      };
      liveKit.onDisconnected = () {
        debugPrint('[LiveViewer] LiveKit disconnected — checking session status...');
        // LiveKit disconnected — check DB if session was ended
        _checkIfSessionEnded(sessionId);
      };

      await liveKit.connectAsViewer(sessionId);
      state = state.copyWith(isVideoConnected: true);
    } catch (e) {
      debugPrint('[LiveViewer] LiveKit connect error: $e');
      // Don't fail the whole join — chat still works without video
    }
  }

  /// When LiveKit disconnects, check if the host ended the session.
  Future<void> _checkIfSessionEnded(String sessionId) async {
    try {
      // Small delay to let DB update propagate
      await Future.delayed(const Duration(milliseconds: 500));
      final session = await _repo.getStreamById(sessionId);
      if (session != null && session.status == 'ended') {
        debugPrint('[LiveViewer] Session confirmed ended in DB');
        state = state.copyWith(
          isEnded: true,
          isVideoConnected: false,
          clearRemoteTrack: true,
        );
      } else {
        debugPrint('[LiveViewer] Session still active — host just disconnected');
        state = state.copyWith(
          isVideoConnected: false,
          clearRemoteTrack: true,
        );
      }
    } catch (e) {
      debugPrint('[LiveViewer] Check session status error: $e');
      state = state.copyWith(
        isVideoConnected: false,
        clearRemoteTrack: true,
      );
    }
  }

  void _subscribeToChatMessages(String sessionId) {
    _chatChannel = Supabase.instance.client
        .channel('live_chat:$sessionId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'live_chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'live_session_id',
            value: sessionId,
          ),
          callback: (payload) {
            final data = payload.newRecord;
            if (data.isEmpty) return;

            // Create message from the payload
            final msg = LiveChatMessage(
              id: (data['id'] as num).toInt(),
              liveSessionId: data['live_session_id'] as String,
              userId: data['user_id'] as String,
              message: data['message'] as String,
              moderationState:
                  data['moderation_state'] as String? ?? 'visible',
              createdAt: data['created_at'] != null
                  ? DateTime.tryParse(data['created_at'] as String)
                  : DateTime.now(),
              username: data['username'] as String?,
            );

            if (msg.moderationState == 'visible') {
              final msgs = [...state.messages, msg];
              state = state.copyWith(
                messages: msgs.length > 200 ? msgs.sublist(msgs.length - 200) : msgs,
              );
            }
          },
        )
        .subscribe();
  }

  void _subscribeToSessionStatus(String sessionId) {
    _sessionChannel = Supabase.instance.client
        .channel('live_session_status:$sessionId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'live_sessions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: sessionId,
          ),
          callback: (payload) {
            final data = payload.newRecord;
            if (data.isEmpty) return;

            final status = data['status'] as String?;
            if (status == 'ended') {
              debugPrint('[LiveViewer] Realtime: session ended!');
              // Disconnect LiveKit and show ended overlay
              LiveKitService.instance.disconnect();
              state = state.copyWith(
                isEnded: true,
                isVideoConnected: false,
                clearRemoteTrack: true,
              );
              return;
            }

            // Update viewer count
            final viewerCount = (data['viewer_count'] as num?)?.toInt();
            if (viewerCount != null && state.session != null) {
              state = state.copyWith(
                session: state.session!.copyWith(
                  viewerCount: viewerCount,
                  status: status ?? state.session!.status,
                ),
              );
            }
          },
        )
        .subscribe();
  }

  /// Send a chat message.
  Future<void> sendMessage(String text) async {
    if (state.session == null) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    try {
      await _repo.sendChatMessage(
        sessionId: state.session!.id,
        message: trimmed,
      );
    } catch (e) {
      debugPrint('[LiveViewer] Send message error: $e');
    }
  }

  /// Leave the stream.
  Future<void> leaveStream() async {
    if (state.session == null) return;
    _chatChannel?.unsubscribe();
    _sessionChannel?.unsubscribe();
    await LiveKitService.instance.disconnect();
    await _repo.leaveSession(state.session!.id);
  }

  /// Reset state (when navigating away).
  void reset() {
    _chatChannel?.unsubscribe();
    _sessionChannel?.unsubscribe();
    LiveKitService.instance.disconnect();
    state = const LiveViewerState();
  }
}

final liveViewerProvider =
    NotifierProvider<LiveViewerNotifier, LiveViewerState>(
        LiveViewerNotifier.new);

// ═══════════════════════════════════════════════════
//  GO LIVE (BROADCAST) STATE
// ═══════════════════════════════════════════════════

class GoLiveState {
  const GoLiveState({
    this.session,
    this.isCreating = false,
    this.isLive = false,
    this.error,
    this.viewerCount = 0,
    this.localVideoTrack,
    this.isCameraOn = false,
    this.isMicOn = false,
    this.streamDuration,
    this.finalStats,
  });

  final LiveStream? session;
  final bool isCreating;
  final bool isLive;
  final String? error;
  final int viewerCount;

  /// Local camera track (LiveKit).
  final lk.VideoTrack? localVideoTrack;
  final bool isCameraOn;
  final bool isMicOn;

  /// Duration of the stream (set when ending).
  final Duration? streamDuration;

  /// Final session stats fetched after ending the stream.
  final LiveStream? finalStats;

  /// Whether to show the stats overlay.
  bool get showStats => finalStats != null && !isLive;

  GoLiveState copyWith({
    LiveStream? session,
    bool? isCreating,
    bool? isLive,
    String? error,
    int? viewerCount,
    lk.VideoTrack? localVideoTrack,
    bool? isCameraOn,
    bool? isMicOn,
    bool clearLocalTrack = false,
    Duration? streamDuration,
    LiveStream? finalStats,
    bool clearFinalStats = false,
  }) {
    return GoLiveState(
      session: session ?? this.session,
      isCreating: isCreating ?? this.isCreating,
      isLive: isLive ?? this.isLive,
      error: error,
      viewerCount: viewerCount ?? this.viewerCount,
      localVideoTrack:
          clearLocalTrack ? null : (localVideoTrack ?? this.localVideoTrack),
      isCameraOn: isCameraOn ?? this.isCameraOn,
      isMicOn: isMicOn ?? this.isMicOn,
      streamDuration: streamDuration ?? this.streamDuration,
      finalStats:
          clearFinalStats ? null : (finalStats ?? this.finalStats),
    );
  }
}

class GoLiveNotifier extends Notifier<GoLiveState> {
  late LiveRepository _repo;

  @override
  GoLiveState build() {
    _repo = ref.watch(liveRepositoryProvider);
    return const GoLiveState();
  }

  /// Create + start a live session.
  Future<void> goLive({
    required String title,
    int? topicId,
    String? community,
  }) async {
    debugPrint('[GoLive] ▶ goLive() called: title=$title');
    state = state.copyWith(isCreating: true, error: null);

    try {
      // 1. Create session
      debugPrint('[GoLive] 1. Creating session...');
      var session = await _repo.createSession(
        title: title,
        topicId: topicId,
        community: community,
      );
      debugPrint('[GoLive] 1. ✓ Session created: ${session.id}');

      // 2. Connect to LiveKit as host (publishes camera + mic)
      debugPrint('[GoLive] 2. Connecting to LiveKit as host...');
      final liveKit = LiveKitService.instance;
      liveKit.onRemoteTrackChanged = () {
        debugPrint('[GoLive] onRemoteTrackChanged → localTrack=${liveKit.localVideoTrack != null}');
        state = state.copyWith(
          localVideoTrack: liveKit.localVideoTrack,
          isCameraOn: liveKit.isCameraEnabled,
          isMicOn: liveKit.isMicEnabled,
        );
      };
      liveKit.onParticipantChanged = () {
        final count = liveKit.remoteParticipantCount;
        debugPrint('[GoLive] onParticipantChanged → viewers=$count');
        state = state.copyWith(viewerCount: count);
        // Sync viewer count to DB so browse/viewer screens see it
        if (state.session != null) {
          _syncViewerCountToDb(state.session!.id, count);
        }
      };

      await liveKit.connectAsHost(session.id);
      debugPrint('[GoLive] 2. ✓ LiveKit connected');

      // 3. Start session in DB (set to live) — only after LiveKit connected
      debugPrint('[GoLive] 3. Starting session in DB...');
      session = await _repo.startSession(session.id);
      debugPrint('[GoLive] 3. ✓ Session started: status=${session.status}');

      state = GoLiveState(
        session: session,
        isLive: true,
        localVideoTrack: liveKit.localVideoTrack,
        isCameraOn: liveKit.isCameraEnabled,
        isMicOn: liveKit.isMicEnabled,
      );
      debugPrint('[GoLive] ✓ State updated: isLive=${state.isLive}');
    } catch (e, st) {
      debugPrint('[GoLive] ✗ ERROR: $e');
      debugPrint('[GoLive] StackTrace: $st');
      state = state.copyWith(isCreating: false, error: e.toString());
    }
  }

  int _lastSyncedCount = -1;

  /// Sync the viewer count from LiveKit to the DB so other screens see it.
  Future<void> _syncViewerCountToDb(String sessionId, int count) async {
    // Avoid unnecessary DB writes
    if (count == _lastSyncedCount) return;
    _lastSyncedCount = count;

    try {
      final updates = <String, dynamic>{
        'viewer_count': count,
      };
      // Track peak viewer count
      if (state.session != null && count > state.session!.peakViewerCount) {
        updates['peak_viewer_count'] = count;
      }
      await Supabase.instance.client
          .from('live_sessions')
          .update(updates)
          .eq('id', sessionId);
    } catch (e) {
      debugPrint('[GoLive] Sync viewer count error: $e');
    }
  }

  /// End the live session and fetch final stats.
  Future<void> endLive() async {
    if (state.session == null) return;
    final sessionId = state.session!.id;

    // Calculate stream duration before disconnecting
    final startedAt = state.session!.startedAt;
    final duration = startedAt != null
        ? DateTime.now().difference(startedAt)
        : null;

    try {
      await LiveKitService.instance.disconnect();
      await _repo.endSession(sessionId);

      // Fetch final stats from DB (peak viewers, unique viewers, chat messages, etc.)
      final finalSession = await _repo.getStreamById(sessionId);

      state = state.copyWith(
        isLive: false,
        clearLocalTrack: true,
        streamDuration: duration,
        finalStats: finalSession,
      );
      debugPrint('[GoLive] Stream ended — stats loaded: peak=${finalSession?.peakViewerCount}, unique=${finalSession?.totalUniqueViewers}, chat=${finalSession?.totalChatMessages}');
    } catch (e) {
      debugPrint('[GoLive] End error: $e');
      state = state.copyWith(isLive: false, clearLocalTrack: true);
    }
  }

  /// Clear stats (when navigating away from stats screen).
  void clearStats() {
    state = const GoLiveState();
  }

  /// Toggle camera on/off.
  Future<void> toggleCamera() async {
    await LiveKitService.instance.toggleCamera();
    state = state.copyWith(
      isCameraOn: LiveKitService.instance.isCameraEnabled,
      localVideoTrack: LiveKitService.instance.localVideoTrack,
    );
  }

  /// Toggle microphone on/off.
  Future<void> toggleMic() async {
    await LiveKitService.instance.toggleMic();
    state = state.copyWith(
      isMicOn: LiveKitService.instance.isMicEnabled,
    );
  }

  /// Switch between front/back camera.
  Future<void> switchCamera() async {
    await LiveKitService.instance.switchCamera();
  }
}

final goLiveProvider =
    NotifierProvider<GoLiveNotifier, GoLiveState>(GoLiveNotifier.new);
