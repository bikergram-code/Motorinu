import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/call/call_notifier.dart';

/// Full-screen incoming call overlay.
/// Shows caller name, avatar, accept/decline buttons.
class IncomingCallScreen extends ConsumerStatefulWidget {
  const IncomingCallScreen({super.key});

  @override
  ConsumerState<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends ConsumerState<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  final AudioPlayer _ringtonePlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    // Start ringtone + vibration
    _startRingtone();
  }

  Future<void> _startRingtone() async {
    try {
      await _ringtonePlayer.setReleaseMode(ReleaseMode.loop);
      await _ringtonePlayer.setVolume(1.0);
      await _ringtonePlayer.play(AssetSource('sounds/motorcycle_ringtone.wav'));
      debugPrint('[Call] Ringtone started');
    } catch (e) {
      debugPrint('[Call] Ringtone error: $e');
    }
    // Vibrate pattern
    HapticFeedback.heavyImpact();
  }

  void _stopRingtone() {
    try {
      _ringtonePlayer.stop();
    } catch (_) {}
  }

  @override
  void dispose() {
    _stopRingtone();
    _ringtonePlayer.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final callState = ref.watch(callNotifierProvider);

    // Auto-dismiss only when caller cancelled / timed out.
    // Do NOT dismiss for connecting/active — the accept handler navigates to CallScreen.
    final shouldDismiss = !callState.isOutgoing &&
        callState.callStatus != CallStatus.ringing &&
        callState.callStatus != CallStatus.connecting &&
        callState.callStatus != CallStatus.active;
    if (shouldDismiss) {
      _stopRingtone();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
    }

    final avatarUrl = callState.remoteAvatarUrl;
    final callerName = callState.remoteName ?? 'Unbekannt';
    final isVideo = callState.callType == 'video';
    final isGroupCall = callState.groupId != null;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A2E), Color(0xFF0F0F1A)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Call type label
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isGroupCall
                          ? Icons.groups_rounded
                          : (isVideo ? Icons.videocam_rounded : Icons.call_rounded),
                      color: Colors.white70,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isGroupCall
                          ? (isVideo ? 'Gruppenvideoanruf' : 'Gruppenanruf')
                          : (isVideo ? 'Videoanruf' : 'Sprachanruf'),
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Caller avatar with glow
              AnimatedBuilder(
                animation: _glowController,
                builder: (context, child) {
                  final glow = _glowController.value;
                  return Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4ADE80).withValues(alpha: 0.3 * glow),
                          blurRadius: 30 + (20 * glow),
                          spreadRadius: 5 + (10 * glow),
                        ),
                      ],
                    ),
                    child: child,
                  );
                },
                child: CircleAvatar(
                  radius: 70,
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  backgroundImage:
                      avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null
                      ? Text(
                          callerName.isNotEmpty
                              ? callerName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : null,
                ),
              ),

              const SizedBox(height: 28),

              // Caller name
              Text(
                callerName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              // "Incoming call" text
              Text(
                'Eingehender Anruf',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 15,
                ),
              ),

              const Spacer(flex: 3),

              // Accept / Decline buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Decline
                    _CallActionButton(
                      icon: Icons.call_end_rounded,
                      label: 'Ablehnen',
                      color: Colors.red,
                      onTap: () async {
                        _stopRingtone();
                        await ref.read(callNotifierProvider.notifier).declineCall();
                        if (context.mounted && Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),

                    // Accept
                    _CallActionButton(
                      icon: isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                      label: 'Annehmen',
                      color: const Color(0xFF4ADE80),
                      onTap: () {
                        _stopRingtone();
                        // Capture notifier before navigating (it's global, survives navigation)
                        final notifier = ref.read(callNotifierProvider.notifier);
                        // Navigate to CallScreen FIRST — before state changes trigger rebuilds
                        context.pushReplacement('/call');
                        // Then accept (LiveKit connect happens on CallScreen)
                        notifier.acceptCall();
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _CallActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
