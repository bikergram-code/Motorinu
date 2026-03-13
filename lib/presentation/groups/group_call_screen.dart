import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

import '../../providers/groups/group_call_notifier.dart';
import '../../services/livekit_service.dart';

/// Fullscreen group voice/video call screen.
class GroupCallScreen extends ConsumerStatefulWidget {
  final int groupId;
  final String groupName;
  final bool startWithVideo;

  const GroupCallScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    this.startWithVideo = false,
  });

  @override
  ConsumerState<GroupCallScreen> createState() => _GroupCallScreenState();
}

class _GroupCallScreenState extends ConsumerState<GroupCallScreen> {
  bool _joining = true;

  @override
  void initState() {
    super.initState();
    _joinCall();
  }

  Future<void> _joinCall() async {
    try {
      await ref.read(groupCallProvider.notifier).joinCall(
            widget.groupId,
            widget.groupName,
            withVideo: widget.startWithVideo,
          );
      if (mounted) setState(() => _joining = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final callState = ref.watch(groupCallProvider);
    final theme = Theme.of(context);

    if (_joining) {
      return Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 20),
              Text(
                'Verbinde mit ${widget.groupName}...',
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    // Check if anyone has video
    final hasAnyVideo = callState.participants.any((p) => p.hasVideo);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            _CallHeader(
              groupName: callState.groupName ?? widget.groupName,
              participantCount: callState.participants.length,
              duration: callState.callDuration,
            ),

            // ── Participants Grid ──
            Expanded(
              child: hasAnyVideo
                  ? _VideoGrid(participants: callState.participants)
                  : _VoiceGrid(participants: callState.participants),
            ),

            // ── Controls ──
            _CallControls(
              isMicEnabled: callState.isMicEnabled,
              isCameraEnabled: callState.isCameraEnabled,
              onToggleMic: () =>
                  ref.read(groupCallProvider.notifier).toggleMic(),
              onToggleCamera: () =>
                  ref.read(groupCallProvider.notifier).toggleCamera(),
              onSwitchCamera: () =>
                  ref.read(groupCallProvider.notifier).switchCamera(),
              onLeave: () async {
                await ref.read(groupCallProvider.notifier).leaveCall();
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  CALL HEADER
// ═══════════════════════════════════════════════════

class _CallHeader extends StatelessWidget {
  final String groupName;
  final int participantCount;
  final Duration duration;

  const _CallHeader({
    required this.groupName,
    required this.participantCount,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  groupName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$participantCount Teilnehmer  ·  $minutes:$seconds',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          // Live indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'LIVE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  VOICE GRID (no video — avatar circles)
// ═══════════════════════════════════════════════════

class _VoiceGrid extends StatelessWidget {
  final List<CallParticipant> participants;
  const _VoiceGrid({required this.participants});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Center(
        child: Wrap(
          spacing: 20,
          runSpacing: 20,
          alignment: WrapAlignment.center,
          children: participants
              .map((p) => _VoiceParticipantTile(participant: p))
              .toList(),
        ),
      ),
    );
  }
}

class _VoiceParticipantTile extends StatelessWidget {
  final CallParticipant participant;
  const _VoiceParticipantTile({required this.participant});

  @override
  Widget build(BuildContext context) {
    final isSpeaking = participant.isSpeaking;
    final isMuted = participant.isMuted;

    return SizedBox(
      width: 90,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar with speaking indicator
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSpeaking ? Colors.green : Colors.transparent,
                width: isSpeaking ? 3 : 0,
              ),
              boxShadow: isSpeaking
                  ? [BoxShadow(color: Colors.green.withOpacity(0.4), blurRadius: 12)]
                  : null,
            ),
            child: CircleAvatar(
              radius: 32,
              backgroundColor: Colors.white.withOpacity(0.1),
              backgroundImage: participant.avatarUrl != null
                  ? NetworkImage(participant.avatarUrl!)
                  : null,
              child: participant.avatarUrl == null
                  ? Text(
                      participant.name.isNotEmpty
                          ? participant.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 6),
          // Name
          Text(
            participant.name,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          // Muted indicator
          if (isMuted)
            Icon(Icons.mic_off, color: Colors.red.shade300, size: 14),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  VIDEO GRID
// ═══════════════════════════════════════════════════

class _VideoGrid extends StatelessWidget {
  final List<CallParticipant> participants;
  const _VideoGrid({required this.participants});

  @override
  Widget build(BuildContext context) {
    final lk = LiveKitService.instance;
    final localVideo = lk.localVideoTrack;
    final remoteVideos = lk.remoteVideoTracks;

    final videoWidgets = <Widget>[];

    // Local video (self)
    if (localVideo != null) {
      videoWidgets.add(_VideoTile(
        name: 'Du',
        videoTrack: localVideo,
        isMirrored: true,
      ));
    }

    // Remote videos
    for (final entry in remoteVideos) {
      final participant = lk.remoteParticipants[entry.key];
      videoWidgets.add(_VideoTile(
        name: participant?.name ?? 'User',
        videoTrack: entry.value,
      ));
    }

    // Voice-only participants (no video)
    final voiceOnly = participants.where((p) => !p.hasVideo).toList();

    return Column(
      children: [
        // Video grid
        if (videoWidgets.isNotEmpty)
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: GridView.count(
                crossAxisCount: videoWidgets.length <= 2 ? 1 : 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: videoWidgets.length <= 2 ? 16 / 9 : 1,
                children: videoWidgets,
              ),
            ),
          ),
        // Voice-only strip at bottom
        if (voiceOnly.isNotEmpty)
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: voiceOnly.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) =>
                  _VoiceParticipantTile(participant: voiceOnly[i]),
            ),
          ),
      ],
    );
  }
}

class _VideoTile extends StatelessWidget {
  final String name;
  final lk.VideoTrack videoTrack;
  final bool isMirrored;

  const _VideoTile({
    required this.name,
    required this.videoTrack,
    this.isMirrored = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          lk.VideoTrackRenderer(
            videoTrack,
            fit: lk.VideoViewFit.cover,
          ),
          // Name overlay
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                name,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  CALL CONTROLS
// ═══════════════════════════════════════════════════

class _CallControls extends StatelessWidget {
  final bool isMicEnabled;
  final bool isCameraEnabled;
  final VoidCallback onToggleMic;
  final VoidCallback onToggleCamera;
  final VoidCallback onSwitchCamera;
  final VoidCallback onLeave;

  const _CallControls({
    required this.isMicEnabled,
    required this.isCameraEnabled,
    required this.onToggleMic,
    required this.onToggleCamera,
    required this.onSwitchCamera,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Mic toggle
          _ControlButton(
            icon: isMicEnabled ? Icons.mic : Icons.mic_off,
            label: isMicEnabled ? 'Stumm' : 'Mikro an',
            isActive: isMicEnabled,
            onTap: onToggleMic,
          ),
          // Camera toggle
          _ControlButton(
            icon: isCameraEnabled ? Icons.videocam : Icons.videocam_off,
            label: isCameraEnabled ? 'Kamera aus' : 'Kamera an',
            isActive: isCameraEnabled,
            onTap: onToggleCamera,
          ),
          // Switch camera (only if camera is on)
          if (isCameraEnabled)
            _ControlButton(
              icon: Icons.cameraswitch_rounded,
              label: 'Wechseln',
              isActive: true,
              onTap: onSwitchCamera,
            ),
          // Leave
          _ControlButton(
            icon: Icons.call_end_rounded,
            label: 'Auflegen',
            isActive: false,
            isDestructive: true,
            onTap: onLeave,
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final bool isDestructive;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.isActive,
    this.isDestructive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDestructive
        ? Colors.red
        : isActive
            ? Colors.white.withOpacity(0.15)
            : Colors.white.withOpacity(0.08);
    final iconColor = isDestructive
        ? Colors.white
        : isActive
            ? Colors.white
            : Colors.white.withOpacity(0.5);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
