import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/livekit_service.dart';

// ═══════════════════════════════════════════════════
//  CALL PARTICIPANT
// ═══════════════════════════════════════════════════

class CallParticipant {
  final String id;
  final String name;
  final String? avatarUrl;
  final bool isSpeaking;
  final bool isMuted;
  final bool hasVideo;

  const CallParticipant({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.isSpeaking = false,
    this.isMuted = false,
    this.hasVideo = false,
  });
}

// ═══════════════════════════════════════════════════
//  GROUP CALL STATE
// ═══════════════════════════════════════════════════

class GroupCallState {
  final int? activeGroupId;
  final String? groupName;
  final bool isInCall;
  final bool isMicEnabled;
  final bool isCameraEnabled;
  final List<CallParticipant> participants;
  final Duration callDuration;

  const GroupCallState({
    this.activeGroupId,
    this.groupName,
    this.isInCall = false,
    this.isMicEnabled = true,
    this.isCameraEnabled = false,
    this.participants = const [],
    this.callDuration = Duration.zero,
  });

  GroupCallState copyWith({
    int? activeGroupId,
    String? groupName,
    bool? isInCall,
    bool? isMicEnabled,
    bool? isCameraEnabled,
    List<CallParticipant>? participants,
    Duration? callDuration,
    bool clearGroup = false,
  }) {
    return GroupCallState(
      activeGroupId: clearGroup ? null : (activeGroupId ?? this.activeGroupId),
      groupName: clearGroup ? null : (groupName ?? this.groupName),
      isInCall: isInCall ?? this.isInCall,
      isMicEnabled: isMicEnabled ?? this.isMicEnabled,
      isCameraEnabled: isCameraEnabled ?? this.isCameraEnabled,
      participants: participants ?? this.participants,
      callDuration: callDuration ?? this.callDuration,
    );
  }
}

// ═══════════════════════════════════════════════════
//  GROUP CALL NOTIFIER
// ═══════════════════════════════════════════════════

final groupCallProvider =
    NotifierProvider<GroupCallNotifier, GroupCallState>(GroupCallNotifier.new);

class GroupCallNotifier extends Notifier<GroupCallState> {
  Timer? _durationTimer;
  Timer? _participantPollTimer;

  @override
  GroupCallState build() {
    ref.onDispose(() {
      _durationTimer?.cancel();
      _participantPollTimer?.cancel();
    });
    return const GroupCallState();
  }

  /// Start or join a group voice call.
  Future<void> joinCall(int groupId, String groupName,
      {bool withVideo = false}) async {
    if (state.isInCall) {
      // Already in a call — leave first
      await leaveCall();
    }

    try {
      final lk = LiveKitService.instance;

      // Disconnect any existing session
      if (lk.isConnected) {
        await lk.disconnect();
      }

      // Setup callbacks
      lk.onParticipantChanged = () => _refreshParticipants();
      lk.onRemoteTrackChanged = () => _refreshParticipants();
      lk.onDisconnected = () {
        debugPrint('[GroupCall] Disconnected');
        _cleanup();
        state = const GroupCallState();
      };

      await lk.connectToGroupCall(groupId, withVideo: withVideo);

      state = state.copyWith(
        activeGroupId: groupId,
        groupName: groupName,
        isInCall: true,
        isMicEnabled: lk.isMicEnabled,
        isCameraEnabled: lk.isCameraEnabled,
      );

      _startDurationTimer();
      _startParticipantPolling();
      _refreshParticipants();

      debugPrint('[GroupCall] Joined call for group $groupId');
    } catch (e) {
      debugPrint('[GroupCall] Join error: $e');
      rethrow;
    }
  }

  /// Leave the current call.
  Future<void> leaveCall() async {
    try {
      final lk = LiveKitService.instance;
      lk.onParticipantChanged = null;
      lk.onRemoteTrackChanged = null;
      lk.onDisconnected = null;
      await lk.disconnect();
    } catch (e) {
      debugPrint('[GroupCall] Leave error: $e');
    }
    _cleanup();
    state = const GroupCallState();
  }

  /// Toggle microphone.
  Future<void> toggleMic() async {
    final lk = LiveKitService.instance;
    await lk.toggleMic();
    state = state.copyWith(isMicEnabled: lk.isMicEnabled);
  }

  /// Toggle camera.
  Future<void> toggleCamera() async {
    final lk = LiveKitService.instance;
    await lk.toggleCamera();
    state = state.copyWith(isCameraEnabled: lk.isCameraEnabled);
  }

  /// Switch front/back camera.
  Future<void> switchCamera() async {
    await LiveKitService.instance.switchCamera();
  }

  // ═══════════════════════════════════════════════════
  //  PRIVATE
  // ═══════════════════════════════════════════════════

  void _refreshParticipants() {
    final lk = LiveKitService.instance;
    final participants = <CallParticipant>[];

    // Add self
    final user = Supabase.instance.client.auth.currentUser;
    final meta = user?.userMetadata;
    participants.add(CallParticipant(
      id: user?.id ?? 'me',
      name: meta?['display_name'] as String? ??
          meta?['username'] as String? ??
          'Du',
      avatarUrl: meta?['avatar_url'] as String?,
      isSpeaking: false,
      isMuted: !lk.isMicEnabled,
      hasVideo: lk.isCameraEnabled,
    ));

    // Add remote participants
    for (final entry in lk.remoteParticipants.entries) {
      final p = entry.value;
      participants.add(CallParticipant(
        id: p.identity ?? entry.key,
        name: p.name ?? p.identity ?? 'User',
        isSpeaking: p.isSpeaking,
        isMuted: !(p.audioTrackPublications.any((t) => !t.muted)),
        hasVideo: p.videoTrackPublications.any((t) => t.subscribed && t.track != null),
      ));
    }

    state = state.copyWith(participants: participants);
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    final startTime = DateTime.now();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final elapsed = DateTime.now().difference(startTime);
      state = state.copyWith(callDuration: elapsed);
    });
  }

  void _startParticipantPolling() {
    _participantPollTimer?.cancel();
    _participantPollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (state.isInCall) _refreshParticipants();
    });
  }

  void _cleanup() {
    _durationTimer?.cancel();
    _durationTimer = null;
    _participantPollTimer?.cancel();
    _participantPollTimer = null;
  }
}
