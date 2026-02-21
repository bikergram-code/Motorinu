import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/live_stream.dart';
import '../../data/repositories/live_repository.dart';
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

  @override
  LiveDiscoveryState build() {
    _repo = ref.watch(liveRepositoryProvider);
    _community = ref.watch(communityProvider)?.name ?? 'bikergram';
    return const LiveDiscoveryState();
  }

  Future<void> loadStreams() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final streams = await _repo.getActiveStreams(community: _community);
      state = LiveDiscoveryState(streams: streams);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
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
  });

  final LiveStream? session;
  final List<LiveChatMessage> messages;
  final bool isLoading;
  final bool isEnded;
  final String? error;

  LiveViewerState copyWith({
    LiveStream? session,
    List<LiveChatMessage>? messages,
    bool? isLoading,
    bool? isEnded,
    String? error,
  }) {
    return LiveViewerState(
      session: session ?? this.session,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isEnded: isEnded ?? this.isEnded,
      error: error,
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
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
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
              state = state.copyWith(
                messages: [...state.messages, msg],
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
              state = state.copyWith(isEnded: true);
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
    await _repo.leaveSession(state.session!.id);
  }

  /// Reset state (when navigating away).
  void reset() {
    _chatChannel?.unsubscribe();
    _sessionChannel?.unsubscribe();
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
  });

  final LiveStream? session;
  final bool isCreating;
  final bool isLive;
  final String? error;
  final int viewerCount;

  GoLiveState copyWith({
    LiveStream? session,
    bool? isCreating,
    bool? isLive,
    String? error,
    int? viewerCount,
  }) {
    return GoLiveState(
      session: session ?? this.session,
      isCreating: isCreating ?? this.isCreating,
      isLive: isLive ?? this.isLive,
      error: error,
      viewerCount: viewerCount ?? this.viewerCount,
    );
  }
}

class GoLiveNotifier extends Notifier<GoLiveState> {
  late LiveRepository _repo;
  RealtimeChannel? _viewerChannel;

  @override
  GoLiveState build() {
    _repo = ref.watch(liveRepositoryProvider);

    ref.onDispose(() {
      _viewerChannel?.unsubscribe();
    });

    return const GoLiveState();
  }

  /// Create + start a live session.
  Future<void> goLive({
    required String title,
    int? topicId,
    String? community,
  }) async {
    state = state.copyWith(isCreating: true, error: null);

    try {
      // 1. Create session
      var session = await _repo.createSession(
        title: title,
        topicId: topicId,
        community: community,
      );

      // 2. Start session (set to live)
      session = await _repo.startSession(session.id);

      state = GoLiveState(
        session: session,
        isLive: true,
      );

      // 3. Listen for viewer count updates
      _subscribeToViewerCount(session.id);
    } catch (e) {
      state = state.copyWith(isCreating: false, error: e.toString());
    }
  }

  void _subscribeToViewerCount(String sessionId) {
    _viewerChannel = Supabase.instance.client
        .channel('live_broadcast:$sessionId')
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
            final count = (data['viewer_count'] as num?)?.toInt() ?? 0;
            state = state.copyWith(viewerCount: count);
          },
        )
        .subscribe();
  }

  /// End the live session.
  Future<void> endLive() async {
    if (state.session == null) return;
    _viewerChannel?.unsubscribe();

    try {
      await _repo.endSession(state.session!.id);
      state = state.copyWith(isLive: false);
    } catch (e) {
      debugPrint('[GoLive] End error: $e');
    }
  }
}

final goLiveProvider =
    NotifierProvider<GoLiveNotifier, GoLiveState>(GoLiveNotifier.new);
