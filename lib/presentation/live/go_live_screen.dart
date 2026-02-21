import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/community.dart';
import '../../providers/core/providers.dart';
import '../../providers/live/live_notifier.dart';
import '../../theme/app_theme.dart';
import '../feed/widgets/topic_picker.dart';

/// Screen to start a live broadcast.
class GoLiveScreen extends ConsumerStatefulWidget {
  const GoLiveScreen({super.key});

  @override
  ConsumerState<GoLiveScreen> createState() => _GoLiveScreenState();
}

class _GoLiveScreenState extends ConsumerState<GoLiveScreen> {
  final _titleController = TextEditingController();
  final List<int> _selectedTopicIds = [];
  bool _isStarting = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _startLive() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte gib einen Titel ein'),
          backgroundColor: Color(0xFF2A2A2A),
        ),
      );
      return;
    }

    setState(() => _isStarting = true);
    HapticFeedback.heavyImpact();

    try {
      final community = ref.read(communityProvider)?.name ?? 'bikergram';
      await ref.read(goLiveProvider.notifier).goLive(
            title: title,
            topicId: _selectedTopicIds.isNotEmpty ? _selectedTopicIds.first : null,
            community: community,
          );

      if (!mounted) return;

      // Navigate to broadcast view
      final goLiveState = ref.read(goLiveProvider);
      if (goLiveState.isLive && goLiveState.session != null) {
        // Replace current screen with broadcast mode
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => _BroadcastActiveScreen(
              sessionId: goLiveState.session!.id,
              title: title,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler: $e'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final community = ref.watch(communityProvider);
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final accentColor = community?.accentColor ?? AppTheme.accentDark;
    final textColor = community?.textColor(brightness) ??
        (isDark ? Colors.white : const Color(0xFF1A1A1A));
    final mutedColor = community?.textMutedColor(brightness) ??
        (isDark
            ? Colors.white.withValues(alpha: 0.4)
            : const Color(0xFF9E9E9E));
    final cardBg = community?.cardFor(brightness) ??
        (isDark ? const Color(0xFF1A1A1A) : Colors.white);

    return Scaffold(
      backgroundColor:
          community?.scaffoldFor(brightness) ?? (isDark ? Colors.black : const Color(0xFFF5F5F5)),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(Icons.close_rounded, color: textColor),
        ),
        title: Text(
          'Go Live',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Camera preview placeholder
            Container(
              height: 280,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red.withValues(alpha: 0.1),
                      ),
                      child: Icon(
                        Icons.videocam_rounded,
                        size: 36,
                        color: Colors.red.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Kamera-Vorschau',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textColor.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'AWS IVS SDK wird in einem späteren Update integriert',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: mutedColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Title input
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: TextField(
                controller: _titleController,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: textColor,
                ),
                decoration: InputDecoration(
                  hintText: 'Titel deines Streams...',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 16,
                    color: mutedColor,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                  prefixIcon: Icon(Icons.title_rounded, color: mutedColor),
                ),
                maxLength: 100,
                maxLines: 1,
              ),
            ),

            const SizedBox(height: 16),

            // Topic picker
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: TopicPicker(
                selectedTopicIds: _selectedTopicIds,
                maxTopics: 1,
                onChanged: (ids) => setState(() {
                  _selectedTopicIds.clear();
                  _selectedTopicIds.addAll(ids);
                }),
              ),
            ),

            const SizedBox(height: 24),

            // Community info
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: accentColor, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Dein Stream wird in der ${community?.displayName ?? 'Community'}-Community live sein.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: accentColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Go Live button
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isStarting ? null : _startLive,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.red.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _isStarting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.videocam_rounded, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'Go Live',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Active broadcast screen (shown while streaming).
class _BroadcastActiveScreen extends ConsumerStatefulWidget {
  const _BroadcastActiveScreen({
    required this.sessionId,
    required this.title,
  });

  final String sessionId;
  final String title;

  @override
  ConsumerState<_BroadcastActiveScreen> createState() =>
      _BroadcastActiveScreenState();
}

class _BroadcastActiveScreenState
    extends ConsumerState<_BroadcastActiveScreen> {
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    // Start a timer to show elapsed time
    _startTimer();
  }

  void _startTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _elapsed += const Duration(seconds: 1));
      return true;
    });
  }

  Future<void> _endLive() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text('Stream beenden?',
            style: GoogleFonts.inter(color: Colors.white)),
        content: Text('Dein Live-Stream wird für alle Zuschauer beendet.',
            style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.6))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Beenden',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(goLiveProvider.notifier).endLive();
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final community = ref.watch(communityProvider);
    final accentColor = community?.accentColor ?? AppTheme.accentDark;
    final goLiveState = ref.watch(goLiveProvider);

    final elapsedStr = _formatElapsed(_elapsed);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview placeholder
          Container(
            color: const Color(0xFF111111),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.videocam_rounded,
                      size: 60,
                      color: Colors.red.withValues(alpha: 0.3)),
                  const SizedBox(height: 12),
                  Text(
                    'Kamera-Stream aktiv',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'IVS Broadcast SDK wird hier eingebunden',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    // LIVE badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
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
                          const SizedBox(width: 6),
                          Text(
                            'LIVE',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Elapsed time
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        elapsedStr,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Viewer count
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.visibility_rounded,
                              color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '${goLiveState.viewerCount}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom controls
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Title
                    Text(
                      widget.title,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // End button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _endLive,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Stream beenden',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
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
    );
  }

  String _formatElapsed(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) return '$hours:$minutes:$seconds';
    return '$minutes:$seconds';
  }
}
