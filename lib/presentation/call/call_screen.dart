import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

import '../../providers/call/call_notifier.dart';
import '../../providers/groups/group_call_notifier.dart' show CallParticipant;
import '../../services/livekit_service.dart';

/// Unified call screen for outgoing ringing + active voice/video calls.
class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({super.key});

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final callState = ref.watch(callNotifierProvider);
    final notifier = ref.read(callNotifierProvider.notifier);

    // Auto-pop when call is fully ended / idle
    if (callState.callStatus == CallStatus.idle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: _buildBody(callState, notifier),
      ),
    );
  }

  Widget _buildBody(CallState callState, CallNotifier notifier) {
    switch (callState.callStatus) {
      case CallStatus.ringing:
        return _buildRingingUI(callState, notifier);
      case CallStatus.connecting:
        return _buildConnectingUI(callState, notifier);
      case CallStatus.active:
        return _buildActiveUI(callState, notifier);
      case CallStatus.ended:
        return _buildEndedUI(callState);
      case CallStatus.declined:
        return _buildStatusUI('Abgelehnt', Icons.call_end_rounded, Colors.red);
      case CallStatus.missed:
        return _buildStatusUI('Keine Antwort', Icons.phone_missed_rounded, Colors.orange);
      case CallStatus.busy:
        return _buildStatusUI('Besetzt', Icons.phone_disabled_rounded, Colors.orange);
      case CallStatus.idle:
        return const SizedBox.shrink();
    }
  }

  // ── Ringing (outgoing) ───────────────────────────────────────────────

  Widget _buildRingingUI(CallState callState, CallNotifier notifier) {
    return Center(
      child: Column(
        children: [
          const Spacer(flex: 2),
          // Avatar with pulse
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = 1.0 + (_pulseController.value * 0.08);
              return Transform.scale(scale: scale, child: child);
            },
            child: _buildAvatar(callState, 80),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              callState.remoteName ?? 'Unbekannt',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            callState.callType == 'video' ? 'Videoanruf' : 'Sprachanruf',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 16),
          ),
          const SizedBox(height: 12),
          Text(
            'Klingelt...',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
          ),
          const Spacer(flex: 3),
          // Cancel button
          _HangUpButton(onTap: () => notifier.endCall()),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  // ── Connecting ───────────────────────────────────────────────────────

  Widget _buildConnectingUI(CallState callState, CallNotifier notifier) {
    return Center(
      child: Column(
        children: [
          const Spacer(flex: 2),
          _buildAvatar(callState, 80),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              callState.remoteName ?? 'Unbekannt',
              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 16),
          const SizedBox(
            width: 24, height: 24,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
          ),
          const SizedBox(height: 8),
          Text(
            'Verbinde...',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 16),
          ),
          const Spacer(flex: 3),
          _HangUpButton(onTap: () => notifier.endCall()),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  // ── Active call ──────────────────────────────────────────────────────

  Widget _buildActiveUI(CallState callState, CallNotifier notifier) {
    final hasVideo = callState.isCameraEnabled ||
        callState.participants.any((p) => p.hasVideo);
    final minutes = callState.callDuration.inMinutes.toString().padLeft(2, '0');
    final seconds = (callState.callDuration.inSeconds % 60).toString().padLeft(2, '0');

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      callState.remoteName ?? 'Anruf',
                      style: const TextStyle(
                        color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$minutes:$seconds',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  callState.callType == 'video' ? 'VIDEO' : 'AUDIO',
                  style: const TextStyle(
                    color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Content area
        Expanded(
          child: hasVideo
              ? _buildVideoContent(callState)
              : _buildVoiceContent(callState),
        ),

        // Controls
        _ActiveCallControls(
          isMicEnabled: callState.isMicEnabled,
          isCameraEnabled: callState.isCameraEnabled,
          isSpeakerOn: callState.isSpeakerOn,
          onToggleMic: notifier.toggleMic,
          onToggleCamera: notifier.toggleCamera,
          onSwitchCamera: notifier.switchCamera,
          onToggleSpeaker: notifier.toggleSpeaker,
          onHangUp: notifier.endCall,
        ),
      ],
    );
  }

  Widget _buildVoiceContent(CallState callState) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Remote participant speaking indicator
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final speaking = callState.participants.length > 1 &&
                  callState.participants[1].isSpeaking;
              final scale = speaking ? 1.0 + (_pulseController.value * 0.05) : 1.0;
              return Transform.scale(scale: scale, child: child);
            },
            child: _buildAvatar(callState, 64),
          ),
          const SizedBox(height: 16),
          Text(
            callState.remoteName ?? 'Anruf',
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600),
          ),
          if (callState.participants.length > 1 && callState.participants[1].isMuted) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mic_off, color: Colors.red.shade300, size: 16),
                const SizedBox(width: 4),
                Text('Stummgeschaltet', style: TextStyle(color: Colors.red.shade300, fontSize: 13)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVideoContent(CallState callState) {
    final livekitSvc = LiveKitService.instance;
    final localVideo = livekitSvc.localVideoTrack;

    // Build video-track lookup by participant identity (Supabase user UUID).
    final videoByIdentity = <String, lk.VideoTrack>{};
    for (final rp in livekitSvc.remoteParticipants.entries) {
      final identity = rp.value.identity ?? rp.key;
      for (final pub in rp.value.videoTrackPublications) {
        if (pub.subscribed && pub.track != null) {
          videoByIdentity[identity] = pub.track as lk.VideoTrack;
          break;
        }
      }
    }

    // Remote participants = everyone except self.
    // Self is always participants[0] (see CallNotifier._refreshParticipants).
    final remotes = callState.participants.length > 1
        ? callState.participants.sublist(1)
        : const <CallParticipant>[];

    return Stack(
      fit: StackFit.expand,
      children: [
        // Remote grid (adaptive based on participant count)
        if (remotes.isEmpty)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAvatar(callState, 48),
                const SizedBox(height: 12),
                Text(
                  callState.groupId != null
                      ? 'Warte auf Teilnehmer\u2026'
                      : (callState.remoteName ?? ''),
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
            ),
          )
        else
          _buildRemoteGrid(remotes, videoByIdentity),

        // Local video (PIP, top-right)
        if (localVideo != null)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: SizedBox(
                  width: 100,
                  height: 140,
                  child: lk.VideoTrackRenderer(
                    localVideo,
                    fit: lk.VideoViewFit.cover,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Adaptive grid for remote participants.
  /// - 1 remote: fullscreen
  /// - 2 remotes: vertical split
  /// - 3+ remotes: 2-column grid
  Widget _buildRemoteGrid(
    List<CallParticipant> remotes,
    Map<String, lk.VideoTrack> videoByIdentity,
  ) {
    final count = remotes.length;

    if (count == 1) {
      return _buildParticipantTile(
        remotes[0],
        videoByIdentity[remotes[0].id],
        fullscreen: true,
      );
    }

    if (count == 2) {
      return Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          children: [
            Expanded(
              child: _buildParticipantTile(
                remotes[0],
                videoByIdentity[remotes[0].id],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: _buildParticipantTile(
                remotes[1],
                videoByIdentity[remotes[1].id],
              ),
            ),
          ],
        ),
      );
    }

    // 3+ participants → 2-column grid
    return GridView.builder(
      padding: const EdgeInsets.all(4),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: 0.75,
      ),
      itemCount: count,
      itemBuilder: (ctx, i) => _buildParticipantTile(
        remotes[i],
        videoByIdentity[remotes[i].id],
      ),
    );
  }

  /// One tile in the grid — video if available, otherwise avatar + name.
  Widget _buildParticipantTile(
    CallParticipant p,
    lk.VideoTrack? videoTrack, {
    bool fullscreen = false,
  }) {
    final tile = Stack(
      fit: StackFit.expand,
      children: [
        // Video or avatar placeholder
        if (videoTrack != null)
          lk.VideoTrackRenderer(videoTrack, fit: lk.VideoViewFit.cover)
        else
          Container(
            color: const Color(0xFF2A2A3E),
            child: Center(
              child: CircleAvatar(
                radius: fullscreen ? 56 : 32,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                backgroundImage: p.avatarUrl != null
                    ? NetworkImage(p.avatarUrl!)
                    : null,
                child: p.avatarUrl == null
                    ? Text(
                        p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: fullscreen ? 42 : 24,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : null,
              ),
            ),
          ),

        // Bottom label: name (+ mic-off icon if muted)
        Positioned(
          left: 6,
          right: 6,
          bottom: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (p.isMuted) ...[
                  Icon(Icons.mic_off,
                      color: Colors.red.shade300, size: 13),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    p.name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: fullscreen ? 13 : 11,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Green border when speaking
        if (p.isSpeaking)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.green, width: 2.5),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
      ],
    );

    if (fullscreen) return tile;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: tile,
    );
  }

  // ── Ended ────────────────────────────────────────────────────────────

  Widget _buildEndedUI(CallState callState) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildAvatar(callState, 64),
          const SizedBox(height: 24),
          Text(
            callState.remoteName ?? '',
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            'Anruf beendet',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusUI(String text, IconData icon, Color color) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 64),
          const SizedBox(height: 16),
          Text(text, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ── Avatar helper ────────────────────────────────────────────────────

  Widget _buildAvatar(CallState callState, double radius) {
    final avatarUrl = callState.remoteAvatarUrl;
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.white.withValues(alpha: 0.1),
      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
      child: avatarUrl == null
          ? Text(
              (callState.remoteName ?? '?').isNotEmpty
                  ? (callState.remoteName ?? '?')[0].toUpperCase()
                  : '?',
              style: TextStyle(
                color: Colors.white,
                fontSize: radius * 0.6,
                fontWeight: FontWeight.w700,
              ),
            )
          : null,
    );
  }
}

// ═══════════════════════════════════════════════════
//  HANG UP BUTTON (ringing / connecting)
// ═══════════════════════════════════════════════════

class _HangUpButton extends StatelessWidget {
  final VoidCallback onTap;
  const _HangUpButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  ACTIVE CALL CONTROLS
// ═══════════════════════════════════════════════════

class _ActiveCallControls extends StatelessWidget {
  final bool isMicEnabled;
  final bool isCameraEnabled;
  final bool isSpeakerOn;
  final VoidCallback onToggleMic;
  final VoidCallback onToggleCamera;
  final VoidCallback onSwitchCamera;
  final VoidCallback onToggleSpeaker;
  final VoidCallback onHangUp;

  const _ActiveCallControls({
    required this.isMicEnabled,
    required this.isCameraEnabled,
    required this.isSpeakerOn,
    required this.onToggleMic,
    required this.onToggleCamera,
    required this.onSwitchCamera,
    required this.onToggleSpeaker,
    required this.onHangUp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _CtrlBtn(
            icon: isMicEnabled ? Icons.mic : Icons.mic_off,
            label: isMicEnabled ? 'Stumm' : 'Stumm',
            isActive: !isMicEnabled,       // highlight when MUTED
            isMuted: !isMicEnabled,         // red tint when muted
            onTap: onToggleMic,
          ),
          _CtrlBtn(
            icon: isSpeakerOn ? Icons.volume_up : Icons.volume_down,
            label: 'Lautspr.',
            isActive: isSpeakerOn,
            onTap: onToggleSpeaker,
          ),
          _CtrlBtn(
            icon: isCameraEnabled ? Icons.videocam : Icons.videocam_off,
            label: isCameraEnabled ? 'Kamera aus' : 'Kamera an',
            isActive: isCameraEnabled,
            onTap: onToggleCamera,
          ),
          if (isCameraEnabled)
            _CtrlBtn(
              icon: Icons.cameraswitch_rounded,
              label: 'Wechseln',
              isActive: true,
              onTap: onSwitchCamera,
            ),
          _CtrlBtn(
            icon: Icons.call_end_rounded,
            label: 'Auflegen',
            isActive: false,
            isDestructive: true,
            onTap: onHangUp,
          ),
        ],
      ),
    );
  }
}

class _CtrlBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final bool isDestructive;
  final bool isMuted;
  final VoidCallback onTap;

  const _CtrlBtn({
    required this.icon,
    required this.label,
    required this.isActive,
    this.isDestructive = false,
    this.isMuted = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDestructive
        ? Colors.red
        : isMuted
            ? Colors.red.withValues(alpha: 0.35)
            : isActive
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.08);
    final iconColor = isDestructive
        ? Colors.white
        : isMuted
            ? Colors.red.shade200
            : isActive
                ? Colors.white
                : Colors.white.withValues(alpha: 0.5);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10),
          ),
        ],
      ),
    );
  }
}
