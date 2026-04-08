import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/community.dart';
import '../../../data/repositories/message_repository.dart';

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

  // Heart rain controllers
  late final ConfettiController _confettiCenter;
  late final ConfettiController _confettiLeft;
  late final ConfettiController _confettiRight;

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

    // Heart rain
    _confettiCenter = ConfettiController(duration: const Duration(seconds: 8));
    _confettiLeft = ConfettiController(duration: const Duration(seconds: 8));
    _confettiRight = ConfettiController(duration: const Duration(seconds: 8));
    _confettiCenter.play();
    _confettiLeft.play();
    _confettiRight.play();
  }

  @override
  void dispose() {
    _controller.dispose();
    try { _confettiCenter.dispose(); } catch (_) {}
    try { _confettiLeft.dispose(); } catch (_) {}
    try { _confettiRight.dispose(); } catch (_) {}
    super.dispose();
  }

  /// Heart-shaped particle path
  Path _heartPath(Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path();
    path.moveTo(w / 2, h * 0.35);
    path.cubicTo(w * 0.15, 0, 0, h * 0.4, w / 2, h);
    path.moveTo(w / 2, h * 0.35);
    path.cubicTo(w * 0.85, 0, w, h * 0.4, w / 2, h);
    path.close();
    return path;
  }

  static const _heartColors = [
    Color(0xFFE91E63), // Pink
    Color(0xFFF44336), // Red
    Color(0xFFFF4081), // Pink Accent
    Color(0xFFFF1744), // Red Accent
    Color(0xFFE040FB), // Purple Accent
    Color(0xFFFF6090), // Light Pink
    Color(0xFFD50000), // Deep Red
    Color(0xFFFF80AB), // Soft Pink
  ];

  @override
  Widget build(BuildContext context) {
    final accent = widget.community.accentColor;
    final matchedAvatarUrl = widget.matchData['matched_avatar_url'] as String?;
    final convId = widget.matchData['conversation_id'] as int?;

    return FadeTransition(
      opacity: _fadeAnim,
      child: Material(
        color: Colors.black.withValues(alpha: 0.85),
        child: Stack(
          children: [
            // Heart rain — center
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiCenter,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: true,
                numberOfParticles: 50,
                maxBlastForce: 15,
                minBlastForce: 5,
                emissionFrequency: 0.06,
                gravity: 0.15,
                createParticlePath: _heartPath,
                colors: _heartColors,
              ),
            ),
            // Heart rain — left
            Align(
              alignment: Alignment.topLeft,
              child: ConfettiWidget(
                confettiController: _confettiLeft,
                blastDirection: -1.0,
                shouldLoop: true,
                numberOfParticles: 25,
                maxBlastForce: 12,
                minBlastForce: 4,
                emissionFrequency: 0.05,
                gravity: 0.12,
                createParticlePath: _heartPath,
                colors: _heartColors,
              ),
            ),
            // Heart rain — right
            Align(
              alignment: Alignment.topRight,
              child: ConfettiWidget(
                confettiController: _confettiRight,
                blastDirection: -2.1,
                shouldLoop: true,
                numberOfParticles: 25,
                maxBlastForce: 12,
                minBlastForce: 4,
                emissionFrequency: 0.05,
                gravity: 0.12,
                createParticlePath: _heartPath,
                colors: _heartColors,
              ),
            ),
            // Content
            Center(
              child: ScaleTransition(
                scale: _scaleAnim,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Avatars with heart
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildAvatar(widget.myAvatarUrl, accent),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Icon(
                              Icons.favorite_rounded,
                              color: Colors.pinkAccent,
                              size: 40,
                            ),
                          ),
                          _buildAvatar(matchedAvatarUrl, accent),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Title
                      Text(
                        'Es ist ein Match! 💕',
                        style: GoogleFonts.inter(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.pinkAccent,
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

                      const SizedBox(height: 28),

                      // Send message button
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

                      const SizedBox(height: 10),

                      // Send contact details button
                      if (convId != null)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _showContactSheet(context, convId, accent),
                            icon: const Text('💌', style: TextStyle(fontSize: 18)),
                            label: Text(
                              'Kontaktdaten senden',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.pinkAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 10),

                      // Continue swiping button
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
          ],
        ),
      ),
    );
  }

  void _showContactSheet(BuildContext context, int convId, Color accent) {
    final addrCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final textCol = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final subCol = isDark ? Colors.white54 : Colors.black54;

    // Pre-fill from profile
    _prefillContactData(addrCtrl, phoneCtrl);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(
              color: isDark ? Colors.white12 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            )),
            const SizedBox(height: 16),
            Text('💌 Kontaktdaten senden', style: GoogleFonts.inter(
              fontSize: 20, fontWeight: FontWeight.w800, color: textCol,
            )),
            const SizedBox(height: 6),
            Text('Teile deine Kontaktdaten mit deinem Match', style: GoogleFonts.inter(
              fontSize: 13, color: subCol,
            )),
            const SizedBox(height: 20),

            // Address (optional)
            TextField(
              controller: addrCtrl,
              style: TextStyle(color: textCol),
              decoration: InputDecoration(
                labelText: '📍 Adresse (optional)',
                labelStyle: TextStyle(color: subCol, fontSize: 14),
                hintText: 'Straße, PLZ Ort',
                hintStyle: TextStyle(color: subCol.withValues(alpha: 0.5)),
                filled: true,
                fillColor: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(Icons.location_on_outlined, color: Colors.pinkAccent, size: 20),
              ),
            ),
            const SizedBox(height: 12),

            // Phone (optional)
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              style: TextStyle(color: textCol),
              decoration: InputDecoration(
                labelText: '📞 Telefonnummer (optional)',
                labelStyle: TextStyle(color: subCol, fontSize: 14),
                hintText: '+49 ...',
                hintStyle: TextStyle(color: subCol.withValues(alpha: 0.5)),
                filled: true,
                fillColor: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(Icons.phone_outlined, color: Colors.pinkAccent, size: 20),
              ),
            ),
            const SizedBox(height: 16),

            // Love icons to send
            Text('Liebesgruß mitsenden:', style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w600, color: subCol,
            )),
            const SizedBox(height: 8),
            _LoveIconRow(
              onSend: (emoji) => _sendContactMessage(ctx, convId, addrCtrl.text, phoneCtrl.text, emoji),
              accent: accent,
            ),

            const SizedBox(height: 16),

            // Send button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _sendContactMessage(ctx, convId, addrCtrl.text, phoneCtrl.text, null),
                icon: const Icon(Icons.send_rounded, size: 18),
                label: Text('Senden', style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700, fontSize: 15,
                )),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pinkAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _prefillContactData(TextEditingController addrCtrl, TextEditingController phoneCtrl) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('phone, postal_code')
          .eq('id', userId)
          .maybeSingle();
      if (profile != null) {
        if (profile['phone'] != null) phoneCtrl.text = profile['phone'] as String;
        if (profile['postal_code'] != null) addrCtrl.text = profile['postal_code'] as String;
      }
    } catch (_) {}
  }

  Future<void> _sendContactMessage(BuildContext ctx, int convId, String address, String phone, String? emoji) async {
    final parts = <String>[];
    if (emoji != null) parts.add(emoji);
    parts.add('💌 Kontaktdaten:');
    if (address.trim().isNotEmpty) parts.add('📍 $address');
    if (phone.trim().isNotEmpty) parts.add('📞 $phone');
    if (parts.length <= 2 && emoji == null) {
      // Nothing entered — just send a love emoji
      parts.clear();
      parts.add('💕');
    }

    final body = parts.join('\n');

    try {
      await MessageRepository().sendMessage(convId, body);
      if (ctx.mounted) {
        Navigator.pop(ctx);
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Text('💌 Kontaktdaten gesendet!'),
          backgroundColor: Colors.pinkAccent,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Text('Fehler: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Widget _buildAvatar(String? url, Color accent) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.pinkAccent, width: 3),
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

/// Row of love emoji chips
class _LoveIconRow extends StatelessWidget {
  final void Function(String emoji) onSend;
  final Color accent;
  const _LoveIconRow({required this.onSend, required this.accent});

  static const _emojis = ['💕', '😘', '🥰', '❤️‍🔥', '💋', '🌹', '💖'];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _emojis.map((e) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: ActionChip(
            label: Text(e, style: const TextStyle(fontSize: 22)),
            backgroundColor: Colors.pinkAccent.withValues(alpha: 0.1),
            side: BorderSide(color: Colors.pinkAccent.withValues(alpha: 0.2)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onPressed: () => onSend(e),
          ),
        )).toList(),
      ),
    );
  }
}
