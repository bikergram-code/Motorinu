import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/call_repository.dart';
import '../../services/livekit_service.dart';
import '../groups/group_call_notifier.dart';

// ═══════════════════════════════════════════════════
//  CALL STATE
// ═══════════════════════════════════════════════════

enum CallStatus { idle, ringing, connecting, active, ended, declined, missed, busy }

class CallState {
  const CallState({
    this.activeCallId,
    this.callType = 'voice',
    this.callStatus = CallStatus.idle,
    this.isOutgoing = false,
    this.remoteName,
    this.remoteAvatarUrl,
    this.remoteUserId,
    this.conversationId,
    this.groupId,
    this.livekitRoom,
    this.isMicEnabled = true,
    this.isCameraEnabled = false,
    this.isSpeakerOn = false,
    this.callDuration = Duration.zero,
    this.participants = const [],
  });

  final int? activeCallId;
  final String callType;
  final CallStatus callStatus;
  final bool isOutgoing;
  final String? remoteName;
  final String? remoteAvatarUrl;
  final String? remoteUserId;
  final int? conversationId;
  final int? groupId;
  final String? livekitRoom;
  final bool isMicEnabled;
  final bool isCameraEnabled;
  final bool isSpeakerOn;
  final Duration callDuration;
  final List<CallParticipant> participants;

  bool get isInCall => callStatus == CallStatus.active || callStatus == CallStatus.ringing || callStatus == CallStatus.connecting;

  CallState copyWith({
    int? activeCallId,
    String? callType,
    CallStatus? callStatus,
    bool? isOutgoing,
    String? remoteName,
    String? remoteAvatarUrl,
    String? remoteUserId,
    int? conversationId,
    int? groupId,
    String? livekitRoom,
    bool? isMicEnabled,
    bool? isCameraEnabled,
    bool? isSpeakerOn,
    Duration? callDuration,
    List<CallParticipant>? participants,
    bool clearAll = false,
  }) {
    if (clearAll) return const CallState();
    return CallState(
      activeCallId: activeCallId ?? this.activeCallId,
      callType: callType ?? this.callType,
      callStatus: callStatus ?? this.callStatus,
      isOutgoing: isOutgoing ?? this.isOutgoing,
      remoteName: remoteName ?? this.remoteName,
      remoteAvatarUrl: remoteAvatarUrl ?? this.remoteAvatarUrl,
      remoteUserId: remoteUserId ?? this.remoteUserId,
      conversationId: conversationId ?? this.conversationId,
      groupId: groupId ?? this.groupId,
      livekitRoom: livekitRoom ?? this.livekitRoom,
      isMicEnabled: isMicEnabled ?? this.isMicEnabled,
      isCameraEnabled: isCameraEnabled ?? this.isCameraEnabled,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      callDuration: callDuration ?? this.callDuration,
      participants: participants ?? this.participants,
    );
  }
}

// ═══════════════════════════════════════════════════
//  CALL NOTIFIER
// ═══════════════════════════════════════════════════

final callNotifierProvider =
    NotifierProvider<CallNotifier, CallState>(CallNotifier.new);

class CallNotifier extends Notifier<CallState> {
  late CallRepository _repo;
  RealtimeChannel? _callChannel;
  RealtimeChannel? _incomingChannel;
  Timer? _timeoutTimer;
  Timer? _durationTimer;
  DateTime? _callStartTime;
  final AudioPlayer _ringbackPlayer = AudioPlayer(); // Freizeichen für Anrufer
  final AudioPlayer _endTonePlayer = AudioPlayer();  // Auflege-Ton

  @override
  CallState build() {
    _repo = CallRepository();
    debugPrint('[CallNotifier] build() called — starting incoming call subscription');

    ref.onDispose(() {
      _callChannel?.unsubscribe();
      _incomingChannel?.unsubscribe();
      _timeoutTimer?.cancel();
      _durationTimer?.cancel();
      _ringbackPlayer.dispose();
      _endTonePlayer.dispose();
    });

    // Start listening for incoming calls — SOFORT, nicht delayed
    _subscribeToIncomingCalls();

    return const CallState();
  }

  // ── Incoming call listener ───────────────────────────────────────────

