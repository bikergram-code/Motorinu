import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

import '../../core/community.dart';
import '../../domain/models/live_stream.dart';
import '../../providers/core/providers.dart';
import '../../providers/live/live_notifier.dart';
import '../../theme/app_theme.dart';

/// Full-screen live stream viewer with chat overlay.
class LiveViewerScreen extends ConsumerStatefulWidget {
  const LiveViewerScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<LiveViewerScreen> createState() => _LiveViewerScreenState();
}

class _LiveViewerScreenState extends ConsumerState<LiveViewerScreen> {
  final _chatController = TextEditingController();
  final _chatScrollController = ScrollController();
  bool _showChat = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      ref.read(liveViewerProvider.notifier).joinStream(widget.sessionId);
    });
  }

  @override
  void dispose() {
    _chatController.dispose();
    _chatScrollController.dispose();
    // Leave stream on dispose
    ref.read(liveViewerProvider.notifier).leaveStream();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_chatScrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_chatScrollController.hasClients) {
          _chatScrollController.animateTo(
            _chatScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _sendMessage() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;
    ref.read(liveViewerProvider.notifier).sendMessage(text);
    _chatController.clear();
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final community = ref.watch(communityProvider);
    final accentColor = community?.accentColor ?? AppTheme.accentDark;
    final viewerState = ref.watch(liveViewerProvider);

    // Auto-scroll chat when new messages arrive
    ref.listen(liveViewerProvider, (prev, next) {
      if (prev != null &&
          next.messages.length > prev.messages.length &&
          _showChat) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Video Surface (placeholder for IVS player) ──
          _buildVideoSurface(viewerState, accentColor),

          // ── Top Bar ──
          _buildTopBar(viewerState, accentColor),

          // ── Chat Overlay ──
          if (_showChat) _buildChatOverlay(viewerState, accentColor),

          // ── Stream Ended Overlay ──
          if (viewerState.isEnded) _buildEndedOverlay(accentColor),

          // ── Loading ──
          if (viewerState.isLoading)
            const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),

          // ── Error ──
          if (viewerState.error != null)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline_rounded,
                      color: Colors.red.withValues(alpha: 0.6), size: 48),
                  const SizedBox(height: 12),
                  Text(
                    viewerState.error!,
                    style: GoogleFonts.inter(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: const Text('Zurück'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoSurface(LiveViewerState state, Color accentColor) {
    // Show remote video track from host via LiveKit
    if (state.remoteVideoTrack != null) {
      return Stack(
        children: [
          // Remote video (fullscreen)
          Positioned.fill(
            child: lk.VideoTrackRenderer(
              state.remoteVideoTrack!,
              fit: lk.VideoViewFit.cover,
            ),
          ),

          // Reconnecting indicator
          if (state.isReconnecting)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.5),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Verbindung wird wiederhergestellt...',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    }

    // No video track yet — show waiting state
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (state.isVideoConnected && state.remoteVideoTrack == null) ...[
              // Connected but waiting for host's video track
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white38,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Warte auf Video vom Host...',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ] else ...[
              // Not connected yet
              Icon(
                Icons.live_tv_rounded,
                size: 64,
                color: accentColor.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 12),
              if (state.session != null)
                Text(
                  state.session!.title,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 8),
              Text(
                'Verbindung wird aufgebaut...',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(LiveViewerState state, Color accentColor) {
    final session = state.session;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // Back button
              GestureDetector(
                onTap: () => context.pop(),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.5),
                  ),
                  child: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 10),

              // Host info
              if (session != null) ...[
                // Avatar
                ClipOval(
                  child: session.hostAvatarUrl != null
                      ? CachedNetworkImage(
                          imageUrl: session.hostAvatarUrl!,
                          width: 32,
                          height: 32,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: 32,
                          height: 32,
                          color: accentColor.withValues(alpha: 0.3),
                          child: Center(
                            child: Text(
                              (session.hostDisplayName ?? session.hostUsername ?? 'U')
                                  .characters
                                  .first
                                  .toUpperCase(),
                              style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        session.hostDisplayName ??
                            session.hostUsername ??
                            'User',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        session.title,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],

              // LIVE badge + viewers
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'LIVE',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.visibility_rounded,
                        color: Colors.white, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      '${session?.viewerCount ?? 0}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // Toggle chat
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _showChat = !_showChat),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.5),
                  ),
                  child: Icon(
                    _showChat
                        ? Icons.chat_bubble_rounded
                        : Icons.chat_bubble_outline_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatOverlay(LiveViewerState state, Color accentColor) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        child: Column(
          children: [
            // Chat messages (semi-transparent overlay)
            Container(
              height: 250,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.white,
                  ],
                  stops: const [0.0, 0.15],
                ).createShader(bounds),
                blendMode: BlendMode.dstIn,
                child: ListView.builder(
                  controller: _chatScrollController,
                  itemCount: state.messages.length,
                  itemBuilder: (_, index) {
                    final msg = state.messages[index];
                    return _buildChatBubble(msg, accentColor);
                  },
                ),
              ),
            ),

            // Chat input
            Container(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: TextField(
                        controller: _chatController,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Nachricht...',
                          hintStyle: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accentColor,
                      ),
                      child: const Icon(Icons.send_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatBubble(LiveChatMessage msg, Color accentColor) {
    final name = msg.displayName ?? msg.username ?? 'User';
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$name ',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                ),
              ),
              TextSpan(
                text: msg.message,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEndedOverlay(Color accentColor) {
    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam_off_rounded,
                color: Colors.white54, size: 56),
            const SizedBox(height: 16),
            Text(
              'Stream beendet',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Dieser Live-Stream wurde vom Host beendet.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Zurück'),
            ),
          ],
        ),
      ),
    );
  }
}
