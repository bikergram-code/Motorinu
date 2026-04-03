import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/community.dart';

class MatchOverlay extends StatefulWidget {
  const MatchOverlay({
    super.key,
    required this.matchData,
    required this.myAvatarUrl,
    required this.community,
    required this.onMessage,
    required this.onContinue,
  });

  final Map<String, dynamic> matchData;
  final String? myAvatarUrl;
  final Community community;
  final VoidCallback onMessage;
  final VoidCallback onContinue;

  @override
  State<MatchOverlay> createState() => _MatchOverlayState();
}

class _MatchOverlayState extends State<MatchOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.community.accentColor;
    // The matched user's avatar (from the candidate data already in the notifier)
    final matchedAvatarUrl = widget.matchData['matched_avatar_url'] as String?;

    return FadeTransition(
      opacity: _fadeAnim,
      child: Material(
        color: Colors.black.withValues(alpha: 0.85),
        child: Center(
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Avatars with heart ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildAvatar(widget.myAvatarUrl, accent),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(
                          Icons.favorite_rounded,
                          color: accent,
                          size: 40,
                        ),
                      ),
                      _buildAvatar(matchedAvatarUrl, accent),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── Title ──
                  Text(
                    'Es ist ein Match! 🔥',
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: accent,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Ihr mögt euch beide! Schreib eine Nachricht.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── Send message button ──
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: widget.onMessage,
                      icon: const Icon(Icons.chat_bubble_rounded, size: 20),
                      label: Text(
                        'Nachricht senden',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Continue swiping button ──
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: widget.onContinue,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white.withValues(alpha: 0.8),
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Weiter swipen',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String? url, Color accent) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: accent, width: 3),
      ),
      child: ClipOval(
        child: url != null && url.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                width: 80,
                height: 80,
                errorWidget: (_, __, ___) => Container(
                  color: accent.withValues(alpha: 0.2),
                  child: Icon(Icons.person_rounded, color: accent, size: 40),
                ),
              )
            : Container(
                color: accent.withValues(alpha: 0.2),
                child: Icon(Icons.person_rounded, color: accent, size: 40),
              ),
      ),
    );
  }
}