  void _subscribeToIncomingCalls() {
    _incomingChannel?.unsubscribe();
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    _incomingChannel = _repo.subscribeToIncomingCalls((callRecord) async {
      debugPrint('[Call] Incoming call detected: ${callRecord['id']}');

      // Don't handle if already in a call
      if (state.isInCall) {
        final callId = callRecord['id'];
        if (callId != null) {
          final id = callId is int ? callId : int.tryParse('$callId');
          if (id != null) {
            await _repo.updateCallStatus(id, 'busy');
          }
        }
        return;
      }

      // Fetch caller info
      final callerId = callRecord['caller_id']?.toString();
      String callerName = 'Unbekannt';
      String? callerAvatar;

      if (callerId != null) {
        final profile = await _repo.getCallerProfile(callerId);
        callerName = profile?['display_name'] as String? ??
            profile?['username'] as String? ??
            'Unbekannt';
        callerAvatar = profile?['avatar_url'] as String?;
      }

      final callId = callRecord['id'];
      final id = callId is int ? callId : int.tryParse('$callId');
      final groupIdRaw = callRecord['group_id'];
      final groupId = groupIdRaw is int ? groupIdRaw : int.tryParse('${groupIdRaw ?? ''}');
      final isGroupCall = groupId != null;

      // Group call: fetch group info, use group-call-{groupId} as room
      String displayName = callerName;
      String? displayAvatar = callerAvatar;
      if (isGroupCall) {
        final group = await _repo.getGroupInfo(groupId);
        final groupName = group?['name'] as String? ?? 'Gruppe';
        final groupAvatar = group?['avatar_url'] as String?;
        displayName = 'Gruppe: $groupName · $callerName ruft an';
        displayAvatar = groupAvatar ?? callerAvatar;
      }

      // livekit_room may be null in the INSERT payload because createCall
      // sets it in a separate UPDATE. Derive it as fallback.
      final room = callRecord['livekit_room']?.toString() ??
          (isGroupCall ? 'group-call-$groupId' : (id != null ? 'call-$id' : null));

      state = state.copyWith(
        activeCallId: id,
        callType: callRecord['call_type']?.toString() ?? 'voice',
        callStatus: CallStatus.ringing,
        isOutgoing: false,
        remoteName: displayName,
        remoteAvatarUrl: displayAvatar,
        remoteUserId: callerId,
        conversationId: callRecord['conversation_id'] as int?,
        groupId: groupId,
        livekitRoom: room,
      );

      // Subscribe to this call's updates (in case caller cancels)
      if (id != null) {
        _subscribeToCallUpdates(id);
      }

      debugPrint('[Call] Incoming: $callerName (${callRecord['call_type']})');
    });
  }

  // ── Outgoing call ────────────────────────────────────────────────────

  /// Initiate a call to another user.
  Future<void> initiateCall({
    required String calleeId,
    required String calleeName,
    String? calleeAvatar,
    required String callType,
    required int conversationId,
  }) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    // Check if callee is already in a call
    debugPrint('[Call] Checking if $calleeId is busy...');
    final existingCall = await _repo.getActiveCallForUser(calleeId);
    if (existingCall != null) {
      debugPrint('[Call] Callee is busy! Existing call: ${existingCall['id']} status=${existingCall['status']}');
      state = state.copyWith(callStatus: CallStatus.busy);
      Future.delayed(const Duration(seconds: 2), () {
        if (state.callStatus == CallStatus.busy) {
          state = const CallState();
        }
      });
      return;
    }
    debugPrint('[Call] Callee is free, creating call...');

    try {
      // Create call in DB
      final callData = await _repo.createCall(
        callerId: userId,
        calleeId: calleeId,
        conversationId: conversationId,
        callType: callType,
      );

      final callId = callData['id'] as int;
      final roomName = callData['livekit_room'] as String?;

      state = state.copyWith(
        activeCallId: callId,
        callType: callType,
        callStatus: CallStatus.ringing,
        isOutgoing: true,
        remoteName: calleeName,
        remoteAvatarUrl: calleeAvatar,
        remoteUserId: calleeId,
        conversationId: conversationId,
        livekitRoom: roomName,
      );

      // Subscribe to call updates (detect accept/decline)
      _subscribeToCallUpdates(callId);

      // Play ringback tone (Freizeichen) for the caller
      _playRingback();

      // 30s timeout → missed
      _timeoutTimer?.cancel();
      _timeoutTimer = Timer(const Duration(seconds: 30), () {
        if (state.callStatus == CallStatus.ringing && state.isOutgoing) {
          debugPrint('[Call] Timeout — marking as missed');
          _repo.updateCallStatus(callId, 'missed');
          state = state.copyWith(callStatus: CallStatus.missed);
          Future.delayed(const Duration(seconds: 2), () {
            if (state.callStatus == CallStatus.missed) {
              state = const CallState();
            }
          });
        }
      });

      debugPrint('[Call] Initiated call $callId to $calleeName ($callType)');
    } catch (e) {
      debugPrint('[Call] Initiate error: $e');
      state = const CallState();
    }
  }

  /// Initiate a group call. All members of the group will receive a ring.
  /// Caller joins the LiveKit room immediately (no "ringing" state for caller).
  Future<void> initiateGroupCall({
    required int groupId,
    required String groupName,
    String? groupAvatar,
    required String callType,
  }) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    if (state.isInCall) {
      debugPrint('[Call] Already in a call, cannot start group call');
      return;
    }

    try {
      // Create signaling row in DB (triggers ring on all group members)
      final callData = await _repo.createCall(
        callerId: userId,
        groupId: groupId,
        callType: callType,
      );

      final callId = callData['id'] as int;
      final roomName = callData['livekit_room'] as String? ?? 'group-call-$groupId';

      // Caller goes directly into active state (no self-ringing)
      state = state.copyWith(
        activeCallId: callId,
        callType: callType,
        callStatus: CallStatus.connecting,
        isOutgoing: true,
        remoteName: groupName,
        remoteAvatarUrl: groupAvatar,
        groupId: groupId,
        livekitRoom: roomName,
      );

      // Mark call as active (so other members see it's live, not missed)
      await _repo.updateCallStatus(callId, 'active', startedAt: DateTime.now());

      // Connect caller to LiveKit room
      final lk = LiveKitService.instance;
      if (lk.isConnected) await lk.disconnect();

      lk.onParticipantChanged = () => _refreshParticipants();
      lk.onRemoteTrackChanged = () => _refreshParticipants();
      lk.onDisconnected = () {
        debugPrint('[Call] LiveKit disconnected (group)');
        endCall();
      };

      await lk.connectToGroupCall(groupId, withVideo: callType == 'video');

      _callStartTime = DateTime.now();
      state = state.copyWith(
        callStatus: CallStatus.active,
        isMicEnabled: lk.isMicEnabled,
        isCameraEnabled: lk.isCameraEnabled,
      );

      _startDurationTimer();
      _refreshParticipants();

      debugPrint('[Call] Initiated GROUP call $callId (group=$groupId, room=$roomName)');
    } catch (e) {
      debugPrint('[Call] Group initiate error: $e');
      state = const CallState();
    }
  }

  // ── Accept / Decline / End ───────────────────────────────────────────

  /// Accept an incoming call.
  Future<void> acceptCall() async {
    final callId = state.activeCallId;
    if (callId == null) return;
    final groupId = state.groupId;
    final isGroupCall = groupId != null;
    // Fallback: derive room name (same convention as createCall)
    final roomName = state.livekitRoom ??
        (isGroupCall ? 'group-call-$groupId' : 'call-$callId');

    try {
      state = state.copyWith(callStatus: CallStatus.connecting);

      // 1-on-1: update DB status. Group: status already 'active' from initiator.
      if (!isGroupCall) {
        await _repo.updateCallStatus(callId, 'active', startedAt: DateTime.now());
      }

      // Connect to LiveKit
      final lk = LiveKitService.instance;
      if (lk.isConnected) await lk.disconnect();

      lk.onParticipantChanged = () => _refreshParticipants();
      lk.onRemoteTrackChanged = () => _refreshParticipants();
      lk.onDisconnected = () {
        debugPrint('[Call] LiveKit disconnected');
        endCall();
      };

      if (isGroupCall) {
        await lk.connectToGroupCall(groupId, withVideo: state.callType == 'video');
      } else {
        await lk.connectToCall(roomName, withVideo: state.callType == 'video');
      }

      _callStartTime = DateTime.now();
      state = state.copyWith(
        callStatus: CallStatus.active,
        isMicEnabled: lk.isMicEnabled,
        isCameraEnabled: lk.isCameraEnabled,
      );

      _startDurationTimer();
      _refreshParticipants();

      debugPrint('[Call] Accepted call $callId (group=$isGroupCall), connected to $roomName');
    } catch (e) {
      debugPrint('[Call] Accept error: $e');
      state = const CallState();
    }
  }

  /// Decline an incoming call.
  Future<void> declineCall() async {
    final callId = state.activeCallId;
    if (callId == null) return;

    try {
      await _repo.updateCallStatus(callId, 'declined');
    } catch (e) {
      debugPrint('[Call] Decline error: $e');
    }

    _cleanup();
    state = const CallState();
    debugPrint('[Call] Declined call $callId');
  }

  /// End an active call (or cancel outgoing ringing).
  /// For group calls: only updates DB status if this member is the caller AND leaving.
  /// Other members just disconnect locally — the call stays active for them.
  Future<void> endCall() async {
    final callId = state.activeCallId;
    final isGroupCall = state.groupId != null;
    if (callId == null) {
      _cleanup();
      state = const CallState();
      return;
    }

    try {
      final duration = _callStartTime != null
          ? DateTime.now().difference(_callStartTime!).inSeconds
          : null;

      // For 1-on-1: mark missed/ended globally.
      // For group: only update DB if caller ends (no one left) OR if ringing was cancelled.
      // Individual member leaving a group call is just a local LiveKit disconnect.
      if (!isGroupCall) {
        final newStatus =
            state.callStatus == CallStatus.ringing && state.isOutgoing
                ? 'missed'
                : 'ended';
        await _repo.updateCallStatus(
          callId,
          newStatus,
          endedAt: DateTime.now(),
          durationSeconds: duration,
        );
      } else if (state.isOutgoing) {
        // Caller ending group call → mark ended so late-joining members see missed
        await _repo.updateCallStatus(
          callId,
          'ended',
          endedAt: DateTime.now(),
          durationSeconds: duration,
        );
      }
    } catch (e) {
      debugPrint('[Call] End error: $e');
    }

    // Disconnect LiveKit
    try {
      final lk = LiveKitService.instance;
      lk.onParticipantChanged = null;
      lk.onRemoteTrackChanged = null;
      lk.onDisconnected = null;
      await lk.disconnect();
    } catch (e) {
      debugPrint('[Call] LiveKit disconnect error: $e');
    }

    _cleanup();
    _playEndTone();
    state = state.copyWith(callStatus: CallStatus.ended);

    // Auto-reset after 2s
    Future.delayed(const Duration(seconds: 2), () {
      if (state.callStatus == CallStatus.ended) {
        state = const CallState();
      }
    });

    debugPrint('[Call] Ended call $callId');
  }

  // ── Controls ─────────────────────────────────────────────────────────

  Future<void> toggleMic() async {
    final newValue = !state.isMicEnabled;
    state = state.copyWith(isMicEnabled: newValue);
    debugPrint('[Call] toggleMic → $newValue');
    try {
      await LiveKitService.instance.setMicEnabled(newValue);
    } catch (e) {
      debugPrint('[Call] toggleMic error: $e');
      state = state.copyWith(isMicEnabled: !newValue);
    }
  }

  Future<void> toggleCamera() async {
    final newValue = !state.isCameraEnabled;
    state = state.copyWith(isCameraEnabled: newValue);
    try {
      await LiveKitService.instance.setCameraEnabled(newValue);
    } catch (e) {
      debugPrint('[Call] toggleCamera error: $e');
      state = state.copyWith(isCameraEnabled: !newValue);
    }
  }

  Future<void> switchCamera() async {
    await LiveKitService.instance.switchCamera();
  }

  Future<void> toggleSpeaker() async {
    final newValue = !state.isSpeakerOn;
    await LiveKitService.instance.setSpeakerphone(newValue);
    state = state.copyWith(isSpeakerOn: newValue);
  }

  // ── Private ──────────────────────────────────────────────────────────

  void _subscribeToCallUpdates(int callId) {
    _callChannel?.unsubscribe();
    _callChannel = _repo.subscribeToCall(callId, (record) async {
      final newStatus = record['status']?.toString();
      debugPrint('[Call] Call $callId status update: $newStatus');

      switch (newStatus) {
        case 'active':
          if (state.isOutgoing && state.callStatus == CallStatus.ringing) {
            // Callee accepted → stop ringback, connect to LiveKit
            _stopRingback();
            _timeoutTimer?.cancel();
            state = state.copyWith(callStatus: CallStatus.connecting);

            try {
              final roomName = state.livekitRoom ?? 'call-$callId';
              final lk = LiveKitService.instance;
              if (lk.isConnected) await lk.disconnect();

              lk.onParticipantChanged = () => _refreshParticipants();
              lk.onRemoteTrackChanged = () => _refreshParticipants();
              lk.onDisconnected = () {
                debugPrint('[Call] LiveKit disconnected (caller side)');
                endCall();
              };

              await lk.connectToCall(roomName, withVideo: state.callType == 'video');

              _callStartTime = DateTime.now();
              state = state.copyWith(
                callStatus: CallStatus.active,
                isMicEnabled: lk.isMicEnabled,
                isCameraEnabled: lk.isCameraEnabled,
              );
              _startDurationTimer();
              _refreshParticipants();
            } catch (e) {
              debugPrint('[Call] Caller connect error: $e');
              endCall();
            }
          }
          break;

        case 'declined':
          _timeoutTimer?.cancel();
          state = state.copyWith(callStatus: CallStatus.declined);
          Future.delayed(const Duration(seconds: 2), () {
            if (state.callStatus == CallStatus.declined) {
              _cleanup();
              state = const CallState();
            }
          });
          break;

        case 'ended':
          try {
            final lk = LiveKitService.instance;
            lk.onParticipantChanged = null;
            lk.onRemoteTrackChanged = null;
            lk.onDisconnected = null;
            await lk.disconnect();
          } catch (_) {}
          _cleanup();
          state = state.copyWith(callStatus: CallStatus.ended);
          Future.delayed(const Duration(seconds: 2), () {
            if (state.callStatus == CallStatus.ended) {
              state = const CallState();
            }
          });
          break;

        case 'missed':
          _timeoutTimer?.cancel();
          _cleanup();
          state = state.copyWith(callStatus: CallStatus.missed);
          Future.delayed(const Duration(seconds: 2), () {
            if (state.callStatus == CallStatus.missed) {
              state = const CallState();
            }
          });
          break;

        case 'busy':
          _timeoutTimer?.cancel();
          _cleanup();
          state = state.copyWith(callStatus: CallStatus.busy);
          Future.delayed(const Duration(seconds: 2), () {
            if (state.callStatus == CallStatus.busy) {
              state = const CallState();
            }
          });
          break;
      }
    });
  }

  void _refreshParticipants() {
    final lk = LiveKitService.instance;
    final participants = <CallParticipant>[];

    // Self
    final user = Supabase.instance.client.auth.currentUser;
    final meta = user?.userMetadata;
    participants.add(CallParticipant(
      id: user?.id ?? 'me',
      name: meta?['display_name'] as String? ??
          meta?['username'] as String? ??
          'Du',
      avatarUrl: meta?['avatar_url'] as String?,
      isMuted: !lk.isMicEnabled,
      hasVideo: lk.isCameraEnabled,
    ));

    // Remote
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
    final start = _callStartTime ?? DateTime.now();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final elapsed = DateTime.now().difference(start);
      state = state.copyWith(callDuration: elapsed);
    });
  }

  void _cleanup() {
    _callChannel?.unsubscribe();
    _callChannel = null;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    _durationTimer?.cancel();
    _durationTimer = null;
    _callStartTime = null;
    _stopRingback();
  }

  // ── Audio helpers ───────────────────────────────────────────────────

  /// Freizeichen for the caller while ringing.
  void _playRingback() {
    try {
      _ringbackPlayer.setReleaseMode(ReleaseMode.loop);
      _ringbackPlayer.setVolume(0.6);
      _ringbackPlayer.play(AssetSource('sounds/ringback_tone.wav'));
      debugPrint('[Call] Ringback tone started');
    } catch (e) {
      debugPrint('[Call] Ringback error: $e');
    }
  }

  void _stopRingback() {
    try {
      _ringbackPlayer.stop();
    } catch (_) {}
  }

  /// Short beep when call ends.
  void _playEndTone() {
    try {
      _endTonePlayer.setReleaseMode(ReleaseMode.release);
      _endTonePlayer.setVolume(0.5);
      _endTonePlayer.play(AssetSource('sounds/call_end.wav'));
      debugPrint('[Call] End tone played');
    } catch (e) {
      debugPrint('[Call] End tone error: $e');
    }
  }
}
